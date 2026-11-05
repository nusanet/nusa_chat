import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:nusa_chat/src/core/util/date_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_conversation.dart';

part 'list_conversation_response.g.dart';

/// Response of `GET .../visitors/{visitor_id}/conversations`
/// (docs/15-websocket-guide.md § Daftar thread conversation).
@JsonSerializable(explicitToJson: true)
class ListConversationResponse extends Equatable {
  @JsonKey(name: 'data')
  final List<ConversationResponse>? data;
  @JsonKey(name: 'pagination')
  final PaginationResponse? pagination;

  const ListConversationResponse({required this.data, required this.pagination});

  factory ListConversationResponse.fromJson(Map<String, dynamic> json) => _$ListConversationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListConversationResponseToJson(this);

  /// Throws [FormatException] when the server left out a required field.
  ChatConversationPage toEntity() {
    final page = pagination?.page;
    final limit = pagination?.limit;
    final total = pagination?.total;
    final totalPages = pagination?.totalPages;
    if (page == null || limit == null || total == null || totalPages == null) {
      throw const FormatException('respons conversation tanpa pagination');
    }
    return ChatConversationPage(
      conversations: (data ?? const []).map((row) => row.toEntity()).toList(),
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  List<Object?> get props => [data, pagination];

  @override
  String toString() {
    return 'ListConversationResponse{data: $data, pagination: $pagination}';
  }
}

/// One row of [ListConversationResponse] (bridge `ConversationRow`).
@JsonSerializable()
class ConversationResponse extends Equatable {
  @JsonKey(name: 'conversation_id')
  final String? conversationId;
  @JsonKey(name: 'status')
  final String? status;
  @JsonKey(name: 'opened_at')
  final String? openedAt;
  @JsonKey(name: 'last_activity_at')
  final String? lastActivityAt;
  @JsonKey(name: 'closed_at')
  final String? closedAt;

  const ConversationResponse({
    required this.conversationId,
    required this.status,
    required this.openedAt,
    required this.lastActivityAt,
    this.closedAt,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) => _$ConversationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationResponseToJson(this);

  /// Throws [FormatException] when the server left out a required field.
  ChatConversation toEntity() {
    final id = conversationId;
    final opened = DateHelper.tryParseServerDate(openedAt);
    final lastActivity = DateHelper.tryParseServerDate(lastActivityAt);
    if (id == null || id.isEmpty || opened == null || lastActivity == null) {
      throw const FormatException('conversation tanpa conversation_id/opened_at/last_activity_at');
    }
    return ChatConversation(
      id: id,
      status: ChatConversationStatus.fromValue(status),
      openedAt: opened,
      lastActivityAt: lastActivity,
      closedAt: DateHelper.tryParseServerDate(closedAt),
    );
  }

  @override
  List<Object?> get props => [conversationId, status, openedAt, lastActivityAt, closedAt];

  @override
  String toString() {
    return 'ConversationResponse{conversationId: $conversationId, status: $status, openedAt: $openedAt, lastActivityAt: $lastActivityAt, closedAt: $closedAt}';
  }
}

@JsonSerializable()
class PaginationResponse extends Equatable {
  @JsonKey(name: 'page')
  final int? page;
  @JsonKey(name: 'limit')
  final int? limit;
  @JsonKey(name: 'total')
  final int? total;
  @JsonKey(name: 'total_pages')
  final int? totalPages;

  const PaginationResponse({required this.page, required this.limit, required this.total, required this.totalPages});

  factory PaginationResponse.fromJson(Map<String, dynamic> json) => _$PaginationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationResponseToJson(this);

  @override
  List<Object?> get props => [page, limit, total, totalPages];

  @override
  String toString() {
    return 'PaginationResponse{page: $page, limit: $limit, total: $total, totalPages: $totalPages}';
  }
}
