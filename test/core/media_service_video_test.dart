import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter_compress/flutter_compress_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nusa_chat/src/core/service/media_service.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeAdapter implements HttpClientAdapter {
  int calls = 0;
  bool fail = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (fail) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    return ResponseBody.fromBytes(
      [1, 2, 3, 4],
      200,
      headers: {
        Headers.contentLengthHeader: ['4'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakePicker extends ImagePicker {
  String? path;

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => path == null ? null : XFile(path!);
}

class _FakeCompress extends FlutterCompressPlatform with MockPlatformInterfaceMixin {
  final progress = StreamController<CompressionProgress>.broadcast();

  VideoInfo Function(String path) onInfo = (path) => _info(path);
  Future<VideoCompressResult> Function(String id, String directory, String name)? onCompress;
  Future<String> Function(String path, int positionMs)? onThumbnail;

  VideoCompressConfig? config;
  String? cancelled;
  final thumbnailPositions = <int>[];

  static VideoInfo _info(String path) =>
      VideoInfo(path: path, width: 1920, height: 1080, durationMs: 5000, sizeBytes: 100, bitrateKbps: 8000);

  @override
  Stream<CompressionProgress> get progressStream => progress.stream;

  @override
  Future<VideoInfo> getVideoInfo(String path) async => onInfo(path);

  @override
  Future<VideoCompressResult> compress(
    String id,
    String path,
    VideoCompressConfig config,
    String? outputDirectory,
    String? outputName,
  ) {
    this.config = config;
    return onCompress!(id, outputDirectory!, outputName!);
  }

  @override
  Future<void> cancel(String? id) async => cancelled = id;

  @override
  Future<String> getThumbnail(String path, {int positionMs = 0, int quality = 80, int? maxWidth}) async {
    thumbnailPositions.add(positionMs);
    return onThumbnail?.call(path, positionMs) ?? Future.value('/thumb/$positionMs.jpg');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const encoderChannel = MethodChannel('nusa_chat/video');

  late Directory temp;
  late Directory other;
  late _FakeAdapter adapter;
  late _FakePicker picker;
  late _FakeCompress compressor;
  late NusaChatMediaServiceImpl service;

  const info = NusaChatVideoInfo(duration: Duration(minutes: 2), width: 1920, height: 1080, bitrate: 16000000);

  /// A finished compression that wrote [size] bytes.
  Future<VideoCompressResult> Function(String, String, String) succeeding(int size) => (id, directory, name) async {
    compressor.progress.add(CompressionProgress(id: id, progress: 0.5));
    final file = File('$directory/$name.mp4')..writeAsBytesSync(List.filled(size, 0));
    return VideoCompressResult(
      id: id,
      outputPath: file.path,
      originalSizeBytes: 100,
      compressedSizeBytes: size,
      width: 1280,
      height: 720,
      durationMs: 30000,
      codec: 'h264',
      skipped: false,
    );
  };

  setUp(() {
    // flutter_compress does the encoding everywhere but on Android.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    temp = Directory.systemTemp.createTempSync('nusa_chat_test');
    other = Directory.systemTemp.createTempSync('nusa_chat_other');
    adapter = _FakeAdapter();
    picker = _FakePicker();
    compressor = _FakeCompress()..onCompress = succeeding(1000);
    FlutterCompressPlatform.instance = compressor;
    service = NusaChatMediaServiceImpl(imagePicker: picker, dio: Dio()..httpClientAdapter = adapter);
    messenger.setMockMethodCallHandler(pathProvider, (call) async => temp.path);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(pathProvider, null);
    messenger.setMockMethodCallHandler(encoderChannel, null);
    compressor.progress.close();
    temp.deleteSync(recursive: true);
    other.deleteSync(recursive: true);
  });

  Future<dynamic> compress({void Function(double)? onProgress}) => service.compressVideo(
    '/tmp/in.mov',
    info: info,
    start: const Duration(seconds: 10),
    end: const Duration(seconds: 40),
    onProgress: onProgress,
  );

  Matcher failsWith(NusaChatMediaError error) =>
      throwsA(isA<NusaChatMediaException>().having((e) => e.error, 'error', error));

  test('pastikan pickVideo mengembalikan path atau null saat batal', () async {
    expect(await service.pickVideo(), isNull);
    picker.path = '/tmp/in.mov';
    expect(await service.pickVideo(), '/tmp/in.mov');
  });

  group('videoInfo', () {
    test('pastikan metadata dibaca', () async {
      final result = await service.videoInfo('/tmp/in.mov');
      expect(result.duration, const Duration(seconds: 5));
      expect((result.width, result.height, result.bitrate), (1920, 1080, 8000000));
    });

    test('pastikan bitrate yang tidak diketahui menjadi null', () async {
      compressor.onInfo = (path) =>
          VideoInfo(path: path, width: 10, height: 10, durationMs: 10, sizeBytes: 1, bitrateKbps: 0);
      expect((await service.videoInfo('/tmp/in.mov')).bitrate, isNull);
    });

    test('pastikan metadata kosong berarti tidak didukung', () async {
      compressor.onInfo = (path) =>
          VideoInfo(path: path, width: 0, height: 0, durationMs: 0, sizeBytes: 1, bitrateKbps: 0);
      await expectLater(service.videoInfo('/tmp/in.mov'), failsWith(NusaChatMediaError.unsupported));
    });

    test('pastikan file yang tidak terbaca berarti tidak didukung', () async {
      compressor.onInfo = (path) => throw VideoCompressException('failed', 'x');
      await expectLater(service.videoInfo('/tmp/in.mov'), failsWith(NusaChatMediaError.unsupported));
      compressor.onInfo = (path) => throw PlatformException(code: 'x');
      await expectLater(service.videoInfo('/tmp/in.mov'), failsWith(NusaChatMediaError.unsupported));
    });
  });

  test('pastikan thumbnail diminta per posisi', () async {
    final paths = await service.videoThumbnails('/tmp/in.mov', const [Duration.zero, Duration(seconds: 2)]);
    expect(paths, ['/thumb/0.jpg', '/thumb/2000.jpg']);
  });

  group('compressVideo', () {
    test('pastikan pengaturan kompresi, potongan dan hasilnya', () async {
      final seen = <double>[];
      final video = await compress(onProgress: seen.add);
      final config = compressor.config!;

      expect(config.codec, VideoCodec.h264);
      expect(config.container, VideoContainer.mp4);
      expect(config.videoBitrateKbps, 800);
      expect(config.audioBitrateKbps, 64);
      expect((config.maxWidth, config.maxHeight), (1280, 720));
      expect(config.frameRate, 30);
      expect(config.keepOriginalIfLarger, isFalse);
      expect(config.androidNotification, isNull);
      expect((config.trim!.startMs, config.trim!.endMs), (10000, 40000));

      expect(video.type, ChatMessageType.video);
      expect(video.mimeType, 'video/mp4');
      expect(video.size, 1000);
      expect(video.duration, const Duration(seconds: 30));
      expect(video.thumbnailPath, '/thumb/0.jpg');
      expect(video.path, startsWith(temp.path));
      expect(video.fileName, endsWith('.mp4'));
      expect(seen, [0.5]);
    });

    test('pastikan hasil di atas batas ditolak dan filenya dihapus', () async {
      compressor.onCompress = succeeding(MediaHelper.maxVideoBytes + 1);
      await expectLater(
        compress(),
        throwsA(
          isA<NusaChatMediaException>()
              .having((e) => e.error, 'error', NusaChatMediaError.tooLarge)
              .having((e) => e.maxBytes, 'maxBytes', MediaHelper.maxVideoBytes),
        ),
      );
      expect(temp.listSync(), isEmpty);
    });

    test('pastikan batal menghentikan pekerjaan yang berjalan dan menghasilkan null', () async {
      final gate = Completer<VideoCompressResult>();
      String? job;
      compressor.onCompress = (id, directory, name) {
        job = id;
        return gate.future;
      };
      final running = compress();
      await Future<void>.delayed(Duration.zero);
      await service.cancelVideoCompression();
      expect(compressor.cancelled, job);

      gate.completeError(VideoCompressCancelledException());
      expect(await running, isNull);
      await service.cancelVideoCompression();
    });

    test('pastikan gagal menjadi compressionFailed', () async {
      compressor.onCompress = (id, directory, name) async => throw VideoCompressException('failed', 'x');
      await expectLater(compress(), failsWith(NusaChatMediaError.compressionFailed));
      compressor.onCompress = (id, directory, name) async => throw PlatformException(code: 'x');
      await expectLater(compress(), failsWith(NusaChatMediaError.compressionFailed));
    });

    test('pastikan video tetap terkirim tanpa thumbnail', () async {
      compressor.onThumbnail = (path, positionMs) async => throw VideoCompressException('failed', 'x');
      expect((await compress()).thumbnailPath, isNull);
      compressor.onThumbnail = (path, positionMs) async => throw PlatformException(code: 'x');
      expect((await compress()).thumbnailPath, isNull);
    });
  });

  group('compressVideo di Android', () {
    const small = NusaChatVideoInfo(duration: Duration(seconds: 30), width: 1280, height: 720, bitrate: 2000000);
    const whole = Duration(seconds: 30);

    late List<MethodCall> calls;
    late Map<String, String?> tracks;
    late int encodedSize;
    PlatformException? encodeError;
    PlatformException? tracksError;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      calls = [];
      tracks = {'video': 'video/avc', 'audio': 'audio/mp4a-latm'};
      encodedSize = 1000;
      encodeError = null;
      tracksError = null;
      messenger.setMockMethodCallHandler(encoderChannel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'tracks':
            if (tracksError != null) throw tracksError!;
            return tracks;
          case 'encode':
            if (encodeError != null) throw encodeError!;
            final arguments = call.arguments as Map;
            await messenger.handlePlatformMessage(
              encoderChannel.name,
              encoderChannel.codec.encodeMethodCall(const MethodCall('progress', 0.5)),
              (_) {},
            );
            File(arguments['output'] as String).writeAsBytesSync(List.filled(encodedSize, 0));
        }
        return null;
      });
    });

    bool encoded() => calls.any((call) => call.method == 'encode');

    File source({String name = 'picked.mp4', int size = 500}) =>
        File('${other.path}/$name')..writeAsBytesSync(List.filled(size, 0));

    Future<dynamic> send(
      File file, {
      NusaChatVideoInfo video = small,
      Duration start = Duration.zero,
      Duration end = whole,
      void Function(double)? onProgress,
    }) => service.compressVideo(file.path, info: video, start: start, end: end, onProgress: onProgress);

    test('pastikan video dienkode dengan batas dan potongannya', () async {
      final seen = <double>[];
      final video = await service.compressVideo(
        source().path,
        info: info,
        start: const Duration(seconds: 10),
        end: const Duration(seconds: 40),
        onProgress: seen.add,
      );
      video!;

      final call = calls.singleWhere((call) => call.method == 'encode');
      final arguments = call.arguments as Map;
      expect(arguments['maxShortSide'], 720);
      expect(arguments['maxLongSide'], 1280);
      expect(arguments['videoBitrate'], 800000);
      expect(arguments['maxFps'], 30);
      expect((arguments['startMs'], arguments['endMs']), (10000, 40000));
      expect(arguments['output'], video.path);

      expect(video.type, ChatMessageType.video);
      expect(video.size, 1000);
      expect(video.duration, const Duration(seconds: 30));
      expect(video.thumbnailPath, '/thumb/0.jpg');
      expect(compressor.config, isNull);
      expect(seen, [0.5]);
    });

    test('pastikan video yang sudah memenuhi syarat dikirim apa adanya', () async {
      final file = source();
      final video = await send(file);

      expect(encoded(), isFalse);
      expect(compressor.config, isNull);
      expect(video.size, 500);
      expect(video.duration, whole);
      expect(video.mimeType, 'video/mp4');
      expect(video.path, startsWith(temp.path));
      expect(video.path, isNot(file.path));
      expect(file.existsSync(), isTrue);
    });

    test('pastikan video tanpa suara juga dikirim apa adanya', () async {
      tracks = {'video': 'video/avc', 'audio': null};
      await send(source());
      expect(encoded(), isFalse);
    });

    test('pastikan video 480p dikirim apa adanya, tidak diperbesar', () async {
      await send(source(), video: const NusaChatVideoInfo(duration: whole, width: 854, height: 480, bitrate: 1000000));
      expect(encoded(), isFalse);
    });

    test('pastikan video potret 720p dikirim apa adanya', () async {
      await send(source(), video: const NusaChatVideoInfo(duration: whole, width: 720, height: 1280, bitrate: 1000000));
      expect(encoded(), isFalse);
    });

    final encodesAgain = <String, Future<dynamic> Function()>{
      'dipotong di awal': () => send(source(), start: const Duration(seconds: 1)),
      'dipotong di akhir': () => send(source(), end: const Duration(seconds: 29)),
      'lebih dari 1 menit 30 detik': () => send(
        source(),
        video: const NusaChatVideoInfo(duration: Duration(seconds: 91), width: 1280, height: 720),
        end: const Duration(seconds: 91),
      ),
      'sisi pendek di atas 720': () =>
          send(source(), video: const NusaChatVideoInfo(duration: whole, width: 1920, height: 1080)),
      'sisi panjang di atas 1280': () =>
          send(source(), video: const NusaChatVideoInfo(duration: whole, width: 1600, height: 400)),
      'bukan mp4': () => send(source(name: 'picked.mov')),
      'di atas batas ukuran': () => send(source(size: MediaHelper.maxVideoBytes + 1)),
    };
    encodesAgain.forEach((reason, run) {
      test('pastikan video dienkode bila $reason', () async {
        await run();
        expect(encoded(), isTrue);
      });
    });

    test('pastikan video H.265 dienkode', () async {
      tracks = {'video': 'video/hevc', 'audio': 'audio/mp4a-latm'};
      await send(source());
      expect(encoded(), isTrue);
    });

    test('pastikan audio selain AAC dienkode', () async {
      tracks = {'video': 'video/avc', 'audio': 'audio/opus'};
      await send(source());
      expect(encoded(), isTrue);
    });

    test('pastikan hasil di atas batas ditolak dan filenya dihapus', () async {
      encodedSize = MediaHelper.maxVideoBytes + 1;
      await expectLater(
        send(source(), start: const Duration(seconds: 1)),
        throwsA(
          isA<NusaChatMediaException>()
              .having((e) => e.error, 'error', NusaChatMediaError.tooLarge)
              .having((e) => e.maxBytes, 'maxBytes', MediaHelper.maxVideoBytes),
        ),
      );
      expect(temp.listSync(), isEmpty);
    });

    test('pastikan dibatalkan menghasilkan null', () async {
      encodeError = PlatformException(code: 'cancelled');
      expect(await send(source(), start: const Duration(seconds: 1)), isNull);
    });

    test('pastikan gagal menjadi compressionFailed', () async {
      encodeError = PlatformException(code: 'failed');
      await expectLater(
        send(source(), start: const Duration(seconds: 1)),
        failsWith(NusaChatMediaError.compressionFailed),
      );
    });

    test('pastikan file yang track-nya tidak terbaca menjadi compressionFailed', () async {
      tracksError = PlatformException(code: 'unreadable');
      await expectLater(send(source()), failsWith(NusaChatMediaError.compressionFailed));
    });

    test('pastikan batal diteruskan ke sisi native', () async {
      await service.cancelVideoCompression();
      expect(calls.single.method, 'cancel');
    });
  });

  group('discardVideo', () {
    test('pastikan salinan sementara dihapus', () async {
      final file = File('${temp.path}/picked.mp4')..writeAsBytesSync([1]);
      await service.discardVideo(file.path);
      expect(file.existsSync(), isFalse);
      await service.discardVideo(file.path);
    });

    test('pastikan file di luar folder sementara tidak disentuh', () async {
      final file = File('${other.path}/mine.mp4')..writeAsBytesSync([1]);
      await service.discardVideo(file.path);
      expect(file.existsSync(), isTrue);
    });
  });

  group('downloadVideo', () {
    test('pastikan video diunduh sekali lalu dipakai ulang', () async {
      final seen = <double>[];
      final path = await service.downloadVideo('https://x/media/abc', onProgress: seen.add);
      expect(await File(path).readAsBytes(), [1, 2, 3, 4]);
      expect(seen.last, 1.0);
      expect(temp.listSync().where((f) => f.path.endsWith('.part')), isEmpty);

      expect(await service.downloadVideo('https://x/media/abc'), path);
      expect(adapter.calls, 1);
    });

    test('pastikan gagal unduh menjadi failed', () async {
      adapter.fail = true;
      await expectLater(service.downloadVideo('https://x/media/abc'), failsWith(NusaChatMediaError.failed));
    });
  });
}
