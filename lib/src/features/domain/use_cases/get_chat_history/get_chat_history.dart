import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class GetChatHistory implements UseCase<List<ChatMessage>, ParamsGetChatHistory> {
  final ChatRepository repository;

  GetChatHistory({required this.repository});

  @override
  Future<Either<Failure, List<ChatMessage>>> call(ParamsGetChatHistory params) async {
    return await repository.getMessages(params.session, since: params.since);
  }
}

class ParamsGetChatHistory extends Equatable {
  final ChatSession session;
  final DateTime? since;

  const ParamsGetChatHistory({required this.session, this.since});

  @override
  List<Object?> get props => [session, since];

  @override
  String toString() {
    return 'ParamsGetChatHistory{session: $session, since: $since}';
  }
}
