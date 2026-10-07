import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/core/util/date_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

part 'message_response.g.dart';

/// One row of `GET .../conversations/{conversation_id}/messages` (bridge `MessageRow`).
///
/// `body` means something different per `type` (docs/13-media-support.md):
/// text → the text; location → JSON `{latitude, longitude}`; image/audio →
/// caption; document → JSON `{caption, filename}`.
@JsonSerializable()
class MessageResponse extends Equatable {
  @JsonKey(name: 'message_id')
  final String? messageId;
  @JsonKey(name: 'conversation_id')
  final String? conversationId;
  @JsonKey(name: 'direction')
  final String? direction;
  @JsonKey(name: 'type')
  final String? type;
  @JsonKey(name: 'body')
  final String? body;
  @JsonKey(name: 'media_url')
  final String? mediaUrl;
  @JsonKey(name: 'status')
  final String? status;
  @JsonKey(name: 'created_at')
  final String? createdAt;

  const MessageResponse({
    required this.messageId,
    this.conversationId,
    required this.direction,
    required this.type,
    this.body,
    this.mediaUrl,
    this.status,
    this.createdAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) => _$MessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MessageResponseToJson(this);

  /// `inbound` is the visitor (this device); `outbound` is the agent's reply.
  ///
  /// [resolveMediaUrl] turns a `media_id` (the visitor's uploads) into a URL;
  /// the agent's `media_url` is already a direct link.
  ChatMessage toEntity({String Function(String mediaId)? resolveMediaUrl}) {
    final isMine = direction == 'inbound';
    final messageType = ChatMessageType.fromValue(type);
    var text = body ?? '';
    String? fileName;
    ChatLocation? location;

    if (messageType == ChatMessageType.document) {
      final json = _tryDecodeObject(body);
      if (json != null) {
        text = json['caption']?.toString() ?? '';
        fileName = json['filename']?.toString();
      }
    } else if (messageType == ChatMessageType.location) {
      final json = _tryDecodeObject(body);
      final latitude = json?['latitude'];
      final longitude = json?['longitude'];
      if (latitude is num && longitude is num) {
        location = ChatLocation(latitude: latitude.toDouble(), longitude: longitude.toDouble());
        text = '';
      }
    }

    final rawMedia = mediaUrl;
    ChatMedia? media;
    if (rawMedia != null && rawMedia.isNotEmpty) {
      final isLink = rawMedia.startsWith('http://') || rawMedia.startsWith('https://');
      media = ChatMedia(
        url: isLink ? rawMedia : resolveMediaUrl?.call(rawMedia),
        mediaId: isLink ? null : rawMedia,
        fileName: fileName,
      );
    }

    return ChatMessage(
      id: messageId,
      localId: messageId ?? '',
      text: text,
      type: messageType,
      media: media,
      location: location,
      isMine: isMine,
      createdAt: DateHelper.tryParseServerDate(createdAt) ?? DateTime.now(),
      status: status == 'failed' && isMine ? ChatMessageStatus.failed : ChatMessageStatus.sent,
    );
  }

  static Map<String, dynamic>? _tryDecodeObject(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final json = jsonDecode(source);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get props => [messageId, conversationId, direction, type, body, mediaUrl, status, createdAt];

  @override
  String toString() {
    return 'MessageResponse{messageId: $messageId, conversationId: $conversationId, direction: $direction, type: $type, body: $body, mediaUrl: $mediaUrl, status: $status, createdAt: $createdAt}';
  }
}
