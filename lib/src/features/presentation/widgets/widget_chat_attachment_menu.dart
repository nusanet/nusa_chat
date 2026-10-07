import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/styles/shadows.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// What the composer's "+" offers.
enum NusaChatAttachmentKind { gallery, document, location }

/// Opens the attachment menu: a white card above the
/// composer, over a dimmed chat, listing [kinds] with tinted icon discs.
/// [bottom] is the distance from the bottom of the screen to the composer's top.
Future<NusaChatAttachmentKind?> showNusaChatAttachmentMenu(
  BuildContext context, {
  required List<NusaChatAttachmentKind> kinds,
  required double bottom,
  NusaChatStrings strings = const NusaChatStrings(),
}) {
  final theme = NusaChatThemeScope.of(context);
  return showGeneralDialog<NusaChatAttachmentKind>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x52121926),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return NusaChatThemeScope(
        theme: theme,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.only(left: BaseSpacing.lg, bottom: bottom + BaseSpacing.sm),
            child: NusaChatAttachmentMenu(
              kinds: kinds,
              strings: strings,
              onSelected: (kind) => Navigator.of(dialogContext).pop(kind),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(curved),
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      );
    },
  );
}

class NusaChatAttachmentMenu extends StatelessWidget {
  final List<NusaChatAttachmentKind> kinds;
  final NusaChatStrings strings;
  final ValueChanged<NusaChatAttachmentKind> onSelected;

  const NusaChatAttachmentMenu({
    super.key,
    required this.kinds,
    required this.onSelected,
    this.strings = const NusaChatStrings(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Material(
      color: theme.composerColor,
      borderRadius: BorderRadius.circular(BaseRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: Shadows.sm),
        child: IntrinsicWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BaseSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final kind in kinds)
                  InkWell(
                    onTap: () => onSelected(kind),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        BaseSpacing.md,
                        BaseSpacing.sm,
                        BaseSpacing.xxl * 2,
                        BaseSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          _IconDisc(icon: _icon(kind), color: _color(theme, kind)),
                          const SizedBox(width: BaseSpacing.md),
                          Text(_label(kind), style: theme.agentTextStyle),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _icon(NusaChatAttachmentKind kind) => switch (kind) {
    NusaChatAttachmentKind.gallery => BaseIcons.photo,
    NusaChatAttachmentKind.document => BaseIcons.file,
    NusaChatAttachmentKind.location => BaseIcons.mapPin,
  };

  Color _color(NusaChatTheme theme, NusaChatAttachmentKind kind) => switch (kind) {
    NusaChatAttachmentKind.gallery => theme.galleryIconColor,
    NusaChatAttachmentKind.document => theme.documentIconColor,
    NusaChatAttachmentKind.location => theme.locationIconColor,
  };

  String _label(NusaChatAttachmentKind kind) => switch (kind) {
    NusaChatAttachmentKind.gallery => strings.attachGallery,
    NusaChatAttachmentKind.document => strings.attachDocument,
    NusaChatAttachmentKind.location => strings.attachLocation,
  };
}

class _IconDisc extends StatelessWidget {
  final String icon;
  final Color color;

  const _IconDisc({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: WidgetSvgIcon(icon, size: 18, color: color),
    );
  }
}
