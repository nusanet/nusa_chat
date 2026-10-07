import 'package:dartz/dartz.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class DisconnectChatSocket implements UseCase<bool, NoParams> {
  final ChatRepository repository;

  DisconnectChatSocket({required this.repository});

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    await repository.disconnect();
    return const Right(true);
  }
}
