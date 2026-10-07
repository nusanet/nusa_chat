import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// What happens on the real-time connection, as seen by the domain.
sealed class ChatSocketEvent extends Equatable {
  const ChatSocketEvent();

  @override
  List<Object?> get props => [];
}

/// The WebSocket handshake (with Origin) succeeded.
class ChatSocketOpened extends ChatSocketEvent {
  const ChatSocketOpened();
}

/// The server saved the oldest pending message. The server does not echo a
/// client id, so pending messages are acknowledged in the order they were sent.
class ChatSocketAck extends ChatSocketEvent {
  final String? messageId;

  const ChatSocketAck({required this.messageId});

  @override
  List<Object?> get props => [messageId];
}

/// `{type: "error"}` from the server, e.g. `rate_limited`.
class ChatSocketError extends ChatSocketEvent {
  final String error;

  const ChatSocketError({required this.error});

  bool get isRateLimited => error == 'rate_limited';

  @override
  List<Object?> get props => [error];
}

/// A message pushed by the agent.
class ChatSocketIncomingMessage extends ChatSocketEvent {
  final ChatMessage message;

  const ChatSocketIncomingMessage({required this.message});

  @override
  List<Object?> get props => [message];
}

/// A frame this version does not understand.
class ChatSocketUnknown extends ChatSocketEvent {
  final Map<String, dynamic> raw;

  const ChatSocketUnknown({required this.raw});

  @override
  List<Object?> get props => [raw];
}

/// The connection ended. [code] `1008` means the session or origin was
/// rejected (e.g. the conversation was closed after 24h of inactivity).
class ChatSocketClosed extends ChatSocketEvent {
  final int? code;
  final String? reason;

  const ChatSocketClosed({this.code, this.reason});

  /// Policy violation: reconnecting with the same session will not help.
  bool get isSessionRejected => code == 1008;

  @override
  List<Object?> get props => [code, reason];
}
