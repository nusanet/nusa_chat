import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'send_message_body.g.dart';

/// What the visitor sends, identical over WebSocket and the HTTP fallback
/// (docs/15-websocket-guide.md § 2, docs/13-media-support.md § Protokol WS):
///
/// - text: `{"type": "message", "body": "..."}`
/// - media: `{"type": "message", "message_type": "image", "media_id": "...", "caption": "..."}`
/// - location: `{"type": "location", "latitude": -6.2, "longitude": 106.8}`
@JsonSerializable(includeIfNull: false)
class SendMessageBody extends Equatable {
  @JsonKey(name: 'type')
  final String type;
  @JsonKey(name: 'body')
  final String? body;
  @JsonKey(name: 'message_type')
  final String? messageType;
  @JsonKey(name: 'media_id')
  final String? mediaId;
  @JsonKey(name: 'caption')
  final String? caption;
  @JsonKey(name: 'latitude')
  final double? latitude;
  @JsonKey(name: 'longitude')
  final double? longitude;

  const SendMessageBody({
    this.type = 'message',
    this.body,
    this.messageType,
    this.mediaId,
    this.caption,
    this.latitude,
    this.longitude,
  });

  /// A media message; the file was uploaded first and got [mediaId].
  const SendMessageBody.media({required String this.messageType, required String this.mediaId, this.caption})
    : type = 'message',
      body = null,
      latitude = null,
      longitude = null;

  const SendMessageBody.location({required double this.latitude, required double this.longitude})
    : type = 'location',
      body = null,
      messageType = null,
      mediaId = null,
      caption = null;

  factory SendMessageBody.fromJson(Map<String, dynamic> json) => _$SendMessageBodyFromJson(json);

  Map<String, dynamic> toJson() => _$SendMessageBodyToJson(this);

  @override
  List<Object?> get props => [type, body, messageType, mediaId, caption, latitude, longitude];

  @override
  String toString() {
    return 'SendMessageBody{type: $type, body: $body, messageType: $messageType, mediaId: $mediaId, caption: $caption, latitude: $latitude, longitude: $longitude}';
  }
}
