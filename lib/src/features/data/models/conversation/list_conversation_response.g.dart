// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_conversation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListConversationResponse _$ListConversationResponseFromJson(Map<String, dynamic> json) => ListConversationResponse(
  data: (json['data'] as List<dynamic>?)?.map((e) => ConversationResponse.fromJson(e as Map<String, dynamic>)).toList(),
  pagination: json['pagination'] == null
      ? null
      : PaginationResponse.fromJson(json['pagination'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ListConversationResponseToJson(ListConversationResponse instance) => <String, dynamic>{
  'data': instance.data?.map((e) => e.toJson()).toList(),
  'pagination': instance.pagination?.toJson(),
};

ConversationResponse _$ConversationResponseFromJson(Map<String, dynamic> json) => ConversationResponse(
  conversationId: json['conversation_id'] as String?,
  status: json['status'] as String?,
  openedAt: json['opened_at'] as String?,
  lastActivityAt: json['last_activity_at'] as String?,
  closedAt: json['closed_at'] as String?,
);

Map<String, dynamic> _$ConversationResponseToJson(ConversationResponse instance) => <String, dynamic>{
  'conversation_id': instance.conversationId,
  'status': instance.status,
  'opened_at': instance.openedAt,
  'last_activity_at': instance.lastActivityAt,
  'closed_at': instance.closedAt,
};

PaginationResponse _$PaginationResponseFromJson(Map<String, dynamic> json) => PaginationResponse(
  page: (json['page'] as num?)?.toInt(),
  limit: (json['limit'] as num?)?.toInt(),
  total: (json['total'] as num?)?.toInt(),
  totalPages: (json['total_pages'] as num?)?.toInt(),
);

Map<String, dynamic> _$PaginationResponseToJson(PaginationResponse instance) => <String, dynamic>{
  'page': instance.page,
  'limit': instance.limit,
  'total': instance.total,
  'total_pages': instance.totalPages,
};
