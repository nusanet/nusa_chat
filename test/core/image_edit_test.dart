import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/util/image_edit.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_crop_page.dart';

/// A [width]×[height] image: red on the left half, blue on the right.
Future<ui.Image> halves(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(Rect.fromLTWH(0, 0, width / 2, height.toDouble()), Paint()..color = const Color(0xFFFF0000))
    ..drawRect(Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()), Paint()..color = const Color(0xFF0000FF));
  return recorder.endRecording().toImage(width, height);
}

Future<Color> pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final offset = (y * image.width + x) * 4;
  return Color.fromARGB(255, data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
}

void main() {
  group('NusaChatCropBox', () {
    test('pastikan fit memberi kotak terbesar dengan rasio piksel yang diminta', () {
      // A 2:1 photo cropped square: half its width, all its height.
      final box = NusaChatCropBox.fit(1, 2);
      expect(box.width, closeTo(0.5, 1e-9));
      expect(box.height, closeTo(1, 1e-9));
      expect(box.center.dx, closeTo(0.5, 1e-9));

      // 16:9 on a square photo: full width.
      final wide = NusaChatCropBox.fit(16 / 9, 1, center: const Offset(0.9, 0.9));
      expect(wide.width, closeTo(1, 1e-9));
      expect(wide.height, closeTo(9 / 16, 1e-9));
      expect(wide.bottom, closeTo(1, 1e-9), reason: 'pushed back inside');
    });

    test('pastikan move tidak keluar dari gambar', () {
      final box = NusaChatCropBox.move(const Rect.fromLTWH(0.2, 0.2, 0.5, 0.5), const Offset(1, -1));
      expect(box, const Rect.fromLTWH(0.5, 0, 0.5, 0.5));
    });

    test('pastikan resize bebas menahan sudut seberang dan ukuran minimum', () {
      final box = NusaChatCropBox.resize(NusaChatCropBox.full, 2, const Offset(0.6, 0.4));
      expect(box.topLeft, Offset.zero);
      expect(box.bottomRight, const Offset(0.6, 0.4));

      final tiny = NusaChatCropBox.resize(NusaChatCropBox.full, 0, const Offset(0.99, 0.99));
      expect(tiny.width, closeTo(NusaChatCropBox.minSide, 1e-9));
      expect(tiny.bottomRight, const Offset(1, 1));
    });

    test('pastikan resize dengan rasio menjaga bentuk dan tetap di dalam gambar', () {
      // 1:1 pixels on a 2:1 photo → fraction aspect 0.5.
      final box = NusaChatCropBox.resize(NusaChatCropBox.fit(1, 2), 2, const Offset(2, 2), ratio: 1, imageAspect: 2);
      expect(box.width / box.height, closeTo(0.5, 1e-9));
      expect(box.right, lessThanOrEqualTo(1 + 1e-9));
      expect(box.bottom, lessThanOrEqualTo(1 + 1e-9));
    });
  });

  group('NusaChatImageEdit', () {
    testWidgets('pastikan crop memutar lalu memotong', (tester) async {
      await tester.runAsync(() async {
        final source = await halves(200, 100);

        final turned = await NusaChatImageEdit.crop(source, quarterTurns: 1);
        expect([turned.width, turned.height], [100, 200]);
        // Turned clockwise, the red left half is now on top.
        expect(await pixel(turned, 50, 10), const Color(0xFFFF0000));
        expect(await pixel(turned, 50, 190), const Color(0xFF0000FF));

        final right = await NusaChatImageEdit.crop(source, crop: const Rect.fromLTWH(0.5, 0, 0.5, 1));
        expect([right.width, right.height], [100, 100]);
        expect(await pixel(right, 50, 50), const Color(0xFF0000FF));
      });
    });

    testWidgets('pastikan draw menggambar coretan di posisi relatif', (tester) async {
      await tester.runAsync(() async {
        final source = await halves(200, 100);
        final drawn = await NusaChatImageEdit.draw(source, [
          const NusaChatStrokeMark(color: Color(0xFF00FF00), points: [Offset(0.1, 0.5), Offset(0.9, 0.5)], width: 0.05),
        ]);
        expect(await pixel(drawn, 100, 50), const Color(0xFF00FF00));
        expect(await pixel(drawn, 100, 10), const Color(0xFF0000FF));
      });
    });

    testWidgets('pastikan save menulis JPEG dan menjaga keterangan', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('nusa_chat_edit');
        addTearDown(() => dir.delete(recursive: true));
        const original = ChatAttachment(
          type: ChatMessageType.image,
          path: '/x/IMG_01.png',
          fileName: 'IMG_01.png',
          mimeType: 'image/png',
          size: 10,
          caption: 'Lampu LOS',
        );

        final saved = await NusaChatImageEdit.save(await halves(64, 32), original, directory: dir);

        expect(saved.fileName, 'IMG_01.jpg');
        expect(saved.mimeType, 'image/jpeg');
        expect(saved.caption, 'Lampu LOS');
        final bytes = await File(saved.path).readAsBytes();
        expect(saved.size, bytes.length);
        final decoded = img.decodeJpg(bytes)!;
        expect([decoded.width, decoded.height], [64, 32]);
      });
    });
  });
}
