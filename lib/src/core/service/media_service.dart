import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
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

  NusaChatMediaServiceImpl({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker() {
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
