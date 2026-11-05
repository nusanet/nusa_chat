import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// A `{id, title}` object of an `interactive` message, or null when either is
/// missing or empty: the bridge never acks a `button_reply` without them, so
/// such a button could only ever leave a reply pending.
ChatButton? chatButtonFromJson(Object? json) {
  if (json is! Map) return null;
  final id = json['id'];
  final title = json['title'];
  if (id is! String || id.isEmpty || title is! String || title.isEmpty) return null;
  return ChatButton(id: id, title: title);
}

/// The usable buttons of a `buttons` array; the bridge sends null when there
/// are none.
List<ChatButton> chatButtonsFromJson(Object? json) {
  if (json is! List) return const [];
  return [for (final item in json) ?chatButtonFromJson(item)];
}
