import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_compress/flutter_compress.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:nusa_chat/src/core/service/nusa_chat_video_encoder.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/video_trim.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Why picking, locating or recording did not produce a result.
enum NusaChatMediaError {
  permissionDenied,

  /// Location services (GPS) are off.
  serviceDisabled,

  /// The bridge would reject the file's type.
  unsupported,

  /// The file is over the bridge's size limit for its type.
  tooLarge,

  failed,

  /// A video could not be compressed.
  compressionFailed,
}

class NusaChatMediaException implements Exception {
  final NusaChatMediaError error;

  /// For [NusaChatMediaError.tooLarge]: the limit in bytes.
  final int? maxBytes;

  const NusaChatMediaException(this.error, {this.maxBytes});

  @override
  String toString() => 'NusaChatMediaException{error: $error, maxBytes: $maxBytes}';
}

/// A position from the device, with its accuracy in metres.
class NusaChatPosition {
  final ChatLocation location;
  final double accuracy;

  const NusaChatPosition({required this.location, required this.accuracy});
}

/// What a video file holds.
class NusaChatVideoInfo {
  final Duration duration;

  /// As the platform reports it, which is also what its encoder scales from.
  final int width;
  final int height;

  /// Bits per second, when known.
  final int? bitrate;

  const NusaChatVideoInfo({required this.duration, required this.width, required this.height, this.bitrate});
}

/// Device access the composer needs. Replaceable (e.g. in tests) through
/// `NusaChatPage.mediaService`.
///
/// Photos come from the system photo picker (Android Photo Picker, iOS
/// PHPicker), which needs no storage or photo-library permission — Google
/// Play rejects `READ_MEDIA_IMAGES` for occasional sharing.
abstract class NusaChatMediaService {
  /// Empty when the user cancels. Throws [NusaChatMediaException] for a file
  /// the bridge would reject.
  Future<List<ChatAttachment>> pickImages({required int limit});

  /// Null when the user cancels.
  Future<ChatAttachment?> pickDocument();

  /// Validates a photo taken with the in-app camera.
  Future<ChatAttachment> imageFromPath(String path);

  /// The path of a video from the system photo picker; null when the user
  /// cancels. It still has to be trimmed and compressed with [compressVideo].
  Future<String?> pickVideo();

  /// Throws [NusaChatMediaException] for a file that cannot be read as a video.
  Future<NusaChatVideoInfo> videoInfo(String path);

  /// One image file per position, in order; for the trim timeline.
  Future<List<String>> videoThumbnails(String path, List<Duration> positions);

  /// Encodes the part of the video from [start] to [end] (see
  /// [NusaChatVideoSpec]) into a file the bridge accepts.
  ///
  /// [onProgress] goes from 0 to 1. Null when cancelled with
  /// [cancelVideoCompression]. Throws [NusaChatMediaException] when it fails
  /// or the result is still over the bridge's limit.
  Future<ChatAttachment?> compressVideo(
    String path, {
    required NusaChatVideoInfo info,
    required Duration start,
    required Duration end,
    void Function(double progress)? onProgress,
  });

  Future<void> cancelVideoCompression();

  /// Deletes the temporary copy [pickVideo] made, once it is not needed.
  Future<void> discardVideo(String path);

  /// Saves the video at [url] on this device and returns the file, for playing.
  /// The bridge's media endpoint has no byte ranges, which iOS players need to
  /// stream, so a video is always played from a file.
  Future<String> downloadVideo(String url, {void Function(double progress)? onProgress});

  Future<NusaChatPosition> currentPosition();

  NusaChatVoiceRecorder createRecorder();
}

/// Records one voice note at a time.
abstract class NusaChatVoiceRecorder {
  /// Asks for the microphone and starts. Throws [NusaChatMediaException].
  Future<void> start();

  /// Stops and returns the recording, or null if nothing was recorded.
  Future<ChatAttachment?> stop();

  /// Stops and deletes the recording.
  Future<void> cancel();

  Future<void> dispose();
}

