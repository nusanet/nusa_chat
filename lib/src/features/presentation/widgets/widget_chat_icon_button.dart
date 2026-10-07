import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/shadows.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The round icon button of the top bar:
/// a 30px disc of 80% white with `Shadow/sm` and a 20px brand-blue icon.
/// Same as nusa_selecta's `WidgetRoundButton`. Use it for custom app bar
/// actions so they match the back button.
class NusaChatIconButton extends StatelessWidget {
  /// A bundled icon path from `BaseIcons`, or null when [icon] is given.
  final String? svgAsset;
  final Widget? icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Icon colour; `NusaChatTheme.appBarIconColor` by default.
  final Color? color;

  /// Disc fill; `NusaChatTheme.appBarButtonColor` by default.
  final Color? background;

  const NusaChatIconButton({super.key, this.svgAsset, this.icon, this.onTap, this.tooltip, this.color, this.background})
    : assert(svgAsset != null || icon != null, 'provide either svgAsset or icon');

  static const size = 30.0;
  static const iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final iconColor = color ?? theme.appBarIconColor;
    Widget button = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: Shadows.sm),
        child: Material(
          color: background ?? theme.appBarButtonColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: iconColor, size: iconSize),
                child: SizedBox.square(
                  dimension: iconSize,
                  child: icon ?? WidgetSvgIcon(svgAsset!, size: iconSize, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip, child: button);
    return Semantics(button: true, label: tooltip, child: button);
  }
}
