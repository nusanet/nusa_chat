// A tiny stand-in for nusacontact-socket-bridge, for running the example
// without the real server (which needs Bun, MySQL and MinIO).
//
// It implements the widget contract the plugin uses — docs/15-websocket-guide.md:
//   POST /v1/widget/{website_id}/sessions
//   GET  /v1/widget/{website_id}/conversations/{conversation_id}/messages[?since=]
//   POST /v1/widget/{website_id}/conversations/{conversation_id}/messages   (HTTP fallback)
//   WS   /v1/ws?visitor_id=..&conversation_id=..                           (Origin checked)
// plus a helper to play the agent:
//   POST /agent/{visitor_id}   body: {"text": "..."}
//
// New conversations are seeded with a sample conversation,
// and every visitor message gets an automatic agent reply.
//
//   dart run tool/mock_bridge.dart [--port 4000] [--origin http://localhost:5173] [--no-seed] [--no-auto-reply]
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

final _random = Random.secure();

String _hex(int length) => List.generate(length, (_) => _random.nextInt(16).toRadixString(16)).join();

String _uuid() => '${_hex(8)}-${_hex(4)}-4${_hex(3)}-a${_hex(3)}-${_hex(12)}';

class _Conversation {
  final String id;
  final String visitorId;
  final List<Map<String, dynamic>> messages = [];

  _Conversation(this.id, this.visitorId);
}

late final String _allowedOrigin;
late final bool _autoReply;
late final bool _seed;

final _conversations = <String, _Conversation>{}; // by conversation_id
final _visitorConversation = <String, String>{}; // visitor_id -> conversation_id
final _sockets = <String, WebSocket>{}; // visitor_id -> socket

Future<void> main(List<String> args) async {
  String option(String name, String fallback) {
    final index = args.indexOf('--$name');
    return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
  }

  final port = int.parse(option('port', '4000'));
  _allowedOrigin = option('origin', 'http://localhost:5173');
  _autoReply = !args.contains('--no-auto-reply');
  _seed = !args.contains('--no-seed');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('mock bridge on http://0.0.0.0:$port  (allowed origin: $_allowedOrigin)');
  await for (final request in server) {
    unawaited(
      _handle(request).catchError((Object error) {
        stderr.writeln('error: $error');
        try {
          request.response.statusCode = 500;
          request.response.close();
        } catch (_) {}
      }),
    );
  }
}

Future<void> _handle(HttpRequest request) async {
  final segments = request.uri.pathSegments;
  stdout.writeln('${request.method} ${request.uri}');

  if (segments.length == 2 && segments[0] == 'v1' && segments[1] == 'ws') return _handleSocket(request);

  if (request.method == 'POST' && segments.length == 2 && segments[0] == 'agent') {
    final body = await _readJson(request);
    final ok = _agentReply(segments[1], body['text']?.toString() ?? '');
    return _json(request, ok ? 200 : 404, ok ? {'ok': true} : {'error': 'visitor tidak dikenal'});
  }

  if (segments.length >= 4 && segments[0] == 'v1' && segments[1] == 'widget') {
    if (request.headers.value('origin') != _allowedOrigin) {
      return _json(request, 403, {'error': 'origin tidak diizinkan'});
    }
    if (request.method == 'POST' && segments.length == 4 && segments[3] == 'sessions') {
      return _createSession(request);
    }
    if (segments.length == 6 && segments[3] == 'conversations' && segments[5] == 'messages') {
      final conversation = _conversations[segments[4]];
      if (conversation == null) return _json(request, 404, {'error': 'conversation tidak ditemukan'});
      if (request.method == 'GET') {
        final since = DateTime.tryParse(request.uri.queryParameters['since'] ?? '');
        final rows = conversation.messages
            .where((m) => since == null || DateTime.parse(m['created_at'] as String).isAfter(since))
            .toList();
        return _json(request, 200, {'data': rows});
      }
      if (request.method == 'POST') {
        final body = await _readJson(request);
        final saved = _saveVisitorMessage(conversation, body['body']?.toString() ?? '');
        return _json(request, 200, {'message_id': saved['message_id']});
      }
    }
  }
  return _json(request, 404, {'error': 'not found'});
}

