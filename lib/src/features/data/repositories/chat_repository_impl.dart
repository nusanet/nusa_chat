import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/error/exception.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/service/network_info.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_local_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/features/data/models/data_api_failure/data_api_failure.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/session/session_body.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource remoteDataSource;
  final ChatSocketDataSource socketDataSource;
  final ChatLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final NusaChatConfig config;

  ChatRepositoryImpl({
    required this.remoteDataSource,
    required this.socketDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.config,
  });

  @override
  Future<Either<Failure, ChatSession>> startSession() async {
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) return Left(ConnectionFailure());

    final hostVisitorId = config.visitorId;
    final savedVisitorId = hostVisitorId == null ? await _readSavedVisitorId() : null;

    final result = await _createSession(hostVisitorId ?? savedVisitorId);
    // A remembered id the server no longer accepts: start over with a fresh one.
    if (result.isLeft() && savedVisitorId != null && _isBadRequest(result)) {
      await localDataSource.clear(config.websiteId);
      return _createSession(null);
    }
    return result;
  }

  Future<String?> _readSavedVisitorId() async {
    try {
      return await localDataSource.getVisitorId(config.websiteId);
    } catch (_) {
      return null;
    }
  }

  bool _isBadRequest(Either<Failure, ChatSession> result) {
    return result.fold((failure) => failure is ServerFailure && failure.dataApiFailure.statusCode == 400, (_) => false);
  }

  Future<Either<Failure, ChatSession>> _createSession(String? visitorId) async {
    try {
      final response = await remoteDataSource.createSession(
        SessionBody(pageUrl: config.pageUrl, visitorId: visitorId, displayName: config.displayName),
      );
      final session = response.toEntity();
      try {
        await localDataSource.saveVisitorId(config.websiteId, session.visitorId);
        await localDataSource.saveConversationId(config.websiteId, session.conversationId);
      } catch (_) {
        // Not remembering the ids only costs a new conversation next time.
      }
      return Right(session);
    } on DioException catch (error) {
      return Left(_serverFailure(error));
    } catch (error) {
      return Left(ParsingFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ChatMessage>>> getMessages(ChatSession session, {DateTime? since}) async {
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) return Left(ConnectionFailure());

    try {
      final response = await remoteDataSource.getMessages(session.conversationId, since: since);
      final messages = (response.data ?? const [])
          .map((row) => row.toEntity(resolveMediaUrl: remoteDataSource.mediaUrl))
          .toList();
      return Right(messages);
    } on DioException catch (error) {
      return Left(_serverFailure(error));
    } catch (error) {
      return Left(ParsingFailure(error.toString()));
    }
  }

  @override
  Stream<ChatSocketEvent> connect(ChatSession session) {
    final uri = Uri.parse('${config.socketBaseUrl}${session.wsPath}');
    return socketDataSource
        .connect(uri, origin: config.origin)
        .map(
          (frame) => switch (frame) {
            SocketOpenedFrame() => const ChatSocketOpened(),
            SocketEventFrame(:final event) => event.toEntity(),
            SocketClosedFrame(:final code, :final reason) => ChatSocketClosed(code: code, reason: reason),
          },
        );
  }

  @override
  Future<Either<Failure, String?>> sendText(ChatSession session, String text) {
    return _send(session, SendMessageBody(body: text));
  }

  @override
  Future<Either<Failure, String?>> sendMedia(ChatSession session, UploadedMedia media, {String caption = ''}) {
    return _send(
      session,
      SendMessageBody.media(
        messageType: media.messageType,
        mediaId: media.mediaId,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Future<Either<Failure, String?>> sendLocation(ChatSession session, ChatLocation location) {
    return _send(session, SendMessageBody.location(latitude: location.latitude, longitude: location.longitude));
  }

  @override
  Future<Either<Failure, UploadedMedia>> uploadMedia(
    ChatAttachment attachment, {
    void Function(double progress)? onProgress,
  }) async {
    final isConnected = await networkInfo.isConnected;
    if (!isConnected) return Left(ConnectionFailure());

    try {
      final response = await remoteDataSource.uploadMedia(
        path: attachment.path,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      );
      return Right(response.toEntity());
    } on DioException catch (error) {
      return Left(_serverFailure(error));
    } catch (error) {
      return Left(ParsingFailure(error.toString()));
    }
  }

  @override
  String mediaUrl(String mediaId) => remoteDataSource.mediaUrl(mediaId);

  Future<Either<Failure, String?>> _send(ChatSession session, SendMessageBody body) async {
    if (socketDataSource.isOpen) {
      try {
        socketDataSource.send(body);
        return const Right(null);
      } on SocketException {
        // Fall through to HTTP.
      }
    }

    final isConnected = await networkInfo.isConnected;
    if (!isConnected) return Left(ConnectionFailure());

    try {
      final response = await remoteDataSource.sendMessage(session.conversationId, body);
      return Right(response.messageId);
    } on DioException catch (error) {
      return Left(_serverFailure(error));
    } catch (error) {
      return Left(ParsingFailure(error.toString()));
    }
  }

  @override
  Future<void> disconnect() => socketDataSource.close();

  /// The bridge answers errors as `{error: "..."}`.
  ServerFailure _serverFailure(DioException error) {
    final data = error.response?.data;
    final message = data is Map && data['error'] != null ? data['error'].toString() : null;
    return ServerFailure(
      DataApiFailure(statusCode: error.response?.statusCode, message: message, httpMessage: error.message),
    );
  }
}
