import 'package:equatable/equatable.dart';

/// A slash command the website's robot answers, e.g. `/status`. Suggested
/// while the visitor types `/`; sending it is sending [command] as text.
class ChatCommand extends Equatable {
  /// Starts with `/`.
  final String command;
  final String description;

  const ChatCommand({required this.command, this.description = ''});

  /// Whether this command is a suggestion for [text], what the visitor has
  /// typed so far: a `/` and the start of the command, case ignored.
  bool matches(String text) => text.startsWith('/') && command.toLowerCase().startsWith(text.toLowerCase());

  @override
  List<Object?> get props => [command, description];

  @override
  String toString() {
    return 'ChatCommand{command: $command, description: $description}';
  }
}
