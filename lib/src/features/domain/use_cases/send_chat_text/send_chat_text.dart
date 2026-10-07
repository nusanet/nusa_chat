import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

/// Returns `null` when sent over the socket (an ack follows), or the
/// `message_id` when the HTTP fallback was used.
class SendChatText implements UseCase<String?, ParamsSendChatText> {
  final ChatRepository repository;

  SendChatText({required this.repository});

  @override
  Future<Either<Failure, String?>> call(ParamsSendChatText params) async {
    return await repository.sendText(params.session, params.text);
  }
}

class ParamsSendChatText extends Equatable {
  final ChatSession session;
  final String text;

  const ParamsSendChatText({required this.session, required this.text});

  @override
  List<Object?> get props => [session, text];

  @override
  String toString() {
    return 'ParamsSendChatText{session: $session, text: $text}';
  }
}
