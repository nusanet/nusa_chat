import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_icon_button.dart';

/// The chat header: a
/// `surface/brand` bar behind the status bar, a round back button, the
/// centred Body 1 SemiBold title and round actions. Under the status bar it
/// is 12px gap + a 44px row + 16px bottom padding, with the 24px page margin.
class NusaChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Replaces the title text entirely.
  final Widget? titleWidget;

  /// Replaces the default back button. Pass [SizedBox.shrink] to hide it.
  final Widget? leading;

  /// Called by the default back button; `Navigator.maybePop` when null.
  final VoidCallback? onBack;

  /// Trailing widgets, ideally [NusaChatIconButton]s, 8px apart.
  final List<Widget> actions;

  final Color? backgroundColor;

  const NusaChatAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.onBack,
    this.actions = const [],
    this.backgroundColor,
  });

  static const _topGap = BaseSpacing.md;
  static const _rowHeight = 44.0;
  static const _bottomPadding = BaseSpacing.lg;

  @override
  Size get preferredSize => const Size.fromHeight(_topGap + _rowHeight + _bottomPadding);

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final background = backgroundColor ?? theme.appBarColor;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    final leadingWidget =
        leading ??
        (onBack != null || canPop
            ? NusaChatIconButton(
                svgAsset: BaseIcons.arrowLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : const SizedBox.shrink());

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: BaseSpacing.sm), actions[i]],
      ],
    );

    final brightness = ThemeData.estimateBrightnessForColor(background);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Material(
        color: background,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(BaseSpacing.pageMargin, _topGap, BaseSpacing.pageMargin, _bottomPadding),
            child: SizedBox(
              height: _rowHeight,
              child: NavigationToolbar(
                leading: leadingWidget,
                middle: DefaultTextStyle(
                  style: theme.appBarTitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Semantics(header: true, child: titleWidget ?? Text(title)),
                ),
                trailing: trailing,
                middleSpacing: BaseSpacing.sm,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
