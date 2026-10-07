import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';

void main() {
  group('NusaChatEmojis', () {
    test('pastikan setiap tab selain recent berisi emoji', () {
      for (final category in NusaChatEmojiCategory.values.skip(1)) {
        expect(NusaChatEmojis.of(category), isNotEmpty, reason: category.name);
      }
      expect(NusaChatEmojis.of(NusaChatEmojiCategory.recent), isEmpty);
    });

    test('pastikan pencarian bahasa Indonesia dan Inggris', () {
      expect(NusaChatEmojis.search('sinyal'), contains('📶'));
      expect(NusaChatEmojis.search('signal'), contains('📶'));
      expect(NusaChatEmojis.search('bendera indonesia'), contains('🇮🇩'));
      expect(NusaChatEmojis.search('  '), isEmpty);
      expect(NusaChatEmojis.search('qwertyzxcv'), isEmpty);
    });

    test('pastikan kata kunci persis didahulukan', () {
      // 🔥 has the keyword "api"; 🎆 only "kembang api".
      final results = NusaChatEmojis.search('api');
      expect(results.indexOf('🔥'), lessThan(results.indexOf('🎆')));
    });

    test('pastikan withDefaults mendahulukan recents lalu diisi default sampai 32', () {
      final list = NusaChatEmojis.withDefaults(['🐱', '🙏']);
      expect(list.take(3), ['🐱', '🙏', '😊']);
      expect(list, hasLength(NusaChatEmojis.recentLimit));
      expect(list.toSet(), hasLength(list.length));
    });

    test('pastikan emoji default ada di katalog', () {
      final all = {for (final c in NusaChatEmojiCategory.values) ...NusaChatEmojis.of(c).map((e) => e.char)};
      for (final emoji in NusaChatEmojis.defaultRecents) {
        expect(all, contains(emoji));
      }
    });
  });
}
