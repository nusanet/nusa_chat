import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The composer action: a 44px circle washed
/// `#40FF76 → #03A9F4` with a white 20px send icon. Dimmed while disabled.
/// The same disc holds the microphone while the field is empty.
class NusaChatSendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;

  /// A bundled `BaseIcons` path; the send icon by default.
  final String icon;
  final String semanticLabel;

  const NusaChatSendButton({
    super.key,
    required this.onPressed,
    this.size = 44,
    this.icon = BaseIcons.send,
    this.semanticLabel = 'Kirim',
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : theme.sendButtonDisabledOpacity,
        duration: const Duration(milliseconds: 150),
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: theme.sendButtonGradient, shape: BoxShape.circle),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                child: Center(
                  child: WidgetSvgIcon(icon, size: size * 20 / 44, color: theme.sendIconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
