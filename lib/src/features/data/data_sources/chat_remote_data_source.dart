import 'package:dio/dio.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/features/data/models/media/upload_media_response.dart';
import 'package:nusa_chat/src/features/data/models/message/list_message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_response.dart';
import 'package:nusa_chat/src/features/data/models/session/session_body.dart';
import 'package:nusa_chat/src/features/data/models/session/session_response.dart';

/// The bridge's widget REST endpoints (docs/04-api.md § 2). The `Origin`
/// header is set once on [dio] by the injection container.
abstract class ChatRemoteDataSource {
  Future<SessionResponse> createSession(SessionBody body);

  Future<ListMessageResponse> getMessages(String conversationId, {DateTime? since});

  /// HTTP fallback for when the WebSocket is not open — same body as over WS.
  Future<SendMessageResponse> sendMessage(String conversationId, SendMessageBody body);

  /// Multipart upload (field `file`) before a media message is sent.
  Future<UploadMediaResponse> uploadMedia({
    required String path,
    required String fileName,
    required String mimeType,
    void Function(int sent, int total)? onSendProgress,
  });

  /// Absolute URL of an uploaded file (`GET .../media/{media_id}`).
  String mediaUrl(String mediaId);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final Dio dio;
  final NusaChatConfig config;

  ChatRemoteDataSourceImpl({required this.dio, required this.config});

  String get _widgetPath => '/v1/widget/${Uri.encodeComponent(config.websiteId)}';

  @override
  Future<SessionResponse> createSession(SessionBody body) async {
    final path = '$_widgetPath/sessions';
    final response = await dio.post(path, data: body.toJson());
    if (response.statusCode == 200) {
      return SessionResponse.fromJson(response.data);
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: response,
      );
    }
  }

  @override
  Future<ListMessageResponse> getMessages(String conversationId, {DateTime? since}) async {
    final path = '$_widgetPath/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final response = await dio.get(
      path,
      queryParameters: since == null ? null : {'since': since.toUtc().toIso8601String()},
    );
    if (response.statusCode == 200) {
      return ListMessageResponse.fromJson(response.data);
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: response,
      );
    }
  }

  @override
  Future<UploadMediaResponse> uploadMedia({
    required String path,
    required String fileName,
    required String mimeType,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final uploadPath = '$_widgetPath/media';
    final formData = FormData.fromMap({
      // The bridge decides the message type from this part's Content-Type.
      'file': await MultipartFile.fromFile(path, filename: fileName, contentType: DioMediaType.parse(mimeType)),
    });
    final response = await dio.post(
      uploadPath,
      data: formData,
      options: Options(contentType: 'multipart/form-data', sendTimeout: const Duration(minutes: 2)),
      onSendProgress: onSendProgress,
    );
    if (response.statusCode == 200) {
      return UploadMediaResponse.fromJson(response.data);
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: uploadPath),
        response: response,
      );
    }
  }

  @override
  String mediaUrl(String mediaId) => '${config.normalizedBaseUrl}$_widgetPath/media/${Uri.encodeComponent(mediaId)}';

  @override
  Future<SendMessageResponse> sendMessage(String conversationId, SendMessageBody body) async {
    final path = '$_widgetPath/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final response = await dio.post(path, data: body.toJson());
    if (response.statusCode == 200) {
      return SendMessageResponse.fromJson(response.data);
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: response,
      );
    }
  }
}
