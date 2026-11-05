import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Stands in for the native player: "loads" every file at once as a 1280x720
/// video of [duration], or fails when [failInit] is set.
class FakeVideoPlayer extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  Duration duration;
  bool failInit;

  FakeVideoPlayer({this.duration = const Duration(minutes: 2), this.failInit = false});

  final _events = <int, StreamController<VideoEvent>>{};
  var _nextId = 0;

  final created = <DataSource>[];
  final seeks = <Duration>[];
  var playCount = 0;
  var pauseCount = 0;
  Duration position = Duration.zero;

  /// The video reached its end, as the native player reports it.
  void finish() {
    position = duration;
    _events.values.last.add(VideoEvent(eventType: VideoEventType.completed));
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource);
    final id = _nextId++;
    final events = StreamController<VideoEvent>();
    _events[id] = events;
    if (failInit) {
      events.addError(PlatformException(code: 'VideoError', message: 'cannot play'));
    } else {
      events.add(VideoEvent(eventType: VideoEventType.initialized, duration: duration, size: const Size(1280, 720)));
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async => _events.remove(playerId)?.close();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => playCount++;

  @override
  Future<void> pause(int playerId) async => pauseCount++;

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seeks.add(position);
    this.position = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
