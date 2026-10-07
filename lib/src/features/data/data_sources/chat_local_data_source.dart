import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the server-generated `visitor_id` per website, so the next
/// bootstrap resumes the same conversation (docs/15-websocket-guide.md:
/// "Simpan visitor_id dan conversation_id").
abstract class ChatLocalDataSource {
  Future<String?> getVisitorId(String websiteId);

  Future<void> saveVisitorId(String websiteId, String visitorId);

  Future<String?> getConversationId(String websiteId);

  Future<void> saveConversationId(String websiteId, String conversationId);

  Future<void> clear(String websiteId);
}

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  final SharedPreferencesAsync preferences;

  ChatLocalDataSourceImpl({required this.preferences});

  static String _visitorKey(String websiteId) => 'nusa_chat.$websiteId.visitor_id';

  static String _conversationKey(String websiteId) => 'nusa_chat.$websiteId.conversation_id';

  @override
  Future<String?> getVisitorId(String websiteId) => preferences.getString(_visitorKey(websiteId));

  @override
  Future<void> saveVisitorId(String websiteId, String visitorId) =>
      preferences.setString(_visitorKey(websiteId), visitorId);

  @override
  Future<String?> getConversationId(String websiteId) => preferences.getString(_conversationKey(websiteId));

  @override
  Future<void> saveConversationId(String websiteId, String conversationId) =>
      preferences.setString(_conversationKey(websiteId), conversationId);

  @override
  Future<void> clear(String websiteId) async {
    await preferences.remove(_visitorKey(websiteId));
    await preferences.remove(_conversationKey(websiteId));
  }
}
