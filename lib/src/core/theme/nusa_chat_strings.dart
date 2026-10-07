import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/widgets.dart';
import 'package:nusa_chat/src/core/util/emoji/emoji.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// User-facing texts of the chat (Bahasa Indonesia by default).
@immutable
class NusaChatStrings {
  final String title;

  /// Name shown above agent messages.
  final String agentName;
  final String hintText;
  final String connecting;
  final String reconnecting;
  final String retry;
  final String emptyMessage;

  /// Day dividers and the floating date while scrolling (see [dayLabel]).
  final String today;

  final String yesterday;

  /// Monday first, as [DateTime.weekday].
  final List<String> weekdays;

  /// Short month names, January first.
  final List<String> months;
  final String failedToSend;

  /// Long-press actions on a message.
  final String copy;

  /// Shown after a message is copied.
  final String copied;

  /// Labels for media messages, used where only text fits (e.g. a custom
  /// bubble built from `NusaChatMessageData.displayText`).
  final String imageLabel;
  final String documentLabel;
  final String audioLabel;
  final String locationLabel;
  final String unsupportedLabel;

  /// Attachment menu.
  final String attachGallery;

  final String attachDocument;

  final String attachLocation;

  /// Title of the image/document preview screen.
  final String previewTitle;

  final String captionHint;

  /// Shown while a voice note records.
  final String recording;

  final String cancel;

  final String send;

  final String sendLocationTitle;

  /// `{meters}` is replaced by the GPS accuracy.
  final String locationAccuracy;

  final String fetchingLocation;

  final String openInMaps;

  final String uploading;

  /// `{max}` is replaced by e.g. `5 MB`.
  final String fileTooLarge;

  final String fileNotSupported;

  final String cameraUnavailable;

  final String cameraPermissionDenied;

  final String microphonePermissionDenied;

  final String locationPermissionDenied;

  final String locationServiceDisabled;

  final String locationFailed;

  final String recordingTooShort;

  final String mediaLoadFailed;

  final String openFailed;

  /// Emoji panel.
  final String emojiSearchHint;

  final String emojiRecent;

  final String emojiSmileys;

  final String emojiPeople;

  final String emojiAnimals;

  final String emojiFood;

  final String emojiActivities;

  final String emojiTravel;

  final String emojiObjects;

  final String emojiSearchResults;

  final String emojiNotFound;

  final String emojiBackspace;

  /// Photo crop and edit.
  final String cropTitle;

  final String save;

  final String undo;

  final String cropFree;

  final String rotate;

  final String editPencil;

  final String editText;

  final String editArrow;

  final String editTextHint;

  final String editTitle;

  final String editFailed;

  /// Places the text being typed in the editor.
  final String done;

  const NusaChatStrings({
    this.title = 'NusaChat',
    this.agentName = 'NusaSelecta',
    this.hintText = 'Tulis pesan...',
    this.connecting = 'Menghubungkan...',
    this.reconnecting = 'Koneksi terputus, menghubungkan ulang...',
    this.retry = 'Coba lagi',
    this.emptyMessage = 'Halo! Ada yang bisa kami bantu? Tulis pesan untuk memulai percakapan.',
    this.today = 'Hari ini',
    this.yesterday = 'Kemarin',
    this.weekdays = const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'],
    this.months = const ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'],
    this.failedToSend = 'Gagal terkirim. Ketuk untuk kirim ulang.',
    this.copy = 'Salin',
    this.copied = 'Pesan disalin',
    this.imageLabel = '[Gambar]',
    this.documentLabel = '[Dokumen]',
    this.audioLabel = '[Pesan suara]',
    this.locationLabel = '[Lokasi]',
    this.unsupportedLabel = '[Pesan tidak didukung]',
    this.attachGallery = 'Galeri',
    this.attachDocument = 'Dokumen',
    this.attachLocation = 'Lokasi',
    this.previewTitle = 'Kirim ke NusaSelecta',
    this.captionHint = 'Tambahkan keterangan...',
    this.recording = 'Merekam...',
    this.cancel = 'Batal',
    this.send = 'Kirim',
    this.sendLocationTitle = 'Kirim lokasi saat ini?',
    this.locationAccuracy = 'Akurasi ±{meters} m',
    this.fetchingLocation = 'Mencari lokasi...',
    this.openInMaps = 'Buka di Maps',
    this.uploading = 'Mengunggah...',
    this.fileTooLarge = 'Ukuran file melebihi batas {max}.',
    this.fileNotSupported = 'Jenis file tidak didukung.',
    this.cameraUnavailable = 'Kamera tidak tersedia.',
    this.cameraPermissionDenied = 'Izin kamera ditolak. Aktifkan di pengaturan.',
    this.microphonePermissionDenied = 'Izin mikrofon ditolak. Aktifkan di pengaturan.',
    this.locationPermissionDenied = 'Izin lokasi ditolak. Aktifkan di pengaturan.',
    this.locationServiceDisabled = 'Layanan lokasi (GPS) belum aktif.',
    this.locationFailed = 'Lokasi tidak bisa didapat. Coba lagi.',
    this.recordingTooShort = 'Tahan lebih lama untuk merekam pesan suara.',
    this.mediaLoadFailed = 'Media tidak bisa dimuat.',
    this.openFailed = 'File tidak bisa dibuka.',
    this.emojiSearchHint = 'Cari emoji',
    this.emojiRecent = 'Sering Digunakan',
    this.emojiSmileys = 'Smiley & Emosi',
    this.emojiPeople = 'Orang & Tubuh',
    this.emojiAnimals = 'Hewan & Alam',
    this.emojiFood = 'Makanan & Minuman',
    this.emojiActivities = 'Aktivitas',
    this.emojiTravel = 'Perjalanan & Tempat',
    this.emojiObjects = 'Objek & Simbol',
    this.emojiSearchResults = 'Hasil Pencarian',
    this.emojiNotFound = 'Emoji tidak ditemukan',
    this.emojiBackspace = 'Hapus',
    this.cropTitle = 'Potong',
    this.save = 'Simpan',
    this.undo = 'Urungkan',
    this.cropFree = 'Bebas',
    this.rotate = 'Putar',
    this.editPencil = 'Pensil',
    this.editText = 'Teks',
    this.editArrow = 'Panah',
    this.editTextHint = 'Ketik teks...',
    this.editTitle = 'Edit',
    this.editFailed = 'Gambar tidak bisa disimpan. Coba lagi.',
    this.done = 'Selesai',
  });

