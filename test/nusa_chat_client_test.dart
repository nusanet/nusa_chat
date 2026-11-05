import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/data/models/data_api_failure/data_api_failure.dart';

import 'helper/mock_helper.mocks.dart';

void main() {
  late MockChatRepository mockRepository;
  late NusaChatClient client;

  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');

  setUp(() {
    mockRepository = MockChatRepository();
    client = NusaChatClient.withRepository(mockRepository);
  });

  group('getActiveSession', () {
    test('pastikan session dari bootstrap server diteruskan', () async {
      when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));

      expect(await client.getActiveSession(), tSession);
      verify(mockRepository.startSession());
    });

    test('pastikan failure server jadi NusaChatException dengan status', () async {
      when(mockRepository.startSession()).thenAnswer(
        (_) async => Left(ServerFailure(const DataApiFailure(statusCode: 403, message: 'origin tidak diizinkan'))),
      );

      expect(
        client.getActiveSession,
        throwsA(
          isA<NusaChatException>()
              .having((e) => e.message, 'message', 'origin tidak diizinkan')
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('pastikan failure non-server tanpa statusCode', () async {
      when(mockRepository.startSession()).thenAnswer((_) async => Left(ConnectionFailure()));

      expect(
        client.getActiveSession,
        throwsA(isA<NusaChatException>().having((e) => e.statusCode, 'statusCode', isNull)),
      );
    });
  });

  group('getConversations', () {
    const tPage = ChatConversationPage(conversations: [], page: 1, limit: 20, total: 0, totalPages: 0);

    test('pastikan default sesuai bridge: terbaru dulu, halaman 1, 20 baris', () async {
      when(
        mockRepository.getConversations(order: ChatConversationOrder.desc, page: 1, limit: 20),
      ).thenAnswer((_) async => const Right(tPage));

      expect(await client.getConversations(), tPage);
    });

    test('pastikan parameter diteruskan', () async {
      when(
        mockRepository.getConversations(order: ChatConversationOrder.asc, page: 3, limit: 5),
      ).thenAnswer((_) async => const Right(tPage));

      expect(await client.getConversations(order: ChatConversationOrder.asc, page: 3, limit: 5), tPage);
    });

    test('pastikan failure jadi NusaChatException', () async {
      when(
        mockRepository.getConversations(order: anyNamed('order'), page: anyNamed('page'), limit: anyNamed('limit')),
      ).thenAnswer((_) async => Left(ServerFailure(const DataApiFailure(statusCode: 404, message: 'x'))));

      expect(client.getConversations, throwsA(isA<NusaChatException>().having((e) => e.statusCode, 'statusCode', 404)));
    });
  });

  group('getConversationMessages', () {
    final tMessage = ChatMessage(localId: 'm', text: 'x', isMine: true, createdAt: DateTime.utc(2026));

    test('pastikan pesan conversation diteruskan', () async {
      when(mockRepository.getConversationMessages('c-1')).thenAnswer((_) async => Right([tMessage]));

      expect(await client.getConversationMessages('c-1'), [tMessage]);
    });

    test('pastikan failure jadi NusaChatException', () async {
      when(mockRepository.getConversationMessages(any)).thenAnswer((_) async => Left(ConnectionFailure()));

      expect(() => client.getConversationMessages('c-1'), throwsA(isA<NusaChatException>()));
    });
  });

  group('getVisitorMessages', () {
    final tMessage = ChatMessage(localId: 'm', text: 'x', isMine: true, createdAt: DateTime.utc(2026));

    test('pastikan default 50 pesan tanpa since', () async {
      when(mockRepository.getVisitorMessages(limit: 50)).thenAnswer((_) async => Right([tMessage]));

      expect(await client.getVisitorMessages(), [tMessage]);
    });

    test('pastikan limit dan since diteruskan', () async {
      final since = DateTime.utc(2026);
      when(mockRepository.getVisitorMessages(limit: 5, since: since)).thenAnswer((_) async => Right([tMessage]));

      expect(await client.getVisitorMessages(limit: 5, since: since), [tMessage]);
    });

    test('pastikan failure jadi NusaChatException', () async {
      when(
        mockRepository.getVisitorMessages(limit: anyNamed('limit'), since: anyNamed('since')),
      ).thenAnswer((_) async => Left(ConnectionFailure()));

      expect(client.getVisitorMessages, throwsA(isA<NusaChatException>()));
    });
  });

  test('pastikan klien dari config bisa dibuat dan dibuang', () async {
    final real = NusaChatClient(const NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o'));
    await real.dispose();
    await client.dispose();
  });

  test('pastikan toString NusaChatException', () {
    expect(const NusaChatException('x', statusCode: 500).toString(), 'NusaChatException{message: x, statusCode: 500}');
  });
}
