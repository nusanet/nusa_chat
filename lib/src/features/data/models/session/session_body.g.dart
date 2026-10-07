// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBody _$SessionBodyFromJson(Map<String, dynamic> json) => SessionBody(
  pageUrl: json['page_url'] as String?,
  referrer: json['referrer'] as String?,
  visitorId: json['visitor_id'] as String?,
  displayName: json['display_name'] as String?,
);

Map<String, dynamic> _$SessionBodyToJson(SessionBody instance) => <String, dynamic>{
  'page_url': ?instance.pageUrl,
  'referrer': ?instance.referrer,
  'visitor_id': ?instance.visitorId,
  'display_name': ?instance.displayName,
};
