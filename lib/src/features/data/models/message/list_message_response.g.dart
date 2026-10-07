// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_message_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListMessageResponse _$ListMessageResponseFromJson(Map<String, dynamic> json) => ListMessageResponse(
  data: (json['data'] as List<dynamic>?)?.map((e) => MessageResponse.fromJson(e as Map<String, dynamic>)).toList(),
);

Map<String, dynamic> _$ListMessageResponseToJson(ListMessageResponse instance) => <String, dynamic>{
  'data': instance.data?.map((e) => e.toJson()).toList(),
};
