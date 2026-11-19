import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';

part 'list_command_response.g.dart';

/// Response of `GET /v1/widget/{website_id}/commands`: `{data: [{command, description}]}`.
@JsonSerializable(explicitToJson: true)
class ListCommandResponse extends Equatable {
  @JsonKey(name: 'data')
  final List<CommandResponse>? data;

  const ListCommandResponse({required this.data});

  factory ListCommandResponse.fromJson(Map<String, dynamic> json) => _$ListCommandResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListCommandResponseToJson(this);

  /// The usable commands, in the server's order: a row without a `/` command
  /// is left out, and so is a repeat of one already listed.
  List<ChatCommand> toEntity() {
    final seen = <String>{};
    return [
      for (final row in data ?? const <CommandResponse>[])
        if (row.toEntity() case final command? when seen.add(command.command.toLowerCase())) command,
    ];
  }

  @override
  List<Object?> get props => [data];

  @override
  String toString() {
    return 'ListCommandResponse{data: $data}';
  }
}

/// One row of [ListCommandResponse].
@JsonSerializable()
class CommandResponse extends Equatable {
  @JsonKey(name: 'command')
  final String? command;
  @JsonKey(name: 'description')
  final String? description;

  const CommandResponse({required this.command, this.description});

  factory CommandResponse.fromJson(Map<String, dynamic> json) => _$CommandResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CommandResponseToJson(this);

  /// Null when [command] is missing, has no name after the `/` or contains
  /// a space: it could not be typed as one word.
  ChatCommand? toEntity() {
    final value = command?.trim();
    if (value == null || value.length < 2 || !value.startsWith('/') || value.contains(RegExp(r'\s'))) return null;
    return ChatCommand(command: value, description: description?.trim() ?? '');
  }

  @override
  List<Object?> get props => [command, description];

  @override
  String toString() {
    return 'CommandResponse{command: $command, description: $description}';
  }
}
