import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Bootstrap the session, load history and connect.
class ChatStarted extends ChatEvent {
  const ChatStarted();
}

class ChatTextSubmitted extends ChatEvent {
  final String text;

  const ChatTextSubmitted({required this.text});

  @override
  List<Object?> get props => [text];

  @override
  String toString() {
    return 'ChatTextSubmitted{text: $text}';
  }
}

/// Send picked/recorded files, one message each, in order.
class ChatAttachmentsSubmitted extends ChatEvent {
  final List<ChatAttachment> attachments;

  const ChatAttachmentsSubmitted({required this.attachments});

  @override
  List<Object?> get props => [attachments];

  @override
  String toString() {
    return 'ChatAttachmentsSubmitted{attachments: $attachments}';
  }
}

class ChatLocationSubmitted extends ChatEvent {
  final ChatLocation location;

  const ChatLocationSubmitted({required this.location});

  @override
  List<Object?> get props => [location];

  @override
  String toString() {
    return 'ChatLocationSubmitted{location: $location}';
  }
}

/// Show a one-off notice, e.g. a picked file the bridge would reject.
class ChatNoticeRequested extends ChatEvent {
  final String message;

  const ChatNoticeRequested({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Resend a [ChatMessageStatus.failed] message.
class ChatMessageRetried extends ChatEvent {
  final String localId;

  const ChatMessageRetried({required this.localId});

  @override
  List<Object?> get props => [localId];

  @override
  String toString() {
    return 'ChatMessageRetried{localId: $localId}';
  }
}

/// Reconnect now if disconnected, e.g. when the app returns to the foreground.
class ChatReconnectRequested extends ChatEvent {
  const ChatReconnectRequested();
}

/// The app went to the background; the socket is closed until resumed.
class ChatPaused extends ChatEvent {
  const ChatPaused();
}

/// A frame from the real-time connection.
class ChatSocketEventReceived extends ChatEvent {
  final ChatSocketEvent event;

  const ChatSocketEventReceived({required this.event});

  @override
  List<Object?> get props => [event];

  @override
  String toString() {
    return 'ChatSocketEventReceived{event: $event}';
  }
}
