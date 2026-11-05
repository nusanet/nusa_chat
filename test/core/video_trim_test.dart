import 'package:flutter_test/flutter_test.dart';
import 'package:nusa_chat/src/core/util/video_trim.dart';

Duration s(int seconds) => Duration(seconds: seconds);

void main() {
  group('NusaChatTrimRange', () {
    test('pastikan video panjang mulai dari awal sepanjang batasnya', () {
      final range = NusaChatTrimRange.initial(s(120), maxLength: s(30));
      expect(range.start, Duration.zero);
      expect(range.end, s(30));
      expect(range.length, s(30));
    });

    test('pastikan batas bawaan 1 menit 30 detik', () {
      expect(NusaChatTrimRange.initial(s(120)).length, s(90));
    });

    test('pastikan video pendek terpilih seluruhnya', () {
      final range = NusaChatTrimRange.initial(s(12));
      expect(range.end, s(12));
    });

    test('pastikan ujung ikut bergeser agar tidak melebihi batas saat awal ditarik', () {
      final moved = NusaChatTrimRange.initial(s(120), maxLength: s(30)).withEnd(s(60));
      expect(moved.start, s(30));
      expect(moved.withStart(s(10)).end, s(40));
      expect(moved.withStart(s(10)).length, s(30));
    });

    test('pastikan awal ikut bergeser agar tidak melebihi batas saat ujung ditarik', () {
      final range = NusaChatTrimRange.initial(s(120), maxLength: s(30)).withEnd(s(100));
      expect(range.start, s(70));
      expect(range.end, s(100));
    });

    test('pastikan pilihan bisa dipendekkan tapi tidak kurang dari 1 detik', () {
      final range = NusaChatTrimRange.initial(s(120), maxLength: s(30));
      expect(range.withEnd(s(10)).length, s(10));
      expect(range.withEnd(Duration.zero).end, s(1));
      expect(range.withEnd(s(10)).withStart(s(50)).start, s(50));
      expect(range.withEnd(s(10)).withStart(s(50)).end, s(51));
    });

    test('pastikan batas video dihormati', () {
      final range = NusaChatTrimRange.initial(s(120), maxLength: s(30));
      expect(range.withEnd(s(500)).end, s(120));
      expect(range.withStart(s(-5)).start, Duration.zero);
      expect(range.withStart(s(500)).start, s(119));
      expect(range.withStart(s(500)).end, s(120));
    });

    test('pastikan menggeser pilihan menjaga panjangnya', () {
      final range = NusaChatTrimRange.initial(s(120), maxLength: s(30));
      expect(range.movedBy(s(20)).start, s(20));
      expect(range.movedBy(s(20)).length, s(30));
      expect(range.movedBy(s(500)).end, s(120));
      expect(range.movedBy(s(500)).length, s(30));
      expect(range.movedBy(s(-5)).start, Duration.zero);
    });

    test('pastikan video lebih pendek dari 1 detik tetap valid', () {
      const total = Duration(milliseconds: 400);
      final range = NusaChatTrimRange.initial(total);
      expect(range.end, total);
      expect(range.withEnd(Duration.zero).end, total);
      expect(range.withStart(total).start, Duration.zero);
    });

    test('pastikan kesetaraan berdasarkan nilai', () {
      expect(NusaChatTrimRange.initial(s(60)), NusaChatTrimRange.initial(s(60)));
      expect(NusaChatTrimRange.initial(s(60)).hashCode, NusaChatTrimRange.initial(s(60)).hashCode);
      expect(NusaChatTrimRange.initial(s(60)), isNot(NusaChatTrimRange.initial(s(90))));
      expect(NusaChatTrimRange.initial(s(60)).toString(), contains('total'));
    });
  });

  group('NusaChatVideoSpec', () {
    test('pastikan 1080p landscape diturunkan ke 720p', () {
      final spec = NusaChatVideoSpec.forSource(width: 1920, height: 1080);
      expect((spec.width, spec.height), (1280, 720));
      expect(spec.videoBitrateMbps, NusaChatVideoSpec.maxVideoBitrateMbps);
    });

    test('pastikan orientasi encoded dipertahankan', () {
      final spec = NusaChatVideoSpec.forSource(width: 1080, height: 1920);
      expect((spec.width, spec.height), (720, 1280));
    });

    test('pastikan 4K dan rasio lebar dibatasi sisi panjangnya', () {
      final spec = NusaChatVideoSpec.forSource(width: 3840, height: 1080);
      expect((spec.width, spec.height), (1280, 360));
    });

    test('pastikan video kecil tidak diperbesar dan dimensi selalu genap', () {
      final spec = NusaChatVideoSpec.forSource(width: 641, height: 361);
      expect(spec.width.isEven && spec.height.isEven, isTrue);
      expect(spec.width, lessThanOrEqualTo(642));
      expect(spec.height, lessThanOrEqualTo(362));
    });

    test('pastikan bitrate tidak melebihi sumbernya', () {
      expect(NusaChatVideoSpec.forSource(width: 640, height: 360, sourceBitrate: 500000).videoBitrateMbps, 0.5);
      expect(
        NusaChatVideoSpec.forSource(width: 1920, height: 1080, sourceBitrate: 20000000).videoBitrateMbps,
        NusaChatVideoSpec.maxVideoBitrateMbps,
      );
    });

    test('pastikan 1 menit 30 detik muat di bawah 15 MB, juga dengan encoder yang melampaui target 18%', () {
      const seconds = 90;
      const overshoot = 1.18;
      const sourceAudioBitrate = 320000;
      final bits = (NusaChatVideoSpec.maxVideoBitrateMbps * 1000000 * overshoot + sourceAudioBitrate) * seconds;
      expect(bits / 8, lessThan(15000000));
    });

    test('pastikan kesetaraan berdasarkan nilai', () {
      const a = NusaChatVideoSpec(width: 2, height: 2, videoBitrateMbps: 1);
      const b = NusaChatVideoSpec(width: 2, height: 2, videoBitrateMbps: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('videoBitrateMbps'));
    });
  });
}
