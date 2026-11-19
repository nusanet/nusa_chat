import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_command.dart';

/// The slash commands that match what the visitor is typing, above the
/// composer: each row shows the command and what it does. Past
/// [NusaChatTheme.commandMaxHeight] it scrolls, with a scrollbar and a fade
/// at the bottom while more rows are below.
///
/// Styled by the `command*` fields of [NusaChatTheme]; replace it entirely
/// with `NusaChatPage.commandSuggestionsBuilder`.
class NusaChatCommandSuggestions extends StatefulWidget {
  final List<ChatCommand> commands;
  final ValueChanged<ChatCommand> onSelected;

  const NusaChatCommandSuggestions({super.key, required this.commands, required this.onSelected});

  @override
  State<NusaChatCommandSuggestions> createState() => _NusaChatCommandSuggestionsState();
}

class _NusaChatCommandSuggestionsState extends State<NusaChatCommandSuggestions> {
  final _scroll = ScrollController();

  /// Rows are hidden below the visible part.
  bool _moreBelow = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_checkMoreBelow);
    _checkAfterLayout();
  }

  @override
  void didUpdateWidget(NusaChatCommandSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commands != widget.commands) _checkAfterLayout();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _checkAfterLayout() => WidgetsBinding.instance.addPostFrameCallback((_) => _checkMoreBelow());

  void _checkMoreBelow() {
    if (!mounted || !_scroll.hasClients) return;
    final moreBelow = _scroll.position.extentAfter > 0.5;
    if (moreBelow != _moreBelow) setState(() => _moreBelow = moreBelow);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final background = theme.commandColor ?? theme.composerColor;
    final commandStyle =
        theme.commandTextStyle ?? theme.inputTextStyle.copyWith(color: theme.primaryColor, fontWeight: FontWeight.w600);
    final descriptionStyle = theme.commandDescriptionStyle ?? theme.inputHintStyle;

    // Part of the composer: tapping a row keeps the keyboard up.
    return TextFieldTapRegion(
      child: Material(
        color: background,
        shape: Border(top: BorderSide(color: theme.commandBorderColor ?? theme.inputBorderColor)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: theme.commandMaxHeight),
          child: Stack(
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _checkMoreBelow();
                  return false;
                },
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: _moreBelow || (_scroll.hasClients && _scroll.position.extentBefore > 0),
                  child: ListView.builder(
                    controller: _scroll,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: BaseSpacing.xs),
                    itemCount: widget.commands.length,
                    itemBuilder: (context, index) {
                      final command = widget.commands[index];
                      return InkWell(
                        key: ValueKey('nusa_chat.command.${command.command}'),
                        onTap: () => widget.onSelected(command),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg, vertical: BaseSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(command.command, style: commandStyle),
                              if (command.description.isNotEmpty)
                                Text(
                                  command.description,
                                  style: descriptionStyle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_moreBelow)
                Positioned(
                  key: const ValueKey('nusa_chat.command.more_below'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 32,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [background.withValues(alpha: 0), background],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
