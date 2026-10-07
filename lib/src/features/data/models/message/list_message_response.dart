import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/features/data/models/message/message_response.dart';

part 'list_message_response.g.dart';

/// Response of `GET .../conversations/{conversation_id}/messages`: `{data: MessageRow[]}`.
@JsonSerializable(explicitToJson: true)
class ListMessageResponse extends Equatable {
  @JsonKey(name: 'data')
  final List<MessageResponse>? data;

  const ListMessageResponse({required this.data});

  factory ListMessageResponse.fromJson(Map<String, dynamic> json) => _$ListMessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListMessageResponseToJson(this);

  @override
  List<Object?> get props => [data];

  @override
  String toString() {
    return 'ListMessageResponse{data: $data}';
  }
}
