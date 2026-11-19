import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/use_cases/connect_chat_socket/connect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/disconnect_chat_socket/disconnect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_commands/get_chat_commands.dart';
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
  const tCommands = [ChatCommand(command: '/status', description: 'Cek status')];

  ChatBloc buildBloc({bool commands = true}) => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    sendChatButtonReply: SendChatButtonReply(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
    getChatCommands: commands ? GetChatCommands(repository: mockRepository) : null,
    reconnectDelay: (_) => Duration.zero,
  );

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.getCommands()).thenAnswer((_) async => const Right(tCommands));
  });

  tearDown(() => socket.close());

  test('pastikan perintah dimuat saat chat dimulai', () async {
    final bloc = buildBloc()..add(const ChatStarted());

    final state = await bloc.stream.firstWhere((state) => state.commands.isNotEmpty);

    expect(state.commands, tCommands);
    await bloc.close();
  });

  test('pastikan perintah hanya dimuat sekali walau chat dimulai ulang', () async {
    final bloc = buildBloc()..add(const ChatStarted());
    await bloc.stream.firstWhere((state) => state.commands.isNotEmpty);

    bloc.add(const ChatStarted());
    await bloc.stream.firstWhere((state) => state.status == ChatViewStatus.loaded);

    verify(mockRepository.getCommands()).called(1);
    await bloc.close();
  });

  test('pastikan gagal memuat tidak mengganggu chat dan dicoba lagi saat mulai ulang', () async {
    when(mockRepository.getCommands()).thenAnswer((_) async => Left(ConnectionFailure()));
    final bloc = buildBloc()..add(const ChatStarted());
    await bloc.stream.firstWhere((state) => state.status == ChatViewStatus.loaded);
    await pumpEventQueue();
    expect(bloc.state.commands, isEmpty);

    when(mockRepository.getCommands()).thenAnswer((_) async => const Right(tCommands));
    bloc.add(const ChatStarted());
    final state = await bloc.stream.firstWhere((state) => state.commands.isNotEmpty);

    expect(state.commands, tCommands);
    verify(mockRepository.getCommands()).called(2);
    await bloc.close();
  });

  test('pastikan tanpa GetChatCommands tidak ada perintah', () async {
    final bloc = buildBloc(commands: false)..add(const ChatStarted());
    await bloc.stream.firstWhere((state) => state.status == ChatViewStatus.loaded);
    await pumpEventQueue();

    expect(bloc.state.commands, isEmpty);
    verifyNever(mockRepository.getCommands());
    await bloc.close();
  });

  test('pastikan perintah yang datang setelah bloc ditutup diabaikan', () async {
    final gate = Completer<Either<Failure, List<ChatCommand>>>();
    when(mockRepository.getCommands()).thenAnswer((_) => gate.future);
    final bloc = buildBloc()..add(const ChatStarted());
    await pumpEventQueue();

    await bloc.close();
    gate.complete(const Right(tCommands));
    await pumpEventQueue();

    expect(bloc.state.commands, isEmpty);
  });

  test('pastikan event dan state membawa perintah', () {
    const event = ChatCommandsReceived(commands: tCommands);
    expect(event, const ChatCommandsReceived(commands: tCommands));
    expect(event.toString(), contains('/status'));
    expect(const ChatState(commands: tCommands).toString(), contains('commands: 1'));
    expect(const ChatState().copyWith(commands: tCommands).commands, tCommands);
  });
}
