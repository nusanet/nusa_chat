import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

void main() {
  test('pastikan MIME diambil dari ekstensi sesuai yang diterima bridge', () {
    expect(MediaHelper.mimeTypeOf('/tmp/IMG_1.JPG'), 'image/jpeg');
    expect(MediaHelper.mimeTypeOf('laporan.xlsx'), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    expect(MediaHelper.mimeTypeOf('voice.ogg'), 'audio/ogg');
    expect(MediaHelper.mimeTypeOf('animasi.gif'), isNull);
    expect(MediaHelper.mimeTypeOf('tanpa-ekstensi'), isNull);
  });

  test('pastikan tipe pesan dari MIME', () {
    expect(MediaHelper.typeOfMime('image/png'), ChatMessageType.image);
    expect(MediaHelper.typeOfMime('audio/mp4'), ChatMessageType.audio);
    expect(MediaHelper.typeOfMime('application/pdf'), ChatMessageType.document);
    expect(MediaHelper.typeOfMime('application/zip'), isNull);
  });

  test('pastikan batas ukuran per tipe', () {
    expect(MediaHelper.maxBytesOf(ChatMessageType.image), 5 * 1024 * 1024);
    expect(MediaHelper.maxBytesOf(ChatMessageType.document), 16 * 1024 * 1024);
  });

  test('pastikan format ukuran dan durasi', () {
    expect(MediaHelper.formatSize(512), '512 B');
    expect(MediaHelper.formatSize(245 * 1024), '245 KB');
    expect(MediaHelper.formatSize(1258291), '1,2 MB');
    expect(MediaHelper.formatDuration(const Duration(seconds: 7)), '0:07');
    expect(MediaHelper.formatDuration(const Duration(minutes: 12, seconds: 30)), '12:30');
  });
}