  /// What a bubble shows for [message]: its text, or a label for non-text
  /// messages (followed by the caption when there is one).
  String displayText(ChatMessage message) {
    String withCaption(String label) {
      final caption = message.type == ChatMessageType.image || message.type == ChatMessageType.audio
          ? message.text.trim()
          : '';
      return caption.isEmpty ? label : '$label $caption';
    }

    return switch (message.type) {
      ChatMessageType.text => message.text,
      ChatMessageType.image => withCaption(imageLabel),
      ChatMessageType.audio => withCaption(audioLabel),
      ChatMessageType.document =>
        message.media?.fileName == null ? documentLabel : '$documentLabel ${message.media!.fileName}',
      ChatMessageType.location => locationLabel,
      ChatMessageType.unknown => unsupportedLabel,
    };
  }

  /// The day of [date] (local time) as WhatsApp shows it: "Hari ini",
  /// "Kemarin", the weekday within the last week, then "12 Okt", or
  /// "12 Okt 2025" for another year.
  String dayLabel(DateTime date, {DateTime? now}) {
    final local = date.toLocal();
    final today0 = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
    final day = DateUtils.dateOnly(local);
    final daysAgo = today0.difference(day).inHours ~/ 24;
    if (daysAgo == 0) return today;
    if (daysAgo == 1) return yesterday;
    if (daysAgo > 1 && daysAgo < 7) return weekdays[local.weekday - 1];
    final short = '${local.day} ${months[local.month - 1]}';
    return local.year == today0.year ? short : '$short ${local.year}';
  }

  /// Section label of an emoji panel tab.
  String emojiCategory(NusaChatEmojiCategory category) => switch (category) {
    NusaChatEmojiCategory.recent => emojiRecent,
    NusaChatEmojiCategory.smileys => emojiSmileys,
    NusaChatEmojiCategory.people => emojiPeople,
    NusaChatEmojiCategory.animals => emojiAnimals,
    NusaChatEmojiCategory.food => emojiFood,
    NusaChatEmojiCategory.activities => emojiActivities,
    NusaChatEmojiCategory.travel => emojiTravel,
    NusaChatEmojiCategory.objects => emojiObjects,
  };

