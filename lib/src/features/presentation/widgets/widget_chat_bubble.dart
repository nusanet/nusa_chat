import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// A message bubble. The visitor's
/// own messages are `blue/800` with white text and a squared bottom-right
/// corner; the agent's are white with `Shadow/xs` and a squared bottom-left
/// corner. 12/12/8/12 padding, Body 2 message, Body 4 time at 75%.
///
/// With [media] the bubble takes its full
/// width, the media sits 4px from the edge and [text] becomes its caption.
class NusaChatBubble extends StatelessWidget {
  final String text;

  /// An image, document card, voice note or location shown above [text].
  final Widget? media;
  final String time;
  final bool isMine;

  /// Delivery state, shown next to the time on [isMine] bubbles.
  final ChatMessageStatus? status;

  /// Tapping a failed bubble retries it.
  final VoidCallback? onTap;

  const NusaChatBubble({
    super.key,
    required this.text,
    required this.time,
    this.media,
    this.isMine = false,
    this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final textStyle = isMine ? theme.myTextStyle : theme.agentTextStyle;
    final timeStyle = isMine ? theme.myTimeStyle : theme.agentTimeStyle;
    final radius = Radius.circular(theme.bubbleRadius);
    final tail = Radius.circular(theme.bubbleTailRadius);

    final hasText = text.trim().isNotEmpty;
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: timeStyle),
        if (isMine && status != null) ...[
          const SizedBox(width: BaseSpacing.xs),
          _StatusIcon(status: status!, color: theme.myStatusColor, errorColor: theme.errorColor),
        ],
      ],
    );

    final Widget content;
    if (media == null) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(BaseSpacing.md, BaseSpacing.md, BaseSpacing.md, BaseSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(text, style: textStyle),
            ),
            const SizedBox(height: BaseSpacing.xs),
            meta,
          ],
        ),
      );
    } else {
      content = SizedBox(
        width: theme.bubbleMaxWidth,
        child: Padding(
          padding: const EdgeInsets.all(BaseSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              media!,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  BaseSpacing.sm,
                  hasText ? BaseSpacing.sm : BaseSpacing.xs,
                  BaseSpacing.sm,
                  BaseSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasText) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(text, style: textStyle),
                      ),
                      const SizedBox(height: BaseSpacing.xs),
                    ],
                    meta,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: theme.bubbleMaxWidth),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMine ? theme.myBubbleColor : theme.agentBubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: isMine ? radius : tail,
          bottomRight: isMine ? tail : radius,
        ),
        boxShadow: isMine ? null : theme.agentBubbleShadow,
      ),
      child: content,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: onTap == null ? bubble : GestureDetector(onTap: onTap, child: bubble),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final ChatMessageStatus status;
  final Color color;
  final Color errorColor;

  const _StatusIcon({required this.status, required this.color, required this.errorColor});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ChatMessageStatus.pending => WidgetSvgIcon(BaseIcons.clock, size: 14, color: color),
      ChatMessageStatus.sent => WidgetSvgIcon(BaseIcons.checks, size: 16, color: color),
      ChatMessageStatus.failed => WidgetSvgIcon(BaseIcons.alertCircle, size: 16, color: errorColor),
    };
  }
}
