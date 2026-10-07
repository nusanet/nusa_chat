import 'dart:async';
import 'dart:convert';

import 'package:nusa_chat/src/core/error/exception.dart';
import 'package:nusa_chat/src/features/data/models/message/send_message_body.dart';
import 'package:nusa_chat/src/features/data/models/socket/socket_event_model.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens a WebSocket with extra handshake headers. Replaceable in tests.
typedef WebSocketConnector = WebSocketChannel Function(Uri uri, Map<String, dynamic> headers);

WebSocketChannel _ioConnector(Uri uri, Map<String, dynamic> headers) {
  return IOWebSocketChannel.connect(uri, headers: headers, pingInterval: const Duration(seconds: 25));
}

/// A frame from [ChatSocketDataSource.connect]: either a server event, or the
/// open/close of the connection itself.
sealed class SocketFrame {
  const SocketFrame();
}

class SocketOpenedFrame extends SocketFrame {
  const SocketOpenedFrame();
}

class SocketEventFrame extends SocketFrame {
  final SocketEventModel event;

  const SocketEventFrame(this.event);
}

class SocketClosedFrame extends SocketFrame {
  final int? code;
  final String? reason;

  const SocketClosedFrame({this.code, this.reason});
}

/// The bridge's real-time channel `WS /v1/ws?visitor_id=..&conversation_id=..`.
///
/// A non-browser client must send `Origin` explicitly on the upgrade — the
/// server validates it manually in `onOpen` and closes with `1008` otherwise
/// (docs/15-websocket-guide.md § Langkah 2).
abstract class ChatSocketDataSource {
  bool get isOpen;

  /// Connects and streams frames until the socket closes. The stream always
  /// ends with a [SocketClosedFrame] and never emits errors.
  Stream<SocketFrame> connect(Uri uri, {required String origin});

  /// Throws [SocketException] when the socket is not open.
  void send(SendMessageBody body);

  Future<void> close();
}

class ChatSocketDataSourceImpl implements ChatSocketDataSource {
  final WebSocketConnector connector;

  ChatSocketDataSourceImpl({WebSocketConnector? connector}) : connector = connector ?? _ioConnector;

  WebSocketChannel? _channel;
  bool _isOpen = false;

  @override
  bool get isOpen => _isOpen;

  @override
  Stream<SocketFrame> connect(Uri uri, {required String origin}) {
    late final StreamController<SocketFrame> controller;
    StreamSubscription<dynamic>? subscription;
    WebSocketChannel? channel;

    void finish(int? code, String? reason) {
      if (controller.isClosed) return;
      if (identical(_channel, channel)) {
        _isOpen = false;
        _channel = null;
      }
      controller.add(SocketClosedFrame(code: code, reason: reason));
      controller.close();
    }

    controller = StreamController<SocketFrame>(
      onListen: () async {
        try {
          channel = connector(uri, {'Origin': origin});
          _channel = channel;
          await channel!.ready;
        } catch (error) {
          finish(null, error.toString());
          return;
        }
        if (controller.isClosed) return;
        _isOpen = true;
        controller.add(const SocketOpenedFrame());
        subscription = channel!.stream.listen(
          (data) {
            final event = _decode(data);
            if (event != null && !controller.isClosed) controller.add(SocketEventFrame(event));
          },
          onError: (Object error) => finish(channel?.closeCode, error.toString()),
          onDone: () => finish(channel?.closeCode, channel?.closeReason),
          cancelOnError: true,
        );
      },
      // Not awaited: the done event waits for onCancel, and closing the sink
      // of a channel that never connected does not complete.
      onCancel: () {
        subscription?.cancel();
        _closeQuietly(channel);
        if (identical(_channel, channel)) {
          _isOpen = false;
          _channel = null;
        }
      },
    );
    return controller.stream;
  }

  SocketEventModel? _decode(dynamic data) {
    if (data is! String) return null;
    try {
      final json = jsonDecode(data);
      if (json is Map<String, dynamic>) return SocketEventModel.fromJson(json);
    } on FormatException {
      // Not JSON — ignore the frame.
    }
    return null;
  }

  @override
  void send(SendMessageBody body) {
    final channel = _channel;
    if (channel == null || !_isOpen) throw SocketException('socket tidak terhubung');
    channel.sink.add(jsonEncode(body.toJson()));
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _isOpen = false;
    _channel = null;
    _closeQuietly(channel);
  }

  static void _closeQuietly(WebSocketChannel? channel) {
    channel?.sink.close(1000).catchError((Object _) {});
  }
}
