import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'send_message_response.g.dart';

/// Response of the HTTP fallback send: `{message_id}`.
@JsonSerializable()
class SendMessageResponse extends Equatable {
  @JsonKey(name: 'message_id')
  final String? messageId;

  const SendMessageResponse({required this.messageId});

  factory SendMessageResponse.fromJson(Map<String, dynamic> json) => _$SendMessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SendMessageResponseToJson(this);

  @override
  List<Object?> get props => [messageId];

  @override
  String toString() {
    return 'SendMessageResponse{messageId: $messageId}';
  }
}
