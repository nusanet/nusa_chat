import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';

/// An agent message: avatar, sender name and bubble.
/// The visitor's own messages are a bare right-aligned bubble.
///
/// [showSender] is false for consecutive agent messages, which then keep
/// the avatar's indent without repeating it.
class NusaChatMessageRow extends StatelessWidget {
  final Widget bubble;
  final bool isMine;
  final String? senderName;
  final Widget avatar;
  final bool showSender;

  /// Shown under a failed bubble, e.g. "Gagal terkirim. Ketuk untuk kirim ulang."
  final String? errorText;

  /// Shown under an agent's bubble, e.g. [NusaChatMessageButtons].
  final Widget? footer;

  const NusaChatMessageRow({
    super.key,
    required this.bubble,
    required this.isMine,
    required this.avatar,
    this.senderName,
    this.showSender = true,
    this.errorText,
    this.footer,
  });

  static const _avatarSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    if (isMine) {
      if (errorText == null) return bubble;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          const SizedBox(height: BaseSpacing.xs),
          Text(errorText!, style: theme.statusTextStyle.copyWith(color: theme.errorColor)),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _avatarSize, child: showSender ? avatar : null),
        const SizedBox(width: BaseSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSender && senderName != null) ...[
                Text(senderName!, style: theme.agentNameStyle),
                const SizedBox(height: BaseSpacing.xs),
              ],
              bubble,
              if (footer != null) ...[const SizedBox(height: BaseSpacing.xs), footer!],
            ],
          ),
        ),
      ],
    );
  }
}

/// The reply buttons of an agent message, stacked at the bubble's maximum
/// width. Disabled, but still shown, when [onTap] is null.
class NusaChatMessageButtons extends StatelessWidget {
  final List<ChatButton> buttons;
  final ValueChanged<ChatButton>? onTap;

  const NusaChatMessageButtons({super.key, required this.buttons, this.onTap});

  static const _minHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final borderRadius = BorderRadius.circular(BaseRadius.md);
    final onTap = this.onTap;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: theme.bubbleMaxWidth),
      child: Opacity(
        opacity: onTap == null ? theme.messageButtonDisabledOpacity : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, button) in buttons.indexed) ...[
              if (index > 0) const SizedBox(height: BaseSpacing.xs),
              DecoratedBox(
                decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: theme.agentBubbleShadow),
                child: Material(
                  color: theme.messageButtonColor,
                  borderRadius: borderRadius,
                  clipBehavior: Clip.antiAlias,
                  child: Semantics(
                    button: true,
                    enabled: onTap != null,
                    child: InkWell(
                      onTap: onTap == null ? null : () => onTap(button),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: _minHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md, vertical: BaseSpacing.sm),
                          child: Center(
                            child: Text(button.title, textAlign: TextAlign.center, style: theme.messageButtonTextStyle),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
