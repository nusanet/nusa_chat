import 'package:dartz/dartz.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class StartChatSession implements UseCase<ChatSession, NoParams> {
  final ChatRepository repository;

  StartChatSession({required this.repository});

  @override
  Future<Either<Failure, ChatSession>> call(NoParams params) async {
    return await repository.startSession();
  }
}
