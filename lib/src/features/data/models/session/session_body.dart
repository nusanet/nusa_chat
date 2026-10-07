import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_body.g.dart';

/// Body of `POST /v1/widget/{website_id}/sessions` (docs/15-websocket-guide.md § Langkah 1).
@JsonSerializable(includeIfNull: false)
class SessionBody extends Equatable {
  @JsonKey(name: 'page_url')
  final String? pageUrl;
  @JsonKey(name: 'referrer')
  final String? referrer;
  @JsonKey(name: 'visitor_id')
  final String? visitorId;
  @JsonKey(name: 'display_name')
  final String? displayName;

  const SessionBody({this.pageUrl, this.referrer, this.visitorId, this.displayName});

  factory SessionBody.fromJson(Map<String, dynamic> json) => _$SessionBodyFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBodyToJson(this);

  @override
  List<Object?> get props => [pageUrl, referrer, visitorId, displayName];

  @override
  String toString() {
    return 'SessionBody{pageUrl: $pageUrl, referrer: $referrer, visitorId: $visitorId, displayName: $displayName}';
  }
}
