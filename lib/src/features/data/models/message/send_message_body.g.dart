// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_message_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SendMessageBody _$SendMessageBodyFromJson(Map<String, dynamic> json) => SendMessageBody(
  type: json['type'] as String? ?? 'message',
  body: json['body'] as String?,
  messageType: json['message_type'] as String?,
  mediaId: json['media_id'] as String?,
  caption: json['caption'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  buttonId: json['button_id'] as String?,
  buttonTitle: json['button_title'] as String?,
);

Map<String, dynamic> _$SendMessageBodyToJson(SendMessageBody instance) => <String, dynamic>{
  'type': instance.type,
  'body': ?instance.body,
  'message_type': ?instance.messageType,
  'media_id': ?instance.mediaId,
  'caption': ?instance.caption,
  'latitude': ?instance.latitude,
  'longitude': ?instance.longitude,
  'button_id': ?instance.buttonId,
  'button_title': ?instance.buttonTitle,
};
