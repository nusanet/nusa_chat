import 'package:equatable/equatable.dart';

/// An open chat conversation on the bridge.
class ChatSession extends Equatable {
  final String visitorId;
  final String conversationId;

  /// Path + query to append to the WebSocket base, e.g. `/v1/ws?visitor_id=..&conversation_id=..`.
  final String wsPath;

  const ChatSession({required this.visitorId, required this.conversationId, required this.wsPath});

  @override
  List<Object?> get props => [visitorId, conversationId, wsPath];

  @override
  String toString() {
    return 'ChatSession{visitorId: $visitorId, conversationId: $conversationId, wsPath: $wsPath}';
  }
}
