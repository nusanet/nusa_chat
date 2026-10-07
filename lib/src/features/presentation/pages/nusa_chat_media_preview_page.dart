import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_crop_page.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_draw_page.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_send_button.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// Picks more attachments for the preview's "+" tile; empty when cancelled.
typedef NusaChatAttachmentAdder = Future<List<ChatAttachment>> Function(int remaining);

/// The pre-send preview: a
/// `neutral/900` screen titled "Kirim ke NusaSelecta" with the current item,
/// a row of thumbnails with add and delete, and a caption field per item.
/// A photo can be cropped and drawn on first (top-right buttons).
///
/// Pops with the attachments to send (captions filled in), or null.
class NusaChatMediaPreviewPage extends StatefulWidget {
  final List<ChatAttachment> attachments;
  final NusaChatStrings strings;

  /// Shows the "+" tile while fewer than [maxCount] items are picked.
  final NusaChatAttachmentAdder? onAdd;
  final int maxCount;

  const NusaChatMediaPreviewPage({
    super.key,
    required this.attachments,
    this.strings = const NusaChatStrings(),
    this.onAdd,
    this.maxCount = 10,
  });

  @override
  State<NusaChatMediaPreviewPage> createState() => _NusaChatMediaPreviewPageState();
}

class _NusaChatMediaPreviewPageState extends State<NusaChatMediaPreviewPage> {
  late final List<ChatAttachment> _items = [...widget.attachments];
  final _pageController = PageController();
  final _captionController = TextEditingController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _captionController.text = _items.isEmpty ? '' : _items.first.caption;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _saveCaption() {
    if (_index < _items.length) _items[_index] = _items[_index].copyWith(caption: _captionController.text.trim());
  }

  void _select(int index, {bool animate = true}) {
    _saveCaption();
    setState(() => _index = index);
    _captionController.text = _items[index].caption;
    if (_pageController.hasClients) {
      if (animate) {
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _pageController.jumpToPage(index);
      }
    }
  }

