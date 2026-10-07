import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:nusa_chat/src/core/util/styles/typography.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:path_provider/path_provider.dart';

/// A mark drawn on a photo in the editor. Positions are fractions of the
/// image (0–1) and sizes fractions of its width, so a mark lands in the same
/// place on screen and in the full-size file.
sealed class NusaChatMark {
  final Color color;

  const NusaChatMark(this.color);
}

class NusaChatStrokeMark extends NusaChatMark {
  final List<Offset> points;
  final double width;

  const NusaChatStrokeMark({required Color color, required this.points, required this.width}) : super(color);
}

class NusaChatArrowMark extends NusaChatMark {
  final Offset from;
  final Offset to;
  final double width;

  const NusaChatArrowMark({required Color color, required this.from, required this.to, required this.width})
    : super(color);

  NusaChatArrowMark copyWith({Offset? to}) =>
      NusaChatArrowMark(color: color, from: from, to: to ?? this.to, width: width);
}

class NusaChatTextMark extends NusaChatMark {
  final String text;

  /// Top-left corner.
  final Offset position;
  final double fontSize;

  const NusaChatTextMark({required Color color, required this.text, required this.position, required this.fontSize})
    : super(color);

  NusaChatTextMark copyWith({String? text, Offset? position, Color? color}) => NusaChatTextMark(
    color: color ?? this.color,
    text: text ?? this.text,
    position: position ?? this.position,
    fontSize: fontSize,
  );

  /// Shared by the on-screen text and the saved file, so they wrap alike.
  TextStyle style(double imageWidth) => BaseTypography.p1SemiBold.copyWith(
    color: color,
    fontSize: fontSize * imageWidth,
    height: 1.3,
    shadows: [Shadow(color: const Color(0x66000000), blurRadius: 4 * fontSize * imageWidth / 20)],
  );
}

/// Draws [marks] over an image of [size]; texts only when [withText].
class NusaChatMarksPainter extends CustomPainter {
  final List<NusaChatMark> marks;
  final bool withText;

  NusaChatMarksPainter(this.marks, {this.withText = true});

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in marks) {
      switch (mark) {
        case NusaChatStrokeMark(:final points, :final width):
          final paint = _linePaint(mark.color, width * size.width);
          if (points.length == 1) {
            canvas.drawCircle(_at(points.first, size), paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
            continue;
          }
          final path = Path()..moveTo(points.first.dx * size.width, points.first.dy * size.height);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx * size.width, point.dy * size.height);
          }
          canvas.drawPath(path, paint);
        case NusaChatArrowMark(:final from, :final to, :final width):
          final start = _at(from, size);
          final end = _at(to, size);
          final stroke = width * size.width;
          final paint = _linePaint(mark.color, stroke);
          canvas.drawLine(start, end, paint);
          final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
          final head = math.max(stroke * 4, 12.0);
          for (final side in [-1, 1]) {
            final wing = angle + math.pi + side * math.pi / 6;
            canvas.drawLine(end, end + Offset(math.cos(wing), math.sin(wing)) * head, paint);
          }
        case NusaChatTextMark(:final text, :final position):
          if (!withText || text.isEmpty) continue;
          final painter = TextPainter(
            text: TextSpan(text: text, style: mark.style(size.width)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: math.max(0, size.width - position.dx * size.width));
          painter.paint(canvas, _at(position, size));
          painter.dispose();
      }
    }
  }

  static Offset _at(Offset fraction, Size size) => Offset(fraction.dx * size.width, fraction.dy * size.height);

  static Paint _linePaint(Color color, double width) => Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  @override
  bool shouldRepaint(covariant NusaChatMarksPainter oldDelegate) => true;
}

/// Decoding, cropping, drawing and saving a photo for the editor.
class NusaChatImageEdit {
  const NusaChatImageEdit._();

  /// The longest side kept; a 12 MP photo is scaled down to this.
  static const maxSide = 2560;

  /// Where [save] writes when no directory is given; the temporary directory by default.
  @visibleForTesting
  static Directory? saveDirectory;

  /// Decodes [path] (EXIF rotation applied), no larger than [maxSide].
  static Future<ui.Image> decode(String path) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(await File(path).readAsBytes());
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final tooBig = math.max(descriptor.width, descriptor.height) > maxSide;
    // One side only, so the aspect ratio is kept.
    final codec = await descriptor.instantiateCodec(
      targetWidth: tooBig && descriptor.width >= descriptor.height ? maxSide : null,
      targetHeight: tooBig && descriptor.height > descriptor.width ? maxSide : null,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  /// [source] turned [quarterTurns] × 90° clockwise, then cut to [crop]
  /// (fractions of the turned image).
  static Future<ui.Image> crop(ui.Image source, {int quarterTurns = 0, Rect crop = const Rect.fromLTWH(0, 0, 1, 1)}) {
    final turns = quarterTurns % 4;
    final width = (turns.isOdd ? source.height : source.width).toDouble();
    final height = (turns.isOdd ? source.width : source.height).toDouble();
    final area = Rect.fromLTRB(
      (crop.left * width).roundToDouble(),
      (crop.top * height).roundToDouble(),
      (crop.right * width).roundToDouble(),
      (crop.bottom * height).roundToDouble(),
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..translate(-area.left, -area.top)
      ..translate(width / 2, height / 2)
      ..rotate(turns * math.pi / 2)
      ..translate(-source.width / 2, -source.height / 2)
      ..drawImage(source, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    return _toImage(recorder, area.width.round(), area.height.round());
  }

  /// [source] with [marks] drawn on it.
  static Future<ui.Image> draw(ui.Image source, List<NusaChatMark> marks) {
    final size = Size(source.width.toDouble(), source.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawImage(source, Offset.zero, Paint());
    NusaChatMarksPainter(marks).paint(canvas, size);
    return _toImage(recorder, source.width, source.height);
  }

  static Future<ui.Image> _toImage(ui.PictureRecorder recorder, int width, int height) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(math.max(1, width), math.max(1, height));
    picture.dispose();
    return image;
  }

  /// Saves [image] as a JPEG next to the app's temporary files and returns it
  /// as the edited version of [original] (its caption kept).
  static Future<ChatAttachment> save(ui.Image image, ChatAttachment original, {Directory? directory}) async {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    final height = image.height;
    final pixels = rgba!.buffer.asUint8List();
    // Encoding a big photo takes a moment; keep it off the UI thread.
    final jpeg = await Isolate.run(() => _encodeJpeg(pixels, width, height));

    final dir = directory ?? saveDirectory ?? await getTemporaryDirectory();
    final base = original.fileName.contains('.')
        ? original.fileName.substring(0, original.fileName.lastIndexOf('.'))
        : original.fileName;
    final file = File('${dir.path}/nusa_chat_edit_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    return ChatAttachment(
      type: ChatMessageType.image,
      path: file.path,
      fileName: '$base.jpg',
      mimeType: 'image/jpeg',
      size: jpeg.length,
      caption: original.caption,
    );
  }

  static Uint8List _encodeJpeg(Uint8List rgba, int width, int height) {
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(image, quality: 88);
  }
}
