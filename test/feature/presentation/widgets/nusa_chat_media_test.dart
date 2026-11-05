import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../../helper/fake_video_player.dart';
import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:nusa_chat/src/core/error/failure.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_socket_event.dart';
import 'package:nusa_chat/src/features/domain/use_cases/connect_chat_socket/connect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/disconnect_chat_socket/disconnect_chat_socket.dart';
import 'package:nusa_chat/src/features/domain/use_cases/get_chat_history/get_chat_history.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_button_reply/send_chat_button_reply.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_location/send_chat_location.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_media/send_chat_media.dart';
import 'package:nusa_chat/src/features/domain/use_cases/send_chat_text/send_chat_text.dart';
import 'package:nusa_chat/src/features/domain/use_cases/start_chat_session/start_chat_session.dart';
import 'package:nusa_chat/src/features/presentation/bloc/chat/bloc.dart';

import '../../../helper/mock_helper.mocks.dart';

class FakeRecorder implements NusaChatVoiceRecorder {
  int started = 0;
  int cancelled = 0;

  @override
  Future<void> start() async => started++;

  @override
  Future<ChatAttachment?> stop() async => null;

  @override
  Future<void> cancel() async => cancelled++;

  @override
  Future<void> dispose() async {}
}

class FakeMediaService implements NusaChatMediaService {
  List<ChatAttachment> images = const [];

  /// What [imageFromPath] returns per path: an attachment, or an error to throw.
  Map<String, Object> fromPath = {};
  final recorder = FakeRecorder();
  String? pickedVideo;
  final discarded = <String>[];

  @override
  Future<List<ChatAttachment>> pickImages({required int limit}) async => images;

  @override
  Future<ChatAttachment?> pickDocument() async => null;

  @override
  Future<ChatAttachment> imageFromPath(String path) async {
    final result = fromPath[path];
    if (result is ChatAttachment) return result;
    throw result ?? const FileSystemException('not found');
  }

  @override
  Future<NusaChatPosition> currentPosition() async =>
      const NusaChatPosition(location: ChatLocation(latitude: -6.2, longitude: 106.8), accuracy: 12);

  @override
  NusaChatVoiceRecorder createRecorder() => recorder;

  @override
  Future<String?> pickVideo() async => pickedVideo;

  @override
  Future<NusaChatVideoInfo> videoInfo(String path) async =>
      const NusaChatVideoInfo(duration: Duration(minutes: 2), width: 1920, height: 1080);

  @override
  Future<List<String>> videoThumbnails(String path, List<Duration> positions) async => const [];

  @override
  Future<ChatAttachment?> compressVideo(
    String path, {
    required NusaChatVideoInfo info,
    required Duration start,
    required Duration end,
    void Function(double progress)? onProgress,
  }) async => ChatAttachment(
    type: ChatMessageType.video,
    path: path,
    fileName: 'out.mp4',
    mimeType: 'video/mp4',
    size: 1024,
    duration: end - start,
  );

  @override
  Future<void> cancelVideoCompression() async {}

  @override
  Future<void> discardVideo(String path) async => discarded.add(path);

  @override
  Future<String> downloadVideo(String url, {void Function(double progress)? onProgress}) async => url;
}

