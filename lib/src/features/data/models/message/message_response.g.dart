// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageResponse _$MessageResponseFromJson(Map<String, dynamic> json) => MessageResponse(
  messageId: json['message_id'] as String?,
  conversationId: json['conversation_id'] as String?,
  direction: json['direction'] as String?,
  type: json['type'] as String?,
  body: json['body'] as String?,
  mediaUrl: json['media_url'] as String?,
  status: json['status'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$MessageResponseToJson(MessageResponse instance) => <String, dynamic>{
  'message_id': instance.messageId,
  'conversation_id': instance.conversationId,
  'direction': instance.direction,
  'type': instance.type,
  'body': instance.body,
  'media_url': instance.mediaUrl,
  'status': instance.status,
  'created_at': instance.createdAt,
};
