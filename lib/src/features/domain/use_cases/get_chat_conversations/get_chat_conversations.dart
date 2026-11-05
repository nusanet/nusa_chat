import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_conversation.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class GetChatConversations implements UseCase<ChatConversationPage, ParamsGetChatConversations> {
  final ChatRepository repository;

  GetChatConversations({required this.repository});

  @override
  Future<Either<Failure, ChatConversationPage>> call(ParamsGetChatConversations params) async {
    return await repository.getConversations(order: params.order, page: params.page, limit: params.limit);
  }
}

class ParamsGetChatConversations extends Equatable {
  final ChatConversationOrder order;
  final int page;
  final int limit;

  const ParamsGetChatConversations({required this.order, required this.page, required this.limit});

  @override
  List<Object?> get props => [order, page, limit];

  @override
  String toString() {
    return 'ParamsGetChatConversations{order: $order, page: $page, limit: $limit}';
  }
}
