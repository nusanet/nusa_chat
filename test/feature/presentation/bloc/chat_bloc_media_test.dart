import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
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
import 'package:nusa_chat/src/features/presentation/bloc/chat/bloc.dart';

import '../../../helper/mock_helper.mocks.dart';

void main() {
  late MockChatRepository mockRepository;
  late StreamController<ChatSocketEvent> socket;

  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  const tPhoto = ChatAttachment(
    type: ChatMessageType.image,
    path: '/tmp/a.jpg',
    fileName: 'a.jpg',
    mimeType: 'image/jpeg',
    size: 1000,
    caption: 'Lampu LOS',
  );
  const tUploaded = UploadedMedia(mediaId: 'abc', messageType: 'image');

  ChatBloc buildBloc() => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
    reconnectDelay: (_) => Duration.zero,
  );

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(
      mockRepository.mediaUrl(any),
    ).thenAnswer((invocation) => 'https://x/media/${invocation.positionalArguments[0]}');
    when(mockRepository.sendMedia(any, any, caption: anyNamed('caption'))).thenAnswer((_) async => const Right(null));
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<ChatBloc> started() async {
    final bloc = buildBloc()..add(const ChatStarted());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);
    socket.add(const ChatSocketOpened());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connected);
    return bloc;
  }

  test('pastikan foto diunggah dengan progres, dikirim, lalu sent setelah ack', () async {
    when(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress'))).thenAnswer((invocation) async {
      final onProgress = invocation.namedArguments[#onProgress] as void Function(double);
      onProgress(0.5);
      onProgress(1);
      return const Right(tUploaded);
    });
    final bloc = await started();
    final states = <ChatState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(const ChatAttachmentsSubmitted(attachments: [tPhoto]));
    await bloc.stream.firstWhere(
      (s) => s.messages.single.media?.mediaId == 'abc' && s.messages.single.uploadProgress == null,
    );

    final first = states.first.messages.single;
    expect(first.type, ChatMessageType.image);
    expect(first.text, 'Lampu LOS');
    expect(first.media?.localPath, '/tmp/a.jpg');
    expect(first.uploadProgress, 0);
    expect(states.map((s) => s.messages.single.uploadProgress), containsAllInOrder([0.0, 0.5, 1.0]));
    verify(mockRepository.sendMedia(tSession, tUploaded, caption: 'Lampu LOS'));

    socket.add(const ChatSocketAck(messageId: 'm-1'));
    final acked = await bloc.stream.firstWhere((s) => s.messages.single.status == ChatMessageStatus.sent);
    expect(acked.messages.single.id, 'm-1');
    expect(acked.messages.single.media?.url, 'https://x/media/abc');
    await subscription.cancel();
    await bloc.close();
  });

  test('pastikan ack teks tidak jatuh ke foto yang masih diunggah', () async {
    final upload = Completer<Either<Failure, UploadedMedia>>();
    when(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress'))).thenAnswer((_) => upload.future);
    final bloc = await started();

    bloc.add(const ChatAttachmentsSubmitted(attachments: [tPhoto]));
    await bloc.stream.firstWhere((s) => s.messages.length == 1);
    bloc.add(const ChatTextSubmitted(text: 'halo'));
    await bloc.stream.firstWhere((s) => s.messages.length == 2);
    await Future<void>.delayed(Duration.zero);

    socket.add(const ChatSocketAck(messageId: 'm-text'));
    final state = await bloc.stream.firstWhere((s) => s.messages.any((m) => m.id == 'm-text'));
    expect(state.messages.last.text, 'halo');
    expect(state.messages.first.status, ChatMessageStatus.pending);
    expect(state.messages.first.id, isNull);

    upload.complete(const Right(tUploaded));
    await bloc.close();
  });

  test('pastikan upload gagal bisa dikirim ulang tanpa memilih ulang', () async {
    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => Left(ConnectionFailure()));
    final bloc = await started();

    bloc.add(const ChatAttachmentsSubmitted(attachments: [tPhoto]));
    final failed = await bloc.stream.firstWhere((s) => s.messages.single.status == ChatMessageStatus.failed);
    expect(failed.messages.single.uploadProgress, isNull);

    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => const Right(tUploaded));
    when(mockRepository.sendMedia(any, any, caption: anyNamed('caption'))).thenAnswer((_) async => const Right('m-2'));
    bloc.add(ChatMessageRetried(localId: failed.messages.single.localId));
    final sent = await bloc.stream.firstWhere((s) => s.messages.length == 1 && s.messages.single.id == 'm-2');

    expect(sent.messages.single.status, ChatMessageStatus.sent);
    expect(sent.messages.single.text, 'Lampu LOS');
    verify(mockRepository.uploadMedia(tPhoto, onProgress: anyNamed('onProgress'))).called(2);
    await bloc.close();
  });

  test('pastikan kirim ulang setelah upload berhasil tidak mengunggah lagi', () async {
    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => const Right(tUploaded));
    when(
      mockRepository.sendMedia(any, any, caption: anyNamed('caption')),
    ).thenAnswer((_) async => Left(ConnectionFailure()));
    final bloc = await started();

    bloc.add(const ChatAttachmentsSubmitted(attachments: [tPhoto]));
    final failed = await bloc.stream.firstWhere((s) => s.messages.single.status == ChatMessageStatus.failed);
    expect(failed.messages.single.media?.mediaId, 'abc');

    when(mockRepository.sendMedia(any, any, caption: anyNamed('caption'))).thenAnswer((_) async => const Right('m-3'));
    bloc.add(ChatMessageRetried(localId: failed.messages.single.localId));
    await bloc.stream.firstWhere((s) => s.messages.length == 1 && s.messages.single.id == 'm-3');

    verify(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress'))).called(1);
    await bloc.close();
  });

  test('pastikan beberapa foto dikirim berurutan', () async {
    when(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress'))).thenAnswer(
      (invocation) async => Right(
        UploadedMedia(mediaId: (invocation.positionalArguments[0] as ChatAttachment).fileName, messageType: 'image'),
      ),
    );
    final bloc = await started();

    bloc.add(
      ChatAttachmentsSubmitted(
        attachments: [
          tPhoto,
          const ChatAttachment(
            type: ChatMessageType.image,
            path: '/tmp/b.jpg',
            fileName: 'b.jpg',
            mimeType: 'image/jpeg',
            size: 1,
          ),
        ],
      ),
    );
    final state = await bloc.stream.firstWhere(
      (s) => s.messages.length == 2 && s.messages.every((m) => m.media?.mediaId != null),
    );

    expect(state.messages.map((m) => m.media?.fileName), ['a.jpg', 'b.jpg']);
    final sent = verify(mockRepository.sendMedia(tSession, captureAny, caption: anyNamed('caption'))).captured;
    expect(sent.map((m) => (m as UploadedMedia).mediaId), ['a.jpg', 'b.jpg']);
    await bloc.close();
  });

  test('pastikan lokasi dikirim dan cocok dengan salinan server saat resync', () async {
    const location = ChatLocation(latitude: -6.2, longitude: 106.8);
    when(mockRepository.sendLocation(any, any)).thenAnswer((_) async => const Right(null));
    final bloc = await started();

    bloc.add(const ChatLocationSubmitted(location: location));
    final pending = await bloc.stream.firstWhere((s) => s.messages.length == 1);
    expect(pending.messages.single.location, location);
    verify(mockRepository.sendLocation(tSession, location));

    // The ack was lost; the server copy comes back with the history.
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer(
      (_) async => Right([
        ChatMessage(
          id: 'm-9',
          localId: 'm-9',
          text: '',
          type: ChatMessageType.location,
          location: location,
          isMine: true,
          createdAt: DateTime.utc(2026),
        ),
      ]),
    );
    socket.add(const ChatSocketClosed(code: 1006));
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);
    socket.add(const ChatSocketOpened());
    final synced = await bloc.stream.firstWhere((s) => s.messages.single.id == 'm-9');

    expect(synced.messages.single.status, ChatMessageStatus.sent);
    await bloc.close();
  });

  test('pastikan ChatNoticeRequested memunculkan notice', () async {
    final bloc = buildBloc()..add(const ChatNoticeRequested(message: 'File terlalu besar'));
    final state = await bloc.stream.firstWhere((s) => s.notice != null);
    expect(state.notice?.message, 'File terlalu besar');
    await bloc.close();
  });
}
