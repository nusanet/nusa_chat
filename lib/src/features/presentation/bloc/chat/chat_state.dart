import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

enum ChatViewStatus { initial, loading, loaded, failure }

enum ChatConnectionStatus { disconnected, connecting, connected }

/// A one-off message for a snackbar (e.g. rate limited). [id] changes on
/// every notice so the same text can be shown twice.
class ChatNotice extends Equatable {
  final int id;
  final String message;

  const ChatNotice({required this.id, required this.message});

  @override
  List<Object?> get props => [id, message];
}

class ChatState extends Equatable {
  final ChatViewStatus status;
  final ChatConnectionStatus connection;

  /// Oldest first.
  final List<ChatMessage> messages;

  /// Why [ChatViewStatus.failure] happened.
  final String? errorMessage;

  final ChatNotice? notice;

  const ChatState({
    this.status = ChatViewStatus.initial,
    this.connection = ChatConnectionStatus.disconnected,
    this.messages = const [],
    this.errorMessage,
    this.notice,
  });

  ChatState copyWith({
    ChatViewStatus? status,
    ChatConnectionStatus? connection,
    List<ChatMessage>? messages,
    String? errorMessage,
    ChatNotice? notice,
  }) {
    return ChatState(
      status: status ?? this.status,
      connection: connection ?? this.connection,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [status, connection, messages, errorMessage, notice];

  @override
  String toString() {
    return 'ChatState{status: $status, connection: $connection, messages: ${messages.length}, errorMessage: $errorMessage, notice: $notice}';
  }
}
