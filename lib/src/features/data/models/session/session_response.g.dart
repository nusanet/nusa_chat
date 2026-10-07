// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionResponse _$SessionResponseFromJson(Map<String, dynamic> json) => SessionResponse(
  visitorId: json['visitor_id'] as String?,
  conversationId: json['conversation_id'] as String?,
  wsUrl: json['ws_url'] as String?,
);

Map<String, dynamic> _$SessionResponseToJson(SessionResponse instance) => <String, dynamic>{
  'visitor_id': instance.visitorId,
  'conversation_id': instance.conversationId,
  'ws_url': instance.wsUrl,
};
