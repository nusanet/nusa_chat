import 'dart:async';
import 'dart:convert';
import 'dart:io' hide SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/core/error/exception.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';

/// Drives [ChatSocketDataSourceImpl] against a real local WebSocket server.
void main() {
  late HttpServer server;
  late ChatSocketDataSourceImpl dataSource;
  final received = <String>[];
  String? receivedOrigin;

  setUp(() async {
    received.clear();
    receivedOrigin = null;
    dataSource = ChatSocketDataSourceImpl();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      receivedOrigin = request.headers.value('origin');
      final socket = await WebSocketTransformer.upgrade(request);
      if (request.uri.queryParameters['reject'] == '1') {
        await socket.close(1008, 'origin tidak diizinkan');
        return;
      }
      socket.listen((data) {
        received.add(data as String);
        socket.add(jsonEncode({'type': 'ack', 'message_id': 'm-1'}));
        socket.add('not json');
        socket.add(jsonEncode({'type': 'message', 'from': 'agent', 'message_type': 'text', 'body': 'Hai'}));
      });
    });
  });

  tearDown(() async {
    await dataSource.close();
    await server.close(force: true);
  });

  Uri uri([String query = '']) => Uri.parse('ws://127.0.0.1:${server.port}/v1/ws$query');

  test('pastikan Origin terkirim, pesan terkirim dan frame ter-decode', () async {
    final frames = <SocketFrame>[];
    final opened = Completer<void>();
    final gotMessage = Completer<void>();
    final subscription = dataSource.connect(uri(), origin: 'https://app.example.com').listen((frame) {
      frames.add(frame);
      if (frame is SocketOpenedFrame) opened.complete();
      if (frame is SocketEventFrame && frame.event is SocketAgentMessageModel) gotMessage.complete();
    });

    await opened.future;
    expect(dataSource.isOpen, isTrue);
    expect(receivedOrigin, 'https://app.example.com');

    dataSource.send(const SendMessageBody(body: 'Halo'));
    await gotMessage.future;

    expect(received, [
      jsonEncode({'type': 'message', 'body': 'Halo'}),
    ]);
    expect(frames.whereType<SocketEventFrame>().map((f) => f.event).toList(), [
      const SocketAckModel(messageId: 'm-1'),
      const SocketAgentMessageModel(messageId: null, messageType: 'text', body: 'Hai', from: 'agent'),
    ]);
    await subscription.cancel();
    expect(dataSource.isOpen, isFalse);
  });

  test('pastikan close code 1008 diteruskan sebagai frame terakhir', () async {
    final frames = await dataSource.connect(uri('?reject=1'), origin: 'x').toList();

    expect(frames.first, isA<SocketOpenedFrame>());
    final closed = frames.last as SocketClosedFrame;
    expect(closed.code, 1008);
    expect(dataSource.isOpen, isFalse);
  });

  test('pastikan gagal connect berakhir dengan SocketClosedFrame, bukan error', () async {
    final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = unused.port;
    await unused.close();

    final frames = await dataSource.connect(Uri.parse('ws://127.0.0.1:$port/v1/ws'), origin: 'x').toList();

    expect(frames.single, isA<SocketClosedFrame>());
  });

  test('pastikan send saat belum terhubung melempar SocketException', () {
    expect(() => dataSource.send(const SendMessageBody(body: 'x')), throwsA(isA<SocketException>()));
  });
}
