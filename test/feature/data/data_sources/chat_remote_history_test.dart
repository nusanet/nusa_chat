import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';

import '../../../helper/mock_helper.mocks.dart';

void main() {
  late MockDio mockDio;
  late ChatRemoteDataSourceImpl dataSource;

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'my nusa', origin: 'o');

  void stubGet(int status, Object? data) {
    when(mockDio.get(any, queryParameters: anyNamed('queryParameters'))).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: status,
        data: data,
      ),
    );
  }

  setUp(() {
    mockDio = MockDio();
    dataSource = ChatRemoteDataSourceImpl(dio: mockDio, config: tConfig);
  });

  group('getVisitorMessages', () {
    test('pastikan path dan limit benar tanpa since', () async {
      stubGet(200, {
        'data': [
          {'message_id': 'm-1', 'conversation_id': 'c-1', 'direction': 'inbound', 'type': 'text', 'body': 'Halo'},
        ],
      });

      final response = await dataSource.getVisitorMessages('62 81', limit: 50);

      expect(response.data!.single.messageId, 'm-1');
      verify(mockDio.get('/v1/widget/my%20nusa/visitors/62%2081/messages', queryParameters: {'limit': 50}));
    });

    test('pastikan since dikirim sebagai UTC', () async {
      stubGet(200, {'data': []});

      await dataSource.getVisitorMessages('v1', limit: 5, since: DateTime.utc(2026, 1, 2, 3));

      verify(
        mockDio.get(
          '/v1/widget/my%20nusa/visitors/v1/messages',
          queryParameters: {'limit': 5, 'since': '2026-01-02T03:00:00.000Z'},
        ),
      );
    });

    test('pastikan DioException kalau status bukan 200', () {
      stubGet(204, null);
      expect(dataSource.getVisitorMessages('v1', limit: 5), throwsA(isA<DioException>()));
    });
  });

  group('getVisitorConversations', () {
    test('pastikan path, order, page dan limit benar', () async {
      stubGet(200, {
        'data': [],
        'pagination': {'page': 2, 'limit': 10, 'total': 11, 'total_pages': 2},
      });

      final response = await dataSource.getVisitorConversations('v1', order: 'asc', page: 2, limit: 10);

      expect(response.pagination!.total, 11);
      verify(
        mockDio.get(
          '/v1/widget/my%20nusa/visitors/v1/conversations',
          queryParameters: {'order': 'asc', 'page': 2, 'limit': 10},
        ),
      );
    });

    test('pastikan DioException kalau status bukan 200', () {
      stubGet(204, null);
      expect(dataSource.getVisitorConversations('v1', order: 'desc', page: 1, limit: 20), throwsA(isA<DioException>()));
    });
  });
}
