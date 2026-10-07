import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
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

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o');
  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  final tMessages = [
    ChatMessage(
      id: 'm-1',
      localId: 'm-1',
      text: 'Ada lampu merah LOS.',
      isMine: true,
      createdAt: DateTime(2026, 1, 1, 10, 10),
    ),
    ChatMessage(
      id: 'm-2',
      localId: 'm-2',
      text: 'Terima kasih informasinya.',
      isMine: false,
      createdAt: DateTime(2026, 1, 1, 10, 12),
    ),
  ];

  ChatBloc buildBloc() => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
  );

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => Right(tMessages));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<void> pump(WidgetTester tester, NusaChatPage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();
  }

  testWidgets('pastikan tampilan default sesuai desain: judul, nama agent, bubble, waktu', (tester) async {
    var reported = false;
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc(), onReportTap: () => reported = true));

    expect(find.text('NusaChat'), findsOneWidget);
    expect(find.text('NusaSelecta'), findsOneWidget);
    expect(find.text('Ada lampu merah LOS.'), findsOneWidget);
    expect(find.text('10:10'), findsOneWidget);
    expect(find.text('Tulis pesan...'), findsOneWidget);
    expect(find.byType(NusaChatAvatar), findsOneWidget);

    final myBubble = tester.widget<Container>(
      find.ancestor(of: find.text('Ada lampu merah LOS.'), matching: find.byType(Container)).first,
    );
    expect((myBubble.decoration! as BoxDecoration).color, const Color(0xFF164276));

    await tester.tap(find.byType(NusaChatIconButton));
    expect(reported, isTrue);
  });

  testWidgets('pastikan kirim pesan lewat composer', (tester) async {
    await pump(
      tester,
      NusaChatPage(config: tConfig, bloc: buildBloc(), attachments: const NusaChatAttachmentOptions.none()),
    );

    final send = find.byType(NusaChatSendButton);
    expect(tester.widget<NusaChatSendButton>(send).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Kapan selesai?');
    await tester.pump();
    expect(tester.widget<NusaChatSendButton>(send).onPressed, isNotNull);

    await tester.tap(send);
    await tester.pump();
    await tester.pump();

    expect(find.text('Kapan selesai?'), findsOneWidget);
    verify(mockRepository.sendText(tSession, 'Kapan selesai?'));
  });

  testWidgets('pastikan initialMessage mengisi composer tanpa terkirim otomatis', (tester) async {
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc(), initialMessage: 'Tanya paket'));

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Tanya paket');
    verifyNever(mockRepository.sendText(any, any));

    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pump();
    verify(mockRepository.sendText(tSession, 'Tanya paket')).called(1);
  });

  testWidgets('pastikan tahan bubble menampilkan opsi salin lalu menyalin teksnya', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));

    await tester.longPress(find.text('Terima kasih informasinya.'));
    await tester.pumpAndSettle();
    expect(find.text('Salin'), findsOneWidget);

    await tester.tap(find.text('Salin'));
    await tester.pumpAndSettle();
    expect(copied, 'Terima kasih informasinya.');
    expect(find.text('Salin'), findsNothing);
    expect(find.text('Pesan disalin'), findsOneWidget);
  });

  testWidgets('pastikan snackbar mengikuti tema', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final theme = NusaChatTheme.fallback().copyWith(
      snackBarColor: const Color(0xFF00AA00),
      snackBarTextStyle: const TextStyle(color: Color(0xFF111111), fontSize: 15),
      snackBarBehavior: SnackBarBehavior.fixed,
      snackBarRadius: 0,
    );
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc(), theme: theme));

    await tester.longPress(find.text('Terima kasih informasinya.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salin'));
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, const Color(0xFF00AA00));
    expect(snackBar.behavior, SnackBarBehavior.fixed);
    expect((snackBar.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.zero);
    expect(tester.widget<Text>(find.text('Pesan disalin')).style!.fontSize, 15);
  });

  testWidgets('pastikan input lepas fokus saat tap di luar, tetap fokus saat tap kirim', (tester) async {
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));
    FocusNode focus() => tester.widget<TextField>(find.byType(TextField)).focusNode!;

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus().hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'Halo');
    await tester.pump();
    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pump();
    expect(focus().hasFocus, isTrue);

    await tester.tap(find.text('Terima kasih informasinya.'));
    await tester.pump();
    expect(focus().hasFocus, isFalse);
  });

  testWidgets('pastikan warna, teks, app bar dan komponen bisa diganti', (tester) async {
    await pump(
      tester,
      NusaChatPage(
        config: tConfig,
        bloc: buildBloc(),
        theme: NusaChatTheme.fallback().copyWith(myBubbleColor: Colors.purple),
        strings: const NusaChatStrings(title: 'Bantuan', agentName: 'CS Nusanet'),
        actions: [NusaChatIconButton(icon: const Icon(Icons.call), onTap: () {})],
        agentAvatarBuilder: (_) => const Text('AV'),
        sendButtonBuilder: (_, onSend) => TextButton(onPressed: onSend, child: const Text('KIRIM')),
        attachments: const NusaChatAttachmentOptions.none(),
      ),
    );

    expect(find.text('Bantuan'), findsOneWidget);
    expect(find.text('CS Nusanet'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.text('AV'), findsOneWidget);
    expect(find.text('KIRIM'), findsOneWidget);
    expect(find.byType(NusaChatSendButton), findsNothing);

    final myBubble = tester.widget<Container>(
      find.ancestor(of: find.text('Ada lampu merah LOS.'), matching: find.byType(Container)).first,
    );
    expect((myBubble.decoration! as BoxDecoration).color, Colors.purple);
  });

  testWidgets('pastikan appBarBuilder dan messageBuilder mengganti total', (tester) async {
    await pump(
      tester,
      NusaChatPage(
        config: tConfig,
        bloc: buildBloc(),
        appBarBuilder: (context, data) => AppBar(title: Text('Custom ${data.title}')),
        messageBuilder: (context, data, defaultWidget) =>
            data.message.isMine ? Text('ME: ${data.displayText}') : defaultWidget,
      ),
    );

    expect(find.text('Custom NusaChat'), findsOneWidget);
    expect(find.byType(NusaChatAppBar), findsNothing);
    expect(find.text('ME: Ada lampu merah LOS.'), findsOneWidget);
    expect(find.text('Terima kasih informasinya.'), findsOneWidget);
  });

  testWidgets('pastikan error view dengan tombol coba lagi', (tester) async {
    when(mockRepository.startSession()).thenAnswer((_) async => Left(ServerFailureStub()));
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(config: tConfig, bloc: buildBloc()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('origin tidak diizinkan'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Ada lampu merah LOS.'), findsOneWidget);
  });

  testWidgets('pastikan pemisah hari muncul di antara pesan beda hari', (tester) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer(
      (_) async => Right([
        ChatMessage(id: 'a', localId: 'a', text: 'Lampu LOS merah', isMine: true, createdAt: yesterday),
        ChatMessage(id: 'b', localId: 'b', text: 'Sudah normal?', isMine: false, createdAt: now),
        ChatMessage(id: 'c', localId: 'c', text: 'Sudah, terima kasih', isMine: true, createdAt: now),
      ]),
    );
    await pump(tester, NusaChatPage(config: tConfig, bloc: buildBloc()));

    expect(find.widgetWithText(NusaChatDateChip, 'Kemarin'), findsOneWidget);
    expect(find.widgetWithText(NusaChatDateChip, 'Hari ini'), findsOneWidget);
    // A new day starts a new group, so the agent's name shows again.
    expect(find.text('NusaSelecta'), findsOneWidget);
  });

  testWidgets('pastikan tanggal mengambang tampil saat scroll lalu hilang', (tester) async {
    final start = DateTime.now().subtract(const Duration(days: 30));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer(
      (_) async => Right([
        for (var i = 0; i < 40; i++)
          ChatMessage(
            id: 'm$i',
            localId: 'm$i',
            text: 'Pesan $i',
            isMine: i.isEven,
            createdAt: start.add(Duration(days: i ~/ 4)),
          ),
      ]),
    );
    await pump(
      tester,
      NusaChatPage(config: tConfig, bloc: buildBloc(), dateBuilder: (context, date, label) => Text('tgl:$label')),
    );
    final floating = find.byKey(const ValueKey('nusa_chat.floating_date'));
    double opacity() => tester.widget<AnimatedOpacity>(floating).opacity;
    expect(opacity(), 0);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(opacity(), 1);
    expect(find.descendant(of: floating, matching: find.textContaining('tgl:')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(opacity(), 0);
  });

  test('pastikan dayLabel mengikuti aturan WhatsApp', () {
    const strings = NusaChatStrings();
    final now = DateTime(2026, 10, 7, 9); // Rabu
    expect(strings.dayLabel(DateTime(2026, 10, 7, 0, 5), now: now), 'Hari ini');
    expect(strings.dayLabel(DateTime(2026, 10, 6, 23, 59), now: now), 'Kemarin');
    expect(strings.dayLabel(DateTime(2026, 10, 5), now: now), 'Senin');
    expect(strings.dayLabel(DateTime(2026, 10, 1), now: now), 'Kamis');
    expect(strings.dayLabel(DateTime(2026, 9, 30), now: now), '30 Sep');
    expect(strings.dayLabel(DateTime(2025, 12, 3), now: now), '3 Des 2025');
  });
}

class ServerFailureStub extends Failure {
  @override
  String get message => 'origin tidak diizinkan';

  @override
  List<Object?> get props => [];
}
