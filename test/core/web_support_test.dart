import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/util/image_edit.dart';
import 'package:nusa_chat/src/core/util/local_file.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_remote_data_source.dart';
import 'package:nusa_chat/src/features/data/data_sources/chat_socket_data_source.dart';
import 'package:nusa_chat/src/injection_container.dart';
import 'package:web_socket_channel/io.dart';

/// Answers every request with [response] and keeps the last request's body.
class _RecordingAdapter implements HttpClientAdapter {
  final Map<String, dynamic> response;
  RequestOptions? options;
  List<int> body = [];

  _RecordingAdapter(this.response);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    this.options = options;
    body = [
      if (requestStream != null)
        for (final chunk in await requestStream.toList()) ...chunk,
    ];
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _config = NusaChatConfig(baseUrl: 'https://chat.example.com', websiteId: 'w', origin: 'https://app.example');

void main() {
  late Directory dir;
  late File photo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nusa_chat_web');
    photo = File('${dir.path}/IMG_01.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
  });

  tearDown(() async {
    NusaChatLocalFile.debugIsWeb = null;
    await dir.delete(recursive: true);
  });

  group('NusaChatLocalFile', () {
    test('pastikan file lokal dibaca lewat path di Android/iOS', () async {
      NusaChatLocalFile.debugIsWeb = false;
      expect(NusaChatLocalFile.isWeb, isFalse);
      expect(NusaChatLocalFile.exists(photo.path), isTrue);
      expect(NusaChatLocalFile.exists('${dir.path}/hilang.jpg'), isFalse);
      expect(await NusaChatLocalFile.length(photo.path), 7);
      expect(await NusaChatLocalFile.readAsBytes(photo.path), photo.readAsBytesSync());
      expect(NusaChatLocalFile.image(photo.path), isA<FileImage>());
    });

    test('pastikan di web path dianggap blob URL', () {
      NusaChatLocalFile.debugIsWeb = true;
      expect(NusaChatLocalFile.isWeb, isTrue);
      expect(NusaChatLocalFile.exists('blob:https://app.example/1'), isTrue);
      expect(NusaChatLocalFile.exists(''), isFalse);
      final image = NusaChatLocalFile.image('blob:https://app.example/1');
      expect(image, isA<NetworkImage>());
      expect((image as NetworkImage).url, 'blob:https://app.example/1');
    });
  });

  group('MediaHelper', () {
    test('pastikan tipe foto dikenali dari byte awal (foto kamera web tanpa nama)', () {
      expect(MediaHelper.imageMimeOfBytes([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
      expect(MediaHelper.imageMimeOfBytes([0x89, 0x50, 0x4E, 0x47, 0x0D]), 'image/png');
      expect(MediaHelper.imageMimeOfBytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]), 'image/webp');
      expect(MediaHelper.imageMimeOfBytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits]), isNull);
      expect(MediaHelper.imageMimeOfBytes('GIF89a'.codeUnits), isNull);
      expect(MediaHelper.imageMimeOfBytes([0xFF]), isNull);
    });

    test('pastikan ekstensi dari MIME', () {
      expect(MediaHelper.extensionOfMime('image/jpeg'), 'jpg');
      expect(MediaHelper.extensionOfMime('audio/webm'), 'webm');
      expect(MediaHelper.extensionOfMime('image/gif'), isNull);
      expect(MediaHelper.mimeTypeOf('.webm'), 'audio/webm');
    });
  });

  group('koneksi', () {
    test('pastikan WebSocket mengirim Origin sendiri di Android/iOS, di web diserahkan ke browser', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final origins = <String?>[];
      server.listen((request) async {
        origins.add(request.headers.value('origin'));
        await (await WebSocketTransformer.upgrade(request)).close();
      });
      final uri = Uri.parse('ws://127.0.0.1:${server.port}/v1/ws');

      for (final web in [false, true]) {
        NusaChatLocalFile.debugIsWeb = web;
        final channel = defaultWebSocketConnector()(uri, {'Origin': 'https://app.example'});
        await channel.ready;
        if (!web) expect(channel, isA<IOWebSocketChannel>());
        await channel.sink.close();
      }
      // On the VM the generic connect() sends no Origin; a browser adds the page's own.
      expect(origins, ['https://app.example', null]);
    });

    test('pastikan header Origin hanya dikirim di luar browser', () {
      NusaChatLocalFile.debugIsWeb = false;
      expect(NusaChatInjector.buildDio(_config).options.headers['Origin'], 'https://app.example');

      NusaChatLocalFile.debugIsWeb = true;
      expect(NusaChatInjector.buildDio(_config).options.headers.containsKey('Origin'), isFalse);
    });

    test('pastikan upload di web mengirim isi file dari blob, bukan dari disk', () async {
      final adapter = _RecordingAdapter({'media_id': 'md-1', 'message_type': 'image'});
      final dio = Dio(BaseOptions(baseUrl: 'https://chat.example.com'))..httpClientAdapter = adapter;
      final dataSource = ChatRemoteDataSourceImpl(dio: dio, config: _config);

      for (final web in [true, false]) {
        NusaChatLocalFile.debugIsWeb = web;
        final response = await dataSource.uploadMedia(path: photo.path, fileName: 'foto.jpg', mimeType: 'image/jpeg');

        expect(response.mediaId, 'md-1', reason: 'web: $web');
        expect(adapter.options!.path, '/v1/widget/w/media');
        final body = latin1.decode(adapter.body);
        expect(body, contains('filename="foto.jpg"'));
        expect(body, contains('content-type: image/jpeg'));
        expect(body, contains(latin1.decode(photo.readAsBytesSync())));
      }
    });
  });

  testWidgets('pastikan foto hasil edit di web disimpan di memori, bukan di folder sementara', (tester) async {
    await tester.runAsync(() async {
      NusaChatLocalFile.debugIsWeb = true;
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = const Color(0xFFFF0000));
      final image = await recorder.endRecording().toImage(8, 8);
      const original = ChatAttachment(
        type: ChatMessageType.image,
        path: 'blob:https://app.example/1',
        fileName: 'IMG_01.png',
        mimeType: 'image/png',
        size: 10,
        caption: 'Lampu LOS',
      );

      final saved = await NusaChatImageEdit.save(image, original, directory: dir);

      expect(saved.fileName, 'IMG_01.jpg');
      expect(saved.mimeType, 'image/jpeg');
      expect(saved.caption, 'Lampu LOS');
      expect(saved.size, greaterThan(0));
      expect(dir.listSync().where((entity) => entity.path.contains('nusa_chat_edit')), isEmpty);
    });
  });
}
