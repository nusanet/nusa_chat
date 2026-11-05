import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/service/media_service.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/core/util/video_trim.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_editor.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_media.dart';
import 'package:video_player/video_player.dart';

/// Picks the part of a video to send, at most [MediaHelper.maxVideoDuration],
/// on a timeline with two handles; dragging between them slides the selection.
/// "Lanjut" compresses it, with progress and a way to cancel.
///
/// Pops with the compressed video, or null.
class NusaChatVideoTrimPage extends StatefulWidget {
  final String path;
  final NusaChatMediaService mediaService;
  final NusaChatStrings strings;

  const NusaChatVideoTrimPage({
    super.key,
    required this.path,
    required this.mediaService,
    this.strings = const NusaChatStrings(),
  });

  /// Frames on the timeline.
  static const thumbnailCount = 8;

  @override
  State<NusaChatVideoTrimPage> createState() => _NusaChatVideoTrimPageState();
}

class _NusaChatVideoTrimPageState extends State<NusaChatVideoTrimPage> {
  NusaChatVideoInfo? _info;
  VideoPlayerController? _controller;
  NusaChatTrimRange? _range;
  List<String> _thumbnails = const [];

  /// 0–1 while compressing; null otherwise.
  double? _compressProgress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.removeListener(_loopInRange);
    _controller?.dispose();
    if (_compressProgress != null) widget.mediaService.cancelVideoCompression();
    super.dispose();
  }

  Future<void> _load() async {
    final NusaChatVideoInfo info;
    final VideoPlayerController controller;
    try {
      info = await widget.mediaService.videoInfo(widget.path);
      controller = VideoPlayerController.file(File(widget.path));
      await controller.initialize();
    } catch (_) {
      _close(widget.strings.fileNotSupported);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_loopInRange);
    setState(() {
      _info = info;
      _controller = controller;
      _range = NusaChatTrimRange.initial(info.duration);
    });
    unawaited(_loadThumbnails(info.duration));
  }

  /// The timeline works without its pictures.
  Future<void> _loadThumbnails(Duration total) async {
    final step = total ~/ NusaChatVideoTrimPage.thumbnailCount;
    try {
      final thumbnails = await widget.mediaService.videoThumbnails(widget.path, [
        for (var i = 0; i < NusaChatVideoTrimPage.thumbnailCount; i++) step * i,
      ]);
      if (mounted) setState(() => _thumbnails = thumbnails);
    } catch (_) {
      // Keeps the plain timeline.
    }
  }

  void _close(String message) {
    if (!mounted) return;
    showNusaChatSnackBar(context, message);
    Navigator.of(context).pop();
  }

  /// Plays only the selected part, over and over.
  void _loopInRange() {
    final controller = _controller;
    final range = _range;
    if (controller == null || range == null || !mounted) return;
    if (controller.value.isPlaying && controller.value.position >= range.end) {
      controller.seekTo(range.start);
    }
    setState(() {});
  }

  void _togglePlay() {
    final controller = _controller;
    final range = _range;
    if (controller == null || range == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      final position = controller.value.position;
      if (position < range.start || position >= range.end) controller.seekTo(range.start);
      controller.play();
    }
  }

  /// Shows the frame at [position] while a handle is dragged.
  void _setRange(NusaChatTrimRange range, Duration position) {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) controller.pause();
    controller.seekTo(position);
    setState(() => _range = range);
  }

  Future<void> _next() async {
    final info = _info;
    final range = _range;
    if (info == null || range == null || _compressProgress != null) return;
    await _controller?.pause();
    setState(() => _compressProgress = 0);
    try {
      final video = await widget.mediaService.compressVideo(
        widget.path,
        info: info,
        start: range.start,
        end: range.end,
        onProgress: (progress) {
          if (mounted) setState(() => _compressProgress = progress.clamp(0.0, 1.0));
        },
      );
      if (!mounted) return;
      setState(() => _compressProgress = null);
      if (video != null) Navigator.of(context).pop<ChatAttachment>(video);
    } on NusaChatMediaException catch (error) {
      if (!mounted) return;
      setState(() => _compressProgress = null);
      final strings = widget.strings;
      showNusaChatSnackBar(
        context,
        error.error == NusaChatMediaError.tooLarge ? strings.videoTooLarge : strings.videoCompressFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final controller = _controller;
    final range = _range;
    final compressing = _compressProgress != null;
    return PopScope(
      // Back cancels the compression first; the page stays to pick again.
      canPop: !compressing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.mediaService.cancelVideoCompression();
      },
      child: Scaffold(
        backgroundColor: theme.previewBackgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  NusaChatEditorBar(
                    cancelLabel: widget.strings.cancel,
                    onCancel: () => Navigator.of(context).maybePop(),
                    title: widget.strings.videoTrimTitle,
                    actions: [
                      NusaChatEditorTextButton(label: widget.strings.next, onTap: range == null ? null : _next),
                    ],
                  ),
                  Expanded(
                    child: controller == null
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : GestureDetector(
                            key: const ValueKey('nusa_chat.trim_surface'),
                            behavior: HitTestBehavior.opaque,
                            onTap: _togglePlay,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: controller.value.aspectRatio,
                                    child: VideoPlayer(controller),
                                  ),
                                ),
                                if (!controller.value.isPlaying) const NusaChatVideoPlayBadge(),
                              ],
                            ),
                          ),
                  ),
                  if (range != null)
                    Padding(
                      padding: const EdgeInsets.all(BaseSpacing.lg),
                      child: Column(
                        children: [
                          Text(
                            '${MediaHelper.formatDuration(range.length)} · '
                            '${widget.strings.videoMaxDuration.replaceAll('{max}', MediaHelper.formatDuration(MediaHelper.maxVideoDuration))}',
                            style: theme.previewTextStyle,
                          ),
                          const SizedBox(height: BaseSpacing.md),
                          _TrimTimeline(
                            range: range,
                            thumbnails: _thumbnails,
                            playedTo: controller?.value.position,
                            // From the state, not this build: several drags can land in one frame.
                            onStart: (delta) {
                              final next = _range!.withStart(_range!.start + delta);
                              _setRange(next, next.start);
                            },
                            onEnd: (delta) {
                              final next = _range!.withEnd(_range!.end + delta);
                              _setRange(next, next.end);
                            },
                            onMove: (delta) {
                              final next = _range!.movedBy(delta);
                              _setRange(next, next.start);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (compressing)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xB3000000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 56,
                          child: CircularProgressIndicator(
                            value: _compressProgress! <= 0 ? null : _compressProgress,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        const SizedBox(height: BaseSpacing.lg),
                        Text(
                          '${widget.strings.compressingVideo} ${(_compressProgress! * 100).round()}%',
                          style: theme.previewTextStyle,
                        ),
                        const SizedBox(height: BaseSpacing.sm),
                        NusaChatEditorTextButton(
                          label: widget.strings.cancel,
                          muted: true,
                          onTap: widget.mediaService.cancelVideoCompression,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole video as a strip of frames, with the part outside the selection
/// dimmed and a handle on each side of it.
class _TrimTimeline extends StatelessWidget {
  final NusaChatTrimRange range;
  final List<String> thumbnails;
  final Duration? playedTo;
  final ValueChanged<Duration> onStart;
  final ValueChanged<Duration> onEnd;
  final ValueChanged<Duration> onMove;

  const _TrimTimeline({
    required this.range,
    required this.thumbnails,
    required this.playedTo,
    required this.onStart,
    required this.onEnd,
    required this.onMove,
  });

  static const _height = 56.0;
  static const _handleWidth = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The handles sit outside the strip, so both ends can be reached.
          final width = constraints.maxWidth - _handleWidth * 2;
          final total = range.total.inMicroseconds;
          double x(Duration value) => total <= 0 ? 0 : width * value.inMicroseconds / total;
          Duration time(double dx) => Duration(microseconds: width <= 0 ? 0 : (dx / width * total).round());
          final startX = x(range.start);
          final endX = x(range.end);
          final played = playedTo;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _handleWidth,
                width: width,
                top: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BaseRadius.sm),
                  child: ColoredBox(
                    color: theme.previewSurfaceColor,
                    child: Row(
                      children: [
                        for (final thumbnail in thumbnails)
                          Expanded(
                            child: Image.file(
                              File(thumbnail),
                              fit: BoxFit.cover,
                              height: _height,
                              cacheWidth: 120,
                              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _handleWidth,
                width: startX,
                top: 0,
                bottom: 0,
                child: const ColoredBox(color: Color(0xA6000000)),
              ),
              Positioned(
                left: _handleWidth + endX,
                right: _handleWidth,
                top: 0,
                bottom: 0,
                child: const ColoredBox(color: Color(0xA6000000)),
              ),
              Positioned(
                left: _handleWidth + startX,
                width: endX - startX,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  key: const ValueKey('nusa_chat.trim_range'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) => onMove(time(details.delta.dx)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: theme.primaryColor, width: 3)),
                    ),
                  ),
                ),
              ),
              if (played != null && played >= range.start && played <= range.end)
                Positioned(
                  left: _handleWidth + x(played) - 1,
                  width: 2,
                  top: 3,
                  bottom: 3,
                  child: const IgnorePointer(child: ColoredBox(color: Colors.white)),
                ),
              Positioned(
                left: startX,
                width: _handleWidth,
                top: 0,
                bottom: 0,
                child: _TrimHandle(
                  key: const ValueKey('nusa_chat.trim_start'),
                  color: theme.primaryColor,
                  left: true,
                  onDrag: (dx) => onStart(time(dx)),
                ),
              ),
              Positioned(
                left: _handleWidth + endX,
                width: _handleWidth,
                top: 0,
                bottom: 0,
                child: _TrimHandle(
                  key: const ValueKey('nusa_chat.trim_end'),
                  color: theme.primaryColor,
                  left: false,
                  onDrag: (dx) => onEnd(time(dx)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  final Color color;
  final bool left;
  final ValueChanged<double> onDrag;

  const _TrimHandle({super.key, required this.color, required this.left, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(BaseRadius.sm);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.horizontal(left: left ? corner : Radius.zero, right: left ? Radius.zero : corner),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1)),
        ),
      ),
    );
  }
}
