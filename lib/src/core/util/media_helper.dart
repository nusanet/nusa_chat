import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// What the bridge accepts per message type (bridge `src/domain/media.ts`):
/// a file outside these is rejected with 400, so it is caught before upload.
class MediaHelper {
  const MediaHelper._(); // coverage:ignore-line

  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxDocumentBytes = 16 * 1024 * 1024;
  static const maxAudioBytes = 16 * 1024 * 1024;

  /// Document extensions offered by the file picker.
  static const documentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx'];

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ogg': 'audio/ogg',
    'opus': 'audio/ogg',
    'webm': 'audio/webm',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
  };

  static String? extensionOf(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  /// MIME type from the file extension, or null when the bridge would not take it.
  static String? mimeTypeOf(String path) => _mimeByExtension[extensionOf(path)];

  static ChatMessageType? typeOfMime(String mimeType) {
    if (mimeType.startsWith('image/')) return ChatMessageType.image;
    if (mimeType.startsWith('audio/')) return ChatMessageType.audio;
    if (_mimeByExtension.values.contains(mimeType)) return ChatMessageType.document;
    return null;
  }

  static int maxBytesOf(ChatMessageType type) {
    return switch (type) {
      ChatMessageType.image => maxImageBytes,
      ChatMessageType.audio => maxAudioBytes,
      _ => maxDocumentBytes,
    };
  }

  /// `245 KB`, `1,2 MB`.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  /// `0:07`, `12:30`.
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
