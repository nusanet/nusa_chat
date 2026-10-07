import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';

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

  const NusaChatMessageRow({
    super.key,
    required this.bubble,
    required this.isMine,
    required this.avatar,
    this.senderName,
    this.showSender = true,
    this.errorText,
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
            ],
          ),
        ),
      ],
    );
  }
}
