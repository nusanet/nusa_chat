// A tiny stand-in for nusacontact-socket-bridge, for running the example
// without the real server (which needs Bun, MySQL and MinIO).
//
// It implements the widget contract the plugin uses — docs/15-websocket-guide.md:
//   POST /v1/widget/{website_id}/sessions
//   GET  /v1/widget/{website_id}/conversations/{conversation_id}/messages[?since=]
//   POST /v1/widget/{website_id}/conversations/{conversation_id}/messages   (HTTP fallback)
//   GET  /v1/widget/{website_id}/visitors/{visitor_id}/conversations[?order=&page=&limit=]
//   GET  /v1/widget/{website_id}/visitors/{visitor_id}/messages[?limit=&since=]
//   POST /v1/widget/{website_id}/media                                      (multipart; video/mp4 up to 16 MB, images...)
//   GET  /v1/widget/{website_id}/media/{media_id}
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
import 'dart:typed_data';

final _random = Random.secure();

String _hex(int length) => List.generate(length, (_) => _random.nextInt(16).toRadixString(16)).join();

String _uuid() => '${_hex(8)}-${_hex(4)}-4${_hex(3)}-a${_hex(3)}-${_hex(12)}';

class _Conversation {
  final String id;
  final String visitorId;
  final List<Map<String, dynamic>> messages = [];
  final String? closedAt;
  final String _createdAt = DateTime.now().toUtc().toIso8601String();

  _Conversation(this.id, this.visitorId, {this.closedAt});

  String get openedAt => messages.isEmpty ? _createdAt : messages.first['created_at'] as String;

  String get lastActivityAt => messages.isEmpty ? _createdAt : messages.last['created_at'] as String;
}

late final String _allowedOrigin;
late final bool _autoReply;
late final bool _seed;

final _conversations = <String, _Conversation>{}; // by conversation_id
final _visitorConversation = <String, String>{}; // visitor_id -> conversation_id
final _sockets = <String, WebSocket>{}; // visitor_id -> socket
final _media = <String, ({String mimeType, List<int> bytes})>{}; // by media_id

