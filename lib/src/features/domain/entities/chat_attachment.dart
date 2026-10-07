import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// A file picked or recorded on this device, about to be sent.
class ChatAttachment extends Equatable {
  /// [ChatMessageType.image], [ChatMessageType.document] or [ChatMessageType.audio].
  final ChatMessageType type;
  final String path;
  final String fileName;

  /// Sent as the upload's `Content-Type`; the bridge picks the message type from it.
  final String mimeType;
  final int size;

  /// Length of a voice note.
  final Duration? duration;

  /// Shown under an image or document.
  final String caption;

  const ChatAttachment({
    required this.type,
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.size,
    this.duration,
    this.caption = '',
  });

  ChatAttachment copyWith({String? caption}) {
    return ChatAttachment(
      type: type,
      path: path,
      fileName: fileName,
      mimeType: mimeType,
      size: size,
      duration: duration,
      caption: caption ?? this.caption,
    );
  }

  ChatMedia toMedia() {
    return ChatMedia(localPath: path, fileName: fileName, mimeType: mimeType, size: size, duration: duration);
  }

  @override
  List<Object?> get props => [type, path, fileName, mimeType, size, duration, caption];

  @override
  String toString() {
    return 'ChatAttachment{type: $type, path: $path, fileName: $fileName, mimeType: $mimeType, size: $size, duration: $duration, caption: $caption}';
  }
}

/// What `POST /v1/widget/{id}/media` returned.
class UploadedMedia extends Equatable {
  final String mediaId;

  /// `image`, `document` or `audio`, as decided by the bridge from the MIME type.
  final String messageType;

  const UploadedMedia({required this.mediaId, required this.messageType});

  @override
  List<Object?> get props => [mediaId, messageType];
}