void main() {
  late MockChatRepository mockRepository;
  late StreamController<ChatSocketEvent> socket;
  late FakeMediaService media;

  const tConfig = NusaChatConfig(baseUrl: 'https://x', websiteId: 'w', origin: 'o');
  const tSession = ChatSession(visitorId: 'v1', conversationId: 'c1', wsPath: '/v1/ws');
  // A document that is not an image, so nothing has to be decoded in tests.
  const tDocument = ChatAttachment(
    type: ChatMessageType.document,
    path: '/tmp/Bukti_Pembayaran.pdf',
    fileName: 'Bukti_Pembayaran.pdf',
    mimeType: 'application/pdf',
    size: 245 * 1024,
  );

  ChatBloc buildBloc() => ChatBloc(
    startChatSession: StartChatSession(repository: mockRepository),
    getChatHistory: GetChatHistory(repository: mockRepository),
    connectChatSocket: ConnectChatSocket(repository: mockRepository),
    sendChatText: SendChatText(repository: mockRepository),
    sendChatMedia: SendChatMedia(repository: mockRepository),
    sendChatLocation: SendChatLocation(repository: mockRepository),
    sendChatButtonReply: SendChatButtonReply(repository: mockRepository),
    disconnectChatSocket: DisconnectChatSocket(repository: mockRepository),
  );

  setUp(() {
    mockRepository = MockChatRepository();
    socket = StreamController<ChatSocketEvent>.broadcast();
    media = FakeMediaService();
    when(mockRepository.startSession()).thenAnswer((_) async => const Right(tSession));
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer((_) async => const Right([]));
    when(mockRepository.connect(any)).thenAnswer((_) => socket.stream);
    when(mockRepository.disconnect()).thenAnswer((_) async {});
    when(mockRepository.mediaUrl(any)).thenReturn('https://x/media/abc');
    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => const Right(UploadedMedia(mediaId: 'abc', messageType: 'document')));
    when(mockRepository.sendMedia(any, any, caption: anyNamed('caption'))).thenAnswer((_) async => const Right(null));
    when(mockRepository.sendLocation(any, any)).thenAnswer((_) async => const Right(null));
  });

  tearDown(() => socket.close());

  Future<void> pump(
    WidgetTester tester, {
    NusaChatAttachmentOptions? attachments,
    List<NusaChatInitialMessage> initialMessages = const [],
    bool autoSendInitialMessages = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(
          config: tConfig,
          bloc: buildBloc(),
          mediaService: media,
          attachments: attachments ?? const NusaChatAttachmentOptions(),
          initialMessages: initialMessages,
          autoSendInitialMessages: autoSendInitialMessages,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();
  }

  Finder sendButtonWithIcon(String icon) => find.byWidgetPredicate((w) => w is NusaChatSendButton && w.icon == icon);

  testWidgets('pastikan video dipilih dari menu, dipotong, dikompres lalu terkirim', (tester) async {
    final directory = Directory.systemTemp.createTempSync();
    addTearDown(() => directory.deleteSync(recursive: true));
    final picked = File('${directory.path}/in.mp4')..writeAsBytesSync([0]);
    VideoPlayerPlatform.instance = FakeVideoPlayer();
    media.pickedVideo = picked.path;
    await pump(tester);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Potong Video'), findsOneWidget);

    await tester.tap(find.text('Lanjut'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(media.discarded, [picked.path]);
    expect(find.text('Kirim ke NusaSelecta'), findsOneWidget);
    expect(find.textContaining('1:30 ·'), findsOneWidget);

    await tester.tap(find.byType(NusaChatSendButton));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));

    final uploaded = verify(mockRepository.uploadMedia(captureAny, onProgress: anyNamed('onProgress'))).captured.single;
    expect((uploaded as ChatAttachment).type, ChatMessageType.video);
    expect(find.byType(NusaChatVideoContent), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
  });

  testWidgets('pastikan video yang ditolak bridge karena ukuran menyarankan video lebih pendek', (tester) async {
    const custom = 'Pendekkan videonya';
    final bloc = buildBloc();
    when(
      mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
    ).thenAnswer((_) async => Left(MediaTooLargeFailure()));
    await tester.pumpWidget(
      MaterialApp(
        home: NusaChatPage(
          config: tConfig,
          bloc: bloc,
          mediaService: media,
          strings: const NusaChatStrings(videoTooLarge: custom),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    socket.add(const ChatSocketOpened());
    await tester.pump();

    bloc.add(
      const ChatAttachmentsSubmitted(
        attachments: [
          ChatAttachment(
            type: ChatMessageType.video,
            path: '/tmp/a.mp4',
            fileName: 'a.mp4',
            mimeType: 'video/mp4',
            size: 1,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(custom), findsOneWidget);
  });

  testWidgets('pastikan batal memilih video tidak membuka apa pun', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(find.text('Potong Video'), findsNothing);
  });

  testWidgets('pastikan opsi video bisa dimatikan', (tester) async {
    await pump(tester, attachments: const NusaChatAttachmentOptions(video: false));
    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('pastikan mic dan kamera tampil saat kosong, tombol kirim saat mengetik', (tester) async {
    await pump(tester);

    expect(sendButtonWithIcon(BaseIcons.microphone), findsOneWidget);
    expect(find.byTooltip('Kamera'), findsOneWidget);
    expect(find.byTooltip('Lampiran'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Halo');
    await tester.pump();

    expect(sendButtonWithIcon(BaseIcons.send), findsOneWidget);
    expect(sendButtonWithIcon(BaseIcons.microphone), findsNothing);
    expect(find.byTooltip('Kamera'), findsNothing);
  });

  testWidgets('pastikan NusaChatAttachmentOptions.none() menyembunyikan semua lampiran', (tester) async {
    await pump(tester, attachments: const NusaChatAttachmentOptions.none());

    expect(find.byTooltip('Lampiran'), findsNothing);
    expect(find.byTooltip('Kamera'), findsNothing);
    expect(sendButtonWithIcon(BaseIcons.microphone), findsNothing);
  });

  testWidgets('pastikan menu lampiran berisi Foto, Dokumen, Lokasi', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();

    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Dokumen'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
  });

  testWidgets('pastikan file dari galeri lewat pratinjau, diberi keterangan, lalu dikirim', (tester) async {
    media.images = [tDocument];
    await pump(tester);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim ke NusaSelecta'), findsOneWidget);
    expect(find.text('Bukti_Pembayaran.pdf'), findsOneWidget);
    expect(find.text('PDF · 245 KB'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bukti bayar');
    await tester.tap(find.byType(NusaChatSendButton));
    await tester.pumpAndSettle();

    expect(find.text('Kirim ke NusaSelecta'), findsNothing);
    verify(mockRepository.uploadMedia(tDocument.copyWith(caption: 'Bukti bayar'), onProgress: anyNamed('onProgress')));
    verify(
      mockRepository.sendMedia(
        tSession,
        const UploadedMedia(mediaId: 'abc', messageType: 'document'),
        caption: 'Bukti bayar',
      ),
    );
    expect(find.byType(NusaChatDocumentContent), findsOneWidget);
    expect(find.text('Bukti bayar'), findsOneWidget);
  });

  testWidgets('pastikan hapus satu-satunya item menutup pratinjau tanpa mengirim', (tester) async {
    media.images = [tDocument];
    await pump(tester);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim ke NusaSelecta'), findsNothing);
    verifyNever(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')));
  });

  testWidgets('pastikan lokasi dikonfirmasi lewat sheet lalu dikirim', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Lampiran'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lokasi'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim lokasi saat ini?'), findsOneWidget);
    expect(find.text('Akurasi ±12 m'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim'));
    await tester.pumpAndSettle();

    verify(mockRepository.sendLocation(tSession, const ChatLocation(latitude: -6.2, longitude: 106.8)));
    expect(find.byType(NusaChatLocationContent), findsOneWidget);
    expect(find.text('Buka di Maps'), findsOneWidget);
  });

  testWidgets('pastikan rekaman bisa dibatalkan, dan yang terlalu pendek tidak dikirim', (tester) async {
    await pump(tester);

    await tester.tap(sendButtonWithIcon(BaseIcons.microphone));
    await tester.pump();
    expect(media.recorder.started, 1);
    expect(find.text('Merekam...'), findsOneWidget);

    await tester.tap(find.byTooltip('Batal'));
    await tester.pump();
    expect(media.recorder.cancelled, 1);
    expect(find.text('Merekam...'), findsNothing);

    await tester.tap(sendButtonWithIcon(BaseIcons.microphone));
    await tester.pump();
    await tester.tap(sendButtonWithIcon(BaseIcons.send));
    await tester.pump();

    expect(media.recorder.cancelled, 2);
    expect(find.text('Tahan lebih lama untuk merekam pesan suara.'), findsOneWidget);
    verifyNever(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')));
  });

  testWidgets('pastikan pesan media dari riwayat dirender sesuai tipenya', (tester) async {
    when(mockRepository.getMessages(any, since: anyNamed('since'))).thenAnswer(
      (_) async => Right([
        ChatMessage(
          id: 'm-1',
          localId: 'm-1',
          text: 'Tagihan bulan ini',
          type: ChatMessageType.document,
          media: const ChatMedia(url: 'https://cdn.example.com/invoice.pdf', fileName: 'invoice.pdf'),
          isMine: false,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
        ChatMessage(
          id: 'm-2',
          localId: 'm-2',
          text: '',
          type: ChatMessageType.audio,
          media: const ChatMedia(url: 'https://x/media/v', duration: Duration(seconds: 7)),
          isMine: true,
          createdAt: DateTime(2026, 1, 1, 10, 1),
        ),
      ]),
    );
    await pump(tester);

    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Tagihan bulan ini'), findsOneWidget);
    expect(find.byType(NusaChatAudioContent), findsOneWidget);
    expect(find.text('0:07'), findsOneWidget);
  });
  group('initialMessages', () {
    const tUploaded = UploadedMedia(mediaId: 'abc', messageType: 'document');
    String composerText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

    setUp(() => when(mockRepository.sendText(any, any)).thenAnswer((_) async => const Right(null)));

    testWidgets('pastikan autoSend: beberapa gambar, keterangan di gambar pertama yang lolos, lalu teks', (
      tester,
    ) async {
      const tBack = ChatAttachment(
        type: ChatMessageType.document,
        path: '/tmp/belakang.pdf',
        fileName: 'belakang.pdf',
        mimeType: 'application/pdf',
        size: 1024,
      );
      final upload = Completer<Either<Failure, UploadedMedia>>();
      when(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress'))).thenAnswer((_) => upload.future);
      media.fromPath = {'/tmp/produk.pdf': tDocument, '/tmp/belakang.pdf': tBack};
      await pump(
        tester,
        initialMessages: const [
          NusaChatInitialMessage(
            text: 'Tanya produk ini',
            // The first is rejected (missing), so the caption moves to the next.
            imagePaths: ['/tmp/hilang.jpg', '/tmp/produk.pdf', '/tmp/belakang.pdf'],
          ),
          NusaChatInitialMessage(text: 'Ada warna lain?'),
        ],
        autoSendInitialMessages: true,
      );
      await tester.pump();

      expect(composerText(tester), isEmpty);
      // The rest wait for the upload before them.
      verifyNever(mockRepository.sendMedia(any, any, caption: anyNamed('caption')));
      verifyNever(mockRepository.sendText(any, any));

      upload.complete(const Right(tUploaded));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      verifyInOrder([
        mockRepository.uploadMedia(tDocument.copyWith(caption: 'Tanya produk ini'), onProgress: anyNamed('onProgress')),
        mockRepository.sendMedia(tSession, tUploaded, caption: 'Tanya produk ini'),
        mockRepository.uploadMedia(tBack, onProgress: anyNamed('onProgress')),
        mockRepository.sendMedia(tSession, tUploaded, caption: ''),
        mockRepository.sendText(tSession, 'Ada warna lain?'),
      ]);
      expect(find.text('Tanya produk ini'), findsOneWidget);
      expect(find.text('Ada warna lain?'), findsOneWidget);
    });

    testWidgets('pastikan autoSend teks saja dikirim sekali dan composer kosong', (tester) async {
      await pump(
        tester,
        initialMessages: const [NusaChatInitialMessage(text: '  Tanya paket  ')],
        autoSendInitialMessages: true,
      );
      await tester.pumpAndSettle();

      expect(composerText(tester), isEmpty);
      verify(mockRepository.sendText(tSession, 'Tanya paket')).called(1);
    });

    testWidgets('pastikan gambar yang ditolak dilewati dengan notice, teksnya tetap dikirim', (tester) async {
      media.fromPath = {
        '/tmp/besar.jpg': const NusaChatMediaException(NusaChatMediaError.tooLarge, maxBytes: 10 * 1024 * 1024),
      };
      await pump(
        tester,
        initialMessages: const [
          NusaChatInitialMessage(text: 'Foto ini', imagePaths: ['/tmp/besar.jpg']),
          NusaChatInitialMessage(imagePaths: ['/tmp/hilang.jpg']),
        ],
        autoSendInitialMessages: true,
      );
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pumpAndSettle();
      verify(mockRepository.sendText(tSession, 'Foto ini')).called(1);
      verifyNever(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')));
    });

    testWidgets('pastikan tanpa autoSend: teks di composer, gambar di pratinjau dengan keterangannya', (tester) async {
      when(
        mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')),
      ).thenAnswer((_) async => const Right(tUploaded));
      media.fromPath = {'/tmp/produk.pdf': tDocument};
      await pump(
        tester,
        initialMessages: const [
          NusaChatInitialMessage(text: 'Tanya produk ini', imagePaths: ['/tmp/produk.pdf']),
          NusaChatInitialMessage(text: 'Ada warna lain?'),
          NusaChatInitialMessage(text: 'Foto rusak', imagePaths: ['/tmp/hilang.jpg']),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Kirim ke NusaSelecta'), findsOneWidget);
      verifyNever(mockRepository.uploadMedia(any, onProgress: anyNamed('onProgress')));

      // The rejected image's notice covers the send button until it hides.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // The composer underneath has its own send button.
      await tester.tap(
        find.descendant(of: find.byType(NusaChatMediaPreviewPage), matching: find.byType(NusaChatSendButton)),
      );
      await tester.pumpAndSettle();

      verify(mockRepository.sendMedia(tSession, tUploaded, caption: 'Tanya produk ini')).called(1);
      expect(composerText(tester), 'Ada warna lain?\nFoto rusak');
      verifyNever(mockRepository.sendText(any, any));
    });

    testWidgets('pastikan initialMessage lama tetap mengisi composer di depan initialMessages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NusaChatPage(
            config: tConfig,
            bloc: buildBloc(),
            mediaService: media,
            // ignore: deprecated_member_use_from_same_package
            initialMessage: 'Halo',
            initialMessages: const [NusaChatInitialMessage(text: 'Tanya paket')],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(composerText(tester), 'Halo\nTanya paket');
      verifyNever(mockRepository.sendText(any, any));
    });

    testWidgets('pastikan dikirim setelah start yang gagal dicoba lagi', (tester) async {
      var attempts = 0;
      when(
        mockRepository.startSession(),
      ).thenAnswer((_) async => attempts++ == 0 ? Left(ConnectionFailure()) : const Right(tSession));
      await pump(tester, initialMessages: const [NusaChatInitialMessage(text: 'Tanya')], autoSendInitialMessages: true);
      verifyNever(mockRepository.sendText(any, any));

      await tester.tap(find.text('Coba lagi'));
      // The connecting indicator keeps animating, so no pumpAndSettle.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      verify(mockRepository.sendText(tSession, 'Tanya')).called(1);
    });
  });
}
