import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/image_edit.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_editor.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

enum NusaChatDrawTool { pencil, text, arrow }

/// Draws, writes and points at things on a photo, in one of the
/// [NusaChatTheme.editorColors]. Pops with the edited photo, or null.
class NusaChatDrawPage extends StatefulWidget {
  final ChatAttachment attachment;
  final NusaChatStrings strings;

  /// "1 / 2" when the photo is one of several.
  final String? pager;

  const NusaChatDrawPage({super.key, required this.attachment, this.strings = const NusaChatStrings(), this.pager});

  /// Line width and text size on screen; saved relative to the photo's width.
  static const strokeWidth = 4.0;
  static const fontSize = 20.0;

  @override
  State<NusaChatDrawPage> createState() => _NusaChatDrawPageState();
}

class _NusaChatDrawPageState extends State<NusaChatDrawPage> {
  ui.Image? _image;
  final _marks = <NusaChatMark>[];
  var _tool = NusaChatDrawTool.pencil;
  Color? _color;
  var _saving = false;

  /// The text mark being typed, by index in [_marks]. It is typed over the
  /// dimmed photo, then put back where it was placed.
  int? _editing;

  /// The photo's width on screen, so the text being typed has its final size.
  double _canvasWidth = 0;
  final _text = TextEditingController();
  final _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _textFocus.addListener(() {
      if (!_textFocus.hasFocus) _commitText();
    });
    NusaChatImageEdit.decode(widget.attachment.path).then(
      (image) {
        if (mounted) {
          setState(() => _image = image);
        } else {
          image.dispose();
        }
      },
      onError: (_) {
        if (mounted) _fail();
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Color _currentColor(NusaChatTheme theme) => _color ?? theme.editorColors[2 % theme.editorColors.length];

  void _selectColor(Color color) {
    setState(() {
      _color = color;
      final editing = _editing;
      if (editing != null) _marks[editing] = (_marks[editing] as NusaChatTextMark).copyWith(color: color);
    });
  }

  void _selectTool(NusaChatDrawTool tool) {
    _commitText();
    setState(() => _tool = tool);
  }

  /// Ends typing; an empty text is dropped.
  void _commitText() {
    final editing = _editing;
    if (editing == null) return;
    setState(() {
      final text = _text.text.trim();
      final mark = _marks[editing] as NusaChatTextMark;
      if (text.isEmpty) {
        _marks.removeAt(editing);
      } else {
        _marks[editing] = mark.copyWith(text: text);
      }
      _editing = null;
    });
    _textFocus.unfocus();
  }

  void _editText(int index) {
    _commitText();
    // Committing may drop an empty text before this one.
    if (index >= _marks.length || _marks[index] is! NusaChatTextMark) return;
    setState(() {
      _tool = NusaChatDrawTool.text;
      _editing = index;
      _text.text = (_marks[index] as NusaChatTextMark).text;
    });
    _textFocus.requestFocus();
  }

  void _addText(Offset at, Size size, Color color) {
    _commitText();
    _marks.add(
      NusaChatTextMark(
        color: color,
        text: '',
        position: Offset(at.dx / size.width, at.dy / size.height),
        fontSize: NusaChatDrawPage.fontSize / size.width,
      ),
    );
    _editText(_marks.length - 1);
  }

  void _undo() {
    if (_editing != null) {
      _text.clear();
      _commitText();
      return;
    }
    if (_marks.isNotEmpty) setState(_marks.removeLast);
  }

  Future<void> _save() async {
    _commitText();
    final image = _image;
    if (image == null || _saving) return;
    if (_marks.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final drawn = await NusaChatImageEdit.draw(image, _marks);
      final saved = await NusaChatImageEdit.save(drawn, widget.attachment);
      drawn.dispose();
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _fail();
      }
    }
  }

  void _fail() {
    showNusaChatSnackBar(context, widget.strings.editFailed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final strings = widget.strings;
    final color = _currentColor(theme);
    final canUndo = _marks.isNotEmpty;
    return Scaffold(
      backgroundColor: theme.previewBackgroundColor,
      // The keyboard covers the tools instead of squeezing the photo.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                NusaChatEditorBar(
                  cancelLabel: strings.cancel,
                  onCancel: () => Navigator.of(context).pop(),
                  actions: [
                    NusaChatEditorTextButton(
                      label: strings.undo,
                      muted: true,
                      icon: Builder(
                        builder: (context) =>
                            WidgetSvgIcon(BaseIcons.undo, size: 16, color: IconTheme.of(context).color),
                      ),
                      onTap: canUndo ? _undo : null,
                    ),
                    NusaChatEditorTextButton(label: strings.save, onTap: _image == null || _saving ? null : _save),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(BaseSpacing.lg),
                    child: _image == null || _saving
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : LayoutBuilder(builder: (context, constraints) => _buildCanvas(constraints.biggest, color)),
                  ),
                ),
                _buildSwatches(theme, color),
                Padding(
                  padding: const EdgeInsets.fromLTRB(BaseSpacing.lg, BaseSpacing.md, BaseSpacing.lg, BaseSpacing.lg),
                  child: Row(
                    children: [
                      for (final tool in NusaChatDrawTool.values) ...[
                        NusaChatEditorChip(
                          label: switch (tool) {
                            NusaChatDrawTool.pencil => strings.editPencil,
                            NusaChatDrawTool.text => strings.editText,
                            NusaChatDrawTool.arrow => strings.editArrow,
                          },
                          selected: _tool == tool,
                          onTap: () => _selectTool(tool),
                        ),
                        const SizedBox(width: BaseSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_editing != null) _buildTextOverlay(theme, color),
        ],
      ),
    );
  }

  Widget _buildSwatches(NusaChatTheme theme, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg),
      child: Row(
        children: [
          for (final swatch in theme.editorColors) ...[
            _Swatch(color: swatch, selected: swatch == color, onTap: () => _selectColor(swatch)),
            const SizedBox(width: BaseSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// Typing a text: the field over the dimmed photo, the colours just above
  /// the keyboard, "Selesai" (or a tap outside) to place it.
  Widget _buildTextOverlay(NusaChatTheme theme, Color color) {
    final mark = _marks[_editing!] as NusaChatTextMark;
    final style = mark.style(_canvasWidth);
    final media = MediaQuery.of(context);
    final bottom = media.viewInsets.bottom > 0 ? media.viewInsets.bottom : media.viewPadding.bottom;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _commitText,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Padding(
            padding: EdgeInsets.only(top: media.viewPadding.top, bottom: bottom + BaseSpacing.md),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: BaseSpacing.sm),
                      child: NusaChatEditorTextButton(label: widget.strings.done, onTap: _commitText),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.xxl),
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: _text,
                          focusNode: _textFocus,
                          style: style,
                          textAlign: TextAlign.center,
                          cursorColor: mark.color,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: widget.strings.editTextHint,
                            hintStyle: style.copyWith(color: Colors.white.withValues(alpha: 0.7), shadows: const []),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildSwatches(theme, color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(Size area, Color color) {
    final image = _image!;
    final aspect = image.width / image.height;
    final fitted = area.width / area.height > aspect
        ? Size(area.height * aspect, area.height)
        : Size(area.width, area.width / aspect);
    final rect = Alignment.center.inscribe(fitted, Offset.zero & area);
    final size = rect.size;
    _canvasWidth = size.width;
    Offset fraction(Offset local) =>
        Offset((local.dx / size.width).clamp(0.0, 1.0), (local.dy / size.height).clamp(0.0, 1.0));

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BaseRadius.md),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RawImage(image: image, fit: BoxFit.fill),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (details) {
                      switch (_tool) {
                        case NusaChatDrawTool.text:
                          if (_editing != null) {
                            _commitText();
                          } else {
                            _addText(details.localPosition, size, color);
                          }
                        case NusaChatDrawTool.pencil:
                          setState(
                            () => _marks.add(
                              NusaChatStrokeMark(
                                color: color,
                                points: [fraction(details.localPosition)],
                                width: NusaChatDrawPage.strokeWidth / size.width,
                              ),
                            ),
                          );
                        case NusaChatDrawTool.arrow:
                          break;
                      }
                    },
                    onPanStart: (details) {
                      if (_tool == NusaChatDrawTool.text) return;
                      final point = fraction(details.localPosition);
                      final width = NusaChatDrawPage.strokeWidth / size.width;
                      setState(
                        () => _marks.add(
                          _tool == NusaChatDrawTool.pencil
                              ? NusaChatStrokeMark(color: color, points: [point], width: width)
                              : NusaChatArrowMark(color: color, from: point, to: point, width: width),
                        ),
                      );
                    },
                    onPanUpdate: (details) {
                      if (_tool == NusaChatDrawTool.text || _marks.isEmpty) return;
                      final point = fraction(details.localPosition);
                      setState(() {
                        switch (_marks.last) {
                          case final NusaChatStrokeMark stroke:
                            stroke.points.add(point);
                          case final NusaChatArrowMark arrow:
                            _marks.last = arrow.copyWith(to: point);
                          case NusaChatTextMark():
                            break;
                        }
                      });
                    },
                    child: CustomPaint(painter: NusaChatMarksPainter(_marks, withText: false), size: size),
                  ),
                ),
                for (var i = 0; i < _marks.length; i++)
                  if (_marks[i] case final NusaChatTextMark mark when i != _editing)
                    Positioned(
                      // Shifted by the touch margin, so the letters sit at [mark.position].
                      left: mark.position.dx * size.width - _textTouchMargin,
                      top: mark.position.dy * size.height - _textTouchMargin,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * (1 - mark.position.dx) + 2 * _textTouchMargin,
                        ),
                        child: _buildText(i, mark, size),
                      ),
                    ),
              ],
            ),
          ),
        ),
        if (widget.pager != null)
          Positioned(
            left: rect.left + BaseSpacing.md,
            top: rect.top + BaseSpacing.md,
            child: NusaChatPagerBadge(widget.pager!),
          ),
      ],
    );
  }

  /// Extra room around a placed text that still grabs it.
  static const _textTouchMargin = 12.0;

  /// A placed text: tap to change it, drag to move it.
  Widget _buildText(int index, NusaChatTextMark mark, Size size) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Counts from the touch, so the text stays under the finger.
      dragStartBehavior: DragStartBehavior.down,
      onTap: () => _editText(index),
      onPanUpdate: (details) => setState(() {
        final current = _marks[index] as NusaChatTextMark;
        final moved = current.position + Offset(details.delta.dx / size.width, details.delta.dy / size.height);
        _marks[index] = current.copyWith(position: Offset(moved.dx.clamp(0.0, 0.95), moved.dy.clamp(0.0, 0.95)));
      }),
      child: Padding(
        padding: const EdgeInsets.all(_textTouchMargin),
        child: Text(mark.text, style: mark.style(size.width)),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox.square(
        dimension: 26,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: selected ? 26 : 22,
            height: selected ? 26 : 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                width: selected ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
