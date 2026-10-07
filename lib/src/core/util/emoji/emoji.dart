import 'package:flutter/foundation.dart';
import 'package:nusa_chat/src/core/util/emoji/emoji_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tabs of the emoji panel, in order.
enum NusaChatEmojiCategory { recent, smileys, people, animals, food, activities, travel, objects }

@immutable
class NusaChatEmoji {
  final String char;

  /// Lowercase Indonesian and English names, `|`-separated, for search.
  final String keywords;

  const NusaChatEmoji(this.char, this.keywords);
}

/// The emoji catalogue: the categories, search, and "Sering Digunakan".
class NusaChatEmojis {
  const NusaChatEmojis._();

  /// How many emoji "Sering Digunakan" shows — 4 rows of 8.
  static const recentLimit = 32;

  /// "Sering Digunakan" before anything was picked.
  static const defaultRecents = [
    '🙏', '😊', '👍', '😂', '❤️', '🙂', '👌', '😅', //
    '😀', '😃', '😄', '😁', '😆', '🥲', '😉', '😍', //
    '🤔', '😢', '😭', '😤', '😠', '🥳', '😴', '🤗', //
    '👏', '🙌', '💪', '✨', '🔥', '📶', '📡', '😎', //
  ];

  static List<NusaChatEmoji> of(NusaChatEmojiCategory category) => nusaChatEmojiData[category] ?? const [];

  /// Emoji whose name or keyword contains every word of [query] — Indonesian
  /// or English. Exact keywords come first, then matches at the start of a
  /// word, then the rest.
  static List<String> search(String query, {int limit = 64}) {
    final words = query.toLowerCase().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final tiers = [<String>[], <String>[], <String>[]];
    for (final list in nusaChatEmojiData.values) {
      for (final emoji in list) {
        if (!words.every(emoji.keywords.contains)) continue;
        final keywords = emoji.keywords.split('|');
        var tier = 0;
        for (final word in words) {
          if (keywords.contains(word)) continue;
          final atWordStart = keywords.any((k) => k.startsWith(word) || k.contains(' $word'));
          tier = atWordStart ? (tier < 1 ? 1 : tier) : 2;
        }
        tiers[tier].add(emoji.char);
      }
    }
    return tiers.expand((t) => t).take(limit).toList();
  }

  /// [recents] first, topped up with [defaultRecents] to [recentLimit].
  static List<String> withDefaults(List<String> recents) {
    return {...recents, ...defaultRecents}.take(recentLimit).toList();
  }
}

/// Remembers the last emoji the visitor picked, across chats.
abstract class NusaChatEmojiStore {
  Future<List<String>> load();

  Future<void> save(List<String> recents);
}

class NusaChatEmojiStoreImpl implements NusaChatEmojiStore {
  SharedPreferencesAsync? _preferences;

  NusaChatEmojiStoreImpl({SharedPreferencesAsync? preferences}) : _preferences = preferences;

  /// Created on first use, inside the try, so a missing platform channel
  /// (e.g. a widget test) only costs the recents.
  SharedPreferencesAsync get preferences => _preferences ??= SharedPreferencesAsync();

  static const _key = 'nusa_chat.emoji_recents';

  @override
  Future<List<String>> load() async {
    try {
      return await preferences.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<String> recents) async {
    try {
      await preferences.setStringList(_key, recents);
    } catch (_) {
      // Recents are a convenience; losing them is fine.
    }
  }
}
