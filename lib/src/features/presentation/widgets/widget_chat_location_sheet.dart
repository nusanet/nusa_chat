import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/service/media_service.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_media.dart';

/// Finds the current position and asks before sending it. Pops with the
/// [ChatLocation] to send, or null. Failures pop with null after
/// [onError] is told why.
Future<ChatLocation?> showNusaChatLocationSheet(
  BuildContext context, {
  required NusaChatMediaService mediaService,
  required void Function(NusaChatMediaException error) onError,
  NusaChatStrings strings = const NusaChatStrings(),
  NusaChatGoogleMap? googleMap,
}) {
  final theme = NusaChatThemeScope.of(context);
  return showModalBottomSheet<ChatLocation>(
    context: context,
    backgroundColor: theme.composerColor,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BaseRadius.xl))),
    builder: (sheetContext) => NusaChatThemeScope(
      theme: theme,
      child: _LocationSheet(mediaService: mediaService, strings: strings, onError: onError, googleMap: googleMap),
    ),
  );
}

class _LocationSheet extends StatefulWidget {
  final NusaChatMediaService mediaService;
  final NusaChatStrings strings;
  final void Function(NusaChatMediaException error) onError;
  final NusaChatGoogleMap? googleMap;

  const _LocationSheet({required this.mediaService, required this.strings, required this.onError, this.googleMap});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  NusaChatPosition? _position;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final position = await widget.mediaService.currentPosition();
      if (mounted) setState(() => _position = position);
    } on NusaChatMediaException catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final position = _position;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(BaseSpacing.xl, 0, BaseSpacing.xl, BaseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.strings.sendLocationTitle, style: theme.appBarTitleStyle),
            const SizedBox(height: BaseSpacing.lg),
            NusaChatMapTile(
              height: 160,
              pinColor: theme.errorColor,
              background: theme.mediaPlaceholderColor,
              location: position?.location,
              googleMap: widget.googleMap,
            ),
            const SizedBox(height: BaseSpacing.md),
            if (position == null)
              Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                  ),
                  const SizedBox(width: BaseSpacing.sm),
                  Text(widget.strings.fetchingLocation, style: theme.statusTextStyle),
                ],
              )
            else ...[
              Text(
                '${position.location.latitude.toStringAsFixed(6)}, ${position.location.longitude.toStringAsFixed(6)}',
                style: theme.agentTextStyle,
              ),
              Text(
                widget.strings.locationAccuracy.replaceAll('{meters}', position.accuracy.round().toString()),
                style: theme.statusTextStyle,
              ),
            ],
            const SizedBox(height: BaseSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.primaryColor,
                      side: BorderSide(color: theme.primaryColor),
                      minimumSize: const Size.fromHeight(44),
                      textStyle: theme.agentTextStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: Text(widget.strings.cancel),
                  ),
                ),
                const SizedBox(width: BaseSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: position == null ? null : () => Navigator.of(context).pop(position.location),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      minimumSize: const Size.fromHeight(44),
                      textStyle: theme.agentTextStyle.copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: Text(widget.strings.send),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