  void _delete() {
    if (_items.isEmpty) return;
    setState(() => _items.removeAt(_index));
    if (_items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _index = _index.clamp(0, _items.length - 1);
    _captionController.text = _items[_index].caption;
    if (_pageController.hasClients) _pageController.jumpToPage(_index);
  }

  Future<void> _add() async {
    final onAdd = widget.onAdd;
    if (onAdd == null) return;
    _saveCaption();
    final added = await onAdd(widget.maxCount - _items.length);
    if (!mounted || added.isEmpty) return;
    setState(() => _items.addAll(added.take(widget.maxCount - _items.length)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _select(_items.length - 1, animate: false);
    });
  }

  String? _pagerOf(int index) => _items.length > 1 ? '${index + 1} / ${_items.length}' : null;

  /// Opens the crop or edit screen on the current photo; its result replaces it.
  Future<void> _edit(Widget Function(ChatAttachment attachment, String? pager) page) async {
    _saveCaption();
    final index = _index;
    final theme = NusaChatThemeScope.of(context);
    final edited = await Navigator.of(context).push<ChatAttachment>(
      MaterialPageRoute(
        builder: (_) => NusaChatThemeScope(theme: theme, child: page(_items[index], _pagerOf(index))),
      ),
    );
    if (!mounted || edited == null || index >= _items.length) return;
    setState(() => _items[index] = edited.copyWith(caption: _items[index].caption));
  }

  void _send() {
    _saveCaption();
    Navigator.of(context).pop(List<ChatAttachment>.unmodifiable(_items));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final canAdd = widget.onAdd != null && _items.length < widget.maxCount;
    return Scaffold(
      backgroundColor: theme.previewBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(BaseSpacing.lg, BaseSpacing.md, BaseSpacing.lg, BaseSpacing.md),
              child: Row(
                children: [
                  _DarkRoundButton(
                    icon: BaseIcons.close,
                    tooltip: widget.strings.cancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: BaseSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.strings.previewTitle,
                      style: theme.previewTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_items.isNotEmpty && _items[_index].type == ChatMessageType.image) ...[
                    _DarkRoundButton(
                      icon: BaseIcons.crop,
                      tooltip: widget.strings.cropTitle,
                      size: 32,
                      onTap: () => _edit(
                        (attachment, pager) =>
                            NusaChatCropPage(attachment: attachment, strings: widget.strings, pager: pager),
                      ),
                    ),
                    const SizedBox(width: BaseSpacing.sm),
                    _DarkRoundButton(
                      icon: BaseIcons.pencil,
                      tooltip: widget.strings.editTitle,
                      size: 32,
                      onTap: () => _edit(
                        (attachment, pager) =>
                            NusaChatDrawPage(attachment: attachment, strings: widget.strings, pager: pager),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
                  if (index != _index) _select(index, animate: false);
                },
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg, vertical: BaseSpacing.xl),
                  child: _PreviewItem(attachment: _items[index], pager: _pagerOf(index)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BaseSpacing.lg, 0, BaseSpacing.lg, BaseSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < _items.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: BaseSpacing.sm),
                              child: _Thumbnail(attachment: _items[i], selected: i == _index, onTap: () => _select(i)),
                            ),
                          if (canAdd) _AddTile(onTap: _add),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: BaseSpacing.sm),
                  _DarkRoundButton(icon: BaseIcons.trash, tooltip: 'Hapus', onTap: _delete),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(BaseSpacing.lg, 0, BaseSpacing.lg, BaseSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.previewSurfaceColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _captionController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1024,
                        textCapitalization: TextCapitalization.sentences,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        style: theme.inputTextStyle.copyWith(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          counterText: '',
                          border: InputBorder.none,
                          hintText: widget.strings.captionHint,
                          hintStyle: theme.inputHintStyle,
                          contentPadding: const EdgeInsets.symmetric(vertical: BaseSpacing.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: BaseSpacing.sm),
                  NusaChatSendButton(onPressed: _items.isEmpty ? null : _send, semanticLabel: widget.strings.send),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final ChatAttachment attachment;
  final String? pager;

  const _PreviewItem({required this.attachment, this.pager});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final Widget content;
    if (attachment.type == ChatMessageType.image) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(BaseRadius.md),
        child: Image.file(File(attachment.path), fit: BoxFit.contain),
      );
    } else {
      final extension = (MediaHelper.extensionOf(attachment.fileName) ?? '').toUpperCase();
      content = Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BaseSpacing.xl),
          decoration: BoxDecoration(
            color: theme.previewSurfaceColor,
            borderRadius: BorderRadius.circular(BaseRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FileTile(extension: extension, size: 72),
              const SizedBox(height: BaseSpacing.lg),
              Text(
                attachment.fileName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.previewTextStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: BaseSpacing.xs),
              Text(
                [if (extension.isNotEmpty) extension, MediaHelper.formatSize(attachment.size)].join(' · '),
                style: theme.previewTextStyle.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (pager != null)
          Positioned(
            top: BaseSpacing.md,
            left: BaseSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: theme.previewBackgroundColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(BaseRadius.full),
              ),
              child: Text(pager!, style: theme.previewTextStyle.copyWith(fontSize: 10)),
            ),
          ),
      ],
    );
  }
}

/// A white file tile with the red extension label.
class _FileTile extends StatelessWidget {
  final String extension;
  final double size;

  const _FileTile({required this.extension, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(BaseRadius.sm)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WidgetSvgIcon(BaseIcons.file, size: size * 0.4, color: theme.errorColor),
          if (extension.isNotEmpty && size >= 48)
            Text(
              extension,
              style: theme.previewTextStyle.copyWith(
                color: theme.errorColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ChatAttachment attachment;
  final bool selected;
  final VoidCallback onTap;

  const _Thumbnail({required this.attachment, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BaseRadius.md),
          border: Border.all(color: selected ? theme.primaryColor : Colors.transparent, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BaseRadius.sm),
          child: attachment.type == ChatMessageType.image
              ? Image.file(File(attachment.path), fit: BoxFit.cover, cacheWidth: 160)
              : _FileTile(extension: (MediaHelper.extensionOf(attachment.fileName) ?? '').toUpperCase(), size: 48),
        ),
      ),
    );
  }
}

/// The dashed "+" tile.
class _AddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tambah',
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: Colors.white.withValues(alpha: 0.5)),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Center(child: WidgetSvgIcon(BaseIcons.plus, size: 22, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(BaseRadius.md));
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 8) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

class _DarkRoundButton extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const _DarkRoundButton({required this.icon, required this.tooltip, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: theme.previewSurfaceColor,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: WidgetSvgIcon(icon, size: size / 2, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
