import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/data/models/media/upload_media_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_response.dart';
import 'package:nusa_chat/src/features/data/repositories/chat_repository_impl.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';

import '../../../helper/mock_helper.mocks.dart';

void main() {
  late ChatRepositoryImpl repository;
  late MockChatRemoteDataSource mockRemote;
  late MockChatSocketDataSource mockSocket;
  late MockNetworkInfo mockNetworkInfo;

  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  const tAttachment = ChatAttachment(
    type: ChatMessageType.image,
    path: '/tmp/a.jpg',
    fileName: 'a.jpg',
    mimeType: 'image/jpeg',
    size: 1000,
    caption: 'Lampu',
  );
  const tUploaded = UploadedMedia(mediaId: 'abc', messageType: 'image');

  setUp(() {
    mockRemote = MockChatRemoteDataSource();
    mockSocket = MockChatSocketDataSource();
    mockNetworkInfo = MockNetworkInfo();
    when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
    repository = ChatRepositoryImpl(
      remoteDataSource: mockRemote,
      socketDataSource: mockSocket,
      localDataSource: MockChatLocalDataSource(),
      networkInfo: mockNetworkInfo,
      config: const NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o'),
    );
  });

  group('uploadMedia', () {
    test('pastikan file diunggah dengan MIME-nya dan progres diteruskan 0–1', () async {
      when(
        mockRemote.uploadMedia(
          path: anyNamed('path'),
          fileName: anyNamed('fileName'),
          mimeType: anyNamed('mimeType'),
          onSendProgress: anyNamed('onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onSendProgress = invocation.namedArguments[#onSendProgress] as void Function(int, int);
        onSendProgress(50, 100);
        onSendProgress(100, 100);
        return const UploadMediaResponse(mediaId: 'abc', messageType: 'image');
      });

      final progress = <double>[];
      final result = await repository.uploadMedia(tAttachment, onProgress: progress.add);

      expect(result, const Right(tUploaded));
      expect(progress, [0.5, 1.0]);
      verify(
        mockRemote.uploadMedia(
          path: '/tmp/a.jpg',
          fileName: 'a.jpg',
          mimeType: 'image/jpeg',
          onSendProgress: anyNamed('onSendProgress'),
        ),
      );
    });

    test('pastikan pesan validasi bridge diteruskan', () async {
      final options = RequestOptions(path: '/');
      when(
        mockRemote.uploadMedia(
          path: anyNamed('path'),
          fileName: anyNamed('fileName'),
          mimeType: anyNamed('mimeType'),
          onSendProgress: anyNamed('onSendProgress'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 400, data: {'error': 'file kosong'}),
        ),
      );

      final result = await repository.uploadMedia(tAttachment);

      expect(result.fold((failure) => failure.message, (_) => ''), 'file kosong');
    });

    test('pastikan ConnectionFailure kalau offline', () async {
      when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);
      expect(await repository.uploadMedia(tAttachment), Left(ConnectionFailure()));
    });
  });

  test('pastikan media dikirim lewat WebSocket kalau terhubung', () async {
    when(mockSocket.isOpen).thenReturn(true);

    final result = await repository.sendMedia(tSession, tUploaded, caption: 'Lampu');

    expect(result, const Right(null));
    verify(mockSocket.send(const SendMessageBody.media(messageType: 'image', mediaId: 'abc', caption: 'Lampu')));
  });

  test('pastikan lokasi lewat fallback HTTP kalau socket tertutup', () async {
    when(mockSocket.isOpen).thenReturn(false);
    when(mockRemote.sendMessage(any, any)).thenAnswer((_) async => const SendMessageResponse(messageId: 'm-7'));

    final result = await repository.sendLocation(tSession, const ChatLocation(latitude: -6.2, longitude: 106.8));

    expect(result, const Right('m-7'));
    verify(mockRemote.sendMessage('c1', const SendMessageBody.location(latitude: -6.2, longitude: 106.8)));
  });
}
