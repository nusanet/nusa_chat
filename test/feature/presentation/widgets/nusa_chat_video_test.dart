import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../helper/fake_video_player.dart';

class _FakeService extends Fake implements NusaChatMediaService {
  NusaChatVideoInfo info = const NusaChatVideoInfo(duration: Duration(minutes: 2), width: 1920, height: 1080);
  Object? infoError;
  Object? thumbnailError;
  Object? compressError;
  Completer<ChatAttachment?>? compressGate;
  ChatAttachment? compressed = tVideo;
  void Function(double)? progress;
  Duration? start;
  Duration? end;
  int cancels = 0;
  String? downloaded;
  Object? downloadError;
  Completer<void>? downloadGate;

  @override
  Future<NusaChatVideoInfo> videoInfo(String path) async {
    if (infoError != null) throw infoError!;
    return info;
  }

  @override
  Future<List<String>> videoThumbnails(String path, List<Duration> positions) async {
    if (thumbnailError != null) throw thumbnailError!;
    return ['/nope/a.jpg'];
  }

  @override
  Future<ChatAttachment?> compressVideo(
    String path, {
    required NusaChatVideoInfo info,
    required Duration start,
    required Duration end,
    void Function(double progress)? onProgress,
  }) async {
    this.start = start;
    this.end = end;
    progress = onProgress;
    if (compressError != null) throw compressError!;
    if (compressGate != null) return compressGate!.future;
    return compressed;
  }

  @override
  Future<void> cancelVideoCompression() async {
    cancels++;
    compressGate?.complete(null);
    compressGate = null;
  }

  @override
  Future<String> downloadVideo(String url, {void Function(double progress)? onProgress}) async {
    onProgress?.call(0.5);
    await downloadGate?.future;
    if (downloadError != null) throw downloadError!;
    downloaded = url;
    return '/tmp/downloaded.mp4';
  }
}

const tVideo = ChatAttachment(
  type: ChatMessageType.video,
  path: '/tmp/out.mp4',
  fileName: 'out.mp4',
  mimeType: 'video/mp4',
  size: 5 * 1024 * 1024,
  duration: Duration(seconds: 30),
);

