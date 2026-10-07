import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/image_edit.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_editor.dart';

/// The crop ratios; [ratio] is width ÷ height in pixels.
enum NusaChatCropRatio {
  free(null),
  square(1),
  portrait(4 / 5),
  wide(16 / 9);

  final double? ratio;

  const NusaChatCropRatio(this.ratio);
}

/// Crop-box maths in fractions of the (turned) image: a rect inside 0–1.
@visibleForTesting
class NusaChatCropBox {
  const NusaChatCropBox._();

  static const full = Rect.fromLTWH(0, 0, 1, 1);

  /// Smallest side, as a fraction of the image.
  static const minSide = 0.1;

  /// [ratio] (pixels) expressed in fractions of an image [imageAspect] wide per 1 high.
  static double fractionAspect(double ratio, double imageAspect) => ratio / imageAspect;

  /// The largest box with pixel [ratio] that fits, centred on [center].
  static Rect fit(double ratio, double imageAspect, {Offset center = const Offset(0.5, 0.5)}) {
    final k = fractionAspect(ratio, imageAspect);
    final width = k >= 1 ? 1.0 : k;
    final height = k >= 1 ? 1 / k : 1.0;
    return _clampInside(Rect.fromCenter(center: center, width: width, height: height));
  }

  /// [box] moved by [delta], kept inside the image.
  static Rect move(Rect box, Offset delta) => _clampInside(box.shift(delta));

  /// [box] with corner [corner] (0 top-left, 1 top-right, 2 bottom-right,
  /// 3 bottom-left) dragged to [point]; [ratio] keeps the pixel shape.
  static Rect resize(Rect box, int corner, Offset point, {double? ratio, double imageAspect = 1}) {
    final anchor = switch (corner) {
      0 => box.bottomRight,
      1 => box.bottomLeft,
      2 => box.topLeft,
      _ => box.topRight,
    };
    final dirX = corner == 1 || corner == 2 ? 1.0 : -1.0;
    final dirY = corner >= 2 ? 1.0 : -1.0;
    final roomX = dirX > 0 ? 1 - anchor.dx : anchor.dx;
    final roomY = dirY > 0 ? 1 - anchor.dy : anchor.dy;
    var width = ((point.dx - anchor.dx) * dirX).clamp(0.0, roomX);
    var height = ((point.dy - anchor.dy) * dirY).clamp(0.0, roomY);

    if (ratio == null) {
      width = math.max(width, math.min(minSide, roomX));
      height = math.max(height, math.min(minSide, roomY));
    } else {
      final k = fractionAspect(ratio, imageAspect);
      width = math.max(width, height * k);
      final minWidth = math.max(minSide, minSide * k);
      width = width.clamp(math.min(minWidth, math.min(roomX, roomY * k)), math.min(roomX, roomY * k));
      height = width / k;
    }
    return Rect.fromPoints(anchor, anchor + Offset(width * dirX, height * dirY));
  }

  static Rect _clampInside(Rect box) {
    final width = math.min(box.width, 1.0);
    final height = math.min(box.height, 1.0);
    final left = box.left.clamp(0.0, 1 - width);
    final top = box.top.clamp(0.0, 1 - height);
    return Rect.fromLTWH(left, top, width, height);
  }
}

/// Crops to a free box or 1:1, 4:5 and 16:9, and turn the
/// photo. Pops with the cropped photo, or null.
class NusaChatCropPage extends StatefulWidget {
  final ChatAttachment attachment;
  final NusaChatStrings strings;

  /// "1 / 2" when the photo is one of several.
  final String? pager;

  const NusaChatCropPage({super.key, required this.attachment, this.strings = const NusaChatStrings(), this.pager});

  @override
  State<NusaChatCropPage> createState() => _NusaChatCropPageState();
}

class _NusaChatCropPageState extends State<NusaChatCropPage> {
  ui.Image? _image;
  var _turns = 0;
  var _box = NusaChatCropBox.full;
  var _ratio = NusaChatCropRatio.free;
  var _saving = false;

  /// What a drag moves: a corner (0–3), the whole box (4), or nothing.
  int? _dragging;