Future<void> _createSession(HttpRequest request) async {
  final body = await _readJson(request);
  var visitorId = body['visitor_id']?.toString();
  if (visitorId != null && !RegExp(r'^[A-Za-z0-9_-]{1,30}$').hasMatch(visitorId)) {
    return _json(request, 400, {'error': 'visitor_id tidak valid — maks 30 karakter, alfanumerik/-/_ saja'});
  }
  visitorId ??= _hex(24);

  var conversation = _conversations[_visitorConversation[visitorId]];
  if (conversation == null) {
    conversation = _Conversation(_uuid(), visitorId);
    _conversations[conversation.id] = conversation;
    _visitorConversation[visitorId] = conversation.id;
    if (_seed) _seedSampleConversation(conversation);
  }
  return _json(request, 200, {
    'visitor_id': visitorId,
    'conversation_id': conversation.id,
    'ws_url': '/v1/ws?visitor_id=$visitorId&conversation_id=${conversation.id}',
  });
}

Future<void> _handleSocket(HttpRequest request) async {
  final visitorId = request.uri.queryParameters['visitor_id'];
  final conversation = _conversations[request.uri.queryParameters['conversation_id']];
  final origin = request.headers.value('origin');
  final socket = await WebSocketTransformer.upgrade(request);

  if (conversation == null || conversation.visitorId != visitorId) {
    await socket.close(1008, 'sesi tidak valid');
    return;
  }
  if (origin != _allowedOrigin) {
    await socket.close(1008, 'origin tidak diizinkan');
    return;
  }

  _sockets[visitorId!] = socket;
  stdout.writeln('ws open  $visitorId');
  socket.listen(
    (data) {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      if (json['type'] != 'message') {
        socket.add(jsonEncode({'type': 'error', 'error': 'tipe pesan tidak didukung mock'}));
        return;
      }
      final saved = _saveVisitorMessage(conversation, json['body']?.toString() ?? '');
      socket.add(jsonEncode({'type': 'ack', 'message_id': saved['message_id']}));
    },
    onDone: () {
      if (identical(_sockets[visitorId], socket)) _sockets.remove(visitorId);
      stdout.writeln('ws close $visitorId');
    },
  );
}

Map<String, dynamic> _saveVisitorMessage(_Conversation conversation, String text) {
  final row = _row(conversation, 'inbound', text.length > 4096 ? text.substring(0, 4096) : text, DateTime.now());
  conversation.messages.add(row);
  if (_autoReply) {
    Timer(const Duration(milliseconds: 1500), () {
      _agentReply(conversation.visitorId, 'Terima kasih, pesan "$text" sudah kami terima. Mohon ditunggu ya.');
    });
  }
  return row;
}

/// Saves an agent reply and pushes it like the Cloud API route does.
bool _agentReply(String visitorId, String text) {
  final conversation = _conversations[_visitorConversation[visitorId]];
  if (conversation == null) return false;
  final row = _row(conversation, 'outbound', text, DateTime.now());
  conversation.messages.add(row);
  _sockets[visitorId]?.add(
    jsonEncode({
      'type': 'message',
      'from': 'agent',
      'message_type': 'text',
      'body': text,
      'message_id': row['message_id'],
    }),
  );
  return true;
}

Map<String, dynamic> _row(_Conversation conversation, String direction, String body, DateTime at) => {
  'message_id': _uuid(),
  'conversation_id': conversation.id,
  'visitor_id': conversation.visitorId,
  'direction': direction,
  'type': 'text',
  'body': body,
  'media_url': null,
  'wa_message_id': null,
  'status': 'sent',
  'created_at': at.toUtc().toIso8601String(),
};

/// A sample support conversation.
void _seedSampleConversation(_Conversation conversation) {
  final today = DateTime.now();
  DateTime at(int hour, int minute, int second) => DateTime(today.year, today.month, today.day, hour, minute, second);
  conversation.messages.addAll([
    _row(
      conversation,
      'inbound',
      'Halo, selamat pagi. Internet saya mati sejak tadi pagi, bagimana ya?',
      at(10, 10, 0),
    ),
    _row(
      conversation,
      'outbound',
      'Halo, Selamat Pagi Pak Thomas\nKami bantu cek kendala internet Anda. Apakah lampu indikator pada modem/ONT menyala normal?',
      at(10, 12, 0),
    ),
    _row(conversation, 'inbound', 'Ada lampu merah LOS.', at(10, 10, 30)),
    _row(
      conversation,
      'outbound',
      'Terima kasih informasinya. Kami mendeteksi kemungkinan gangguan pada koneksi fiber Anda. Saat ini kami sedang melakukan pengecekan lebih lanjut.',
      at(10, 12, 45),
    ),
    _row(conversation, 'inbound', 'Kapan selesai?', at(10, 13, 0)),
  ]);
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  final text = await utf8.decoder.bind(request).join();
  if (text.isEmpty) return {};
  final json = jsonDecode(text);
  return json is Map<String, dynamic> ? json : {};
}

Future<void> _json(HttpRequest request, int status, Object body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}
