import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/data/models/conversation/list_conversation_response.dart';
import 'package:nusa_chat/src/features/data/models/message/list_message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/message_response.dart';
import 'package:nusa_chat/src/features/data/repositories/chat_repository_impl.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_conversation.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

import '../../../helper/mock_helper.mocks.dart';

void main() {
  late MockChatRemoteDataSource mockRemote;
  late MockChatLocalDataSource mockLocal;
  late MockNetworkInfo mockNetworkInfo;

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'mynusa', origin: 'o');
  const tHostConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'mynusa', origin: 'o', visitorId: 'host');
  final tNotFound = DioException(
    requestOptions: RequestOptions(path: ''),
    response: Response(
      requestOptions: RequestOptions(path: ''),
      statusCode: 404,
      data: {'error': 'visitor tidak ditemukan'},
    ),
  );

  ChatRepositoryImpl build([NusaChatConfig config = tConfig]) => ChatRepositoryImpl(
    remoteDataSource: mockRemote,
    socketDataSource: MockChatSocketDataSource(),
    localDataSource: mockLocal,
    networkInfo: mockNetworkInfo,
    config: config,
  );

  void expectNotFound<T>(Either<Failure, T> result) {
    final failure = result.fold((f) => f, (_) => null);
    expect(failure, isA<ServerFailure>());
    expect((failure! as ServerFailure).dataApiFailure.statusCode, 404);
    expect(failure.message, 'visitor tidak ditemukan');
  }

  setUp(() {
    mockRemote = MockChatRemoteDataSource();
    mockLocal = MockChatLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
    when(mockLocal.getVisitorId('mynusa')).thenAnswer((_) async => 'saved');
  });

  group('getVisitorMessages', () {
    Future<Either<Failure, List<ChatMessage>>> call(ChatRepositoryImpl repository) =>
        repository.getVisitorMessages(limit: 50);

    test('pastikan visitor tersimpan dipakai, urutan server dipertahankan, media di-resolve', () async {
      final since = DateTime.utc(2026);
      when(mockRemote.mediaUrl('media-1')).thenReturn('https://x/media-1');
      when(mockRemote.getVisitorMessages('saved', limit: 5, since: since)).thenAnswer(
        (_) async => const ListMessageResponse(
          data: [
            MessageResponse(messageId: 'm-2', conversationId: 'c-2', direction: 'outbound', type: 'text', body: 'b'),
            MessageResponse(
              messageId: 'm-1',
              conversationId: 'c-1',
              direction: 'inbound',
              type: 'image',
              body: '',
              mediaUrl: 'media-1',
            ),
          ],
        ),
      );

      final result = await build().getVisitorMessages(limit: 5, since: since);

      final messages = result.getOrElse(() => []);
      expect(messages.map((m) => m.id), ['m-2', 'm-1']);
      expect(messages.map((m) => m.conversationId), ['c-2', 'c-1']);
      expect(messages.last.media!.url, 'https://x/media-1');
    });

    test('pastikan visitor dari host diprioritaskan', () async {
      when(
        mockRemote.getVisitorMessages('host', limit: 50),
      ).thenAnswer((_) async => const ListMessageResponse(data: null));

      final result = await call(build(tHostConfig));

      expect(result.getOrElse(() => throw StateError('gagal')), isEmpty);
      verifyNever(mockLocal.getVisitorId(any));
    });

    test('pastikan kosong tanpa request kalau visitor belum dikenal', () async {
      when(mockLocal.getVisitorId('mynusa')).thenAnswer((_) async => null);

      final result = await call(build());

      expect(result.getOrElse(() => throw StateError('gagal')), isEmpty);
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan ConnectionFailure kalau offline', () async {
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      expect((await call(build())).fold((f) => f, (_) => null), isA<ConnectionFailure>());
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan ServerFailure membawa status dan pesan bridge', () async {
      when(mockRemote.getVisitorMessages(any, limit: anyNamed('limit'))).thenThrow(tNotFound);

      expectNotFound(await call(build()));
    });

    test('pastikan ParsingFailure kalau respons rusak', () async {
      when(mockRemote.getVisitorMessages(any, limit: anyNamed('limit'))).thenThrow(TypeError());

      expect((await call(build())).fold((f) => f, (_) => null), isA<ParsingFailure>());
    });
  });

  group('getConversations', () {
    Future<Either<Failure, ChatConversationPage>> call(ChatRepositoryImpl repository) =>
        repository.getConversations(order: ChatConversationOrder.asc, page: 2, limit: 10);

    void stubRemote(ListConversationResponse response) {
      when(
        mockRemote.getVisitorConversations(
          any,
          order: anyNamed('order'),
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        ),
      ).thenAnswer((_) async => response);
    }

    test('pastikan parameter diteruskan dan halaman dipetakan', () async {
      stubRemote(
        const ListConversationResponse(
          data: [
            ConversationResponse(
              conversationId: 'c-1',
              status: 'closed',
              openedAt: '2026-10-01T00:00:00Z',
              lastActivityAt: '2026-10-02T00:00:00Z',
              closedAt: '2026-10-03T00:00:00Z',
            ),
          ],
          pagination: PaginationResponse(page: 2, limit: 10, total: 11, totalPages: 2),
        ),
      );

      final result = await call(build());

      final page = result.getOrElse(() => throw StateError('gagal'));
      expect(page.conversations.single.id, 'c-1');
      expect(page.total, 11);
      verify(mockRemote.getVisitorConversations('saved', order: 'asc', page: 2, limit: 10));
    });

    test('pastikan kosong tanpa request kalau visitor belum dikenal', () async {
      when(mockLocal.getVisitorId('mynusa')).thenAnswer((_) async => null);

      final result = await call(build());

      expect(result, const Right(ChatConversationPage(conversations: [], page: 2, limit: 10, total: 0, totalPages: 0)));
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan visitor tetap kosong kalau storage lokal gagal dibaca', () async {
      when(mockLocal.getVisitorId('mynusa')).thenThrow(Exception('storage'));

      expect((await call(build())).isRight(), isTrue);
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan ConnectionFailure kalau offline', () async {
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      expect((await call(build())).fold((f) => f, (_) => null), isA<ConnectionFailure>());
    });

    test('pastikan ServerFailure membawa status dan pesan bridge', () async {
      when(
        mockRemote.getVisitorConversations(
          any,
          order: anyNamed('order'),
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        ),
      ).thenThrow(tNotFound);

      expectNotFound(await call(build()));
    });

    test('pastikan ParsingFailure kalau pagination hilang', () async {
      stubRemote(const ListConversationResponse(data: [], pagination: null));

      expect((await call(build())).fold((f) => f, (_) => null), isA<ParsingFailure>());
    });
  });
}
