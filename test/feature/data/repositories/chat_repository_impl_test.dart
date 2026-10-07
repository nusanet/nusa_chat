import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/exception.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/features/data/models/data_api_failure/data_api_failure.dart';
import 'package:nusa_chat/src/features/data/models/message/list_message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_response.dart';
import 'package:nusa_chat/src/features/data/models/session/session_body.dart';
import 'package:nusa_chat/src/features/data/models/session/session_response.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';
import 'package:nusa_chat/src/features/data/repositories/chat_repository_impl.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

import '../../../fixture/fixture_reader.dart';
import '../../../helper/mock_helper.mocks.dart';

void main() {
  late ChatRepositoryImpl repository;
  late MockChatRemoteDataSource mockRemote;
  late MockChatSocketDataSource mockSocket;
  late MockChatLocalDataSource mockLocal;
  late MockNetworkInfo mockNetworkInfo;

  const tConfig = NusaChatConfig(
    baseUrl: 'https://chat.example.com/',
    websiteId: 'mynusa',
    origin: 'https://app.example.com',
    displayName: 'Budi',
    pageUrl: 'app://home',
  );
  const tSession = ChatSession(
    visitorId: 'v1',
    conversationId: 'c1',
    wsPath: '/v1/ws?visitor_id=v1&conversation_id=c1',
  );
  const tSessionResponse = SessionResponse(
    visitorId: 'v1',
    conversationId: 'c1',
    wsUrl: '/v1/ws?visitor_id=v1&conversation_id=c1',
  );

  ChatRepositoryImpl build(NusaChatConfig config) => ChatRepositoryImpl(
    remoteDataSource: mockRemote,
    socketDataSource: mockSocket,
    localDataSource: mockLocal,
    networkInfo: mockNetworkInfo,
    config: config,
  );

  DioException dioError(int status, String message) {
    final options = RequestOptions(path: '/');
    return DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: status, data: {'error': message}),
    );
  }

  setUp(() {
    mockRemote = MockChatRemoteDataSource();
    mockSocket = MockChatSocketDataSource();
    mockLocal = MockChatLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    repository = build(tConfig);
    when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
  });

  group('startSession', () {
    test('pastikan ConnectionFailure kalau offline', () async {
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.startSession();

      expect(result, Left(ConnectionFailure()));
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan visitor_id tersimpan dipakai ulang dan id baru disimpan', () async {
      when(mockLocal.getVisitorId('mynusa')).thenAnswer((_) async => 'saved');
      when(mockRemote.createSession(any)).thenAnswer((_) async => tSessionResponse);

      final result = await repository.startSession();

      expect(result, const Right(tSession));
      verify(
        mockRemote.createSession(const SessionBody(pageUrl: 'app://home', visitorId: 'saved', displayName: 'Budi')),
      );
      verify(mockLocal.saveVisitorId('mynusa', 'v1'));
      verify(mockLocal.saveConversationId('mynusa', 'c1'));
    });

    test('pastikan visitor_id dari host diprioritaskan', () async {
      repository = build(
        const NusaChatConfig(baseUrl: 'https://x', websiteId: 'mynusa', origin: 'o', visitorId: '6281234567890'),
      );
      when(mockRemote.createSession(any)).thenAnswer((_) async => tSessionResponse);

      await repository.startSession();

      verify(mockRemote.createSession(const SessionBody(visitorId: '6281234567890')));
      verifyNever(mockLocal.getVisitorId(any));
    });

    test('pastikan visitor_id tersimpan yang ditolak (400) diganti baru', () async {
      when(mockLocal.getVisitorId('mynusa')).thenAnswer((_) async => 'bad');
      when(
        mockRemote.createSession(argThat(predicate<SessionBody>((b) => b.visitorId == 'bad'))),
      ).thenThrow(dioError(400, 'visitor_id tidak valid'));
      when(
        mockRemote.createSession(argThat(predicate<SessionBody>((b) => b.visitorId == null))),
      ).thenAnswer((_) async => tSessionResponse);

      final result = await repository.startSession();

      expect(result, const Right(tSession));
      verify(mockLocal.clear('mynusa'));
    });

    test('pastikan pesan error server diteruskan', () async {
      when(mockRemote.createSession(any)).thenThrow(dioError(403, 'origin tidak diizinkan'));

      final result = await repository.startSession();

      expect(result, Left(ServerFailure(const DataApiFailure(statusCode: 403, message: 'origin tidak diizinkan'))));
    });
  });

  group('getMessages', () {
    test('pastikan baris history dipetakan ke ChatMessage', () async {
      when(
        mockRemote.getMessages('c1', since: anyNamed('since')),
      ).thenAnswer((_) async => ListMessageResponse.fromJson(fixtureJson('list_message_response.json')));

      final result = await repository.getMessages(tSession);

      final messages = result.getOrElse(() => []);
      expect(messages.length, 2);
      expect(messages.first.isMine, isTrue);
    });

    test('pastikan ParsingFailure kalau respons rusak', () async {
      when(mockRemote.getMessages('c1', since: anyNamed('since'))).thenThrow(TypeError());

      final result = await repository.getMessages(tSession);

      expect(result.isLeft(), isTrue);
      expect(result.fold((f) => f, (_) => null), isA<ParsingFailure>());
    });
  });

  group('sendText', () {
    test('pastikan lewat WebSocket kalau terhubung', () async {
      when(mockSocket.isOpen).thenReturn(true);

      final result = await repository.sendText(tSession, 'Halo');

      expect(result, const Right(null));
      verify(mockSocket.send(const SendMessageBody(body: 'Halo')));
      verifyZeroInteractions(mockRemote);
    });

    test('pastikan fallback HTTP kalau socket tidak terhubung', () async {
      when(mockSocket.isOpen).thenReturn(false);
      when(
        mockRemote.sendMessage('c1', const SendMessageBody(body: 'Halo')),
      ).thenAnswer((_) async => const SendMessageResponse(messageId: 'm-1'));

      final result = await repository.sendText(tSession, 'Halo');

      expect(result, const Right('m-1'));
    });

    test('pastikan fallback HTTP kalau kirim lewat socket gagal', () async {
      when(mockSocket.isOpen).thenReturn(true);
      when(mockSocket.send(any)).thenThrow(SocketException('closed'));
      when(mockRemote.sendMessage(any, any)).thenAnswer((_) async => const SendMessageResponse(messageId: 'm-2'));

      final result = await repository.sendText(tSession, 'Halo');

      expect(result, const Right('m-2'));
    });
  });

  test('connect memakai URL wss + Origin dan memetakan frame', () async {
    when(mockSocket.connect(any, origin: anyNamed('origin'))).thenAnswer(
      (_) => Stream.fromIterable(const [
        SocketOpenedFrame(),
        SocketEventFrame(SocketAckModel(messageId: 'm-1')),
        SocketClosedFrame(code: 1008, reason: 'sesi tidak valid'),
      ]),
    );

    final events = await repository.connect(tSession).toList();

    expect(events, const [
      ChatSocketOpened(),
      ChatSocketAck(messageId: 'm-1'),
      ChatSocketClosed(code: 1008, reason: 'sesi tidak valid'),
    ]);
    verify(
      mockSocket.connect(
        Uri.parse('wss://chat.example.com/v1/ws?visitor_id=v1&conversation_id=c1'),
        origin: 'https://app.example.com',
      ),
    );
  });
}