const _maxMediaBytes = 16 * 1024 * 1024;

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

  if (request.method == 'GET' &&
      segments.length == 5 &&
      segments[0] == 'v1' &&
      segments[1] == 'widget' &&
      segments[3] == 'media') {
    final media = _media[segments[4]];
    if (media == null) return _json(request, 404, {'error': 'media tidak ditemukan'});
    request.response
      ..headers.contentType = ContentType.parse(media.mimeType)
      ..contentLength = media.bytes.length
      ..add(media.bytes);
    return request.response.close();
  }

  if (segments.length >= 4 && segments[0] == 'v1' && segments[1] == 'widget') {
    if (request.headers.value('origin') != _allowedOrigin) {
      return _json(request, 403, {'error': 'origin tidak diizinkan'});
    }
    if (request.method == 'POST' && segments.length == 4 && segments[3] == 'sessions') {
      return _createSession(request);
    }
    if (request.method == 'POST' && segments.length == 4 && segments[3] == 'media') return _uploadMedia(request);
    if (request.method == 'GET' && segments.length == 6 && segments[3] == 'visitors') {
      final threads = _conversations.values.where((c) => c.visitorId == segments[4]).toList();
      if (threads.isEmpty) return _json(request, 404, {'error': 'visitor tidak ditemukan'});
      if (segments[5] == 'conversations') return _listConversations(request, threads);
      if (segments[5] == 'messages') return _listVisitorMessages(request, threads);
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

/// `POST .../media`: takes the multipart `file` part as the bridge would.
Future<void> _uploadMedia(HttpRequest request) async {
  final boundary = request.headers.contentType?.parameters['boundary'];
  if (boundary == null) return _json(request, 400, {'error': 'field file wajib diisi'});
  final body = await request.fold<BytesBuilder>(BytesBuilder(copy: false), (all, chunk) => all..add(chunk));
  final bytes = body.takeBytes();
  // Latin-1 keeps one character per byte, so offsets stay valid for the binary body.
  final text = latin1.decode(bytes);
  final partStart = text.indexOf('--$boundary');
  final headersEnd = text.indexOf('\r\n\r\n', partStart);
  final partEnd = text.indexOf('\r\n--$boundary', headersEnd);
  if (partStart < 0 || headersEnd < 0 || partEnd < 0) return _json(request, 400, {'error': 'multipart rusak'});
  final mimeType = RegExp(
    r'content-type: *([^\r\n]+)',
    caseSensitive: false,
  ).firstMatch(text.substring(partStart, headersEnd))?.group(1)?.trim();
  final category = switch (mimeType?.split('/').first) {
    'image' => 'image',
    'audio' => 'audio',
    'video' when mimeType == 'video/mp4' => 'video',
    'application' => 'document',
    _ => null,
  };
  if (category == null) return _json(request, 400, {'error': 'tipe file "$mimeType" tidak didukung'});
  final file = bytes.sublist(headersEnd + 4, partEnd);
  if (file.length > _maxMediaBytes) return _json(request, 400, {'error': 'ukuran file melebihi batas'});
  final mediaId = _hex(24);
  _media[mediaId] = (mimeType: mimeType!, bytes: file);
  stdout.writeln('media    $mediaId $mimeType ${file.length} bytes');
  return _json(request, 200, {'media_id': mediaId, 'message_type': category});
}

Future<void> _listConversations(HttpRequest request, List<_Conversation> threads) {
  final query = request.uri.queryParameters;
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final limit = int.tryParse(query['limit'] ?? '20') ?? 20;
  final direction = query['order'] == 'asc' ? 1 : -1;
  threads.sort((a, b) => direction * a.lastActivityAt.compareTo(b.lastActivityAt));
  return _json(request, 200, {
    'data': [
      for (final thread in threads.skip((page - 1) * limit).take(limit))
        {
          'conversation_id': thread.id,
          'visitor_id': thread.visitorId,
          'status': thread.closedAt == null ? 'open' : 'closed',
          'opened_at': thread.openedAt,
          'last_activity_at': thread.lastActivityAt,
          'closed_at': thread.closedAt,
        },
    ],
    'pagination': {
      'page': page,
      'limit': limit,
      'total': threads.length,
      'total_pages': (threads.length / limit).ceil(),
    },
  });
}

Future<void> _listVisitorMessages(HttpRequest request, List<_Conversation> threads) {
  final since = DateTime.tryParse(request.uri.queryParameters['since'] ?? '');
  final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '50') ?? 50;
  final rows =
      threads
          .expand((thread) => thread.messages)
          .where((m) => since == null || DateTime.parse(m['created_at'] as String).isAfter(since))
          .toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
  return _json(request, 200, {'data': rows.take(limit).toList()});
}

/// An older, closed conversation, so the history has more than the open one.
void _seedClosedConversation(String visitorId) {
  final closedAt = DateTime.now().toUtc().subtract(const Duration(days: 3));
  final thread = _Conversation(_uuid(), visitorId, closedAt: closedAt.toIso8601String());
  _conversations[thread.id] = thread;
  thread.messages.addAll([
    {
      'message_id': _uuid(),
      'conversation_id': thread.id,
      'visitor_id': visitorId,
      'direction': 'inbound',
      'type': 'text',
      'body': 'Bagaimana cara reset password MyNusa?',
      'media_url': null,
      'status': 'sent',
      'created_at': closedAt.subtract(const Duration(hours: 25)).toIso8601String(),
    },
    {
      'message_id': _uuid(),
      'conversation_id': thread.id,
      'visitor_id': visitorId,
      'direction': 'outbound',
      'type': 'interactive',
      'body': jsonEncode({
        'text': 'Buka menu Profil > Keamanan > Ganti Password.',
        'buttons': [
          {'id': 'naila_helpdesk_btn', 'title': 'Hubungi Helpdesk'},
        ],
      }),
      'media_url': null,
      'status': 'sent',
      'created_at': closedAt.subtract(const Duration(hours: 24)).toIso8601String(),
    },
  ]);
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
    if (_seed) {
      _seedSampleConversation(conversation);
      _seedClosedConversation(visitorId);
    }
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
      final mediaId = json['media_id']?.toString();
      final saved = mediaId == null
          ? _saveVisitorMessage(conversation, json['body']?.toString() ?? '')
          : _saveVisitorMedia(conversation, json['message_type'].toString(), mediaId, json['caption']?.toString() ?? '');
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

Map<String, dynamic> _saveVisitorMedia(_Conversation conversation, String type, String mediaId, String caption) {
  final row = _row(conversation, 'inbound', caption, DateTime.now())
    ..['type'] = type
    ..['media_url'] = mediaId;
  conversation.messages.add(row);
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
