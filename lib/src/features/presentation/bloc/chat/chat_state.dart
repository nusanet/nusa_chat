import 'package:equatable/equatable.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

enum ChatViewStatus { initial, loading, loaded, failure }

enum ChatConnectionStatus { disconnected, connecting, connected }

/// A one-off message for a snackbar (e.g. rate limited). [id] changes on
/// every notice so the same text can be shown twice.
class ChatNotice extends Equatable {
  final int id;
  final String message;

  /// The bridge refused a video for its size; shortening it is what helps.
  final bool isVideoTooLarge;

  const ChatNotice({required this.id, required this.message, this.isVideoTooLarge = false});

  @override
  List<Object?> get props => [id, message, isVideoTooLarge];
}

class ChatState extends Equatable {
  final ChatViewStatus status;
  final ChatConnectionStatus connection;

  /// Oldest first.
  final List<ChatMessage> messages;

  /// Why [ChatViewStatus.failure] happened.
  final String? errorMessage;

  final ChatNotice? notice;

  /// The slash commands to suggest; empty until loaded, or when the website
  /// has none or they could not be loaded.
  final List<ChatCommand> commands;

  const ChatState({
    this.status = ChatViewStatus.initial,
    this.connection = ChatConnectionStatus.disconnected,
    this.messages = const [],
    this.errorMessage,
    this.notice,
    this.commands = const [],
  });

  ChatState copyWith({
    ChatViewStatus? status,
    ChatConnectionStatus? connection,
    List<ChatMessage>? messages,
    String? errorMessage,
    ChatNotice? notice,
    List<ChatCommand>? commands,
  }) {
    return ChatState(
      status: status ?? this.status,
      connection: connection ?? this.connection,
      messages: messages ?? this.messages,
      errorMessage: errorMessage ?? this.errorMessage,
      notice: notice ?? this.notice,
      commands: commands ?? this.commands,
    );
  }

  @override
  List<Object?> get props => [status, connection, messages, errorMessage, notice, commands];

  @override
  String toString() {
    return 'ChatState{status: $status, connection: $connection, messages: ${messages.length}, errorMessage: $errorMessage, notice: $notice, commands: ${commands.length}}';
  }
}
