import 'package:equatable/equatable.dart';

/// Connection settings of the NusaContact Socket Bridge the chat talks to.
///
/// [origin] must be one of the `allowed_origins` registered for [websiteId] on
/// the server. A mobile client has no page origin, so it is sent explicitly on
/// every HTTP request and on the WebSocket upgrade (docs/15-websocket-guide.md
/// § Langkah 2) — without it the server answers 403 / closes the socket 1008.
class NusaChatConfig extends Equatable {
  /// Base URL of the bridge, e.g. `https://chat-nusa.example.com`.
  final String baseUrl;

  /// The `website_id` registered on the bridge.
  final String websiteId;

  /// Origin header value, e.g. `https://app.example.com`.
  final String origin;

  /// Visitor identity supplied by the host app (e.g. a normalised phone number
  /// or customer id). Max 30 chars, alphanumeric/`-`/`_`. When null the server
  /// generates one and the plugin remembers it on the device.
  final String? visitorId;

  /// Contact name shown to the agent in NusaWAChannel (1–150 chars).
  final String? displayName;

  /// Context for the agent, e.g. the screen the chat was opened from.
  final String? pageUrl;

  /// Firebase Cloud Messaging token of this device, sent when the session
  /// starts so the server can push agent replies while the chat is closed.
  /// The host app owns Firebase; the plugin only forwards the token.
  final String? fcmToken;

  /// Version of the host app, e.g. `2.1.0`, sent as `client_version` when the
  /// session starts. The bridge hands the chat to the Naila assistant only
  /// when it is at least the `min_client_version` configured for
  /// [websiteId]; without it the visitor gets the old flow (greeting, then
  /// an agent). Digits separated by dots, up to four parts, at most 20
  /// characters: any other value is not sent, as the bridge would refuse the
  /// session with 400.
  final String? clientVersion;

  /// Overrides the WebSocket base derived from [baseUrl] (`http`→`ws`, `https`→`wss`).
  final String? wsBaseUrl;

  /// Shows request/response logs in debug builds.
  final bool enableLog;

  const NusaChatConfig({
    required this.baseUrl,
    required this.websiteId,
    required this.origin,
    this.visitorId,
    this.displayName,
    this.pageUrl,
    this.fcmToken,
    this.clientVersion,
    this.wsBaseUrl,
    this.enableLog = false,
  });

  static final _clientVersionPattern = RegExp(r'^\d+(\.\d+){0,3}$');

  /// [clientVersion] trimmed, or null when it is not a version the bridge accepts.
  String? get validClientVersion {
    final version = clientVersion?.trim();
    if (version == null || version.length > 20 || !_clientVersionPattern.hasMatch(version)) return null;
    return version;
  }

  /// [baseUrl] without a trailing slash.
  String get normalizedBaseUrl => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// WebSocket base URL, derived from [baseUrl] unless [wsBaseUrl] is set.
  String get socketBaseUrl {
    final override = wsBaseUrl;
    if (override != null && override.isNotEmpty) {
      return override.endsWith('/') ? override.substring(0, override.length - 1) : override;
    }
    final base = normalizedBaseUrl;
    if (base.startsWith('https://')) return 'wss://${base.substring(8)}';
    if (base.startsWith('http://')) return 'ws://${base.substring(7)}';
    return base;
  }

  @override
  List<Object?> get props => [
    baseUrl,
    websiteId,
    origin,
    visitorId,
    displayName,
    pageUrl,
    fcmToken,
    clientVersion,
    wsBaseUrl,
    enableLog,
  ];

  @override
  String toString() {
    return 'NusaChatConfig{baseUrl: $baseUrl, websiteId: $websiteId, origin: $origin, visitorId: $visitorId, displayName: $displayName, pageUrl: $pageUrl, fcmToken: $fcmToken, clientVersion: $clientVersion, wsBaseUrl: $wsBaseUrl}';
  }
}
