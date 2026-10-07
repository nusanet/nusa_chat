import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/features/data/models/message/list_message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/session/session_body.dart';
import 'package:nusa_chat/src/features/data/models/session/session_response.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';

import '../../../fixture/fixture_reader.dart';

void main() {
  group('SessionBody', () {
    test('pastikan field null tidak dikirim', () {
      expect(const SessionBody(displayName: 'Budi').toJson(), {'display_name': 'Budi'});
      expect(const SessionBody(pageUrl: 'app://x', visitorId: 'v1', displayName: 'Budi').toJson(), {
        'page_url': 'app://x',
        'visitor_id': 'v1',
        'display_name': 'Budi',
      });
    });
  });

  group('SessionResponse', () {
    test('pastikan fromJson dan toEntity sesuai fixture', () {
      final response = SessionResponse.fromJson(fixtureJson('session_response.json'));

      expect(
        response.toEntity(),
        const ChatSession(
          visitorId: '6281234567890',
          conversationId: 'd732131d-b076-4eed-9492-535fbc4cd1c5',
          wsPath: '/v1/ws?visitor_id=6281234567890&conversation_id=d732131d-b076-4eed-9492-535fbc4cd1c5',
        ),
      );
    });

    test('pastikan ws_url dibentuk sendiri kalau server tidak mengirimnya', () {
      const response = SessionResponse(visitorId: 'v1', conversationId: 'c1', wsUrl: null);
      expect(response.toEntity().wsPath, '/v1/ws?visitor_id=v1&conversation_id=c1');
    });

    test('pastikan throw FormatException kalau id kosong', () {
      const response = SessionResponse(visitorId: null, conversationId: 'c1', wsUrl: null);
      expect(response.toEntity, throwsFormatException);
    });
  });

  group('ListMessageResponse', () {
    test('pastikan inbound jadi pesan milik visitor, outbound milik agent', () {
      final response = ListMessageResponse.fromJson(fixtureJson('list_message_response.json'));
      final messages = response.data!.map((row) => row.toEntity()).toList();

      expect(messages, [
        ChatMessage(
          id: 'm-1',
          localId: 'm-1',
          text: 'Halo, selamat pagi.',
          isMine: true,
          createdAt: DateTime.utc(2026, 10, 6, 3, 10),
        ),
        ChatMessage(
          id: 'm-2',
          localId: 'm-2',
          text: 'Ini dia paketnya',
          type: ChatMessageType.image,
          media: const ChatMedia(url: 'https://media.example.com/foto.jpg'),
          isMine: false,
          createdAt: DateTime.utc(2026, 10, 6, 3, 12),
        ),
      ]);
    });
  });

  test('SendMessageBody sesuai format WS/HTTP', () {
    expect(const SendMessageBody(body: 'Halo').toJson(), {'type': 'message', 'body': 'Halo'});
  });

  group('SocketEventModel', () {
    test('ack', () {
      expect(
        SocketEventModel.fromJson({'type': 'ack', 'message_id': 'm-9'}).toEntity(),
        const ChatSocketAck(messageId: 'm-9'),
      );
    });

    test('error', () {
      final event = SocketEventModel.fromJson({'type': 'error', 'error': 'rate_limited'}).toEntity();
      expect(event, const ChatSocketError(error: 'rate_limited'));
      expect((event as ChatSocketError).isRateLimited, isTrue);
    });

    test('pesan teks dari agent', () {
      final event = SocketEventModel.fromJson({
        'type': 'message',
        'from': 'agent',
        'message_type': 'text',
        'body': 'Ada, silakan cek...',
        'message_id': 'm-3',
      }).toEntity();

      final message = (event as ChatSocketIncomingMessage).message;
      expect(message.id, 'm-3');
      expect(message.text, 'Ada, silakan cek...');
      expect(message.isMine, isFalse);
      expect(message.type, ChatMessageType.text);
    });

    test('pesan media dari agent memakai caption', () {
      final event = SocketEventModel.fromJson({
        'type': 'message',
        'from': 'agent',
        'message_type': 'image',
        'media_url': 'https://media.example.com/a.jpg',
        'caption': 'Ini dia paketnya',
        'message_id': 'm-4',
      }).toEntity();

      final message = (event as ChatSocketIncomingMessage).message;
      expect(message.type, ChatMessageType.image);
      expect(message.text, 'Ini dia paketnya');
    });

    test('tipe tidak dikenal', () {
      expect(SocketEventModel.fromJson({'type': 'typing'}).toEntity(), isA<ChatSocketUnknown>());
    });
  });
}
