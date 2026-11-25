// Entry point of the chat as an embedded web page: only the chat, shown by
// `web/landing.html` in an iframe.
//
//   flutter build web -t lib/embed.dart
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:web/web.dart' as web;

import 'embed_options.dart';

const _baseUrl = String.fromEnvironment('NUSA_CHAT_BASE_URL', defaultValue: 'http://localhost:4000');

/// Website ids the iframe may ask for with `?website=`, separated by commas;
/// the first is the default.
const _websiteIds = String.fromEnvironment('NUSA_CHAT_WEBSITE_IDS', defaultValue: 'dev-website');

/// Sent to the parent page when the visitor taps X; `landing.html` hides the panel.
const _closeMessage = 'nusa_chat:close';

void main() => runApp(EmbedApp(options: EmbedOptions.fromQuery(Uri.base.queryParameters, websiteIds: _websiteIds)));

class EmbedApp extends StatelessWidget {
  final EmbedOptions options;

  const EmbedApp({super.key, required this.options});

  @override
  Widget build(BuildContext context) {
    final embedded = web.window.parent != web.window;
    return MaterialApp(
      title: 'NusaChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1A61B2), useMaterial3: true),
      home: NusaChatPage(
        // No visitorId: taken from the page it could be another visitor's, so
        // the plugin uses the one the server generates.
        config: NusaChatConfig(
          baseUrl: _baseUrl,
          websiteId: options.websiteId,
          origin: Uri.base.origin, // not used on the web: the browser sends the origin of this page
          pageUrl: web.document.referrer.isEmpty ? null : web.document.referrer,
          clientVersion: '2.1.0',
        ),
        theme: options.theme,
        strings: options.strings,
        // Without onBack, and as the first route, the chat has no back button.
        actions: [
          if (embedded && options.showClose)
            NusaChatIconButton(
              svgAsset: BaseIcons.close,
              tooltip: 'Tutup chat',
              // The message carries no data, so any parent may receive it.
              onTap: () => web.window.parent?.postMessage(_closeMessage.toJS, '*'.toJS),
            ),
        ],
      ),
    );
  }
}
