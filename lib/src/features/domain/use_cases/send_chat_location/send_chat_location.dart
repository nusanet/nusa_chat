import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

/// Returns `null` when sent over the socket (an ack follows), or the
/// `message_id` when the HTTP fallback was used.
class SendChatLocation implements UseCase<String?, ParamsSendChatLocation> {
  final ChatRepository repository;

  SendChatLocation({required this.repository});

  @override
  Future<Either<Failure, String?>> call(ParamsSendChatLocation params) async {
    return await repository.sendLocation(params.session, params.location);
  }
}

class ParamsSendChatLocation extends Equatable {
  final ChatSession session;
  final ChatLocation location;

  const ParamsSendChatLocation({required this.session, required this.location});

  @override
  List<Object?> get props => [session, location];

  @override
  String toString() {
    return 'ParamsSendChatLocation{session: $session, location: $location}';
  }
}
