import 'package:flutter/material.dart';
import 'package:nusa_chat/nusa_chat.dart';

/// The look and the website of the embedded chat, read from the URL of the
/// iframe. Anyone can edit that URL, so never read who the visitor is or the
/// bridge's address from it.
///
/// | Parameter | Changes |
/// |---|---|
/// | `color` | visitor bubbles, send button and input border, as `rrggbb` |
/// | `appbar` | app bar background, as `rrggbb` |
/// | `title`, `agent`, `hint` | app bar title, agent name, composer placeholder |
/// | `close=0` | hides the X |
/// | `website` | website id on the bridge, one of the ids allowed at build time |
class EmbedOptions {
  final Color? color;
  final Color? appBarColor;
  final String? title;
  final String? agentName;
  final String? hintText;
  final bool showClose;
  final String websiteId;

  /// [websiteIds] are the ids `website` may name, separated by commas, at least
  /// one; any other value opens the first.
  EmbedOptions.fromQuery(Map<String, String> query, {required String websiteIds})
    : color = _color(query['color']),
      appBarColor = _color(query['appbar']),
      title = _text(query['title']),
      agentName = _text(query['agent']),
      hintText = _text(query['hint']),
      showClose = query['close'] != '0',
      websiteId = _website(query['website'], websiteIds);

  static final _hexColor = RegExp(r'^#?([0-9a-fA-F]{6})$');

  static Color? _color(String? value) {
    final hex = _hexColor.firstMatch(value ?? '')?.group(1);
    return hex == null ? null : Color(0xFF000000 | int.parse(hex, radix: 16));
  }

  static String _website(String? value, String websiteIds) {
    final ids = websiteIds.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    final id = _text(value);
    return ids.contains(id) ? id! : ids.first;
  }

  static String? _text(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Black or white, whichever reads on [background].
  static Color _on(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black87;

  NusaChatTheme get theme {
    var theme = NusaChatTheme.fallback();
    if (color case final color?) {
      final onColor = _on(color);
      theme = theme.copyWith(
        myBubbleColor: color,
        myTextStyle: theme.myTextStyle.copyWith(color: onColor),
        myTimeStyle: theme.myTimeStyle.copyWith(color: onColor.withValues(alpha: 0.7)),
        myStatusColor: onColor.withValues(alpha: 0.7),
        inputFocusedBorderColor: color,
        cursorColor: color,
        sendButtonGradient: LinearGradient(colors: [color, color]),
        sendIconColor: onColor,
      );
    }
    if (appBarColor case final color?) {
      theme = theme.copyWith(
        appBarColor: color,
        appBarTitleStyle: theme.appBarTitleStyle.copyWith(color: _on(color)),
      );
    }
    return theme;
  }

  NusaChatStrings get strings {
    const fallback = NusaChatStrings();
    return NusaChatStrings(
      title: title ?? fallback.title,
      agentName: agentName ?? fallback.agentName,
      hintText: hintText ?? fallback.hintText,
    );
  }
}
