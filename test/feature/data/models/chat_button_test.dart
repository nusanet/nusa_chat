import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/features/data/models/message/chat_button_json.dart';
import 'package:nusa_chat/src/features/data/models/message/message_response.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_session.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_button_reply/send_chat_button_reply.dart';

void main() {
  const tButton = ChatButton(id: 'naila_helpdesk_btn', title: 'Hubungi Helpdesk');
  const tButtonJson = {'id': 'naila_helpdesk_btn', 'title': 'Hubungi Helpdesk'};

  group('chatButtonFromJson', () {
    test('pastikan objek id dan title jadi tombol', () {
      expect(chatButtonFromJson(tButtonJson), tButton);
    });

    test('pastikan null kalau bukan objek atau id/title tidak lengkap', () {
      expect(chatButtonFromJson('x'), isNull);
      expect(chatButtonFromJson({'title': 'A'}), isNull);
      expect(chatButtonFromJson({'id': '', 'title': 'A'}), isNull);
      expect(chatButtonFromJson({'id': 'a'}), isNull);
      expect(chatButtonFromJson({'id': 'a', 'title': ''}), isNull);
    });
  });

  group('chatButtonsFromJson', () {
    test('pastikan kosong kalau buttons null', () {
      expect(chatButtonsFromJson(null), isEmpty);
    });

    test('pastikan tombol rusak dilewati', () {
      expect(
        chatButtonsFromJson([
          tButtonJson,
          'x',
          {'id': 'b'},
        ]),
        [tButton],
      );
    });
  });

  group('SocketEventModel interactive', () {
    test('pastikan payload push agent jadi teks dan tombol', () {
      final event = SocketEventModel.fromJson({
        'type': 'message',
        'from': 'agent',
        'message_type': 'interactive',
        'body': 'Untuk reset password MyNusa, buka menu Profil.',
        'buttons': [tButtonJson],
        'message_id': 'b6a1',
      }).toEntity();

      final message = (event as ChatSocketIncomingMessage).message;
      expect(message.id, 'b6a1');
      expect(message.type, ChatMessageType.interactive);
      expect(message.text, 'Untuk reset password MyNusa, buka menu Profil.');
      expect(message.buttons, [tButton]);
      expect(message.isMine, isFalse);
    });

    test('pastikan pesan lain tanpa tombol', () {
      final model = SocketEventModel.fromJson({'type': 'message', 'message_type': 'text', 'body': 'Halo'});
      final event = model.toEntity() as ChatSocketIncomingMessage;
      expect(event.message.buttons, isEmpty);
    });
  });

  group('MessageResponse interactive', () {
    MessageResponse row(String direction, String? body) =>
        MessageResponse(messageId: 'm-1', direction: direction, type: 'interactive', body: body);

    test('pastikan baris outbound {text, buttons} tetap punya tombol setelah riwayat dimuat', () {
      final message = row(
        'outbound',
        jsonEncode({
          'text': 'Maaf',
          'buttons': [tButtonJson],
        }),
      ).toEntity();
      expect(message.text, 'Maaf');
      expect(message.buttons, [tButton]);
      expect(message.buttonReply, isNull);
      expect(message.isMine, isFalse);
    });

    test('pastikan baris outbound dengan buttons null tidak punya tombol', () {
      final message = row('outbound', jsonEncode({'buttons': null})).toEntity();
      expect(message.text, '');
      expect(message.buttons, isEmpty);
    });

    test('pastikan baris inbound {id, title} jadi balasan visitor', () {
      final message = row('inbound', jsonEncode(tButtonJson)).toEntity();
      expect(message.text, 'Hubungi Helpdesk');
      expect(message.buttonReply, tButton);
      expect(message.buttons, isEmpty);
      expect(message.isMine, isTrue);
    });

    test('pastikan baris inbound tanpa id tidak jadi balasan', () {
      final message = row('inbound', jsonEncode({'title': 'A'})).toEntity();
      expect(message.text, '');
      expect(message.buttonReply, isNull);
    });

    test('pastikan body bukan JSON tetap tampil sebagai teks', () {
      final message = row('outbound', 'teks biasa').toEntity();
      expect(message.text, 'teks biasa');
      expect(message.buttons, isEmpty);
    });
  });

  test('pastikan SendMessageBody.buttonReply sesuai kontrak bridge', () {
    const body = SendMessageBody.buttonReply(buttonId: 'naila_helpdesk_btn', buttonTitle: 'Hubungi Helpdesk');
    expect(body.toJson(), {
      'type': 'button_reply',
      'button_id': 'naila_helpdesk_btn',
      'button_title': 'Hubungi Helpdesk',
    });
    expect(SendMessageBody.fromJson(body.toJson()), body);
  });

  group('ChatMessage.isAnsweredBy', () {
    final tDate = DateTime.utc(2026);
    final tAgent = ChatMessage(localId: 'a', text: 'x', isMine: false, createdAt: tDate, buttons: const [tButton]);
    ChatMessage reply(ChatButton? button) =>
        ChatMessage(localId: 'r', text: 'x', isMine: true, createdAt: tDate, buttonReply: button);

    test('pastikan terjawab oleh balasan salah satu tombolnya', () {
      expect(tAgent.isAnsweredBy([reply(tButton)]), isTrue);
    });

    test('pastikan belum terjawab oleh pesan lain atau tombol lain', () {
      expect(tAgent.isAnsweredBy(const []), isFalse);
      expect(tAgent.isAnsweredBy([reply(null)]), isFalse);
      expect(tAgent.isAnsweredBy([reply(const ChatButton(id: 'lain', title: 'Lain'))]), isFalse);
    });

    test('pastikan pesan tanpa tombol tidak pernah terjawab', () {
      expect(reply(null).isAnsweredBy([reply(null)]), isFalse);
    });

    test('pastikan copyWith mempertahankan tombol dan balasan', () {
      expect(tAgent.copyWith(status: ChatMessageStatus.sent).buttons, [tButton]);
      expect(reply(tButton).copyWith(id: 'm').buttonReply, tButton);
    });
  });

  test('pastikan toString dan props ikut tombol', () {
    const tSession = ChatSession(visitorId: 'v', conversationId: 'c', wsPath: '/ws');
    const params = ParamsSendChatButtonReply(session: tSession, button: tButton);
    expect(params.props, [tSession, tButton]);
    expect(params.toString(), contains('naila_helpdesk_btn'));
    expect(tButton.toString(), contains('Hubungi Helpdesk'));
  });
}
