import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

/// Returns `null` when sent over the socket (an ack follows), or the
/// `message_id` when the HTTP fallback was used.
class SendChatButtonReply implements UseCase<String?, ParamsSendChatButtonReply> {
  final ChatRepository repository;

  SendChatButtonReply({required this.repository});

  @override
  Future<Either<Failure, String?>> call(ParamsSendChatButtonReply params) async {
    return await repository.sendButtonReply(params.session, params.button);
  }
}

class ParamsSendChatButtonReply extends Equatable {
  final ChatSession session;
  final ChatButton button;

  const ParamsSendChatButtonReply({required this.session, required this.button});

  @override
  List<Object?> get props => [session, button];

  @override
  String toString() {
    return 'ParamsSendChatButtonReply{session: $session, button: $button}';
  }
}
