import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/features/data/models/conversation/list_conversation_response.dart';
import 'package:nusa_chat/src/features/data/models/message/message_response.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_conversation.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_conversations/get_chat_conversations.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_conversation_messages/get_conversation_messages.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_visitor_messages/get_visitor_messages.dart';

void main() {
  const tJson = {
    'data': [
      {
        'conversation_id': 'c-2',
        'visitor_id': 'v1',
        'website_id': 'mynusa',
        'status': 'closed',
        'opened_at': '2026-10-18T03:00:00.000Z',
        'last_activity_at': '2026-10-20T01:30:00.000Z',
        'closed_at': '2026-10-21T01:30:00.000Z',
      },
      {
        'conversation_id': 'c-1',
        'status': 'open',
        'opened_at': '2026-10-01 03:00:00',
        'last_activity_at': '2026-10-02 03:00:00',
        'closed_at': null,
      },
    ],
    'pagination': {'page': 1, 'limit': 20, 'total': 37, 'total_pages': 2},
  };

  group('ListConversationResponse', () {
    test('pastikan respons bridge jadi halaman conversation', () {
      final page = ListConversationResponse.fromJson(tJson).toEntity();

      expect(page.page, 1);
      expect(page.limit, 20);
      expect(page.total, 37);
      expect(page.totalPages, 2);
      expect(page.hasMore, isTrue);
      expect(page.conversations, [
        ChatConversation(
          id: 'c-2',
          status: ChatConversationStatus.closed,
          openedAt: DateTime.utc(2026, 10, 18, 3),
          lastActivityAt: DateTime.utc(2026, 10, 20, 1, 30),
          closedAt: DateTime.utc(2026, 10, 21, 1, 30),
        ),
        ChatConversation(
          id: 'c-1',
          status: ChatConversationStatus.open,
          openedAt: DateTime.utc(2026, 10, 1, 3),
          lastActivityAt: DateTime.utc(2026, 10, 2, 3),
        ),
      ]);
    });

    test('pastikan halaman terakhir tidak punya kelanjutan', () {
      const page = ChatConversationPage(conversations: [], page: 2, limit: 20, total: 37, totalPages: 2);
      expect(page.hasMore, isFalse);
    });

    test('pastikan data null jadi daftar kosong', () {
      final page = ListConversationResponse.fromJson(const {
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      }).toEntity();
      expect(page.conversations, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('pastikan FormatException kalau pagination tidak lengkap', () {
      expect(() => const ListConversationResponse(data: [], pagination: null).toEntity(), throwsFormatException);
      expect(
        () => ListConversationResponse.fromJson(const {
          'data': [],
          'pagination': {'page': 1, 'limit': 20, 'total': 0},
        }).toEntity(),
        throwsFormatException,
      );
    });

    test('pastikan toJson bolak-balik', () {
      final response = ListConversationResponse.fromJson(tJson);
      expect(ListConversationResponse.fromJson(response.toJson()), response);
    });

    test('pastikan toString dan props', () {
      final response = ListConversationResponse.fromJson(tJson);
      expect(response.props, [response.data, response.pagination]);
      expect(response.toString(), allOf(contains('c-2'), contains('totalPages: 2')));
    });
  });

  group('ConversationResponse', () {
    ConversationResponse row({String? id = 'c', String? opened = '2026-10-01', String? lastActivity = '2026-10-02'}) =>
        ConversationResponse(conversationId: id, status: 'open', openedAt: opened, lastActivityAt: lastActivity);

    test('pastikan FormatException kalau field wajib hilang', () {
      expect(() => row(id: null).toEntity(), throwsFormatException);
      expect(() => row(id: '').toEntity(), throwsFormatException);
      expect(() => row(opened: null).toEntity(), throwsFormatException);
      expect(() => row(lastActivity: 'bukan tanggal T').toEntity(), throwsFormatException);
    });

    test('pastikan status baru dari server tidak merusak parsing', () {
      expect(
        const ConversationResponse(
          conversationId: 'c',
          status: 'archived',
          openedAt: '2026-10-01T00:00:00Z',
          lastActivityAt: '2026-10-01T00:00:00Z',
        ).toEntity().status,
        ChatConversationStatus.unknown,
      );
    });
  });

  test('pastikan props dan toString params getConversationMessages', () {
    const params = ParamsGetConversationMessages(conversationId: 'c-1');
    expect(params.props, ['c-1']);
    expect(params.toString(), contains('c-1'));
  });

  test('pastikan conversation_id baris pesan ikut ke entity', () {
    const row = MessageResponse(messageId: 'm', conversationId: 'c-1', direction: 'inbound', type: 'text', body: 'x');
    expect(row.toEntity().conversationId, 'c-1');
  });

  test('pastikan toString dan props entity serta params', () {
    final tDate = DateTime.utc(2026);
    final conversation = ChatConversation(
      id: 'c-1',
      status: ChatConversationStatus.open,
      openedAt: tDate,
      lastActivityAt: tDate,
    );
    final page = ChatConversationPage(conversations: [conversation], page: 1, limit: 20, total: 1, totalPages: 1);
    const conversations = ParamsGetChatConversations(order: ChatConversationOrder.asc, page: 2, limit: 5);
    final messages = ParamsGetVisitorMessages(limit: 5, since: tDate);

    expect(conversation.toString(), contains('c-1'));
    expect(page.toString(), contains('total: 1'));
    expect(page.props, [
      [conversation],
      1,
      20,
      1,
      1,
    ]);
    expect(conversations.props, [ChatConversationOrder.asc, 2, 5]);
    expect(conversations.toString(), contains('page: 2'));
    expect(messages.props, [5, tDate]);
    expect(messages.toString(), contains('limit: 5'));
  });
}