  NusaChatStrings copyWith({
    String? title,
    String? agentName,
    String? hintText,
    String? connecting,
    String? reconnecting,
    String? retry,
    String? emptyMessage,
    String? today,
    String? yesterday,
    List<String>? weekdays,
    List<String>? months,
    String? failedToSend,
    String? copy,
    String? copied,
    String? imageLabel,
    String? documentLabel,
    String? audioLabel,
    String? locationLabel,
    String? unsupportedLabel,
    String? attachGallery,
    String? attachDocument,
    String? attachLocation,
    String? previewTitle,
    String? captionHint,
    String? recording,
    String? cancel,
    String? send,
    String? sendLocationTitle,
    String? locationAccuracy,
    String? fetchingLocation,
    String? openInMaps,
    String? uploading,
    String? fileTooLarge,
    String? fileNotSupported,
    String? cameraUnavailable,
    String? cameraPermissionDenied,
    String? microphonePermissionDenied,
    String? locationPermissionDenied,
    String? locationServiceDisabled,
    String? locationFailed,
    String? recordingTooShort,
    String? mediaLoadFailed,
    String? openFailed,
    String? emojiSearchHint,
    String? emojiRecent,
    String? emojiSmileys,
    String? emojiPeople,
    String? emojiAnimals,
    String? emojiFood,
    String? emojiActivities,
    String? emojiTravel,
    String? emojiObjects,
    String? emojiSearchResults,
    String? emojiNotFound,
    String? emojiBackspace,
    String? cropTitle,
    String? save,
    String? undo,
    String? cropFree,
    String? rotate,
    String? editPencil,
    String? editText,
    String? editArrow,
    String? editTextHint,
    String? editTitle,
    String? editFailed,
    String? done,
  }) {
    return NusaChatStrings(
      title: title ?? this.title,
      agentName: agentName ?? this.agentName,
      hintText: hintText ?? this.hintText,
      connecting: connecting ?? this.connecting,
      reconnecting: reconnecting ?? this.reconnecting,
      retry: retry ?? this.retry,
      emptyMessage: emptyMessage ?? this.emptyMessage,
      today: today ?? this.today,
      yesterday: yesterday ?? this.yesterday,
      weekdays: weekdays ?? this.weekdays,
      months: months ?? this.months,
      failedToSend: failedToSend ?? this.failedToSend,
      copy: copy ?? this.copy,
      copied: copied ?? this.copied,
      imageLabel: imageLabel ?? this.imageLabel,
      documentLabel: documentLabel ?? this.documentLabel,
      audioLabel: audioLabel ?? this.audioLabel,
      locationLabel: locationLabel ?? this.locationLabel,
      unsupportedLabel: unsupportedLabel ?? this.unsupportedLabel,
      attachGallery: attachGallery ?? this.attachGallery,
      attachDocument: attachDocument ?? this.attachDocument,
      attachLocation: attachLocation ?? this.attachLocation,
      previewTitle: previewTitle ?? this.previewTitle,
      captionHint: captionHint ?? this.captionHint,
      recording: recording ?? this.recording,
      cancel: cancel ?? this.cancel,
      send: send ?? this.send,
      sendLocationTitle: sendLocationTitle ?? this.sendLocationTitle,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      fetchingLocation: fetchingLocation ?? this.fetchingLocation,
      openInMaps: openInMaps ?? this.openInMaps,
      uploading: uploading ?? this.uploading,
      fileTooLarge: fileTooLarge ?? this.fileTooLarge,
      fileNotSupported: fileNotSupported ?? this.fileNotSupported,
      cameraUnavailable: cameraUnavailable ?? this.cameraUnavailable,
      cameraPermissionDenied: cameraPermissionDenied ?? this.cameraPermissionDenied,
      microphonePermissionDenied: microphonePermissionDenied ?? this.microphonePermissionDenied,
      locationPermissionDenied: locationPermissionDenied ?? this.locationPermissionDenied,
      locationServiceDisabled: locationServiceDisabled ?? this.locationServiceDisabled,
      locationFailed: locationFailed ?? this.locationFailed,
      recordingTooShort: recordingTooShort ?? this.recordingTooShort,
      mediaLoadFailed: mediaLoadFailed ?? this.mediaLoadFailed,
      openFailed: openFailed ?? this.openFailed,
      emojiSearchHint: emojiSearchHint ?? this.emojiSearchHint,
      emojiRecent: emojiRecent ?? this.emojiRecent,
      emojiSmileys: emojiSmileys ?? this.emojiSmileys,
      emojiPeople: emojiPeople ?? this.emojiPeople,
      emojiAnimals: emojiAnimals ?? this.emojiAnimals,
      emojiFood: emojiFood ?? this.emojiFood,
      emojiActivities: emojiActivities ?? this.emojiActivities,
      emojiTravel: emojiTravel ?? this.emojiTravel,
      emojiObjects: emojiObjects ?? this.emojiObjects,
      emojiSearchResults: emojiSearchResults ?? this.emojiSearchResults,
      emojiNotFound: emojiNotFound ?? this.emojiNotFound,
      emojiBackspace: emojiBackspace ?? this.emojiBackspace,
      cropTitle: cropTitle ?? this.cropTitle,
      save: save ?? this.save,
      undo: undo ?? this.undo,
      cropFree: cropFree ?? this.cropFree,
      rotate: rotate ?? this.rotate,
      editPencil: editPencil ?? this.editPencil,
      editText: editText ?? this.editText,
      editArrow: editArrow ?? this.editArrow,
      editTextHint: editTextHint ?? this.editTextHint,
      editTitle: editTitle ?? this.editTitle,
      editFailed: editFailed ?? this.editFailed,
      done: done ?? this.done,
    );
  }
}
