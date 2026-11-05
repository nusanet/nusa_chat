import 'package:flutter/services.dart';

/// The sample types of a video file; null for a track it does not have.
class NusaChatVideoTracks {
  final String? video;
  final String? audio;

  const NusaChatVideoTracks({this.video, this.audio});
}

/// The Android side of this package: encodes with a constant bitrate, which is
/// what keeps the size of a video predictable there.
class NusaChatVideoEncoder {
  static const _channel = MethodChannel('nusa_chat/video');

  const NusaChatVideoEncoder();

  /// Throws [PlatformException] for a file that cannot be read.
  Future<NusaChatVideoTracks> tracks(String path) async {
    final tracks = await _channel.invokeMapMethod<String, String?>('tracks', {'path': path});
    return NusaChatVideoTracks(video: tracks?['video'], audio: tracks?['audio']);
  }

  /// Writes the part from [start] to [end] of [path] to [output]. Returns false
  /// when [cancel] stopped it; throws [PlatformException] when it fails.
  Future<bool> encode({
    required String path,
    required String output,
    required int maxShortSide,
    required int maxLongSide,
    required int videoBitrate,
    required int maxFps,
    required Duration start,
    required Duration end,
    void Function(double progress)? onProgress,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') onProgress?.call(call.arguments as double);
    });
    try {
      await _channel.invokeMethod<void>('encode', {
        'path': path,
        'output': output,
        'maxShortSide': maxShortSide,
        'maxLongSide': maxLongSide,
        'videoBitrate': videoBitrate,
        'maxFps': maxFps,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      });
      return true;
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') return false;
      rethrow;
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
