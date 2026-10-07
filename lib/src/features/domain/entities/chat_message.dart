import 'package:equatable/equatable.dart';

/// Content type of a message.
enum ChatMessageType {
  text,
  image,
  document,
  audio,
  location,
  unknown;

  static ChatMessageType fromValue(String? value) {
    return ChatMessageType.values.firstWhere((type) => type.name == value, orElse: () => ChatMessageType.unknown);
  }
}

/// Delivery state of the visitor's own message.
enum ChatMessageStatus {
  /// Rendered optimistically, waiting for the server `ack`.
  pending,

  /// Saved by the server.
  sent,

  /// Rejected by the server or could not be sent; can be retried.
  failed,
}

/// The file of an image, document or voice note message.
class ChatMedia extends Equatable {
  /// Where the file can be fetched: the bridge's media endpoint for the
  /// visitor's uploads, or the agent's direct link. Null until uploaded.
  final String? url;

  /// The file on this device, for messages sent from it (shown before and
  /// while uploading, and kept as the preview afterwards).
  final String? localPath;

  /// The bridge `media_id` once uploaded; a retry then skips the upload.
  final String? mediaId;

  final String? fileName;
  final String? mimeType;

  /// Bytes, when known (local files only; history does not carry it).
  final int? size;

  /// Length of a voice note, when known.
  final Duration? duration;

  const ChatMedia({this.url, this.localPath, this.mediaId, this.fileName, this.mimeType, this.size, this.duration});

  /// Lower-case extension of [fileName] (or of [localPath]/[url]), e.g. `pdf`.
  String? get extension {
    for (final name in [fileName, localPath, url]) {
      if (name == null) continue;
      final clean = name.split('?').first;
      final slash = clean.lastIndexOf('/');
      final dot = clean.lastIndexOf('.');
      if (dot > slash && dot < clean.length - 1) return clean.substring(dot + 1).toLowerCase();
    }
    return null;
  }

  ChatMedia copyWith({String? url, String? mediaId}) {
    return ChatMedia(
      url: url ?? this.url,
      localPath: localPath,
      mediaId: mediaId ?? this.mediaId,
      fileName: fileName,
      mimeType: mimeType,
      size: size,
      duration: duration,
    );
  }

  @override
  List<Object?> get props => [url, localPath, mediaId, fileName, mimeType, size, duration];

  @override
  String toString() {
    return 'ChatMedia{url: $url, localPath: $localPath, mediaId: $mediaId, fileName: $fileName, mimeType: $mimeType, size: $size, duration: $duration}';
  }
}

/// The point of a location message.
class ChatLocation extends Equatable {
  final double latitude;
  final double longitude;

  const ChatLocation({required this.latitude, required this.longitude});

  /// Opens the point in Google Maps (or the maps app that handles the link).
  Uri get mapsUri => Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() => 'ChatLocation{latitude: $latitude, longitude: $longitude}';
}

/// One message in the conversation, from the visitor ([isMine]) or the agent.
class ChatMessage extends Equatable {
  /// Server `message_id`; null until the message is acknowledged.
  final String? id;

  /// Stable id for list keys and retries; equals [id] for server messages.
  final String localId;

  /// The text, or the caption of a media message.
  final String text;
  final ChatMessageType type;

  /// The file of an image, document or audio message.
  final ChatMedia? media;

  /// The point of a location message.
  final ChatLocation? location;

  /// 0–1 while the file of a pending message is uploading; null otherwise.
  final double? uploadProgress;
  final bool isMine;
  final DateTime createdAt;
  final ChatMessageStatus status;

  /// Server error that made the message [ChatMessageStatus.failed].
  final String? error;

  const ChatMessage({
    this.id,
    required this.localId,
    required this.text,
    this.type = ChatMessageType.text,
    this.media,
    this.location,
    this.uploadProgress,
    required this.isMine,
    required this.createdAt,
    this.status = ChatMessageStatus.sent,
    this.error,
  });

  /// [uploadProgress] and [error] are cleared unless given.
  ChatMessage copyWith({
    String? id,
    ChatMessageStatus? status,
    String? error,
    DateTime? createdAt,
    ChatMedia? media,
    double? uploadProgress,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      localId: localId,
      text: text,
      type: type,
      media: media ?? this.media,
      location: location,
      uploadProgress: uploadProgress,
      isMine: isMine,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    id,
    localId,
    text,
    type,
    media,
    location,
    uploadProgress,
    isMine,
    createdAt,
    status,
    error,
  ];

  @override
  String toString() {
    return 'ChatMessage{id: $id, localId: $localId, text: $text, type: $type, media: $media, location: $location, uploadProgress: $uploadProgress, isMine: $isMine, createdAt: $createdAt, status: $status, error: $error}';
  }
}
