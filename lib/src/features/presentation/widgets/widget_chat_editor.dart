import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/colors.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/core/util/styles/typography.dart';

/// The top bar of the crop and edit screens: "Batal" (and a title) on the
/// left, actions on the right.
class NusaChatEditorBar extends StatelessWidget {
  final String cancelLabel;
  final VoidCallback onCancel;
  final String? title;
  final List<Widget> actions;

  const NusaChatEditorBar({
    super.key,
    required this.cancelLabel,
    required this.onCancel,
    this.title,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.sm),
        child: Row(
          children: [
            NusaChatEditorTextButton(label: cancelLabel, onTap: onCancel, muted: true),
            if (title != null) Text(title!, style: theme.previewTextStyle),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// A text action of [NusaChatEditorBar]; muted for "Batal" and while disabled.
class NusaChatEditorTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  final Widget? icon;

  const NusaChatEditorTextButton({super.key, required this.label, required this.onTap, this.muted = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final color = muted || onTap == null ? BaseColor.textDisabled : BaseColor.textInverse;
    final style = theme.previewTextStyle.copyWith(
      color: color,
      fontWeight: muted || onTap == null ? FontWeight.w400 : FontWeight.w600,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BaseRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.sm, vertical: BaseSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: color),
                child: icon!,
              ),
              const SizedBox(width: BaseSpacing.xs),
            ],
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

/// The pill chips under the crop and edit screens: white when active.
class NusaChatEditorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NusaChatEditorChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? BaseColor.surfaceDefault : theme.previewSurfaceColor,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg, vertical: 6),
            child: Text(
              label,
              style: BaseTypography.p3Medium.withColor(selected ? BasePalette.neutral900 : BaseColor.textInverse),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "1 / 2" badge in the image's corner.
class NusaChatPagerBadge extends StatelessWidget {
  final String text;

  const NusaChatPagerBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.previewBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BaseRadius.fullAll,
      ),
      child: Text(text, style: theme.previewTextStyle.copyWith(fontSize: 10)),
    );
  }
}
