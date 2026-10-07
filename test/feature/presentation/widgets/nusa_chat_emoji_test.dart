import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
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

class FakeEmojiStore implements NusaChatEmojiStore {
  List<String> saved = const [];

  @override
  Future<List<String>> load() async => saved;

  @override
  Future<void> save(List<String> recents) async => saved = recents;
}

void main() {
  late MockChatRepository mockRepository;
  late StreamController<ChatSocketEvent> socket;
  late FakeEmojiStore store;

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o');
  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');

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
    store = FakeEmojiStore();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.mediaUrl(any)).thenReturn('https://x/media/abc');
    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => const Right(UploadedMedia(mediaId: 'abc', messageType: 'document')));
    when(mockRepository.sendMedia(any, any, caption: anyNamed('caption'))).thenAnswer((_) async => const Right(null));
    when(mockRepository.sendLocation(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<void> pump(WidgetTester tester, {NusaChatAttachmentOptions? attachments, bool emoji = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(
          config: tConfig,
          bloc: buildBloc(),
          attachments: attachments ?? const NusaChatAttachmentOptions.none(),
          emoji: emoji,
          emojiStore: store,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();
  }

  Finder composerField() => find.byType(TextField).first;
  String composerText(WidgetTester tester) => tester.widget<TextField>(composerField()).controller!.text;

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
  }

  testWidgets('pastikan tombol emoji membuka panel dan berubah jadi tombol keyboard', (tester) async {
    await pump(tester);
    expect(find.byType(NusaChatEmojiPanel), findsNothing);

    await openPanel(tester);

    expect(find.byType(NusaChatEmojiPanel), findsOneWidget);
    expect(find.byTooltip('Keyboard'), findsOneWidget);
    expect(find.text('Sering Digunakan'), findsOneWidget);
    expect(find.text('Cari emoji'), findsOneWidget);

    await tester.tap(find.byTooltip('Keyboard'));
    await tester.pump();
    // Tests have no keyboard, so the panel waits out its fallback before leaving.
    expect(find.byTooltip('Emoji'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NusaChatEmojiPanel), findsNothing);
    expect(tester.widget<TextField>(composerField()).focusNode!.hasFocus, isTrue);
  });

  testWidgets('pastikan emoji disisipkan di kursor, backspace menghapus satu emoji utuh', (tester) async {
    await pump(tester);
    await tester.enterText(composerField(), 'Siap');
    await openPanel(tester);

    await tester.tap(find.text('🙏'));
    await tester.tap(find.text('😊'));
    await tester.pump();
    expect(composerText(tester), 'Siap🙏😊');

    await tester.tap(find.bySemanticsLabel('Hapus'));
    await tester.pump();
    expect(composerText(tester), 'Siap🙏');

    // The send button sends what the panel typed.
    expect(find.byWidgetPredicate((w) => w is NusaChatSendButton && w.onPressed != null), findsOneWidget);
  });

  testWidgets('pastikan emoji ZWJ dihapus sekaligus', (tester) async {
    await pump(tester);
    await tester.enterText(composerField(), 'a👨‍👩‍👧');
    await openPanel(tester);

    await tester.tap(find.bySemanticsLabel('Hapus'));
    await tester.pump();

    expect(composerText(tester), 'a');
  });

  testWidgets('pastikan pilihan disimpan ke Sering Digunakan', (tester) async {
    store.saved = ['🐱'];
    await pump(tester);
    await openPanel(tester);

    // Saved recents come first.
    expect(find.text('🐱'), findsOneWidget);

    await tester.tap(find.text('👍'));
    await tester.pump();

    expect(store.saved, ['👍', '🐱']);
  });

  testWidgets('pastikan tab kategori mengganti isi grid dan label', (tester) async {
    await pump(tester);
    await openPanel(tester);

    await tester.tap(find.bySemanticsLabel('Hewan & Alam'));
    await tester.pumpAndSettle();

    expect(find.text('Hewan & Alam'), findsOneWidget);
    expect(find.text('🐵'), findsOneWidget);
    expect(find.text('🙏'), findsNothing);
  });

  testWidgets('pastikan swipe kiri/kanan berpindah kategori', (tester) async {
    await pump(tester);
    await openPanel(tester);

    await tester.fling(find.text('🙏'), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Smiley & Emosi'), findsOneWidget);
    expect(find.text('😀'), findsWidgets);

    await tester.fling(find.text('😀').first, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Sering Digunakan'), findsOneWidget);
  });

  testWidgets('pastikan pencarian menampilkan hasil', (tester) async {
    await pump(tester);
    await openPanel(tester);

    await tester.enterText(find.byType(TextField).last, 'sinyal');
    await tester.pumpAndSettle();
    expect(find.text('📶'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'qwertyzxcv');
    await tester.pumpAndSettle();
    expect(find.text('Emoji tidak ditemukan'), findsOneWidget);
  });

  testWidgets('pastikan mengetuk percakapan atau tombol back menutup panel', (tester) async {
    await pump(tester);
    await openPanel(tester);

    await tester.tapAt(const Offset(200, 200));
    await tester.pumpAndSettle();
    expect(find.byType(NusaChatEmojiPanel), findsNothing);

    await openPanel(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NusaChatEmojiPanel), findsNothing);
    expect(find.byType(NusaChatPage), findsOneWidget);
  });

  testWidgets('pastikan emoji: false menyembunyikan tombol emoji', (tester) async {
    await pump(tester, emoji: false);

    expect(find.byTooltip('Emoji'), findsNothing);
  });
}
