import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
  final tAgent = ChatMessage(id: 'a-1', localId: 'a-1', text: 'Halo', isMine: false, createdAt: DateTime.utc(2026));

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
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => Right([tAgent]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
  });

  tearDown(() => socket.close());

  /// Starts the bloc and waits until the socket is open.
  Future<ChatBloc> started() async {
    final bloc = buildBloc()..add(const ChatStarted());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);
    socket.add(const ChatSocketOpened());
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connected);
    return bloc;
  }

  test('state awal', () {
    expect(buildBloc().state, const ChatState());
  });

  blocTest<ChatBloc, ChatState>(
    'pastikan session, history lalu koneksi socket berjalan berurutan',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const ChatStarted());
      await Future<void>.delayed(Duration.zero);
      socket.add(const ChatSocketOpened());
    },
    expect: () => [
      const ChatState(status: ChatViewStatus.loading),
      ChatState(status: ChatViewStatus.loaded, messages: [tAgent]),
      ChatState(status: ChatViewStatus.loaded, messages: [tAgent], connection: ChatConnectionStatus.connecting),
      ChatState(status: ChatViewStatus.loaded, messages: [tAgent], connection: ChatConnectionStatus.connected),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'pastikan failure kalau session gagal',
    setUp: () => when(mockRepository.startSession()).thenAnswer((_) async => Left(ConnectionFailure())),
    build: buildBloc,
    act: (bloc) => bloc.add(const ChatStarted()),
    expect: () => [
      const ChatState(status: ChatViewStatus.loading),
      ChatState(status: ChatViewStatus.failure, errorMessage: ConnectionFailure().message),
    ],
  );

  test('pastikan pesan optimistis jadi sent setelah ack', () async {
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
    final bloc = await started();

    bloc.add(const ChatTextSubmitted(text: '  Kapan selesai?  '));
    final pending = await bloc.stream.firstWhere((s) => s.messages.length == 2);
    expect(pending.messages.last.text, 'Kapan selesai?');
    expect(pending.messages.last.status, ChatMessageStatus.pending);
    verify(mockRepository.sendText(tSession, 'Kapan selesai?'));

    socket.add(const ChatSocketAck(messageId: 'm-9'));
    final acked = await bloc.stream.firstWhere((s) => s.messages.last.status == ChatMessageStatus.sent);
    expect(acked.messages.last.id, 'm-9');
    await bloc.close();
  });

  test('pastikan ack menjawab pesan pending tertua lebih dulu (FIFO)', () async {
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
    final bloc = await started();

    bloc
      ..add(const ChatTextSubmitted(text: 'satu'))
      ..add(const ChatTextSubmitted(text: 'dua'));
    await bloc.stream.firstWhere((s) => s.messages.length == 3);
    socket.add(const ChatSocketAck(messageId: 'm-1'));
    final state = await bloc.stream.firstWhere((s) => s.messages.any((m) => m.id == 'm-1'));

    expect(state.messages[1].text, 'satu');
    expect(state.messages[1].status, ChatMessageStatus.sent);
    expect(state.messages[2].status, ChatMessageStatus.pending);
    await bloc.close();
  });

  test('pastikan rate_limited menandai gagal dan memunculkan notice', () async {
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
    final bloc = await started();

    bloc.add(const ChatTextSubmitted(text: 'spam'));
    await bloc.stream.firstWhere((s) => s.messages.length == 2);
    socket.add(const ChatSocketError(error: 'rate_limited'));
    final state = await bloc.stream.firstWhere((s) => s.notice != null);

    expect(state.messages.last.status, ChatMessageStatus.failed);
    await bloc.close();
  });

  test('pastikan pesan gagal bisa dikirim ulang', () async {
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => Left(ConnectionFailure()));
    final bloc = await started();

    bloc.add(const ChatTextSubmitted(text: 'halo'));
    final failed = await bloc.stream.firstWhere((s) => s.messages.last.status == ChatMessageStatus.failed);

    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right('m-5'));
    bloc.add(ChatMessageRetried(localId: failed.messages.last.localId));
    final retried = await bloc.stream.firstWhere((s) => s.messages.last.id == 'm-5');

    expect(retried.messages.length, 2);
    expect(retried.messages.last.status, ChatMessageStatus.sent);
    await bloc.close();
  });

  test('pastikan pesan agent masuk dan tidak terduplikasi', () async {
    final bloc = await started();
    final reply = ChatMessage(
      id: 'a-2',
      localId: 'a-2',
      text: 'Sudah normal',
      isMine: false,
      createdAt: DateTime.now(),
    );

    socket.add(ChatSocketIncomingMessage(message: reply));
    socket.add(ChatSocketIncomingMessage(message: tAgent));
    final state = await bloc.stream.firstWhere((s) => s.messages.length == 2);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.messages, [tAgent, reply]);
    expect(state.messages.last, reply);
    await bloc.close();
  });

  test('pastikan reconnect lalu resync history setelah koneksi putus', () async {
    final bloc = await started();
    final missed = ChatMessage(id: 'a-3', localId: 'a-3', text: 'Terlewat', isMine: false, createdAt: DateTime.now());
    when(
      mockRepository.getMessages(any, since: argThat(isNotNull, named: 'since')),
    ).thenAnswer((_) async => Right([missed]));

    socket.add(const ChatSocketClosed(code: 1006));
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);
    socket.add(const ChatSocketOpened());
    final state = await bloc.stream.firstWhere((s) => s.messages.length == 2);

    expect(state.messages.last, missed);
    verify(mockRepository.getMessages(tSession, since: tAgent.createdAt));
    await bloc.close();
  });

  test('pastikan close 1008 membuat session baru', () async {
    final bloc = await started();
    const renewed = ChatSession(visitorId: 'v1', conversationId: 'c2', wsPath: '/v1/ws?c2');
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(renewed));

    socket.add(const ChatSocketClosed(code: 1008));
    await bloc.stream.firstWhere((s) => s.connection == ChatConnectionStatus.connecting);

    verify(mockRepository.connect(renewed));
    await bloc.close();
  });

  test('pastikan socket diputus saat bloc ditutup', () async {
    final bloc = await started();
    await bloc.close();
    verify(mockRepository.disconnect());
  });
}
