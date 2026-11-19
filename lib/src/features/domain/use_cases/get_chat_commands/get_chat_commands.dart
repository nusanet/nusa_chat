import 'package:dartz/dartz.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class GetChatCommands implements UseCase<List<ChatCommand>, NoParams> {
  final ChatRepository repository;

  GetChatCommands({required this.repository});

  @override
  Future<Either<Failure, List<ChatCommand>>> call(NoParams params) async {
    return await repository.getCommands();
  }
}
