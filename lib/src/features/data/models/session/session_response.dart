import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';

part 'session_response.g.dart';

/// Response of `POST /v1/widget/{website_id}/sessions`.
@JsonSerializable()
class SessionResponse extends Equatable {
  @JsonKey(name: 'visitor_id')
  final String? visitorId;
  @JsonKey(name: 'conversation_id')
  final String? conversationId;
  @JsonKey(name: 'ws_url')
  final String? wsUrl;

  const SessionResponse({required this.visitorId, required this.conversationId, required this.wsUrl});

  factory SessionResponse.fromJson(Map<String, dynamic> json) => _$SessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionResponseToJson(this);

  /// Throws [FormatException] when the server left out a required id.
  ChatSession toEntity() {
    final visitor = visitorId;
    final conversation = conversationId;
    if (visitor == null || visitor.isEmpty || conversation == null || conversation.isEmpty) {
      throw const FormatException('session response tanpa visitor_id/conversation_id');
    }
    final path = wsUrl;
    return ChatSession(
      visitorId: visitor,
      conversationId: conversation,
      wsPath: (path == null || path.isEmpty)
          ? '/v1/ws?visitor_id=${Uri.encodeQueryComponent(visitor)}&conversation_id=${Uri.encodeQueryComponent(conversation)}'
          : path,
    );
  }

  @override
  List<Object?> get props => [visitorId, conversationId, wsUrl];

  @override
  String toString() {
    return 'SessionResponse{visitorId: $visitorId, conversationId: $conversationId, wsUrl: $wsUrl}';
  }
}
