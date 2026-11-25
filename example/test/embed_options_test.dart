import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat_example/embed_options.dart';

EmbedOptions _options(Map<String, String> query, {String websiteIds = 'web_1'}) =>
    EmbedOptions.fromQuery(query, websiteIds: websiteIds);

void main() {
  test('pastikan tanpa parameter tampilan tetap bawaan', () {
    final options = _options({});
    final fallback = NusaChatTheme.fallback();

    expect(options.theme.myBubbleColor, fallback.myBubbleColor);
    expect(options.theme.appBarColor, fallback.appBarColor);
    expect(options.strings.title, const NusaChatStrings().title);
    expect(options.showClose, isTrue);
  });

  test('pastikan parameter mengubah warna dan teks', () {
    final options = _options({
      'color': '7f3bba',
      'appbar': '#FFF4E5',
      'title': ' Bantuan ',
      'agent': 'CS Nusanet',
      'hint': 'Ketik pertanyaan...',
      'close': '0',
    });

    expect(options.theme.myBubbleColor, const Color(0xFF7F3BBA));
    expect(options.theme.myTextStyle.color, Colors.white);
    expect(options.theme.sendIconColor, Colors.white);
    expect(options.theme.appBarColor, const Color(0xFFFFF4E5));
    expect(options.theme.appBarTitleStyle.color, Colors.black87);
    expect(options.strings.title, 'Bantuan');
    expect(options.strings.agentName, 'CS Nusanet');
    expect(options.strings.hintText, 'Ketik pertanyaan...');
    expect(options.showClose, isFalse);
  });

  test('pastikan teks tetap terbaca di warna terang', () {
    expect(_options({'color': 'ffc24b'}).theme.myTextStyle.color, Colors.black87);
  });

  test('pastikan nilai yang tidak valid diabaikan', () {
    final options = _options({'color': 'merah', 'appbar': '12345', 'title': '  '});

    expect(options.color, isNull);
    expect(options.appBarColor, isNull);
    expect(options.title, isNull);
  });

  test('pastikan website hanya dipakai bila terdaftar saat build, selain itu yang pertama', () {
    const ids = ' web_1, web_2,';

    expect(_options({'website': 'web_2'}, websiteIds: ids).websiteId, 'web_2');
    expect(_options({'website': 'lain'}, websiteIds: ids).websiteId, 'web_1');
    expect(_options({'website': ''}, websiteIds: ids).websiteId, 'web_1');
    expect(_options({}, websiteIds: ids).websiteId, 'web_1');
    expect(_options({'website': 'web_2'}).websiteId, 'web_1');
  });
}
