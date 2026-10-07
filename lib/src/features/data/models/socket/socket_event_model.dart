import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

/// A frame received over the chat WebSocket (docs/15-websocket-guide.md § 4).
///
/// The server sends `{type: "ack" | "error" | "message", ...}`; anything else
/// is kept as [SocketUnknownModel] so a newer server never breaks the client.
sealed class SocketEventModel extends Equatable {
  const SocketEventModel();

  factory SocketEventModel.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'ack':
        return SocketAckModel(messageId: json['message_id'] as String?);
      case 'error':
        return SocketErrorModel(error: json['error']?.toString() ?? '');
      case 'message':
        return SocketAgentMessageModel(
          messageId: json['message_id'] as String?,
          messageType: json['message_type'] as String?,
          body: json['body'] as String?,
          caption: json['caption'] as String?,
          mediaUrl: json['media_url'] as String?,
          filename: json['filename'] as String?,
          from: json['from'] as String?,
          createdAt: json['created_at'] as String?,
        );
      default:
        return SocketUnknownModel(raw: json);
    }
  }

  ChatSocketEvent toEntity();
}

/// `{type: "ack", message_id}` — the oldest unacknowledged message was saved.
class SocketAckModel extends SocketEventModel {
  final String? messageId;

  const SocketAckModel({required this.messageId});

  @override
  ChatSocketEvent toEntity() => ChatSocketAck(messageId: messageId);

  @override
  List<Object?> get props => [messageId];
}

/// `{type: "error", error}` — e.g. `rate_limited`.
class SocketErrorModel extends SocketEventModel {
  final String error;

  const SocketErrorModel({required this.error});

  @override
  ChatSocketEvent toEntity() => ChatSocketError(error: error);

  @override
  List<Object?> get props => [error];
}

/// `{type: "message", from: "agent", message_type, body | media_url+caption(+filename), message_id}`.
/// The agent's `media_url` is a direct link (docs/13-media-support.md § Temuan penting).
class SocketAgentMessageModel extends SocketEventModel {
  final String? messageId;
  final String? messageType;
  final String? body;
  final String? caption;
  final String? mediaUrl;
  final String? filename;
  final String? from;
  final String? createdAt;

  const SocketAgentMessageModel({
    required this.messageId,
    required this.messageType,
    this.body,
    this.caption,
    this.mediaUrl,
    this.filename,
    this.from,
    this.createdAt,
  });

  @override
  ChatSocketEvent toEntity() {
    final type = ChatMessageType.fromValue(messageType);
    return ChatSocketIncomingMessage(
      message: ChatMessage(
        id: messageId,
        localId: messageId ?? 'agent-${DateTime.now().microsecondsSinceEpoch}',
        text: (type == ChatMessageType.text ? body : caption) ?? '',
        type: type,
        media: mediaUrl == null || mediaUrl!.isEmpty ? null : ChatMedia(url: mediaUrl, fileName: filename),
        isMine: false,
        // The agent push carries no timestamp; it is shown as "now".
        createdAt: DateTime.tryParse(createdAt ?? '') ?? DateTime.now(),
        status: ChatMessageStatus.sent,
      ),
    );
  }

  @override
  List<Object?> get props => [messageId, messageType, body, caption, mediaUrl, filename, from, createdAt];
}

class SocketUnknownModel extends SocketEventModel {
  final Map<String, dynamic> raw;

  const SocketUnknownModel({required this.raw});

  @override
  ChatSocketEvent toEntity() => ChatSocketUnknown(raw: raw);

  @override
  List<Object?> get props => [raw];
}
