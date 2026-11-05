import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart' show NusaChatIosPlugin;
import 'package:nusa_chat/src/core/service/nusa_chat_video_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('nusa_chat/video');
  const encoder = NusaChatVideoEncoder();

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<bool> encode({void Function(double)? onProgress}) => encoder.encode(
    path: '/in.mp4',
    output: '/out.mp4',
    maxShortSide: 720,
    maxLongSide: 1280,
    videoBitrate: 1000000,
    maxFps: 30,
    start: const Duration(seconds: 1),
    end: const Duration(seconds: 2),
    onProgress: onProgress,
  );

  /// As the native side reports progress.
  Future<void> report(MethodCall call) async {
    await messenger.handlePlatformMessage(channel.name, channel.codec.encodeMethodCall(call), (_) {});
  }

  group('tracks', () {
    test('pastikan jenis track dibaca', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'tracks');
        expect(call.arguments, {'path': '/in.mp4'});
        return {'video': 'video/avc', 'audio': null};
      });
      final tracks = await encoder.tracks('/in.mp4');
      expect((tracks.video, tracks.audio), ('video/avc', null));
    });

    test('pastikan jawaban kosong berarti tidak ada track', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final tracks = await encoder.tracks('/in.mp4');
      expect((tracks.video, tracks.audio), (null, null));
    });
  });

  group('encode', () {
    test('pastikan argumen dikirim dan progres diteruskan', () async {
      final seen = <double>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'encode');
        expect(call.arguments, {
          'path': '/in.mp4',
          'output': '/out.mp4',
          'maxShortSide': 720,
          'maxLongSide': 1280,
          'videoBitrate': 1000000,
          'maxFps': 30,
          'startMs': 1000,
          'endMs': 2000,
        });
        await report(const MethodCall('progress', 0.5));
        await report(const MethodCall('other'));
        return null;
      });
      expect(await encode(onProgress: seen.add), isTrue);
      expect(seen, [0.5]);
    });

    test('pastikan progres tanpa pendengar diabaikan', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        await report(const MethodCall('progress', 0.5));
        return null;
      });
      expect(await encode(), isTrue);
    });

    test('pastikan dibatalkan menghasilkan false', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'cancelled'));
      expect(await encode(), isFalse);
    });

    test('pastikan kegagalan diteruskan', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'failed'));
      await expectLater(encode(), throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'failed')));
    });
  });

  test('pastikan cancel memanggil sisi native', () async {
    String? method;
    messenger.setMockMethodCallHandler(channel, (call) async => method = call.method);
    await encoder.cancel();
    expect(method, 'cancel');
  });

  test('pastikan registerWith iOS tidak melakukan apa pun', () {
    expect(NusaChatIosPlugin.registerWith, returnsNormally);
  });
}
