import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/util/image_edit.dart';

void main() {
  late Directory dir;
  late ChatAttachment photo;
  const document = ChatAttachment(
    type: ChatMessageType.document,
    path: '/tmp/Bukti.pdf',
    fileName: 'Bukti.pdf',
    mimeType: 'application/pdf',
    size: 1024,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('nusa_chat_editor');
    NusaChatImageEdit.saveDirectory = dir;
    final file = File('${dir.path}/IMG_01.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 120, height: 60)..clear(img.ColorRgb8(30, 90, 180))));
    photo = ChatAttachment(
      type: ChatMessageType.image,
      path: file.path,
      fileName: 'IMG_01.png',
      mimeType: 'image/png',
      size: file.lengthSync(),
      caption: 'Lampu LOS',
    );
  });

  tearDown(() {
    NusaChatImageEdit.saveDirectory = null;
    dir.deleteSync(recursive: true);
  });

  /// Opens the preview with [attachments]; the popped list lands in the returned holder.
  Future<List<List<ChatAttachment>?>> openPreview(WidgetTester tester, List<ChatAttachment> attachments) async {
    final result = <List<ChatAttachment>?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result.add(
              await Navigator.of(context).push<List<ChatAttachment>>(
                MaterialPageRoute(builder: (_) => NusaChatMediaPreviewPage(attachments: attachments)),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  /// Lets real file I/O, decoding and the encoder isolate finish (a spinner
  /// shows meanwhile, so pumpAndSettle would never return).
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// Taps [finder] in the real zone, so the file I/O it starts can finish.
  Future<void> tapIo(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await tester.pump();
    });
    await settleIo(tester);
  }

  testWidgets('pastikan tombol potong dan edit hanya untuk foto', (tester) async {
    await openPreview(tester, [document]);

    expect(find.byTooltip('Potong'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testWidgets('pastikan foto diputar lewat Potong lalu menggantikan aslinya', (tester) async {
    final result = await openPreview(tester, [photo]);

    await tapIo(tester, find.byTooltip('Potong'));

    expect(find.text('Bebas'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);

    await tester.tap(find.text('Putar'));
    await tester.pump();
    await tapIo(tester, find.text('Simpan'));

    expect(find.text('Kirim ke NusaSelecta'), findsOneWidget);
    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pumpAndSettle();

    final sent = result.single!.single;
    expect(sent.fileName, 'IMG_01.jpg');
    expect(sent.caption, 'Lampu LOS');
    final decoded = img.decodeJpg(File(sent.path).readAsBytesSync())!;
    expect([decoded.width, decoded.height], [60, 120], reason: 'turned a quarter');
  });

  testWidgets('pastikan Simpan tanpa perubahan tidak membuat file baru', (tester) async {
    final result = await openPreview(tester, [photo]);

    await tapIo(tester, find.byTooltip('Potong'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pumpAndSettle();
    expect(result.single!.single, photo);
  });

  testWidgets('pastikan coretan pensil disimpan dan Urungkan menghapusnya', (tester) async {
    final result = await openPreview(tester, [photo]);

    await tapIo(tester, find.byTooltip('Edit'));

    expect(find.text('Pensil'), findsOneWidget);
    expect(find.text('Teks'), findsOneWidget);
    expect(find.text('Panah'), findsOneWidget);

    final canvas = find.byType(RawImage);
    await tester.drag(canvas, const Offset(80, 10));
    await tester.pump();
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    // Undone: saving now changes nothing.
    await tester.tap(find.text('Panah'));
    await tester.pump();
    await tester.drag(canvas, const Offset(60, 20));
    await tester.pump();
    await tapIo(tester, find.text('Simpan'));

    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pumpAndSettle();
    final sent = result.single!.single;
    expect(sent.path, isNot(photo.path));
    expect(sent.mimeType, 'image/jpeg');
  });

  testWidgets('pastikan teks diketik di atas foto tanpa mengecilkan foto, lalu bisa digeser', (tester) async {
    await openPreview(tester, [photo]);
    await tapIo(tester, find.byTooltip('Edit'));

    final imageSize = tester.getSize(find.byType(RawImage));
    await tester.tap(find.text('Teks'));
    await tester.pump();
    await tester.tapAt(tester.getTopLeft(find.byType(RawImage)) + const Offset(20, 20));
    await tester.pump();
    expect(find.text('Ketik teks...'), findsOneWidget);

    // The keyboard comes up; the photo keeps its size.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getSize(find.byType(RawImage)), imageSize);

    await tester.enterText(find.byType(TextField), 'Lampu merah');
    await tester.tap(find.text('Selesai'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Lampu merah'), findsOneWidget);

    final before = tester.getTopLeft(find.text('Lampu merah'));
    await tester.drag(find.text('Lampu merah'), const Offset(30, 20));
    await tester.pump();
    final after = tester.getTopLeft(find.text('Lampu merah'));
    expect(after.dx - before.dx, closeTo(30, 1));
    expect(after.dy - before.dy, closeTo(20, 1));

    // An empty text is dropped when left.
    await tester.tapAt(tester.getTopLeft(find.byType(RawImage)) + const Offset(10, 50));
    await tester.pump();
    await tester.tap(find.text('Selesai'));
    await tester.pump();
    expect(find.text('Ketik teks...'), findsNothing);
    expect(find.text('Lampu merah'), findsOneWidget);
  });
}
