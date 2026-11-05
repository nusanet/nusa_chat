import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';

/// The part of a video to keep. Never longer than [maxLength], and never
/// shorter than [minLength] unless the whole video is.
@immutable
class NusaChatTrimRange {
  final Duration start;
  final Duration end;

  /// The length of the whole video.
  final Duration total;
  final Duration maxLength;

  static const minLength = Duration(seconds: 1);

  const NusaChatTrimRange._(this.start, this.end, this.total, this.maxLength);

  /// Starts at the beginning, as long as allowed.
  factory NusaChatTrimRange.initial(Duration total, {Duration maxLength = MediaHelper.maxVideoDuration}) {
    return NusaChatTrimRange._(Duration.zero, _shorter(total, maxLength), total, maxLength);
  }

  Duration get length => end - start;

  /// What the handles keep apart: [minLength], or the whole of a shorter video.
  Duration get _shortest => _shorter(minLength, total);

  /// Moves the start; the end follows when the range would get too long.
  NusaChatTrimRange withStart(Duration value) {
    final newStart = _clamp(value, Duration.zero, total - _shortest);
    final newEnd = _clamp(end, newStart + _shortest, newStart + maxLength);
    return NusaChatTrimRange._(newStart, _shorter(newEnd, total), total, maxLength);
  }

  /// Moves the end; the start follows when the range would get too long.
  NusaChatTrimRange withEnd(Duration value) {
    final newEnd = _clamp(value, _shortest, total);
    final newStart = _clamp(start, newEnd - maxLength, newEnd - _shortest);
    return NusaChatTrimRange._(_longer(newStart, Duration.zero), newEnd, total, maxLength);
  }

  /// Slides the whole range, keeping its length.
  NusaChatTrimRange movedBy(Duration delta) {
    final newStart = _clamp(start + delta, Duration.zero, total - length);
    return NusaChatTrimRange._(newStart, newStart + length, total, maxLength);
  }

  static Duration _shorter(Duration a, Duration b) => a < b ? a : b;

  static Duration _longer(Duration a, Duration b) => a > b ? a : b;

  static Duration _clamp(Duration value, Duration lower, Duration upper) => _shorter(_longer(value, lower), upper);

  @override
  bool operator ==(Object other) =>
      other is NusaChatTrimRange &&
      other.start == start &&
      other.end == end &&
      other.total == total &&
      other.maxLength == maxLength;

  @override
  int get hashCode => Object.hash(start, end, total, maxLength);

  @override
  String toString() => 'NusaChatTrimRange{start: $start, end: $end, total: $total, maxLength: $maxLength}';
}

/// How a video is encoded before it is sent: at most 720p and 30 fps, at a
/// bitrate that keeps the longest allowed clip under [MediaHelper.maxVideoBytes].
/// Good enough to see what the visitor shows, and quick to send on a mobile
/// connection.
@immutable
class NusaChatVideoSpec {
  /// In the same orientation as the size given to [NusaChatVideoSpec.forSource],
  /// so it fits the platform's own report of the video, rotated or not.
  final int width;
  final int height;
  final double videoBitrateMbps;

  static const maxShortSide = 720;
  static const maxLongSide = 1280;

  /// Lower than the target, because a hardware encoder overshoots: 0.8 Mbps
  /// measured 0.95 Mbps at 720p, which is about 12.5 MB for the longest clip.
  /// Android keeps the source's audio track as it is, which adds up to 320 kbps.
  static const maxVideoBitrateMbps = 0.8;
  static const audioBitrate = 64000;
  static const maxFps = 30;

  const NusaChatVideoSpec({required this.width, required this.height, required this.videoBitrateMbps});

  /// Never scales up, and never spends more bits than the source has: a small,
  /// already well compressed video stays small. [sourceBitrate] is in bits per
  /// second, null when unknown.
  factory NusaChatVideoSpec.forSource({required int width, required int height, int? sourceBitrate}) {
    final scale = math.min(
      1.0,
      math.min(maxShortSide / math.min(width, height), maxLongSide / math.max(width, height)),
    );
    final sourceMbps = sourceBitrate == null ? null : sourceBitrate / 1000000;
    return NusaChatVideoSpec(
      width: _even(width * scale),
      height: _even(height * scale),
      videoBitrateMbps: sourceMbps == null ? maxVideoBitrateMbps : math.min(maxVideoBitrateMbps, sourceMbps),
    );
  }

  /// Video encoders need even dimensions.
  static int _even(double value) => math.max(2, (value / 2).round() * 2);

  @override
  bool operator ==(Object other) =>
      other is NusaChatVideoSpec &&
      other.width == width &&
      other.height == height &&
      other.videoBitrateMbps == videoBitrateMbps;

  @override
  int get hashCode => Object.hash(width, height, videoBitrateMbps);

  @override
  String toString() => 'NusaChatVideoSpec{width: $width, height: $height, videoBitrateMbps: $videoBitrateMbps}';
}