void main() {
  late FakeVideoPlayer player;
  late _FakeService service;

  setUp(() {
    player = FakeVideoPlayer();
    VideoPlayerPlatform.instance = player;
    service = _FakeService();
  });

  /// Pushes [page] from a home screen, so its result can be seen.
  Future<Future<T?>> open<T>(WidgetTester tester, Widget page) async {
    late Future<T?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => NusaChatThemeScope(
              theme: NusaChatTheme.fallback(),
              child: TextButton(
                onPressed: () {
                  result = Navigator.of(context).push<T>(
                    MaterialPageRoute(
                      builder: (_) => NusaChatThemeScope(theme: NusaChatTheme.fallback(), child: page),
                    ),
                  );
                },
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await settle(tester);
    return result;
  }

  group('NusaChatVideoTrimPage', () {
    Widget page() => NusaChatVideoTrimPage(path: '/tmp/in.mov', mediaService: service);

    testWidgets('pastikan video panjang langsung dipilih sepanjang batasnya lalu dikompres', (tester) async {
      final result = await open<ChatAttachment>(tester, page());

      expect(find.text('Potong Video'), findsOneWidget);
      expect(find.text('1:30 · Maksimal 1:30'), findsOneWidget);

      await tester.tap(find.text('Lanjut'));
      await settle(tester);

      expect(service.start, Duration.zero);
      expect(service.end, const Duration(seconds: 90));
      expect(await result, tVideo);
    });

    testWidgets('pastikan video pendek terpilih seluruhnya', (tester) async {
      service.info = const NusaChatVideoInfo(duration: Duration(seconds: 12), width: 640, height: 360);
      await open<ChatAttachment>(tester, page());
      expect(find.text('0:12 · Maksimal 1:30'), findsOneWidget);
    });

    testWidgets('pastikan handle dan pilihan bisa ditarik tapi tetap dalam batas', (tester) async {
      await open<ChatAttachment>(tester, page());

      await tester.drag(find.byKey(const ValueKey('nusa_chat.trim_end')), const Offset(150, 0));
      await settle(tester);
      expect(find.textContaining('1:30 ·'), findsOneWidget);

      await tester.drag(find.byKey(const ValueKey('nusa_chat.trim_start')), const Offset(-500, 0));
      await settle(tester);
      expect(find.textContaining('1:30 ·'), findsOneWidget);

      await tester.drag(find.byKey(const ValueKey('nusa_chat.trim_range')), const Offset(60, 0));
      await settle(tester);
      expect(player.seeks, isNotEmpty);

      await tester.drag(find.byKey(const ValueKey('nusa_chat.trim_end')), const Offset(-60, 0));
      await settle(tester);
      expect(find.textContaining('1:30 ·'), findsNothing);

      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(service.end! - service.start!, lessThan(const Duration(seconds: 90)));
    });

    testWidgets('pastikan ketuk video memutar dan menjeda', (tester) async {
      await open<ChatAttachment>(tester, page());
      final surface = find.byKey(const ValueKey('nusa_chat.trim_surface'));

      expect(find.byType(NusaChatVideoPlayBadge), findsOneWidget);

      await tester.tap(surface);
      await settle(tester);
      expect(find.byType(NusaChatVideoPlayBadge), findsNothing);

      await tester.tap(surface);
      await settle(tester);
      expect(find.byType(NusaChatVideoPlayBadge), findsOneWidget);
    });

    testWidgets('pastikan pemutaran berulang di dalam pilihan', (tester) async {
      await open<ChatAttachment>(tester, page());
      await tester.tap(find.byKey(const ValueKey('nusa_chat.trim_surface')));
      await settle(tester);

      player.position = const Duration(seconds: 91);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(player.seeks.last, Duration.zero);
    });

    testWidgets('pastikan progres tampil dan bisa dibatalkan', (tester) async {
      service.compressGate = Completer();
      await open<ChatAttachment>(tester, page());

      await tester.tap(find.text('Lanjut'));
      await settle(tester);
      expect(find.text('Mengompres video... 0%'), findsOneWidget);

      service.progress!(0.42);
      await tester.pump();
      expect(find.text('Mengompres video... 42%'), findsOneWidget);

      await tester.tap(find.text('Batal').last);
      await settle(tester);

      expect(service.cancels, 1);
      expect(find.textContaining('Mengompres'), findsNothing);
      expect(find.text('Potong Video'), findsOneWidget);
    });

    testWidgets('pastikan tombol kembali membatalkan kompresi dulu', (tester) async {
      service.compressGate = Completer();
      await open<ChatAttachment>(tester, page());
      await tester.tap(find.text('Lanjut'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(service.cancels, 1);
      expect(find.text('Potong Video'), findsOneWidget);
    });

    testWidgets('pastikan kompresi gagal memberi tahu dan halaman tetap terbuka', (tester) async {
      service.compressError = const NusaChatMediaException(NusaChatMediaError.compressionFailed);
      await open<ChatAttachment>(tester, page());
      await tester.tap(find.text('Lanjut'));
      await settle(tester);

      expect(find.text('Video tidak bisa diproses. Coba lagi.'), findsOneWidget);
      expect(find.text('Potong Video'), findsOneWidget);
    });

    testWidgets('pastikan hasil terlalu besar menyarankan video lebih pendek', (tester) async {
      service.compressError = const NusaChatMediaException(NusaChatMediaError.tooLarge, maxBytes: 1);
      await open<ChatAttachment>(tester, page());
      await tester.tap(find.text('Lanjut'));
      await settle(tester);

      expect(find.text('Video terlalu besar untuk dikirim. Coba potong agar lebih pendek.'), findsOneWidget);
    });

    testWidgets('pastikan file yang tidak bisa dibaca menutup halaman', (tester) async {
      service.infoError = const NusaChatMediaException(NusaChatMediaError.unsupported);
      final result = await open<ChatAttachment>(tester, page());

      expect(find.text('Jenis file tidak didukung.'), findsOneWidget);
      expect(find.text('Potong Video'), findsNothing);
      expect(await result, isNull);
    });

    testWidgets('pastikan video yang tidak bisa diputar menutup halaman', (tester) async {
      player.failInit = true;
      await open<ChatAttachment>(tester, page());
      expect(find.text('Potong Video'), findsNothing);
    });

    testWidgets('pastikan timeline tetap jalan tanpa gambar', (tester) async {
      service.thumbnailError = Exception('x');
      await open<ChatAttachment>(tester, page());
      expect(find.byKey(const ValueKey('nusa_chat.trim_range')), findsOneWidget);
    });

    testWidgets('pastikan Batal menutup tanpa hasil', (tester) async {
      final result = await open<ChatAttachment>(tester, page());
      await tester.tap(find.text('Batal'));
      await settle(tester);
      expect(await result, isNull);
    });
  });

  group('NusaChatVideoViewerPage', () {
    testWidgets('pastikan video yang belum ada diunduh dengan progres lalu diputar', (tester) async {
      service.downloadGate = Completer();
      await open<void>(
        tester,
        NusaChatVideoViewerPage(
          media: const ChatMedia(url: 'https://x/media/abc'),
          caption: 'Lihat ini',
          mediaService: service,
        ),
      );
      final ring = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
      expect(ring.value, 0.5);

      service.downloadGate!.complete();
      await settle(tester);

      expect(service.downloaded, 'https://x/media/abc');
      expect((player.created.single).uri, contains('/tmp/downloaded.mp4'));
      expect(player.playCount, 1);
      expect(find.text('Lihat ini'), findsOneWidget);
    });

    testWidgets('pastikan file lokal diputar tanpa unduhan', (tester) async {
      final file = File('${Directory.systemTemp.createTempSync().path}/v.mp4')..writeAsBytesSync([0]);
      addTearDown(() => file.parent.deleteSync(recursive: true));
      await open<void>(
        tester,
        NusaChatVideoViewerPage(
          media: ChatMedia(localPath: file.path, url: 'https://x'),
          mediaService: service,
        ),
      );
      expect(service.downloaded, isNull);
      expect(player.created.single.uri, contains('v.mp4'));
    });

    testWidgets('pastikan ketuk memutar lagi dari awal setelah selesai', (tester) async {
      await open<void>(
        tester,
        NusaChatVideoViewerPage(
          media: const ChatMedia(url: 'https://x'),
          mediaService: service,
        ),
      );
      final surface = find.byKey(const ValueKey('nusa_chat.video_surface'));

      player.finish();
      await settle(tester);
      await tester.tap(surface);
      await settle(tester);
      expect(player.seeks.last, Duration.zero);
      expect(find.byType(NusaChatVideoPlayBadge), findsNothing);
    });

    testWidgets('pastikan gagal unduh memberi tahu dan menutup', (tester) async {
      service.downloadError = const NusaChatMediaException(NusaChatMediaError.failed);
      await open<void>(
        tester,
        NusaChatVideoViewerPage(
          media: const ChatMedia(url: 'https://x'),
          mediaService: service,
        ),
      );
      expect(find.text('Media tidak bisa dimuat.'), findsOneWidget);
      expect(find.byType(NusaChatVideoViewerPage), findsNothing);
    });

    testWidgets('pastikan media tanpa sumber menutup halaman', (tester) async {
      await open<void>(tester, NusaChatVideoViewerPage(media: const ChatMedia(), mediaService: service));
      expect(find.byType(NusaChatVideoViewerPage), findsNothing);
    });

    testWidgets('pastikan tombol tutup kembali', (tester) async {
      await open<void>(
        tester,
        NusaChatVideoViewerPage(
          media: const ChatMedia(url: 'https://x'),
          mediaService: service,
        ),
      );
      await tester.tap(find.byType(IconButton));
      await settle(tester);
      expect(find.byType(NusaChatVideoViewerPage), findsNothing);
    });
  });

  group('NusaChatVideoContent', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NusaChatThemeScope(theme: NusaChatTheme.fallback(), child: child),
        ),
      ),
    );

    testWidgets('pastikan durasi dan tombol putar tampil, dan ketuk membuka', (tester) async {
      var taps = 0;
      await pump(
        tester,
        NusaChatVideoContent(
          media: const ChatMedia(url: 'https://x', duration: Duration(seconds: 30)),
          onTap: () => taps++,
        ),
      );
      expect(find.text('0:30'), findsOneWidget);
      expect(find.byType(NusaChatVideoPlayBadge), findsOneWidget);

      await tester.tap(find.byType(NusaChatVideoPlayBadge));
      expect(taps, 1);
    });

    testWidgets('pastikan saat mengunggah tampil progres dan tidak bisa diketuk', (tester) async {
      var taps = 0;
      await pump(tester, NusaChatVideoContent(media: const ChatMedia(), uploadProgress: 0.5, onTap: () => taps++));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(NusaChatVideoPlayBadge), findsNothing);

      await tester.tap(find.byType(NusaChatVideoContent));
      expect(taps, 0);
    });

    testWidgets('pastikan thumbnail yang hilang kembali ke placeholder', (tester) async {
      await tester.runAsync(() async {
        await pump(tester, const NusaChatVideoContent(media: ChatMedia(thumbnailPath: '/nope/t.jpg')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NusaChatVideoContent), findsOneWidget);
    });
  });

  group('pratinjau', () {
    testWidgets('pastikan video tampil dengan durasi dan ukuran, maksimal satu, dan bisa diputar', (tester) async {
      final directory = Directory.systemTemp.createTempSync();
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/out.mp4')..writeAsBytesSync([0]);
      final video = ChatAttachment(
        type: tVideo.type,
        path: file.path,
        fileName: tVideo.fileName,
        mimeType: tVideo.mimeType,
        size: tVideo.size,
        duration: tVideo.duration,
      );
      await open<List<ChatAttachment>>(
        tester,
        NusaChatMediaPreviewPage(attachments: [video], maxCount: 1, onAdd: (_) async => const []),
      );

      expect(find.text('0:30 · 5,0 MB'), findsOneWidget);
      expect(find.byTooltip('Potong'), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);

      await tester.tap(find.byKey(const ValueKey('nusa_chat.preview_video')));
      await settle(tester);
      expect(find.byType(NusaChatVideoViewerPage), findsOneWidget);
    });
  });

  test('pastikan label dan salinan entitas video', () {
    const strings = NusaChatStrings();
    ChatMessage message(String text) =>
        ChatMessage(localId: 'x', text: text, type: ChatMessageType.video, isMine: false, createdAt: DateTime(2026));
    expect(strings.displayText(message('')), '[Video]');
    expect(strings.displayText(message('Lihat')), '[Video] Lihat');
    expect(ChatMessageType.fromValue('video'), ChatMessageType.video);

    const attachment = ChatAttachment(
      type: ChatMessageType.video,
      path: '/a.mp4',
      fileName: 'a.mp4',
      mimeType: 'video/mp4',
      size: 1,
      thumbnailPath: '/t.jpg',
    );
    expect(attachment.copyWith(caption: 'x').thumbnailPath, '/t.jpg');
    expect(attachment.toMedia().thumbnailPath, '/t.jpg');
    expect(attachment.toMedia().copyWith(mediaId: 'm').thumbnailPath, '/t.jpg');
    expect(strings.copyWith(videoLabel: 'V').videoLabel, 'V');
    expect(NusaChatTheme.fallback().copyWith(videoIconColor: Colors.red).videoIconColor, Colors.red);
  });
}

/// Lets the fake player's events and the page's awaits go through, without
/// waiting for spinners that never settle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 500));
}
