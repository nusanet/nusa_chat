import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The image provider of [media]: the local file while it exists (sent from
/// this device), otherwise its URL. Null when neither is available.
ImageProvider? nusaChatImageProvider(ChatMedia? media) {
  final localPath = media?.localPath;
  if (localPath != null && File(localPath).existsSync()) return FileImage(File(localPath));
  final url = media?.url;
  if (url != null && url.isNotEmpty) return NetworkImage(url);
  return null;
}

/// A photo inside a bubble: full bubble
/// width, 12px corners, its natural height clamped to 120–300px. Shows the
/// upload progress over it while [uploadProgress] is set.
class NusaChatImageContent extends StatelessWidget {
  final ChatMedia? media;
  final double? uploadProgress;
  final VoidCallback? onTap;

  /// Shared with the full-screen viewer for the hero animation.
  final Object? heroTag;

  const NusaChatImageContent({super.key, required this.media, this.uploadProgress, this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final provider = nusaChatImageProvider(media);
    final placeholder = Center(
      child: WidgetSvgIcon(BaseIcons.photo, size: 32, color: theme.agentAvatarIconColor.withValues(alpha: 0.8)),
    );

    Widget image = provider == null
        ? SizedBox(height: 160, child: placeholder)
        : Image(
            image: provider,
            width: double.infinity,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, loaded) =>
                frame == null && !loaded ? SizedBox(height: 160, child: placeholder) : child,
            errorBuilder: (context, error, stack) => SizedBox(height: 160, child: placeholder),
          );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return ClipRRect(
      borderRadius: BorderRadius.circular(BaseRadius.md),
      child: ColoredBox(
        color: theme.mediaPlaceholderColor,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 300),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(onTap: uploadProgress == null ? onTap : null, child: image),
              if (uploadProgress != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x66000000),
                    child: Center(child: _UploadRing(progress: uploadProgress!)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadRing extends StatelessWidget {
  final double progress;

  const _UploadRing({required this.progress});

  static const color = Colors.white;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 36,
      child: CircularProgressIndicator(
        // Indeterminate until the first bytes go out.
        value: progress <= 0 ? null : progress,
        strokeWidth: 3,
        color: color,
        backgroundColor: color.withValues(alpha: 0.25),
      ),
    );
  }
}

/// A document card inside a bubble: a white
/// 40px file tile, the name and `PDF · 245 KB`, and a download icon.
class NusaChatDocumentContent extends StatelessWidget {
  final ChatMedia? media;
  final bool isMine;
  final double? uploadProgress;
  final VoidCallback? onTap;

  const NusaChatDocumentContent({
    super.key,
    required this.media,
    required this.isMine,
    this.uploadProgress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final foreground = isMine ? theme.myTextStyle.color! : theme.agentTextStyle.color!;
    final extension = media?.extension?.toUpperCase();
    final size = media?.size;
    final details = [?extension, if (size != null) MediaHelper.formatSize(size)].join(' · ');

    return Material(
      color: isMine ? Colors.white.withValues(alpha: 0.12) : theme.backgroundColor,
      borderRadius: BorderRadius.circular(BaseRadius.md),
      child: InkWell(
        onTap: uploadProgress == null ? onTap : null,
        borderRadius: BorderRadius.circular(BaseRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(BaseSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(BaseRadius.sm)),
                alignment: Alignment.center,
                child: WidgetSvgIcon(BaseIcons.fileText, size: 20, color: theme.myBubbleColor),
              ),
              const SizedBox(width: BaseSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      media?.fileName ?? 'Dokumen',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.agentTextStyle.copyWith(color: foreground, fontWeight: FontWeight.w600),
                    ),
                    if (details.isNotEmpty) Text(details, style: (isMine ? theme.myTimeStyle : theme.agentTimeStyle)),
                  ],
                ),
              ),
              const SizedBox(width: BaseSpacing.sm),
              if (uploadProgress != null)
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    value: uploadProgress! <= 0 ? null : uploadProgress,
                    strokeWidth: 2.5,
                    color: foreground,
                    backgroundColor: foreground.withValues(alpha: 0.25),
                  ),
                )
              else if (onTap != null)
                WidgetSvgIcon(BaseIcons.download, size: 22, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// A location inside a bubble: a map preview with a pin, the coordinates
/// and "Buka di Maps". No map SDK or API key is needed; the tap opens maps.
class NusaChatLocationContent extends StatelessWidget {
  final ChatLocation location;
  final bool isMine;
  final String openLabel;
  final VoidCallback? onTap;

  /// Null shows a drawn placeholder instead of a Google map.
  final NusaChatGoogleMap? googleMap;

  const NusaChatLocationContent({
    super.key,
    required this.location,
    required this.isMine,
    required this.openLabel,
    this.onTap,
    this.googleMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final foreground = isMine ? theme.myTextStyle.color! : theme.agentTextStyle.color!;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          NusaChatMapTile(
            height: 120,
            pinColor: theme.errorColor,
            background: theme.mediaPlaceholderColor,
            location: location,
            googleMap: googleMap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(BaseSpacing.sm, BaseSpacing.sm, BaseSpacing.sm, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                    style: isMine ? theme.myTimeStyle : theme.agentTimeStyle,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(BaseSpacing.sm, BaseSpacing.xs, BaseSpacing.sm, 0),
              child: Row(
                children: [
                  WidgetSvgIcon(BaseIcons.externalLink, size: 16, color: foreground),
                  const SizedBox(width: BaseSpacing.xs),
                  Text(
                    openLabel,
                    style: theme.agentTextStyle.copyWith(color: foreground, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Google Static Maps settings for location previews
/// (https://developers.google.com/maps/documentation/maps-static).
///
/// The key needs the Maps Static API enabled. A key restricted to the app
/// (Android package + SHA-1, iOS bundle id) only works when [headers] carry
/// that identity, as nusa_selecta does for Geocoding:
/// `X-Android-Package` + `X-Android-Cert`, or `X-Ios-Bundle-Identifier`.
class NusaChatGoogleMap {
  final String apiKey;
  final Map<String, String> headers;
  final int zoom;

  /// `roadmap`, `satellite`, `hybrid` or `terrain`.
  final String mapType;

  /// Label language, e.g. `id`.
  final String language;

  const NusaChatGoogleMap({
    required this.apiKey,
    this.headers = const {},
    this.zoom = 16,
    this.mapType = 'roadmap',
    this.language = 'id',
  });

  /// The image of [location] at [width]×[height] logical pixels, with a red
  /// marker. Rendered at 2× (Google caps a side at 640 before scaling).
  Uri staticMapUri(ChatLocation location, {required double width, required double height}) {
    final point = '${location.latitude},${location.longitude}';
    final w = width.round().clamp(1, 640);
    final h = height.round().clamp(1, 640);
    return Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
      'center': point,
      'zoom': '$zoom',
      'size': '${w}x$h',
      'scale': '2',
      'maptype': mapType,
      'language': language,
      'markers': 'color:red|$point',
      'key': apiKey,
    });
  }
}

/// The map preview of a location: a Google Static Maps image centred on
/// [location] with its red marker. Without [googleMap] (no API key), without
/// a [location] yet, or when the image fails, a drawn placeholder with a pin.
class NusaChatMapTile extends StatelessWidget {
  final double height;
  final Color pinColor;
  final Color background;
  final ChatLocation? location;
  final NusaChatGoogleMap? googleMap;

  const NusaChatMapTile({
    super.key,
    required this.height,
    required this.pinColor,
    required this.background,
    this.location,
    this.googleMap,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(
      painter: _MapPainter(background),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: WidgetSvgIcon(BaseIcons.mapPinFilled, size: 32, color: pinColor),
        ),
      ),
    );
    final point = location;
    final map = googleMap;

    return ClipRRect(
      borderRadius: BorderRadius.circular(BaseRadius.md),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: point == null || map == null
            ? placeholder
            : LayoutBuilder(
                builder: (context, constraints) {
                  final uri = map.staticMapUri(point, width: constraints.maxWidth, height: height);
                  return Image.network(
                    uri.toString(),
                    headers: map.headers,
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, loaded) => frame == null && !loaded ? placeholder : child,
                    errorBuilder: (context, error, stack) => placeholder,
                  );
                },
              ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Color background;

  _MapPainter(this.background);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background.withValues(alpha: 0.45));
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 6;
    final lane = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3;
    canvas
      ..drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.55), road)
      ..drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.42, size.height), road)
      ..drawLine(Offset(size.width * 0.75, 0), Offset(size.width * 0.68, size.height), lane)
      ..drawLine(Offset(0, size.height * 0.85), Offset(size.width, size.height * 0.78), lane);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => oldDelegate.background != background;
}

/// A voice note: play/pause, progress and length. Plays the local file when
/// it is still on the device, otherwise streams the URL; one at a time.
class NusaChatAudioContent extends StatefulWidget {
  final ChatMedia? media;
  final bool isMine;
  final double? uploadProgress;

  /// Called when the file cannot be played.
  final VoidCallback? onError;

  const NusaChatAudioContent({super.key, required this.media, required this.isMine, this.uploadProgress, this.onError});

  @override
  State<NusaChatAudioContent> createState() => _NusaChatAudioContentState();
}

class _NusaChatAudioContentState extends State<NusaChatAudioContent> {
  /// The player that is playing now, paused when another one starts.
  static AudioPlayer? _active;

  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _duration = widget.media?.duration;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    if (identical(_active, _player)) _active = null;
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer?> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscriptions
      ..add(player.positionStream.listen((position) => setState(() => _position = position)))
      ..add(
        player.durationStream.listen((duration) {
          if (duration != null) setState(() => _duration = duration);
        }),
      )
      ..add(
        player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            player
              ..pause()
              ..seek(Duration.zero);
          }
          setState(() => _playing = state.playing && state.processingState != ProcessingState.completed);
        }),
      );

    final localPath = widget.media?.localPath;
    final url = widget.media?.url;
    try {
      if (localPath != null && File(localPath).existsSync()) {
        await player.setFilePath(localPath);
      } else if (url != null) {
        await player.setUrl(url);
      } else {
        throw StateError('no source');
      }
      return player;
    } catch (_) {
      _player = null;
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
      await player.dispose();
      widget.onError?.call();
      return null;
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player?.pause();
      return;
    }
    setState(() => _loading = true);
    final player = await _ensurePlayer();
    if (mounted) setState(() => _loading = false);
    if (player == null) return;
    final active = _active;
    if (active != null && !identical(active, player)) await active.pause();
    _active = player;
    unawaited(player.play());
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final foreground = widget.isMine ? theme.myTextStyle.color! : theme.primaryColor;
    final timeStyle = widget.isMine ? theme.myTimeStyle : theme.agentTimeStyle;
    final duration = _duration;
    final total = duration?.inMilliseconds ?? 0;
    final progress = total <= 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final shown = _playing || _position > Duration.zero ? _position : (duration ?? Duration.zero);
    final uploading = widget.uploadProgress != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(BaseSpacing.xs, BaseSpacing.xs, BaseSpacing.sm, 0),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: Material(
              color: foreground.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: uploading ? null : _toggle,
                child: Center(
                  child: uploading || _loading
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            value: uploading && widget.uploadProgress! > 0 ? widget.uploadProgress : null,
                            strokeWidth: 2.5,
                            color: foreground,
                          ),
                        )
                      : WidgetSvgIcon(_playing ? BaseIcons.pause : BaseIcons.play, size: 20, color: foreground),
                ),
              ),
            ),
          ),
          const SizedBox(width: BaseSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: foreground,
                    backgroundColor: foreground.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: BaseSpacing.xs),
                Text(MediaHelper.formatDuration(shown), style: timeStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
