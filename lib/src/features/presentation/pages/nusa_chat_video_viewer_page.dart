import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/service/media_service.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_media.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';
import 'package:video_player/video_player.dart';

/// A video from the chat, full screen. Plays the file on this device; one that
/// is not here yet is downloaded first, with its progress.
class NusaChatVideoViewerPage extends StatefulWidget {
  final ChatMedia media;
  final String caption;
  final NusaChatStrings strings;

  /// Downloads a video that is not on this device.
  final NusaChatMediaService? mediaService;

  const NusaChatVideoViewerPage({
    super.key,
    required this.media,
    this.caption = '',
    this.strings = const NusaChatStrings(),
    this.mediaService,
  });

  @override
  State<NusaChatVideoViewerPage> createState() => _NusaChatVideoViewerPageState();
}

class _NusaChatVideoViewerPageState extends State<NusaChatVideoViewerPage> {
  VideoPlayerController? _controller;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final VideoPlayerController controller;
    try {
      controller = VideoPlayerController.file(File(await _localFile()));
      await controller.initialize();
    } catch (_) {
      if (!mounted) return;
      showNusaChatSnackBar(context, widget.strings.mediaLoadFailed);
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onPlayerChanged);
    setState(() => _controller = controller);
    unawaited(controller.play());
  }

  Future<String> _localFile() async {
    final localPath = widget.media.localPath;
    if (localPath != null && File(localPath).existsSync()) return localPath;
    final url = widget.media.url;
    if (url == null) throw StateError('no source');
    final service = widget.mediaService ?? NusaChatMediaServiceImpl();
    return service.downloadVideo(
      url,
      onProgress: (progress) {
        if (mounted) setState(() => _downloadProgress = progress);
      },
    );
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  /// Starts over from the beginning when played again after the end.
  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isPlaying) {
      controller.pause();
    } else {
      if (value.position >= value.duration) controller.seekTo(Duration.zero);
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller == null)
            Center(
              child: CircularProgressIndicator(
                value: _downloadProgress,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            )
          else
            GestureDetector(
              key: const ValueKey('nusa_chat.video_surface'),
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
                  ),
                  if (!controller.value.isPlaying) const NusaChatVideoPlayBadge(),
                ],
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: widget.strings.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const WidgetSvgIcon(BaseIcons.close, size: 24, color: Colors.white),
                ),
              ),
            ),
          ),
          if (controller != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.caption.trim().isNotEmpty) ...[
                      Text(widget.caption, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${MediaHelper.formatDuration(controller.value.position)} / '
                          '${MediaHelper.formatDuration(controller.value.duration)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
