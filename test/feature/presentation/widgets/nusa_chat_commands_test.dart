import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
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

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o');
  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  const tCommands = [
    ChatCommand(command: '/status', description: 'Cek status dan paket layanan internet Anda'),
    ChatCommand(command: '/upgrade', description: 'Upgrade kecepatan paket internet'),
    ChatCommand(command: '/chat-helpdesk'),
  ];

  ChatBloc buildBloc() => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    sendChatButtonReply: SendChatButtonReply(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
    getChatCommands: GetChatCommands(repository: mockRepository),
  );

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.getCommands()).thenAnswer((_) async => const Right(tCommands));
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<void> pump(WidgetTester tester, {bool commands = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(config: tConfig, bloc: buildBloc(), commands: commands),
      ),
    );
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();
  }

  Finder suggestion(String command) => find.byKey(ValueKey('nusa_chat.command.$command'));

  testWidgets('pastikan semua perintah muncul saat mengetik garis miring', (tester) async {
    await pump(tester);
    expect(find.byType(NusaChatCommandSuggestions), findsNothing);

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();

    expect(suggestion('/status'), findsOneWidget);
    expect(suggestion('/upgrade'), findsOneWidget);
    expect(suggestion('/chat-helpdesk'), findsOneWidget);
    expect(find.text('Cek status dan paket layanan internet Anda'), findsOneWidget);
  });

  testWidgets('pastikan daftar disaring sesuai ketikan dan hilang kalau tidak ada yang cocok', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '/UP');
    await tester.pump();
    expect(suggestion('/upgrade'), findsOneWidget);
    expect(suggestion('/status'), findsNothing);

    await tester.enterText(find.byType(TextField), '/xyz');
    await tester.pump();
    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
  });

  testWidgets('pastikan daftar hilang setelah spasi atau teks biasa', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '/status ');
    await tester.pump();
    expect(find.byType(NusaChatCommandSuggestions), findsNothing);

    await tester.enterText(find.byType(TextField), 'halo /status');
    await tester.pump();
    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
  });

  testWidgets('pastikan ketuk perintah mengisi kolom tanpa mengirim', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '/st');
    await tester.pump();

    await tester.tap(suggestion('/status'));
    await tester.pump();

    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;
    expect(controller.text, '/status ');
    expect(controller.selection, const TextSelection.collapsed(offset: 8));
    verifyNever(mockRepository.sendText(any, any));
    expect(find.byType(NusaChatCommandSuggestions), findsNothing);

    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pump();
    verify(mockRepository.sendText(tSession, '/status'));
  });

  testWidgets('pastikan tidak ada saran kalau endpoint gagal', (tester) async {
    when(mockRepository.getCommands()).thenAnswer((_) async => Left(ConnectionFailure()));
    await pump(tester);

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();

    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
  });

  testWidgets('pastikan tidak ada saran kalau daftar perintah kosong', (tester) async {
    when(mockRepository.getCommands()).thenAnswer((_) async => const Right([]));
    await pump(tester);

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();

    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
  });

  testWidgets('pastikan commandSuggestionsBuilder mengganti tampilan dan bisa mengisi kolom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(
          config: tConfig,
          bloc: buildBloc(),
          commandSuggestionsBuilder: (context, commands, onSelected) => Column(
            children: [
              for (final command in commands)
                TextButton(onPressed: () => onSelected(command), child: Text('custom ${command.command}')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), '/up');
    await tester.pump();

    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
    await tester.tap(find.text('custom /upgrade'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '/upgrade ');
  });

  testWidgets('pastikan commands: false tidak menampilkan saran', (tester) async {
    await pump(tester, commands: false);

    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();

    expect(find.byType(NusaChatCommandSuggestions), findsNothing);
  });
}
