import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
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

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o');
  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  const tButton = ChatButton(id: 'naila_helpdesk_btn', title: 'Hubungi Helpdesk');
  final tAgent = ChatMessage(
    id: 'a-1',
    localId: 'a-1',
    text: 'Untuk reset password, buka menu Profil.',
    type: ChatMessageType.interactive,
    buttons: const [tButton],
    isMine: false,
    createdAt: DateTime(2026, 1, 1, 10),
  );

  ChatBloc buildBloc() => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    sendChatButtonReply: SendChatButtonReply(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
  );

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

  Future<void> pump(WidgetTester tester, NusaChatPage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();
  }

  NusaChatMessageButtons buttons(WidgetTester tester) =>
      tester.widget<NusaChatMessageButtons>(find.byType(NusaChatMessageButtons));

  testWidgets('pastikan teks dan tombol pesan interactive tampil', (tester) async {
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));

    expect(find.text('Untuk reset password, buka menu Profil.'), findsOneWidget);
    expect(find.text('Hubungi Helpdesk'), findsOneWidget);
    expect(buttons(tester).onTap, isNotNull);
  });

  testWidgets('pastikan tap langsung tampil di frame berikutnya: bubble visitor dan tombol nonaktif', (tester) async {
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));

    await tester.tap(find.text('Hubungi Helpdesk'));
    await tester.pump();

    // Di tombol dan di bubble visitor, tanpa menunggu ack dari server.
    expect(find.text('Hubungi Helpdesk'), findsNWidgets(2));
    expect(buttons(tester).onTap, isNull);
    verify(mockRepository.sendButtonReply(tSession, tButton)).called(1);
  });

  testWidgets('pastikan pesan interactive dari socket langsung tampil dengan tombolnya', (tester) async {
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));
    expect(find.byType(NusaChatMessageButtons), findsNothing);

    socket.add(ChatSocketIncomingMessage(message: tAgent));
    await tester.pump();

    expect(find.text('Hubungi Helpdesk'), findsOneWidget);
    expect(buttons(tester).onTap, isNotNull);
  });

  testWidgets('pastikan tombol tetap nonaktif setelah riwayat dimuat ulang', (tester) async {
    final reply = ChatMessage(
      id: 'r-1',
      localId: 'r-1',
      text: 'Hubungi Helpdesk',
      type: ChatMessageType.interactive,
      buttonReply: tButton,
      isMine: true,
      createdAt: DateTime(2026, 1, 1, 10, 1),
    );
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => Right([tAgent, reply]));
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));

    expect(buttons(tester).onTap, isNull);
    await tester.tap(find.text('Hubungi Helpdesk').first);
    await tester.pump();
    verifyNever(mockRepository.sendButtonReply(any, any));
  });

  testWidgets('pastikan tombol tetap berfungsi dengan bubbleBuilder custom', (tester) async {
    await pump(
      tester,
      NusaChatPage(
        config: tConfig,
        bloc: buildBloc(),
        bubbleBuilder: (context, data) => Text('custom ${data.displayText}'),
      ),
    );

    await tester.tap(find.text('Hubungi Helpdesk'));
    await tester.pump();

    verify(mockRepository.sendButtonReply(tSession, tButton)).called(1);
  });

  testWidgets('pastikan beberapa tombol bertumpuk dan pesan biasa tanpa tombol', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NusaChatMessageButtons(
            buttons: [
              ChatButton(id: 'a', title: 'A'),
              ChatButton(id: 'b', title: 'B'),
            ],
          ),
        ),
      ),
    );

    final a = tester.getCenter(find.text('A'));
    final b = tester.getCenter(find.text('B'));
    expect(b.dy, greaterThan(a.dy));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.5);
  });

  test('pastikan warna tombol bisa diganti lewat tema', () {
    final theme = NusaChatTheme.fallback().copyWith(
      messageButtonColor: Colors.red,
      messageButtonTextStyle: const TextStyle(fontSize: 20),
      messageButtonDisabledOpacity: 0.2,
    );
    expect(theme.messageButtonColor, Colors.red);
    expect(theme.messageButtonTextStyle.fontSize, 20);
    expect(theme.messageButtonDisabledOpacity, 0.2);
  });
}