  @override
  void initState() {
    super.initState();
    NusaChatImageEdit.decode(widget.attachment.path).then(
      (image) {
        if (mounted) {
          setState(() => _image = image);
        } else {
          image.dispose();
        }
      },
      onError: (_) {
        if (mounted) _fail();
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Width ÷ height of the photo as it is turned now.
  double get _aspect {
    final image = _image!;
    return _turns.isOdd ? image.height / image.width : image.width / image.height;
  }

  void _selectRatio(NusaChatCropRatio ratio) {
    setState(() {
      _ratio = ratio;
      final value = ratio.ratio;
      if (value != null) _box = NusaChatCropBox.fit(value, _aspect, center: _box.center);
    });
  }

  void _rotate() {
    setState(() {
      _turns = (_turns + 1) % 4;
      final value = _ratio.ratio;
      _box = value == null ? NusaChatCropBox.full : NusaChatCropBox.fit(value, _aspect);
    });
  }

  Future<void> _save() async {
    final image = _image;
    if (image == null || _saving) return;
    if (_turns == 0 && _box == NusaChatCropBox.full) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final cropped = await NusaChatImageEdit.crop(image, quarterTurns: _turns, crop: _box);
      final saved = await NusaChatImageEdit.save(cropped, widget.attachment);
      cropped.dispose();
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _fail();
      }
    }
  }

  void _fail() {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(widget.strings.editFailed), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final strings = widget.strings;
    return Scaffold(
      backgroundColor: theme.previewBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            NusaChatEditorBar(
              cancelLabel: strings.cancel,
              onCancel: () => Navigator.of(context).pop(),
              title: strings.cropTitle,
              actions: [NusaChatEditorTextButton(label: strings.save, onTap: _image == null || _saving ? null : _save)],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(BaseSpacing.lg),
                child: _image == null || _saving
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : LayoutBuilder(builder: (context, constraints) => _buildCropArea(constraints.biggest)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BaseSpacing.lg, 0, BaseSpacing.lg, BaseSpacing.lg),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final ratio in NusaChatCropRatio.values) ...[
                      NusaChatEditorChip(
                        label: switch (ratio) {
                          NusaChatCropRatio.free => strings.cropFree,
                          NusaChatCropRatio.square => '1:1',
                          NusaChatCropRatio.portrait => '4:5',
                          NusaChatCropRatio.wide => '16:9',
                        },
                        selected: _ratio == ratio,
                        onTap: () => _selectRatio(ratio),
                      ),
                      const SizedBox(width: BaseSpacing.sm),
                    ],
                    NusaChatEditorChip(label: strings.rotate, selected: false, onTap: _rotate),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropArea(Size area) {
    final aspect = _aspect;
    final fitted = area.width / area.height > aspect
        ? Size(area.height * aspect, area.height)
        : Size(area.width, area.width / aspect);
    final imageRect = Alignment.center.inscribe(fitted, Offset.zero & area);
    Rect toScreen(Rect box) => Rect.fromLTRB(
      imageRect.left + box.left * imageRect.width,
      imageRect.top + box.top * imageRect.height,
      imageRect.left + box.right * imageRect.width,
      imageRect.top + box.bottom * imageRect.height,
    );
    Offset toFraction(Offset point) =>
        Offset((point.dx - imageRect.left) / imageRect.width, (point.dy - imageRect.top) / imageRect.height);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        final box = toScreen(_box);
        final corners = [box.topLeft, box.topRight, box.bottomRight, box.bottomLeft];
        final distances = [for (final c in corners) (c - details.localPosition).distance];
        final nearest = distances.indexOf(distances.reduce(math.min));
        _dragging = distances[nearest] <= 36 ? nearest : (box.contains(details.localPosition) ? 4 : null);
      },
      onPanUpdate: (details) {
        final dragging = _dragging;
        if (dragging == null) return;
        setState(() {
          _box = dragging == 4
              ? NusaChatCropBox.move(
                  _box,
                  Offset(details.delta.dx / imageRect.width, details.delta.dy / imageRect.height),
                )
              : NusaChatCropBox.resize(
                  _box,
                  dragging,
                  toFraction(details.localPosition),
                  ratio: _ratio.ratio,
                  imageAspect: aspect,
                );
        });
      },
      onPanEnd: (_) => _dragging = null,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: imageRect,
            child: RotatedBox(
              quarterTurns: _turns,
              child: RawImage(image: _image, fit: BoxFit.fill),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CropPainter(imageRect: imageRect, box: toScreen(_box)),
            ),
          ),
          if (widget.pager != null)
            Positioned(
              left: imageRect.left + BaseSpacing.md,
              top: imageRect.top + BaseSpacing.md,
              child: NusaChatPagerBadge(widget.pager!),
            ),
        ],
      ),
    );
  }
}

/// Dims outside the box and draws its frame, thirds and corner handles.
class _CropPainter extends CustomPainter {
  final Rect imageRect;
  final Rect box;

  _CropPainter({required this.imageRect, required this.box});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(imageRect), Path()..addRect(box)),
      Paint()..color = const Color(0x99000000),
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final third in [1 / 3, 2 / 3]) {
      final x = box.left + box.width * third;
      final y = box.top + box.height * third;
      canvas
        ..drawLine(Offset(x, box.top), Offset(x, box.bottom), line)
        ..drawLine(Offset(box.left, y), Offset(box.right, y), line);
    }
    canvas.drawRect(
      box,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const length = 14.0;
    for (final (corner, dx, dy) in [
      (box.topLeft, 1.0, 1.0),
      (box.topRight, -1.0, 1.0),
      (box.bottomRight, -1.0, -1.0),
      (box.bottomLeft, 1.0, -1.0),
    ]) {
      canvas
        ..drawLine(corner, corner + Offset(length * dx, 0), handle)
        ..drawLine(corner, corner + Offset(0, length * dy), handle);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.box != box || oldDelegate.imageRect != imageRect;
}
