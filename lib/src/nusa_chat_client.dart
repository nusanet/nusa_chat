import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/foundation.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_conversation.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_conversations/get_chat_conversations.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_conversation_messages/get_conversation_messages.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_visitor_messages/get_visitor_messages.dart';
import 'package:nusa_chat/src/features/domain/use_cases/start_chat_session/start_chat_session.dart';
import 'package:nusa_chat/src/injection_container.dart';

/// Talks to the bridge outside `NusaChatPage`, for the host app's own views
/// (e.g. a "continue chat" entry). Nothing here opens the socket.
///
/// ```dart
/// final client = NusaChatClient(config);
/// final session = await client.getActiveSession();
/// await client.dispose();
/// ```
///
/// Methods throw [NusaChatException] when the request fails.
class NusaChatClient {
  final ChatRepository Function() _repository;
  final Future<void> Function()? _onDispose;

  // Resolved on first use, so creating a client costs nothing.
  late final _startChatSession = StartChatSession(repository: _repository());
  late final _getChatConversations = GetChatConversations(repository: _repository());
  late final _getVisitorMessages = GetVisitorMessages(repository: _repository());
  late final _getConversationMessages = GetConversationMessages(repository: _repository());

  NusaChatClient._(this._repository, this._onDispose);

  factory NusaChatClient(NusaChatConfig config) {
    final injector = NusaChatInjector.init(config);
    return NusaChatClient._(() => injector.sl(), injector.dispose);
  }

  @visibleForTesting
  factory NusaChatClient.withRepository(ChatRepository repository) => NusaChatClient._(() => repository, null);

  /// The visitor's open conversation, from the server (`POST .../sessions`,
  /// the same bootstrap the chat screen does — it also sends
  /// [NusaChatConfig.fcmToken]). When none is open, e.g. the last one was
  /// closed after 24h idle, the server opens a new one.
  Future<ChatSession> getActiveSession() async => _unwrap(await _startChatSession(NoParams()));

  /// A page of the visitor's conversations, open and closed, sorted by last
  /// activity (`GET .../visitors/{visitor_id}/conversations`). [page] and
  /// [limit] must be positive.
  ///
  /// The visitor is [NusaChatConfig.visitorId], or the one remembered from an
  /// earlier chat. Without either the page is empty; nothing is opened on the
  /// server. An id the server does not know throws with status 404.
  Future<ChatConversationPage> getConversations({
    ChatConversationOrder order = ChatConversationOrder.desc,
    int page = 1,
    int limit = 20,
  }) async {
    return _unwrap(await _getChatConversations(ParamsGetChatConversations(order: order, page: page, limit: limit)));
  }

  /// The messages of one conversation from [getConversations], open or closed,
  /// oldest first (`GET .../conversations/{conversation_id}/messages`).
  Future<List<ChatMessage>> getConversationMessages(String conversationId) async {
    return _unwrap(await _getConversationMessages(ParamsGetConversationMessages(conversationId: conversationId)));
  }

  /// The visitor's messages across all conversations, newest first
  /// (`GET .../visitors/{visitor_id}/messages`): at most [limit], which must
  /// be positive, and only those after [since] when given. Group them with
  /// [ChatMessage.conversationId].
  ///
  /// The visitor is resolved as in [getConversations]; without one the list is
  /// empty. An id the server does not know throws with status 404.
  Future<List<ChatMessage>> getVisitorMessages({int limit = 50, DateTime? since}) async {
    return _unwrap(await _getVisitorMessages(ParamsGetVisitorMessages(limit: limit, since: since)));
  }

  Future<void> dispose() async => _onDispose?.call();

  static T _unwrap<T>(Either<Failure, T> result) {
    return result.fold(
      (failure) => throw NusaChatException(
        failure.message,
        statusCode: failure is ServerFailure ? failure.dataApiFailure.statusCode : null,
      ),
      (value) => value,
    );
  }
}

/// A [NusaChatClient] request failed; [message] can be shown to the user.
class NusaChatException implements Exception {
  final String message;

  /// HTTP status of a server error; null for connection and parsing errors.
  final int? statusCode;

  const NusaChatException(this.message, {this.statusCode});

  @override
  String toString() => 'NusaChatException{message: $message, statusCode: $statusCode}';
}
