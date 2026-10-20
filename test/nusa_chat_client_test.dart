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

  test('pastikan klien dari config bisa dibuat dan dibuang', () async {
    final real = NusaChatClient(const NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o'));
    await real.dispose();
    await client.dispose();
  });

  test('pastikan toString NusaChatException', () {
    expect(const NusaChatException('x', statusCode: 500).toString(), 'NusaChatException{message: x, statusCode: 500}');
  });
}
