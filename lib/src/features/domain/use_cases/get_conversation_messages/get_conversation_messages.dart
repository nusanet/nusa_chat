import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class GetConversationMessages implements UseCase<List<ChatMessage>, ParamsGetConversationMessages> {
  final ChatRepository repository;

  GetConversationMessages({required this.repository});

  @override
  Future<Either<Failure, List<ChatMessage>>> call(ParamsGetConversationMessages params) async {
    return await repository.getConversationMessages(params.conversationId);
  }
}

class ParamsGetConversationMessages extends Equatable {
  final String conversationId;

  const ParamsGetConversationMessages({required this.conversationId});

  @override
  List<Object?> get props => [conversationId];

  @override
  String toString() {
    return 'ParamsGetConversationMessages{conversationId: $conversationId}';
  }
}
