// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_command_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListCommandResponse _$ListCommandResponseFromJson(Map<String, dynamic> json) => ListCommandResponse(
  data: (json['data'] as List<dynamic>?)?.map((e) => CommandResponse.fromJson(e as Map<String, dynamic>)).toList(),
);

Map<String, dynamic> _$ListCommandResponseToJson(ListCommandResponse instance) => <String, dynamic>{
  'data': instance.data?.map((e) => e.toJson()).toList(),
};

CommandResponse _$CommandResponseFromJson(Map<String, dynamic> json) =>
    CommandResponse(command: json['command'] as String?, description: json['description'] as String?);

Map<String, dynamic> _$CommandResponseToJson(CommandResponse instance) => <String, dynamic>{
  'command': instance.command,
  'description': instance.description,
};
