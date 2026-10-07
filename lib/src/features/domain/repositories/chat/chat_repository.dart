import 'package:dartz/dartz.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

abstract class ChatRepository {
  /// Bootstraps (or resumes) the visitor's conversation and remembers its ids.
  Future<Either<Failure, ChatSession>> startSession();

  /// Messages of [session], oldest first; only those after [since] when given.
  Future<Either<Failure, List<ChatMessage>>> getMessages(ChatSession session, {DateTime? since});

  /// Opens the real-time connection. Ends with [ChatSocketClosed].
  Stream<ChatSocketEvent> connect(ChatSession session);

  /// Sends [text] over the socket when open — the server confirms with a
  /// [ChatSocketAck] later and this returns `null` — otherwise over the HTTP
  /// fallback, returning the saved `message_id` right away.
  Future<Either<Failure, String?>> sendText(ChatSession session, String text);

  /// Uploads the file of [attachment]; [onProgress] gets 0–1.
  Future<Either<Failure, UploadedMedia>> uploadMedia(
    ChatAttachment attachment, {
    void Function(double progress)? onProgress,
  });

  /// Sends an uploaded file as a message; same socket/HTTP rules as [sendText].
  Future<Either<Failure, String?>> sendMedia(ChatSession session, UploadedMedia media, {String caption = ''});

  /// Same socket/HTTP rules as [sendText].
  Future<Either<Failure, String?>> sendLocation(ChatSession session, ChatLocation location);

  /// Where an uploaded file can be fetched.
  String mediaUrl(String mediaId);

  Future<void> disconnect();
}
