import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';

/// Shown while the session and history load.
class NusaChatLoadingView extends StatelessWidget {
  const NusaChatLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.primaryColor),
      ),
    );
  }
}

/// Shown when the chat could not be opened.
class NusaChatErrorView extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const NusaChatErrorView({super.key, required this.message, required this.retryLabel, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BaseSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: theme.statusTextStyle),
            const SizedBox(height: BaseSpacing.lg),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: theme.primaryColor, textStyle: theme.agentNameStyle),
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the conversation has no messages yet.
class NusaChatEmptyView extends StatelessWidget {
  final String message;

  const NusaChatEmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BaseSpacing.pageMargin),
        child: Text(message, textAlign: TextAlign.center, style: theme.statusTextStyle),
      ),
    );
  }
}

/// A small pill over the top of the message list while (re)connecting.
class NusaChatConnectionBanner extends StatelessWidget {
  final String message;

  const NusaChatConnectionBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md, vertical: BaseSpacing.xs),
      decoration: BoxDecoration(
        color: theme.composerColor,
        borderRadius: BorderRadius.circular(BaseRadius.full),
        boxShadow: theme.agentBubbleShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.primaryColor)),
          const SizedBox(width: BaseSpacing.sm),
          Text(message, style: theme.statusTextStyle),
        ],
      ),
    );
  }
}

/// The day pill: between messages of different days, and floating at the
/// top while scrolling.
class NusaChatDateChip extends StatelessWidget {
  final String label;

  const NusaChatDateChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md, vertical: BaseSpacing.xs),
      decoration: BoxDecoration(
        color: theme.dateChipColor,
        borderRadius: BorderRadius.circular(BaseRadius.full),
        boxShadow: theme.agentBubbleShadow,
      ),
      child: Text(label, style: theme.dateChipTextStyle),
    );
  }
}
