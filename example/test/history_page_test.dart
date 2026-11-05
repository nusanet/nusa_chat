import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/data/models/data_api_failure/data_api_failure.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';
import 'package:nusa_chat_example/history_page.dart';

class _FakeRepository implements ChatRepository {
  final List<Either<Failure, ChatConversationPage>> pages;
  final List<ChatMessage>? messages;
  final List<int> requestedPages = [];

  _FakeRepository(this.pages, {this.messages});

  @override
  Future<Either<Failure, ChatConversationPage>> getConversations({
    required ChatConversationOrder order,
    required int page,
    required int limit,
  }) async {
    requestedPages.add(page);
    return pages.removeAt(0);
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getConversationMessages(String conversationId) async {
    final custom = messages;
    if (custom != null) return Right(custom);
    return Right([
      ChatMessage(
        id: 'm-1',
        localId: 'm-1',
        text: 'Buka menu Profil',
        type: ChatMessageType.interactive,
        buttons: const [ChatButton(id: 'b', title: 'Hubungi Helpdesk')],
        isMine: false,
        createdAt: DateTime.utc(2026),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final tConversation = ChatConversation(
    id: 'c-1',
    status: ChatConversationStatus.closed,
    openedAt: DateTime(2026, 10, 1, 8),
    lastActivityAt: DateTime(2026, 10, 2, 9, 30),
    closedAt: DateTime(2026, 10, 3),
  );
  ChatConversationPage page(int number, int totalPages) => ChatConversationPage(
    conversations: [tConversation],
    page: number,
    limit: 20,
    total: totalPages,
    totalPages: totalPages,
  );

  Future<void> pump(WidgetTester tester, _FakeRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(home: ConversationHistoryPage(client: NusaChatClient.withRepository(repository))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pastikan daftar conversation tampil dan bisa memuat halaman berikutnya', (tester) async {
    final repository = _FakeRepository([Right(page(1, 2)), Right(page(2, 2))]);
    await pump(tester, repository);

    expect(find.text('02/10/2026 09:30'), findsOneWidget);
    expect(find.textContaining('Selesai'), findsOneWidget);

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('02/10/2026 09:30'), findsNWidgets(2));
    expect(find.text('Muat lebih banyak'), findsNothing);
  });

  testWidgets('pastikan thread terbuka dengan tombol yang nonaktif', (tester) async {
    await pump(tester, _FakeRepository([Right(page(1, 1))]));

    await tester.tap(find.text('02/10/2026 09:30'));
    await tester.pumpAndSettle();

    expect(find.text('Buka menu Profil'), findsOneWidget);
    expect(tester.widget<NusaChatMessageButtons>(find.byType(NusaChatMessageButtons)).onTap, isNull);
  });

  testWidgets('pastikan foto, dokumen, voice note dan lokasi tampil sebagai medianya, bukan label', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ChatMessage message(
      String id,
      ChatMessageType type, {
      String text = '',
      ChatMedia? media,
      ChatLocation? location,
    }) => ChatMessage(
      id: id,
      localId: id,
      text: text,
      type: type,
      media: media,
      location: location,
      isMine: false,
      createdAt: DateTime.utc(2026),
    );
    await pump(
      tester,
      _FakeRepository(
        [Right(page(1, 1))],
        messages: [
          message(
            'i',
            ChatMessageType.image,
            text: 'Foto modem',
            media: const ChatMedia(mediaId: 'img'),
          ),
          message(
            'd',
            ChatMessageType.document,
            media: const ChatMedia(url: 'https://x/a.pdf', fileName: 'a.pdf'),
          ),
          message('a', ChatMessageType.audio, media: const ChatMedia(mediaId: 'voice')),
          message('l', ChatMessageType.location, location: const ChatLocation(latitude: -6.2, longitude: 106.8)),
        ],
      ),
    );

    await tester.tap(find.text('02/10/2026 09:30'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NusaChatImageContent), findsOneWidget);
    expect(find.text('Foto modem'), findsOneWidget);
    expect(find.byType(NusaChatDocumentContent), findsOneWidget);
    expect(find.byType(NusaChatAudioContent), findsOneWidget);
    expect(find.byType(NusaChatLocationContent), findsOneWidget);
    expect(find.text(const NusaChatStrings().locationLabel), findsNothing);
  });

  testWidgets('pastikan 404 ditampilkan sebagai belum ada riwayat', (tester) async {
    await pump(
      tester,
      _FakeRepository([Left(ServerFailure(const DataApiFailure(statusCode: 404, message: 'visitor tidak ditemukan')))]),
    );

    expect(find.text('Belum ada riwayat percakapan.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
  });

  testWidgets('pastikan error lain bisa dicoba lagi', (tester) async {
    await pump(tester, _FakeRepository([Left(ConnectionFailure()), Right(page(1, 1))]));

    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('02/10/2026 09:30'), findsOneWidget);
  });
}
