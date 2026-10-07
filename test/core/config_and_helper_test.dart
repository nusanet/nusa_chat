import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/util/date_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

void main() {
  group('NusaChatConfig', () {
    test('pastikan URL WebSocket diturunkan dari baseUrl', () {
      expect(
        const NusaChatConfig(baseUrl: 'https://chat.example.com/', websiteId: 'w', origin: 'o').socketBaseUrl,
        'wss://chat.example.com',
      );
      expect(
        const NusaChatConfig(baseUrl: 'http://10.0.2.2:4000', websiteId: 'w', origin: 'o').socketBaseUrl,
        'ws://10.0.2.2:4000',
      );
      expect(
        const NusaChatConfig(
          baseUrl: 'https://api.example.com',
          wsBaseUrl: 'wss://ws.example.com/',
          websiteId: 'w',
          origin: 'o',
        ).socketBaseUrl,
        'wss://ws.example.com',
      );
    });
  });

  group('DateHelper', () {
    test('formatTime HH:mm', () {
      expect(DateHelper.formatTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
    });

    test('tryParseServerDate menerima ISO dan format MySQL (UTC)', () {
      expect(DateHelper.tryParseServerDate('2026-10-06T03:10:00.000Z'), DateTime.utc(2026, 10, 6, 3, 10));
      expect(DateHelper.tryParseServerDate('2026-10-06 03:10:00'), DateTime.utc(2026, 10, 6, 3, 10));
      expect(DateHelper.tryParseServerDate(null), isNull);
    });
  });

  test('NusaChatStrings.displayText memberi label untuk pesan non-teks', () {
    const strings = NusaChatStrings();
    ChatMessage message(ChatMessageType type, String text) =>
        ChatMessage(localId: 'x', text: text, type: type, isMine: false, createdAt: DateTime(2026));

    expect(strings.displayText(message(ChatMessageType.text, 'Halo')), 'Halo');
    expect(strings.displayText(message(ChatMessageType.image, 'Foto rumah')), '[Gambar] Foto rumah');
    expect(strings.displayText(message(ChatMessageType.document, '{"caption":"x"}')), '[Dokumen]');
    expect(strings.displayText(message(ChatMessageType.location, '{"latitude":1}')), '[Lokasi]');
  });
}
