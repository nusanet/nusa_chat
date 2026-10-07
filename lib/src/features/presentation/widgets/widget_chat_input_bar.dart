import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_send_button.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// A voice note being recorded.
class NusaChatRecording {
  final Duration elapsed;
  final String label;

  /// Stops and throws the recording away.
  final VoidCallback cancel;

  /// Stops and sends the recording.
  final VoidCallback send;

  const NusaChatRecording({required this.elapsed, required this.label, required this.cancel, required this.send});
}

/// What a custom composer gets from the chat page.
class NusaChatComposer {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  /// Sends the controller's text and clears it.
  final VoidCallback send;

  /// Whether there is text to send.
  final bool canSend;

  /// Opens the attachment menu; null hides the "+" button.
  final VoidCallback? onAttach;

  /// Opens the in-app camera; null hides the camera button.
  final VoidCallback? onCamera;

  /// Starts a voice note; null keeps the send button when the field is empty.
  final VoidCallback? onRecord;

  /// Set while a voice note records; the bar then shows the recording.
  final NusaChatRecording? recording;

  /// Toggles the emoji panel; null hides the emoji button.
  final VoidCallback? onEmoji;

  /// The emoji panel is showing in the keyboard's place; the emoji button
  /// then shows a keyboard.
  final bool emojiPanelOpen;

  const NusaChatComposer({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.send,
    required this.canSend,
    this.onAttach,
    this.onCamera,
    this.onRecord,
    this.recording,
    this.onEmoji,
    this.emojiPanelOpen = false,
  });
}

/// The composer: a white bar, 12/16 padding, 8px gap,
/// holding a 44px pill field (`neutral/50`, 1px border — `neutral/200` at
/// rest, `blue/600` while focused or typing) and the round send button.
///
/// Around the field: "+" for the attachment menu, the camera, and the voice
/// button in the send button's place while the field is empty. Inside it, the
/// emoji button opens the emoji panel and turns into a keyboard button while
/// the panel shows.
class NusaChatInputBar extends StatelessWidget {
  final NusaChatComposer composer;

  /// Replaces the default [NusaChatSendButton].
  final Widget Function(BuildContext context, VoidCallback? onSend)? sendButtonBuilder;

  const NusaChatInputBar({super.key, required this.composer, this.sendButtonBuilder});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final onSend = composer.canSend ? composer.send : null;

    // The whole bar counts as "inside" the field, so tapping send keeps the
    // keyboard up; a tap anywhere else dismisses it (see onTapOutside).
    return TextFieldTapRegion(
      child: Material(
        color: theme.composerColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg, vertical: BaseSpacing.md),
            child: composer.recording != null
                ? _RecordingRow(recording: composer.recording!, sendButtonBuilder: sendButtonBuilder)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (composer.onAttach != null) ...[
                        _BarIconButton(icon: BaseIcons.plus, tooltip: 'Lampiran', onTap: composer.onAttach!),
                        const SizedBox(width: BaseSpacing.sm),
                      ],
                      Expanded(child: _Field(composer: composer)),
                      if (composer.onCamera != null && !composer.canSend) ...[
                        const SizedBox(width: BaseSpacing.sm),
                        _BarIconButton(icon: BaseIcons.camera, tooltip: 'Kamera', onTap: composer.onCamera!),
                      ],
                      const SizedBox(width: BaseSpacing.sm),
                      if (composer.onRecord != null && !composer.canSend)
                        NusaChatSendButton(
                          onPressed: composer.onRecord,
                          icon: BaseIcons.microphone,
                          semanticLabel: 'Rekam pesan suara',
                        )
                      else
                        sendButtonBuilder?.call(context, onSend) ?? NusaChatSendButton(onPressed: onSend),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A 24px brand-blue icon in a 44px target, bottom-aligned with the field.
class _BarIconButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BarIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return SizedBox.square(
      dimension: 44,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: WidgetSvgIcon(icon, size: 24, color: theme.primaryColor),
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  final NusaChatRecording recording;
  final Widget Function(BuildContext context, VoidCallback? onSend)? sendButtonBuilder;

  const _RecordingRow({required this.recording, this.sendButtonBuilder});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            tooltip: 'Batal',
            padding: EdgeInsets.zero,
            onPressed: recording.cancel,
            icon: WidgetSvgIcon(BaseIcons.trash, size: 24, color: theme.errorColor),
          ),
        ),
        const SizedBox(width: BaseSpacing.sm),
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md),
            decoration: BoxDecoration(
              color: theme.inputFillColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.inputFocusedBorderColor),
            ),
            child: Row(
              children: [
                _BlinkingDot(color: theme.recordingColor),
                const SizedBox(width: BaseSpacing.sm),
                Text(MediaHelper.formatDuration(recording.elapsed), style: theme.inputTextStyle),
                const SizedBox(width: BaseSpacing.sm),
                Expanded(
                  child: Text(recording.label, style: theme.inputHintStyle, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: BaseSpacing.sm),
        sendButtonBuilder?.call(context, recording.send) ?? NusaChatSendButton(onPressed: recording.send),
      ],
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.2).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final NusaChatComposer composer;

  const _Field({required this.composer});

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  @override
  void initState() {
    super.initState();
    widget.composer.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _Field oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composer.focusNode != widget.composer.focusNode) {
      oldWidget.composer.focusNode.removeListener(_onFocusChanged);
      widget.composer.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.composer.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final composer = widget.composer;
    final active = composer.focusNode.hasFocus || composer.canSend || composer.emojiPanelOpen;
    final onEmoji = composer.onEmoji;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.only(left: onEmoji == null ? BaseSpacing.md : BaseSpacing.xs, right: BaseSpacing.md),
      decoration: BoxDecoration(
        color: theme.inputFillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: active ? theme.inputFocusedBorderColor : theme.inputBorderColor),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onEmoji != null)
            // 36×42 target bottom-aligned, so it stays by the last line.
            SizedBox(
              width: 36,
              height: 42,
              child: IconButton(
                tooltip: composer.emojiPanelOpen ? 'Keyboard' : 'Emoji',
                padding: EdgeInsets.zero,
                onPressed: onEmoji,
                icon: WidgetSvgIcon(
                  composer.emojiPanelOpen ? BaseIcons.keyboard : BaseIcons.moodSmile,
                  size: 20,
                  color: composer.emojiPanelOpen ? theme.primaryColor : theme.inputHintStyle.color,
                ),
              ),
            ),
          Expanded(child: _buildTextField(theme, composer)),
        ],
      ),
    );
  }

  Widget _buildTextField(NusaChatTheme theme, NusaChatComposer composer) {
    return TextField(
      controller: composer.controller,
      focusNode: composer.focusNode,
      minLines: 1,
      maxLines: 5,
      maxLength: 4096,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      onTapOutside: (_) => composer.focusNode.unfocus(),
      style: theme.inputTextStyle,
      cursorColor: theme.cursorColor,
      decoration: InputDecoration(
        isCollapsed: true,
        counterText: '',
        border: InputBorder.none,
        hintText: composer.hintText,
        hintStyle: theme.inputHintStyle,
        contentPadding: const EdgeInsets.symmetric(vertical: BaseSpacing.md),
      ),
    );
  }
}
