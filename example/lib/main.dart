import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nusa_chat/nusa_chat.dart';

/// Backend settings, passed at build time:
///
/// ```sh
/// flutter run \
///   --dart-define=NUSA_CHAT_BASE_URL=https://chat-nusa.example.com \
///   --dart-define=NUSA_CHAT_WEBSITE_ID=mynusa \
///   --dart-define=NUSA_CHAT_ORIGIN=https://nusaselecta.app
/// ```
///
/// Without them the app talks to the mock bridge (`dart run tool/mock_bridge.dart`)
/// on this machine — `10.0.2.2` is the host as seen from the Android emulator.
const _baseUrl = String.fromEnvironment('NUSA_CHAT_BASE_URL');
const _websiteId = String.fromEnvironment('NUSA_CHAT_WEBSITE_ID', defaultValue: 'dev-website');
const _origin = String.fromEnvironment('NUSA_CHAT_ORIGIN', defaultValue: 'http://localhost:5173');
const _visitorId = String.fromEnvironment('NUSA_CHAT_VISITOR_ID');
const _displayName = String.fromEnvironment('NUSA_CHAT_DISPLAY_NAME', defaultValue: 'Rihanna');

/// Google Maps key with the Maps Static API enabled, for location previews.
/// Without it the preview is a drawn placeholder.
const _googleMapsKey = String.fromEnvironment('NUSA_CHAT_GOOGLE_MAPS_KEY');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NusaChat Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1A61B2), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  NusaChatConfig get _config {
    final defaultHost = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    return NusaChatConfig(
      baseUrl: _baseUrl.isEmpty ? 'http://$defaultHost:4000' : _baseUrl,
      websiteId: _websiteId,
      origin: _origin,
      visitorId: _visitorId.isEmpty ? null : _visitorId,
      displayName: _displayName,
      pageUrl: 'app://nusa_chat_example/home',
      enableLog: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NusaChat Example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Buka NusaChat'),
            onPressed: () => NusaChat.open(
              context,
              page: NusaChatPage(
                config: _config,
                onReportTap: () => _snack(context, 'Laporkan percakapan'),
                attachments: NusaChatAttachmentOptions(
                  googleMap: _googleMapsKey.isEmpty ? null : const NusaChatGoogleMap(apiKey: _googleMapsKey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Tanya soal pesanan'),
            onPressed: () => NusaChat.open(
              context,
              page: NusaChatPage(config: _config, initialMessage: 'Halo, saya mau tanya soal pesanan #INV-123'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Buka NusaChat (kustom)'),
            onPressed: () => NusaChat.open(context, page: _customized(context)),
          ),
        ],
      ),
    );
  }

  /// Every customization point at once: colours, texts, app bar actions and
  /// replaced components.
  NusaChatPage _customized(BuildContext context) {
    final theme = NusaChatTheme.fallback().copyWith(
      appBarColor: const Color(0xFFFFF4E5),
      myBubbleColor: const Color(0xFF7F3BBA),
      agentAvatarColor: const Color(0xFFE67A0F),
      inputFocusedBorderColor: const Color(0xFF7F3BBA),
      sendButtonGradient: const LinearGradient(colors: [Color(0xFFA86BE1), Color(0xFF7F3BBA)]),
    );
    return NusaChatPage(
      config: _config,
      theme: theme,
      strings: const NusaChatStrings(title: 'Bantuan', agentName: 'CS Nusanet', hintText: 'Ketik pertanyaan...'),
      actions: [
        NusaChatIconButton(icon: const Icon(Icons.call_outlined), onTap: () => _snack(context, 'Telepon CS')),
        NusaChatIconButton(svgAsset: BaseIcons.messageReport, onTap: () => _snack(context, 'Laporkan')),
      ],
      agentAvatarBuilder: (context) => const NusaChatAvatar(child: Icon(Icons.support_agent, color: Colors.white)),
      sendButtonBuilder: (context, onSend) => IconButton.filled(
        onPressed: onSend,
        icon: const Icon(Icons.send_rounded),
        style: IconButton.styleFrom(backgroundColor: const Color(0xFF7F3BBA)),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
