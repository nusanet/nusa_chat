import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nusa_chat/nusa_chat.dart';

void main() {
  late Directory dir;
  late ChatMedia media;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nusa_chat_viewer');
    final file = File('${dir.path}/photo.png')..writeAsBytesSync(img.encodePng(img.Image(width: 300, height: 600)));
    media = ChatMedia(localPath: file.path, fileName: 'photo.png', mimeType: 'image/png', size: 1);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pumpViewer(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: NusaChatImageViewerPage(media: media, caption: 'Lampu LOS'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  Matrix4 transform(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value;

  testWidgets('pastikan foto memenuhi layar, bukan kotak kecil di pojok kiri atas', (tester) async {
    await pumpViewer(tester);

    final screen = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(find.byType(RawImage)), screen);
    expect(tester.getTopLeft(find.byType(RawImage)), Offset.zero);
    expect(find.text('Lampu LOS'), findsOneWidget);
  });

  testWidgets('pastikan ketuk dua kali memperbesar lalu mengembalikan', (tester) async {
    await pumpViewer(tester);
    final center = tester.getCenter(find.byType(RawImage));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(transform(tester).getMaxScaleOnAxis(), closeTo(NusaChatImageViewerPage.doubleTapScale, 0.01));
    // The tapped spot stays under the finger.
    expect(MatrixUtils.transformPoint(transform(tester), center), offsetMoreOrLessEquals(center, epsilon: 0.5));

    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(transform(tester).getMaxScaleOnAxis(), closeTo(1, 0.01));
  });

  testWidgets('pastikan cubit dua jari memperbesar', (tester) async {
    await pumpViewer(tester);
    final center = tester.getCenter(find.byType(RawImage));

    final a = await tester.startGesture(center - const Offset(40, 0));
    final b = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(center - Offset(40.0 + i * 12, 0));
      await b.moveTo(center + Offset(40.0 + i * 12, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(transform(tester).getMaxScaleOnAxis(), greaterThan(1.5));
  });
}
