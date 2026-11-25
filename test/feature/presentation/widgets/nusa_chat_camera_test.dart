import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/util/local_file.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A desktop webcam: 1280x720, without zoom, torch or focus.
class _FakeWebcam extends CameraPlatform with MockPlatformInterfaceMixin {
  int created = 0;
  int disposed = 0;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(name: 'webcam', lensDirection: CameraLensDirection.external, sensorOrientation: 0),
  ];

  @override
  Future<int> createCameraWithSettings(CameraDescription description, MediaSettings mediaSettings) async => ++created;

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(CameraInitializedEvent(cameraId, 1280, 720, ExposureMode.auto, false, FocusMode.auto, false));

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => StreamController<CameraErrorEvent>().stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => throw PlatformException(code: 'zoomLevelNotSupported');

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      throw PlatformException(code: 'torchModeNotSupported');

  @override
  Widget buildPreview(int cameraId) => const SizedBox.expand(key: Key('preview'));

  @override
  Future<void> dispose(int cameraId) async => disposed++;
}

void main() {
  late _FakeWebcam webcam;
  late CameraPlatform original;

  setUp(() {
    original = CameraPlatform.instance;
    CameraPlatform.instance = webcam = _FakeWebcam();
  });

  tearDown(() {
    CameraPlatform.instance = original;
    NusaChatLocalFile.debugIsWeb = null;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: NusaChatCameraPage()));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('pastikan kamera tanpa zoom, torch dan fokus tetap terbuka', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('pastikan kamera dibuka lagi setelah aplikasi kembali aktif', (tester) async {
    await open(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('preview')), findsNothing);
    expect(webcam.disposed, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(webcam.created, 2);
  });

  testWidgets('pastikan rasio preview mengikuti video di web dan sensor di Android/iOS', (tester) async {
    for (final (web, ratio) in [(true, 1280 / 720), (false, 720 / 1280)]) {
      NusaChatLocalFile.debugIsWeb = web;
      await tester.pumpWidget(const SizedBox());
      await open(tester);

      final size = tester.getSize(find.byKey(const Key('preview')));
      expect(size.aspectRatio, closeTo(ratio, 0.01), reason: 'web: $web');
    }
  });
}
