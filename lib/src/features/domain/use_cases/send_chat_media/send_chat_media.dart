import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

/// Uploads the file (unless [ParamsSendChatMedia.uploaded] says it already
/// was) and sends it as a message. Like `SendChatText`, the result's
/// `messageId` is null when sent over the socket (an ack follows).
class SendChatMedia implements UseCase<SentChatMedia, ParamsSendChatMedia> {
  final ChatRepository repository;

  SendChatMedia({required this.repository});

  @override
  Future<Either<Failure, SentChatMedia>> call(ParamsSendChatMedia params) async {
    var uploaded = params.uploaded;
    if (uploaded == null) {
      final result = await repository.uploadMedia(params.attachment, onProgress: params.onProgress);
      final failure = result.fold((failure) => failure, (_) => null);
      if (failure != null) return Left(failure);
      uploaded = result.getOrElse(() => throw StateError('unreachable'));
      params.onUploaded?.call(uploaded, repository.mediaUrl(uploaded.mediaId));
    }

    final media = uploaded;
    final result = await repository.sendMedia(params.session, media, caption: params.attachment.caption);
    return result.map((messageId) => SentChatMedia(media: media, messageId: messageId));
  }
}

class SentChatMedia extends Equatable {
  final UploadedMedia media;
  final String? messageId;

  const SentChatMedia({required this.media, required this.messageId});

  @override
  List<Object?> get props => [media, messageId];
}

class ParamsSendChatMedia extends Equatable {
  final ChatSession session;
  final ChatAttachment attachment;

  /// Set on a retry whose upload already succeeded.
  final UploadedMedia? uploaded;

  /// Upload progress, 0–1.
  final void Function(double progress)? onProgress;

  /// Called once the upload succeeded, with the file's URL.
  final void Function(UploadedMedia media, String url)? onUploaded;

  const ParamsSendChatMedia({
    required this.session,
    required this.attachment,
    this.uploaded,
    this.onProgress,
    this.onUploaded,
  });

  @override
  List<Object?> get props => [session, attachment, uploaded];

  @override
  String toString() {
    return 'ParamsSendChatMedia{session: $session, attachment: $attachment, uploaded: $uploaded}';
  }
}
