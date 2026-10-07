import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/core/use_cases/use_case.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/repositories/chat/chat_repository.dart';

class ConnectChatSocket implements StreamUseCase<ChatSocketEvent, ParamsConnectChatSocket> {
  final ChatRepository repository;

  ConnectChatSocket({required this.repository});

  @override
  Stream<ChatSocketEvent> call(ParamsConnectChatSocket params) {
    return repository.connect(params.session);
  }
}

class ParamsConnectChatSocket extends Equatable {
  final ChatSession session;

  const ParamsConnectChatSocket({required this.session});

  @override
  List<Object?> get props => [session];

  @override
  String toString() {
    return 'ParamsConnectChatSocket{session: $session}';
  }
}
