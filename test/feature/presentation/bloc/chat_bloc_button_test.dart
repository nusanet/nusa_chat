import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/use_cases/connect_chat_socket/connect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/disconnect_chat_socket/disconnect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_history/get_chat_history.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_button_reply/send_chat_button_reply.dart';
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
  const tButton = ChatButton(id: 'naila_helpdesk_btn', title: 'Hubungi Helpdesk');
  final tAgent = ChatMessage(
    id: 'a-1',
    localId: 'a-1',
    text: 'Maaf',
    type: ChatMessageType.interactive,
    buttons: const [tButton],
    isMine: false,
    createdAt: DateTime.utc(2026),
  );
  const tTap = ChatButtonReplySubmitted(messageLocalId: 'a-1', button: tButton);

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => Right([tAgent]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.sendButtonReply(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<ChatBloc> started() async {
    final bloc = ChatBloc(
      startChatSession: StartChatSession(repository: mockRepository),
      getChatHistory: GetChatHistory(repository: mockRepository),
      connectChatSocket: ConnectChatSocket(repository: mockRepository),
      sendChatText: SendChatText(repository: mockRepository),
      sendChatMedia: SendChatMedia(repository: mockRepository),
      sendChatLocation: SendChatLocation(repository: mockRepository),
      sendChatButtonReply: SendChatButtonReply(repository: mockRepository),
      disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
      reconnectDelay: (_) => Duration.zero,
    )..add(const ChatStarted());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);
    socket.add(const ChatSocketOpened());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connected);
    return bloc;
  }

  test('pastikan tap tombol jadi pesan optimistis lalu sent setelah ack', () async {
    final bloc = await started();

    bloc.add(tTap);
    final pending = await bloc.stream.firstWhere((s) => s.messages.length == 2);
    expect(pending.messages.last.text, 'Hubungi Helpdesk');
    expect(pending.messages.last.type, ChatMessageType.interactive);
    expect(pending.messages.last.buttonReply, tButton);
    expect(pending.messages.last.isMine, isTrue);
    expect(pending.messages.last.status, ChatMessageStatus.pending);
    verify(mockRepository.sendButtonReply(tSession, tButton));

    socket.add(const ChatSocketAck(messageId: 'm-9'));
    final acked = await bloc.stream.firstWhere((s) => s.messages.last.status == ChatMessageStatus.sent);
    expect(acked.messages.last.id, 'm-9');
    await bloc.close();
  });

  test('pastikan double tap hanya mengirim satu balasan', () async {
    final bloc = await started();

    bloc
      ..add(tTap)
      ..add(tTap);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.messages, hasLength(2));
    verify(mockRepository.sendButtonReply(tSession, tButton)).called(1);
    await bloc.close();
  });

  test('pastikan pesan yang tidak dikenal diabaikan', () async {
    final bloc = await started();

    bloc.add(const ChatButtonReplySubmitted(messageLocalId: 'tidak-ada', button: tButton));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.messages, [tAgent]);
    verifyNever(mockRepository.sendButtonReply(any, any));
    await bloc.close();
  });

  test('pastikan balasan gagal bisa dikirim ulang tanpa tombol terbuka lagi', () async {
    when(mockRepository.sendButtonReply(any, any)).thenAnswer((_) async => Left(ConnectionFailure()));
    final bloc = await started();

    bloc.add(tTap);
    final failed = await bloc.stream.firstWhere(
      (s) => s.messages.length == 2 && s.messages.last.status == ChatMessageStatus.failed,
    );
    expect(tAgent.isAnsweredBy(failed.messages.skip(1)), isTrue);

    when(mockRepository.sendButtonReply(any, any)).thenAnswer((_) async => const Right('m-10'));
    bloc.add(ChatMessageRetried(localId: failed.messages.last.localId));
    final sent = await bloc.stream.firstWhere((s) => s.messages.last.id == 'm-10');

    expect(sent.messages, hasLength(2));
    expect(sent.messages.last.status, ChatMessageStatus.sent);
    expect(sent.messages.last.buttonReply, tButton);
    verify(mockRepository.sendButtonReply(tSession, tButton)).called(2);
    await bloc.close();
  });

  test('pastikan salinan server dari balasan pending tidak jadi bubble ganda saat resync', () async {
    final bloc = await started();
    bloc.add(tTap);
    await bloc.stream.firstWhere((s) => s.messages.length == 2);

    final serverCopy = ChatMessage(
      id: 'm-11',
      localId: 'm-11',
      text: 'Hubungi Helpdesk',
      type: ChatMessageType.interactive,
      buttonReply: tButton,
      isMine: true,
      createdAt: DateTime.utc(2026, 1, 2),
    );
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => Right([serverCopy]));
    socket
      ..add(const ChatSocketClosed(code: 1006))
      ..add(const ChatSocketOpened());
    final synced = await bloc.stream.firstWhere((s) => s.messages.last.id == 'm-11');

    expect(synced.messages, hasLength(2));
    expect(synced.messages.last.status, ChatMessageStatus.sent);
    await bloc.close();
  });
}
