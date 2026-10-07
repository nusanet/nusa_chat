import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';

part 'upload_media_response.g.dart';

/// `POST /v1/widget/{website_id}/media` → `{media_id, message_type}`.
@JsonSerializable()
class UploadMediaResponse extends Equatable {
  @JsonKey(name: 'media_id')
  final String? mediaId;
  @JsonKey(name: 'message_type')
  final String? messageType;

  const UploadMediaResponse({required this.mediaId, required this.messageType});

  factory UploadMediaResponse.fromJson(Map<String, dynamic> json) => _$UploadMediaResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UploadMediaResponseToJson(this);

  /// Throws [FormatException] when the server left out a field.
  UploadedMedia toEntity() {
    final id = mediaId;
    final type = messageType;
    if (id == null || id.isEmpty || type == null || type.isEmpty) {
      throw const FormatException('respons upload tanpa media_id/message_type');
    }
    return UploadedMedia(mediaId: id, messageType: type);
  }

  @override
  List<Object?> get props => [mediaId, messageType];

  @override
  String toString() {
    return 'UploadMediaResponse{mediaId: $mediaId, messageType: $messageType}';
  }
}
