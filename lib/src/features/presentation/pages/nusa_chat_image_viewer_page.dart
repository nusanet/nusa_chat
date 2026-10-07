import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_media.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// A photo from the chat, full screen: pinch to zoom (1–5×), double-tap to
/// zoom in on a spot and back out, drag to look around while zoomed.
class NusaChatImageViewerPage extends StatefulWidget {
  final ChatMedia media;
  final String caption;
  final Object? heroTag;

  const NusaChatImageViewerPage({super.key, required this.media, this.caption = '', this.heroTag});

  static const maxScale = 5.0;

  /// How far a double-tap zooms in.
  static const doubleTapScale = 2.5;

  @override
  State<NusaChatImageViewerPage> createState() => _NusaChatImageViewerPageState();
}

class _NusaChatImageViewerPageState extends State<NusaChatImageViewerPage> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoom;
  late final Animation<double> _zoomCurve;
  Matrix4Tween? _zoomTween;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _zoom = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _zoomCurve = CurvedAnimation(parent: _zoom, curve: Curves.easeOut)
      ..addListener(() {
        final tween = _zoomTween;
        if (tween != null) _transform.value = tween.evaluate(_zoomCurve);
      });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Zooms in around the tapped spot, or back out when already zoomed.
  void _onDoubleTap() {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 target;
    if (zoomedIn) {
      target = Matrix4.identity();
    } else {
      const scale = NusaChatImageViewerPage.doubleTapScale;
      final at = _doubleTapAt;
      target = Matrix4.identity()
        ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target);
    _zoom.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = nusaChatImageProvider(widget.media);
    Widget image = provider == null
        ? const SizedBox.expand()
        : Image(image: provider, fit: BoxFit.contain, width: double.infinity, height: double.infinity);
    if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // The photo takes the whole screen; the buttons are placed on top.
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: NusaChatImageViewerPage.maxScale,
              child: image,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const WidgetSvgIcon(BaseIcons.close, size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
          if (widget.caption.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
                child: Text(widget.caption, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}
