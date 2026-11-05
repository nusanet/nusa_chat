import 'package:equatable/equatable.dart';

enum ChatConversationStatus {
  open,

  /// Closed by the server after 24h idle; the visitor's next chat gets a new conversation.
  closed,
  unknown;

  static ChatConversationStatus fromValue(String? value) {
    return ChatConversationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ChatConversationStatus.unknown,
    );
  }
}

/// Sorting of conversations by their last activity; [desc] is the newest first.
enum ChatConversationOrder { asc, desc }

/// One conversation thread of the visitor, open or closed.
class ChatConversation extends Equatable {
  final String id;
  final ChatConversationStatus status;
  final DateTime openedAt;
  final DateTime lastActivityAt;

  /// Null while the conversation is open.
  final DateTime? closedAt;

  const ChatConversation({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.lastActivityAt,
    this.closedAt,
  });

  @override
  List<Object?> get props => [id, status, openedAt, lastActivityAt, closedAt];

  @override
  String toString() {
    return 'ChatConversation{id: $id, status: $status, openedAt: $openedAt, lastActivityAt: $lastActivityAt, closedAt: $closedAt}';
  }
}

/// One page of the visitor's conversations.
class ChatConversationPage extends Equatable {
  final List<ChatConversation> conversations;

  /// 1-based.
  final int page;
  final int limit;

  /// Conversations across all pages.
  final int total;
  final int totalPages;

  const ChatConversationPage({
    required this.conversations,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [conversations, page, limit, total, totalPages];

  @override
  String toString() {
    return 'ChatConversationPage{conversations: ${conversations.length}, page: $page, limit: $limit, total: $total, totalPages: $totalPages}';
  }
}
