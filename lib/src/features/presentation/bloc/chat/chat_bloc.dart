import 'dart:async';
import 'dart:math' as math;

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/core/util/constant_error_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/use_cases/connect_chat_socket/connect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/disconnect_chat_socket/disconnect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_history/get_chat_history.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_location/send_chat_location.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_media/send_chat_media.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_text/send_chat_text.dart';
import 'package:nusa_chat/src/features/domain/use_cases/start_chat_session/start_chat_session.dart';

import './bloc.dart';

/// Drives one chat screen: session bootstrap, history, the real-time socket
/// (with reconnect + resync) and optimistic sending.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final StartChatSession startChatSession;
  final GetChatHistory getChatHistory;
  final ConnectChatSocket connectChatSocket;
  final SendChatText sendChatText;
  final SendChatMedia sendChatMedia;
  final SendChatLocation sendChatLocation;
  final DisconnectChatSocket disconnectChatSocket;

  /// Delay before reconnect attempt `n` (0-based). Exponential, 1s → 30s.
  final Duration Function(int attempt) reconnectDelay;

  ChatBloc({
    required this.startChatSession,
    required this.getChatHistory,
    required this.connectChatSocket,
    required this.sendChatText,
    required this.sendChatMedia,
    required this.sendChatLocation,
    required this.disconnectChatSocket,
    Duration Function(int attempt)? reconnectDelay,
  }) : reconnectDelay = reconnectDelay ?? _defaultReconnectDelay,
       super(const ChatState()) {
    on<ChatStarted>(_onChatStarted);
    on<ChatTextSubmitted>(_onChatTextSubmitted);
    on<ChatAttachmentsSubmitted>(_onChatAttachmentsSubmitted);
    on<ChatLocationSubmitted>(_onChatLocationSubmitted);
    on<ChatNoticeRequested>((event, emit) => _notify(emit, event.message));
    on<ChatMessageRetried>(_onChatMessageRetried);
    on<ChatReconnectRequested>(_onChatReconnectRequested);
    on<ChatPaused>(_onChatPaused);
    on<ChatSocketEventReceived>(_onChatSocketEventReceived);
  }

  static Duration _defaultReconnectDelay(int attempt) => Duration(seconds: math.min(30, math.pow(2, attempt).toInt()));

  ChatSession? _session;
  StreamSubscription<ChatSocketEvent>? _socketSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _hasConnectedOnce = false;
  bool _sessionRenewed = false;
  bool _paused = false;
  int _localSequence = 0;

  /// Local ids of messages sent over the socket and not yet acked, oldest
  /// first. Acks carry no client id, so they answer these in order — an
  /// upload still in progress is pending too, but must not take an ack.
  final List<String> _awaitingAck = [];
  int _noticeSequence = 0;

  FutureOr<void> _onChatStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(status: ChatViewStatus.loading));

    final sessionResult = await startChatSession(NoParams());
    final session = sessionResult.fold((failure) => null, (session) => session);
    if (session == null) {
      final message = sessionResult.fold((failure) => failure.message, (_) => '');
      emit(state.copyWith(status: ChatViewStatus.failure, errorMessage: message));
      return;
    }
    _session = session;

    final historyResult = await getChatHistory(ParamsGetChatHistory(session: session));
    final failed = historyResult.fold((failure) => failure, (_) => null);
    if (failed != null) {
      emit(state.copyWith(status: ChatViewStatus.failure, errorMessage: failed.message));
      return;
    }

    final history = historyResult.getOrElse(() => const []);
    emit(state.copyWith(status: ChatViewStatus.loaded, messages: _merge(state.messages, history)));
    _connect(emit);
  }

  void _connect(Emitter<ChatState> emit) {
    final session = _session;
    if (session == null || isClosed || _paused) return;
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    emit(state.copyWith(connection: ChatConnectionStatus.connecting));
    _socketSubscription = connectChatSocket(ParamsConnectChatSocket(session: session)).listen((socketEvent) {
      if (!isClosed) add(ChatSocketEventReceived(event: socketEvent));
    });
  }

  FutureOr<void> _onChatSocketEventReceived(ChatSocketEventReceived event, Emitter<ChatState> emit) async {
    final socketEvent = event.event;
    switch (socketEvent) {
      case ChatSocketOpened():
        _reconnectAttempt = 0;
        _sessionRenewed = false;
        emit(state.copyWith(connection: ChatConnectionStatus.connected));
        if (_hasConnectedOnce) await _resync(emit);
        _hasConnectedOnce = true;
      case ChatSocketAck(:final messageId):
        _updateOldestPending(emit, (message) => message.copyWith(id: messageId, status: ChatMessageStatus.sent));
      case ChatSocketError(:final error):
        _updateOldestPending(emit, (message) => message.copyWith(status: ChatMessageStatus.failed, error: error));
        if (socketEvent.isRateLimited) _notify(emit, ConstantErrorMessage.rateLimited);
      case ChatSocketIncomingMessage(:final message):
        emit(state.copyWith(messages: _merge(state.messages, [message])));
      case ChatSocketUnknown():
        break;
      case ChatSocketClosed():
        await _onSocketClosed(socketEvent, emit);
    }
  }

  Future<void> _onSocketClosed(ChatSocketClosed closed, Emitter<ChatState> emit) async {
    _socketSubscription = null;
    emit(state.copyWith(connection: ChatConnectionStatus.disconnected));
    if (isClosed || _paused) return;

    // The conversation was closed (24h idle) or the session is no longer
    // valid: bootstrap again once — same visitor_id, new conversation.
    if (closed.isSessionRejected && !_sessionRenewed) {
      _sessionRenewed = true;
      final result = await startChatSession(NoParams());
      final session = result.fold((_) => null, (session) => session);
      if (session != null) {
        _session = session;
        _connect(emit);
        return;
      }
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = reconnectDelay(_reconnectAttempt);
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      if (!isClosed) add(const ChatReconnectRequested());
    });
  }

  FutureOr<void> _onChatReconnectRequested(ChatReconnectRequested event, Emitter<ChatState> emit) {
    _paused = false;
    if (_session == null) {
      if (state.status == ChatViewStatus.failure) add(const ChatStarted());
      return null;
    }
    if (state.connection != ChatConnectionStatus.disconnected) return null;
    _connect(emit);
  }

  FutureOr<void> _onChatPaused(ChatPaused event, Emitter<ChatState> emit) async {
    _paused = true;
    _reconnectTimer?.cancel();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await disconnectChatSocket(NoParams());
    emit(state.copyWith(connection: ChatConnectionStatus.disconnected));
  }

  /// Fetch what arrived while disconnected (agent replies are not queued for
  /// offline visitors — they are only in the history).
  Future<void> _resync(Emitter<ChatState> emit) async {
    final session = _session;
    if (session == null) return;
    final since = _lastServerTimestamp();
    final result = await getChatHistory(ParamsGetChatHistory(session: session, since: since));
    result.fold((_) {}, (messages) => emit(state.copyWith(messages: _merge(state.messages, messages))));
  }

  DateTime? _lastServerTimestamp() {
    for (final message in state.messages.reversed) {
      if (message.id != null && message.status == ChatMessageStatus.sent) return message.createdAt;
    }
    return null;
  }

  FutureOr<void> _onChatTextSubmitted(ChatTextSubmitted event, Emitter<ChatState> emit) async {
    final text = event.text.trim();
    if (text.isEmpty) return;
    await _send(text, emit);
  }

  FutureOr<void> _onChatMessageRetried(ChatMessageRetried event, Emitter<ChatState> emit) async {
    final index = state.messages.indexWhere((message) => message.localId == event.localId);
    if (index < 0 || state.messages[index].status != ChatMessageStatus.failed) return;
    final failed = state.messages[index];
    emit(state.copyWith(messages: [...state.messages]..removeAt(index)));
    switch (failed.type) {
      case ChatMessageType.image || ChatMessageType.document || ChatMessageType.audio:
        final media = failed.media;
        if (media?.localPath == null) return;
        await _sendAttachment(
          ChatAttachment(
            type: failed.type,
            path: media!.localPath!,
            fileName: media.fileName ?? media.localPath!.split('/').last,
            mimeType: media.mimeType ?? 'application/octet-stream',
            size: media.size ?? 0,
            duration: media.duration,
            caption: failed.text,
          ),
          emit,
          uploaded: media.mediaId,
        );
      case ChatMessageType.location:
        if (failed.location != null) await _sendLocation(failed.location!, emit);
      case ChatMessageType.text || ChatMessageType.unknown:
        await _send(failed.text, emit);
    }
  }

  ChatMessage _pending(ChatMessageType type, {String text = '', ChatMedia? media, ChatLocation? location}) {
    return ChatMessage(
      localId: 'local-${DateTime.now().microsecondsSinceEpoch}-${_localSequence++}',
      text: text,
      type: type,
      media: media,
      location: location,
      isMine: true,
      createdAt: DateTime.now(),
      status: ChatMessageStatus.pending,
    );
  }

  Future<void> _send(String text, Emitter<ChatState> emit) async {
    final pending = _pending(ChatMessageType.text, text: text);
    emit(state.copyWith(messages: [...state.messages, pending]));

    final session = _session;
    if (session == null) {
      _replace(emit, pending.localId, (message) => message.copyWith(status: ChatMessageStatus.failed));
      return;
    }

    final result = await sendChatText(ParamsSendChatText(session: session, text: text));
    _onSent(emit, pending.localId, result.map((messageId) => messageId));
  }

  FutureOr<void> _onChatAttachmentsSubmitted(ChatAttachmentsSubmitted event, Emitter<ChatState> emit) async {
    // One by one, so the agent receives them in the order they were picked.
    for (final attachment in event.attachments) {
      if (isClosed) return;
      await _sendAttachment(attachment, emit);
    }
  }

  /// [uploaded] is the `media_id` of a retry whose upload already succeeded.
  Future<void> _sendAttachment(ChatAttachment attachment, Emitter<ChatState> emit, {String? uploaded}) async {
    final pending = _pending(
      attachment.type,
      text: attachment.caption,
      media: attachment.toMedia().copyWith(mediaId: uploaded),
    );
    emit(
      state.copyWith(
        messages: [
          ...state.messages,
          pending.copyWith(uploadProgress: uploaded == null ? 0 : null),
        ],
      ),
    );

    final session = _session;
    if (session == null) {
      _replace(emit, pending.localId, (message) => message.copyWith(status: ChatMessageStatus.failed));
      return;
    }

    var lastProgress = 0.0;
    final result = await sendChatMedia(
      ParamsSendChatMedia(
        session: session,
        attachment: attachment,
        uploaded: uploaded == null ? null : UploadedMedia(mediaId: uploaded, messageType: attachment.type.name),
        onProgress: (progress) {
          // Every 5% is plenty for a progress ring.
          if (progress - lastProgress < 0.05 && progress < 1) return;
          lastProgress = progress;
          if (!emit.isDone) _replace(emit, pending.localId, (message) => message.copyWith(uploadProgress: progress));
        },
        onUploaded: (media, url) {
          if (emit.isDone) return;
          _replace(
            emit,
            pending.localId,
            (message) => message.copyWith(
              media: message.media?.copyWith(mediaId: media.mediaId, url: url),
            ),
          );
        },
      ),
    );
    _onSent(emit, pending.localId, result.map((sent) => sent.messageId));
  }

  FutureOr<void> _onChatLocationSubmitted(ChatLocationSubmitted event, Emitter<ChatState> emit) async {
    await _sendLocation(event.location, emit);
  }

  Future<void> _sendLocation(ChatLocation location, Emitter<ChatState> emit) async {
    final pending = _pending(ChatMessageType.location, location: location);
    emit(state.copyWith(messages: [...state.messages, pending]));

    final session = _session;
    if (session == null) {
      _replace(emit, pending.localId, (message) => message.copyWith(status: ChatMessageStatus.failed));
      return;
    }

    final result = await sendChatLocation(ParamsSendChatLocation(session: session, location: location));
    _onSent(emit, pending.localId, result);
  }

  /// Sent over HTTP: saved already (a `message_id`). Over WS: wait for the ack.
  void _onSent(Emitter<ChatState> emit, String localId, Either<Failure, String?> result) {
    if (emit.isDone) return;
    result.fold(
      (failure) => _replace(
        emit,
        localId,
        (message) => message.copyWith(status: ChatMessageStatus.failed, error: failure.message),
      ),
      (messageId) {
        if (messageId != null) {
          _replace(emit, localId, (message) => message.copyWith(id: messageId, status: ChatMessageStatus.sent));
        } else {
          _awaitingAck.add(localId);
        }
      },
    );
  }

  void _replace(Emitter<ChatState> emit, String localId, ChatMessage Function(ChatMessage) update) {
    final messages = [for (final message in state.messages) message.localId == localId ? update(message) : message];
    emit(state.copyWith(messages: messages));
  }

  /// Acks and errors carry no client id: they answer the oldest message still
  /// waiting for the socket.
  void _updateOldestPending(Emitter<ChatState> emit, ChatMessage Function(ChatMessage) update) {
    while (_awaitingAck.isNotEmpty) {
      final localId = _awaitingAck.removeAt(0);
      final waiting = state.messages.any(
        (m) => m.localId == localId && m.status == ChatMessageStatus.pending && m.id == null,
      );
      if (waiting) {
        _replace(emit, localId, update);
        return;
      }
    }
  }

  void _notify(Emitter<ChatState> emit, String message) {
    emit(
      state.copyWith(
        notice: ChatNotice(id: ++_noticeSequence, message: message),
      ),
    );
  }

  /// Adds [incoming] server messages to [current], skipping known ids. A
  /// server copy of a message still pending locally (sent just before a
  /// disconnect, ack lost) replaces that pending message instead.
  List<ChatMessage> _merge(List<ChatMessage> current, List<ChatMessage> incoming) {
    final result = [...current];
    final knownIds = {for (final message in current) ?message.id};
    for (final message in incoming) {
      if (message.id != null && knownIds.contains(message.id)) continue;
      if (message.isMine) {
        final pendingIndex = result.indexWhere(
          (m) => m.isMine && m.id == null && m.status != ChatMessageStatus.sent && _sameContent(m, message),
        );
        if (pendingIndex >= 0) {
          _awaitingAck.remove(result[pendingIndex].localId);
          // Keep the local file as the preview; take the server's URL.
          final local = result[pendingIndex];
          result[pendingIndex] = local.copyWith(
            id: message.id,
            status: ChatMessageStatus.sent,
            createdAt: message.createdAt,
            media: local.media?.copyWith(url: message.media?.url, mediaId: message.media?.mediaId),
          );
          if (message.id != null) knownIds.add(message.id!);
          continue;
        }
      }
      result.add(message);
      if (message.id != null) knownIds.add(message.id!);
    }
    return result;
  }

  /// Whether [server] is the saved copy of the local [local] message.
  static bool _sameContent(ChatMessage local, ChatMessage server) {
    if (local.type != server.type) return false;
    return switch (local.type) {
      ChatMessageType.image ||
      ChatMessageType.document ||
      ChatMessageType.audio => local.media?.mediaId != null && local.media?.mediaId == server.media?.mediaId,
      ChatMessageType.location => local.location == server.location,
      ChatMessageType.text || ChatMessageType.unknown => local.text == server.text,
    };
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _socketSubscription?.cancel();
    await disconnectChatSocket(NoParams());
    return super.close();
  }
}
