import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class GetVisitorMessages implements UseCase<List<ChatMessage>, ParamsGetVisitorMessages> {
  final ChatRepository repository;

  GetVisitorMessages({required this.repository});

  @override
  Future<Either<Failure, List<ChatMessage>>> call(ParamsGetVisitorMessages params) async {
    return await repository.getVisitorMessages(limit: params.limit, since: params.since);
  }
}

class ParamsGetVisitorMessages extends Equatable {
  final int limit;
  final DateTime? since;

  const ParamsGetVisitorMessages({required this.limit, this.since});

  @override
  List<Object?> get props => [limit, since];

  @override
  String toString() {
    return 'ParamsGetVisitorMessages{limit: $limit, since: $since}';
  }
}