class NusaChatMediaServiceImpl implements NusaChatMediaService {
  final ImagePicker _imagePicker;
  final Dio _dio;
  final NusaChatVideoEncoder _encoder;
  CancellationToken? _compression;

  NusaChatMediaServiceImpl({ImagePicker? imagePicker, Dio? dio, NusaChatVideoEncoder? encoder})
    : _imagePicker = imagePicker ?? ImagePicker(),
      _dio = dio ?? Dio(),
      _encoder = encoder ?? const NusaChatVideoEncoder() {
    final platform = ImagePickerPlatform.instance;
    // The system Photo Picker (backported to older Android by Play services)
    // instead of the legacy document chooser.
    if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  }

  /// Big enough for a readable photo, small enough for the 5 MB limit.
  static const _maxImageSide = 2048.0;
  static const _imageQuality = 80;

  @override
  Future<List<ChatAttachment>> pickImages({required int limit}) async {
    final List<XFile> files;
    if (limit <= 1) {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxImageSide,
        maxHeight: _maxImageSide,
        imageQuality: _imageQuality,
      );
      files = [?file];
    } else {
      files = await _imagePicker.pickMultiImage(
        limit: limit,
        maxWidth: _maxImageSide,
        maxHeight: _maxImageSide,
        imageQuality: _imageQuality,
      );
    }
    return [for (final file in files.take(limit)) await imageFromPath(file.path)];
  }

  @override
  Future<ChatAttachment> imageFromPath(String path) async {
    return _attachment(path, expected: ChatMessageType.image);
  }

  @override
  Future<String?> pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    return file?.path;
  }

  @override
  Future<NusaChatVideoInfo> videoInfo(String path) async {
    final VideoInfo info;
    try {
      info = await FlutterCompress.instance.getVideoInfo(path);
    } on CompressException {
      throw const NusaChatMediaException(NusaChatMediaError.unsupported);
    } on PlatformException {
      throw const NusaChatMediaException(NusaChatMediaError.unsupported);
    }
    if (info.durationMs <= 0 || info.width <= 0 || info.height <= 0) {
      throw const NusaChatMediaException(NusaChatMediaError.unsupported);
    }
    return NusaChatVideoInfo(
      duration: Duration(milliseconds: info.durationMs),
      width: info.width,
      height: info.height,
      bitrate: info.bitrateKbps <= 0 ? null : info.bitrateKbps * 1000,
    );
  }

  @override
  Future<List<String>> videoThumbnails(String path, List<Duration> positions) async {
    return [
      for (final position in positions)
        await FlutterCompress.instance.getThumbnail(
          path,
          positionMs: position.inMilliseconds,
          quality: 40,
          maxWidth: 120,
        ),
    ];
  }

  @override
  Future<ChatAttachment?> compressVideo(
    String path, {
    required NusaChatVideoInfo info,
    required Duration start,
    required Duration end,
    void Function(double progress)? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final name = 'nusa_chat_video_${DateTime.now().millisecondsSinceEpoch}';
    final String? outputPath;
    try {
      if (await _canSendAsIs(path, info: info, start: start, end: end)) {
        // A copy, because the picked file is discarded once this screen closes.
        outputPath = (await File(path).copy('${directory.path}/$name.mp4')).path;
      } else if (_encodesNatively) {
        outputPath = await _encodeNatively(path, '${directory.path}/$name.mp4', info, start, end, onProgress);
      } else {
        outputPath = await _compress(path, directory.path, name, info, start, end, onProgress);
      }
    } on CompressException {
      throw const NusaChatMediaException(NusaChatMediaError.compressionFailed);
    } on PlatformException {
      throw const NusaChatMediaException(NusaChatMediaError.compressionFailed);
    }
    if (outputPath == null) return null;

    final output = File(outputPath);
    final size = await output.length();
    if (size > MediaHelper.maxVideoBytes) {
      await output.delete();
      throw const NusaChatMediaException(NusaChatMediaError.tooLarge, maxBytes: MediaHelper.maxVideoBytes);
    }
    return ChatAttachment(
      type: ChatMessageType.video,
      path: output.path,
      fileName: output.path.split('/').last,
      mimeType: 'video/mp4',
      size: size,
      duration: end - start,
      thumbnailPath: await _videoThumbnail(output.path),
    );
  }

  bool get _encodesNatively => defaultTargetPlatform == TargetPlatform.android;

  /// Encoding again only loses quality when the whole video already is what the
  /// bridge can send. Only Android can read a file's tracks; elsewhere it is
  /// always encoded.
  Future<bool> _canSendAsIs(
    String path, {
    required NusaChatVideoInfo info,
    required Duration start,
    required Duration end,
  }) async {
    if (!_encodesNatively || start > Duration.zero || end < info.duration) return false;
    if (info.duration > MediaHelper.maxVideoDuration) return false;
    if (math.min(info.width, info.height) > NusaChatVideoSpec.maxShortSide) return false;
    if (math.max(info.width, info.height) > NusaChatVideoSpec.maxLongSide) return false;
    if (MediaHelper.mimeTypeOf(path) != 'video/mp4') return false;
    if (await File(path).length() > MediaHelper.maxVideoBytes) return false;
    final tracks = await _encoder.tracks(path);
    return tracks.video == 'video/avc' && (tracks.audio == null || tracks.audio == 'audio/mp4a-latm');
  }

  Future<String?> _encodeNatively(
    String path,
    String output,
    NusaChatVideoInfo info,
    Duration start,
    Duration end,
    void Function(double progress)? onProgress,
  ) async {
    final spec = NusaChatVideoSpec.forSource(width: info.width, height: info.height, sourceBitrate: info.bitrate);
    final finished = await _encoder.encode(
      path: path,
      output: output,
      maxShortSide: NusaChatVideoSpec.maxShortSide,
      maxLongSide: NusaChatVideoSpec.maxLongSide,
      videoBitrate: (spec.videoBitrateMbps * 1000000).round(),
      maxFps: NusaChatVideoSpec.maxFps,
      start: start,
      end: end,
      onProgress: onProgress,
    );
    return finished ? output : null;
  }

  Future<String?> _compress(
    String path,
    String directory,
    String name,
    NusaChatVideoInfo info,
    Duration start,
    Duration end,
    void Function(double progress)? onProgress,
  ) async {
    final spec = NusaChatVideoSpec.forSource(width: info.width, height: info.height, sourceBitrate: info.bitrate);
    final token = _compression = CancellationToken();
    try {
      final result = await FlutterCompress.instance.compress(
        path,
        VideoCompressConfig(
          codec: VideoCodec.h264,
          container: VideoContainer.mp4,
          videoBitrateKbps: (spec.videoBitrateMbps * 1000).round(),
          audioBitrateKbps: NusaChatVideoSpec.audioBitrate ~/ 1000,
          maxWidth: spec.width,
          maxHeight: spec.height,
          frameRate: NusaChatVideoSpec.maxFps.toDouble(),
          trim: TrimRange(startMs: start.inMilliseconds, endMs: end.inMilliseconds),
          // The original is the untrimmed video, never an acceptable result.
          keepOriginalIfLarger: false,
        ),
        onProgress: (progress) => onProgress?.call(progress.progress),
        cancellationToken: token,
        outputDirectory: directory,
        outputName: name,
      );
      return result.outputPath;
    } on VideoCompressCancelledException {
      return null;
    } finally {
      _compression = null;
    }
  }

  /// A video without a thumbnail still sends, with the placeholder in its bubble.
  Future<String?> _videoThumbnail(String path) async {
    try {
      return await FlutterCompress.instance.getThumbnail(path, quality: 70, maxWidth: 720);
    } on CompressException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> cancelVideoCompression() async {
    if (_encodesNatively) {
      await _encoder.cancel();
    } else {
      _compression?.cancel();
    }
  }

  @override
  Future<void> discardVideo(String path) async {
    final directory = await getTemporaryDirectory();
    // Only ever a copy made for us, never a file of the user's.
    if (!path.startsWith(directory.path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String> downloadVideo(String url, {void Function(double progress)? onProgress}) async {
    final directory = await getTemporaryDirectory();
    final target = File('${directory.path}/nusa_chat_video_${url.hashCode.toUnsigned(32).toRadixString(16)}.mp4');
    if (await target.exists()) return target.path;
    final partial = '${target.path}.part';
    try {
      await _dio.download(
        url,
        partial,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } on DioException {
      throw const NusaChatMediaException(NusaChatMediaError.failed);
    }
    await File(partial).rename(target.path);
    return target.path;
  }

  @override
  Future<ChatAttachment?> pickDocument() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: MediaHelper.documentExtensions);
    final file = result == null || result.files.isEmpty ? null : result.files.first;
    final path = file?.path;
    if (file == null || path == null) return null;
    return _attachment(path, expected: ChatMessageType.document, fileName: file.name);
  }

  Future<ChatAttachment> _attachment(String path, {required ChatMessageType expected, String? fileName}) async {
    final name = fileName ?? path.split('/').last;
    final mimeType = MediaHelper.mimeTypeOf(name) ?? MediaHelper.mimeTypeOf(path);
    if (mimeType == null || MediaHelper.typeOfMime(mimeType) != expected) {
      throw const NusaChatMediaException(NusaChatMediaError.unsupported);
    }
    final size = await File(path).length();
    final maxBytes = MediaHelper.maxBytesOf(expected);
    if (size > maxBytes) throw NusaChatMediaException(NusaChatMediaError.tooLarge, maxBytes: maxBytes);
    return ChatAttachment(type: expected, path: path, fileName: name, mimeType: mimeType, size: size);
  }

  @override
  Future<NusaChatPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const NusaChatMediaException(NusaChatMediaError.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const NusaChatMediaException(NusaChatMediaError.permissionDenied);
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } on TimeoutException {
      position = await Geolocator.getLastKnownPosition();
    } catch (_) {
      position = null;
    }
    if (position == null) throw const NusaChatMediaException(NusaChatMediaError.failed);
    return NusaChatPosition(
      location: ChatLocation(latitude: position.latitude, longitude: position.longitude),
      accuracy: position.accuracy,
    );
  }

  @override
  NusaChatVoiceRecorder createRecorder() => NusaChatVoiceRecorderImpl();
}

/// Records Opus in an OGG container on Android 10+ (accepted by the bridge
/// and WhatsApp as a voice note). iOS cannot write OGG, so it records AAC
/// (`audio/mp4`), which the bridge has to allow (`ALLOWED_MIME.audio`).
class NusaChatVoiceRecorderImpl implements NusaChatVoiceRecorder {
  final AudioRecorder _recorder;

  NusaChatVoiceRecorderImpl({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final _stopwatch = Stopwatch();
  String? _mimeType;

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const NusaChatMediaException(NusaChatMediaError.permissionDenied);
    }
    final useOpus =
        defaultTargetPlatform == TargetPlatform.android && await _recorder.isEncoderSupported(AudioEncoder.opus);
    final extension = useOpus ? 'ogg' : 'm4a';
    _mimeType = useOpus ? 'audio/ogg' : 'audio/mp4';
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/nusa_chat_voice_${DateTime.now().millisecondsSinceEpoch}.$extension';
    try {
      await _recorder.start(
        RecordConfig(
          encoder: useOpus ? AudioEncoder.opus : AudioEncoder.aacLc,
          bitRate: useOpus ? 32000 : 64000,
          sampleRate: useOpus ? 48000 : 44100,
          numChannels: 1,
        ),
        path: path,
      );
    } catch (_) {
      throw const NusaChatMediaException(NusaChatMediaError.failed);
    }
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  Future<ChatAttachment?> stop() async {
    _stopwatch.stop();
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size == 0) return null;
    return ChatAttachment(
      type: ChatMessageType.audio,
      path: path,
      fileName: path.split('/').last,
      mimeType: _mimeType ?? 'audio/ogg',
      size: size,
      duration: _stopwatch.elapsed,
    );
  }

  @override
  Future<void> cancel() async {
    _stopwatch.stop();
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
