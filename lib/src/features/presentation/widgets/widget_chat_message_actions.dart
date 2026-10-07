import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// What can be done with a long-pressed message.
enum NusaChatMessageAction { copy }

/// The actions for a long-pressed message. Pops with the chosen
/// [NusaChatMessageAction], or null when dismissed.
Future<NusaChatMessageAction?> showNusaChatMessageActions(
  BuildContext context, {
  NusaChatStrings strings = const NusaChatStrings(),
}) {
  final theme = NusaChatThemeScope.of(context);
  return showModalBottomSheet<NusaChatMessageAction>(
    context: context,
    backgroundColor: theme.composerColor,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(BaseRadius.xl))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: BaseSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: WidgetSvgIcon(BaseIcons.copy, size: 24, color: theme.inputTextStyle.color),
              title: Text(strings.copy, style: theme.inputTextStyle),
              onTap: () => Navigator.of(sheetContext).pop(NusaChatMessageAction.copy),
            ),
          ],
        ),
      ),
    ),
  );
}
