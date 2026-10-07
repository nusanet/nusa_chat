import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/emoji/emoji.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The emoji panel that takes the keyboard's place:
/// 8 category tabs, "Cari emoji", the section label, an 8-column grid and a
/// floating backspace. Swipe left and right to change category.
///
/// While the search field has focus the keyboard is up, so the panel shows
/// only the field and one row of results above it ([compactHeight]).
class NusaChatEmojiPanel extends StatefulWidget {
  final ValueChanged<String> onEmoji;
  final VoidCallback onBackspace;
  final NusaChatStrings strings;

  /// Keeps "Sering Digunakan"; null keeps it for this panel only.
  final NusaChatEmojiStore? store;

  /// Total height, [bottomPadding] included. The chat page passes the
  /// keyboard's height, so swapping one for the other doesn't move the chat.
  final double height;

  /// Kept clear at the bottom (the system navigation bar).
  final double bottomPadding;

  /// Called when the search field gains or loses focus.
  final ValueChanged<bool>? onSearchingChanged;

  const NusaChatEmojiPanel({
    super.key,
    required this.onEmoji,
    required this.onBackspace,
    this.strings = const NusaChatStrings(),
    this.store,
    this.height = defaultHeight,
    this.bottomPadding = 0,
    this.onSearchingChanged,
  });

  /// Used until the keyboard has been seen.
  static const defaultHeight = 296.0;

  /// The search field and one row of results.
  static const compactHeight = BaseSpacing.sm + 36 + BaseSpacing.sm + _keyHeight + BaseSpacing.sm + BaseSpacing.sm;

  static const _keyHeight = 32.0;
  static const _rowGap = 8.0;
  static const _columns = 8;

  @override
  State<NusaChatEmojiPanel> createState() => _NusaChatEmojiPanelState();
}

class _NusaChatEmojiPanelState extends State<NusaChatEmojiPanel> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _pages = PageController();

  /// Only the tabs and the label listen, so a swipe doesn't rebuild the panel.
  final _category = ValueNotifier(NusaChatEmojiCategory.recent);

  /// Each category's emoji, built once.
  static final _catalogue = {
    for (final category in NusaChatEmojiCategory.values.skip(1))
      category: NusaChatEmojis.of(category).map((e) => e.char).toList(growable: false),
  };

  /// Shown under "Sering Digunakan". Picks are saved straight away but only
  /// shown the next time the panel opens, so keys don't move under the finger.
  List<String> _recents = NusaChatEmojis.withDefaults(const []);
  List<String> _saved = const [];

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() {});
      widget.onSearchingChanged?.call(_searchFocus.hasFocus);
    });
    _search.addListener(() => setState(() {}));
    widget.store?.load().then((saved) {
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _recents = NusaChatEmojis.withDefaults(saved);
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _pages.dispose();
    _category.dispose();
    super.dispose();
  }

  void _pick(String emoji) {
    widget.onEmoji(emoji);
    _saved = [emoji, ..._saved.where((e) => e != emoji)].take(NusaChatEmojis.recentLimit).toList();
    widget.store?.save(_saved);
  }

  /// A tab tap: slide to a neighbour, jump further away.
  void _select(NusaChatEmojiCategory category) {
    if (!_pages.hasClients) return;
    if ((category.index - _category.value.index).abs() == 1) {
      _pages.animateToPage(category.index, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(category.index);
    }
  }

  List<String> _emojisOf(NusaChatEmojiCategory category) =>
      category == NusaChatEmojiCategory.recent ? _recents : _catalogue[category]!;

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    final query = _search.text.trim();
    final results = query.isEmpty ? null : NusaChatEmojis.search(query);
    final searching = _searchFocus.hasFocus;

    final search = Padding(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md),
      child: _SearchField(controller: _search, focusNode: _searchFocus, hint: widget.strings.emojiSearchHint),
    );

    return Material(
      color: theme.emojiPanelColor,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.inputBorderColor)),
        ),
        padding: EdgeInsets.only(top: BaseSpacing.sm, bottom: searching ? 0 : widget.bottomPadding),
        // Taller than its content while the keyboard swaps in; never squeezed.
        child: searching
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: BaseSpacing.sm),
                  _ResultRow(emojis: results ?? _recents, empty: widget.strings.emojiNotFound, onPick: _pick),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _category,
                    builder: (context, category, _) =>
                        _Tabs(selected: category, strings: widget.strings, onSelect: _select),
                  ),
                  const SizedBox(height: BaseSpacing.sm),
                  search,
                  const SizedBox(height: BaseSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md),
                    child: ValueListenableBuilder(
                      valueListenable: _category,
                      builder: (context, category, _) => Text(
                        results == null ? widget.strings.emojiCategory(category) : widget.strings.emojiSearchResults,
                        style: theme.emojiSectionStyle,
                      ),
                    ),
                  ),
                  const SizedBox(height: BaseSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: results == null
                              ? PageView.builder(
                                  controller: _pages,
                                  // Lays out the neighbouring pages ahead, so their emoji are
                                  // already drawn when a swipe starts.
                                  allowImplicitScrolling: true,
                                  itemCount: NusaChatEmojiCategory.values.length,
                                  onPageChanged: (index) => _category.value = NusaChatEmojiCategory.values[index],
                                  itemBuilder: (context, index) => _Grid(
                                    key: PageStorageKey(NusaChatEmojiCategory.values[index]),
                                    emojis: _emojisOf(NusaChatEmojiCategory.values[index]),
                                    onPick: _pick,
                                  ),
                                )
                              : results.isEmpty
                              ? Center(child: Text(widget.strings.emojiNotFound, style: theme.statusTextStyle))
                              : _Grid(emojis: results, onPick: _pick),
                        ),
                        Positioned(
                          right: BaseSpacing.md,
                          bottom: BaseSpacing.sm,
                          child: _BackspaceButton(label: widget.strings.emojiBackspace, onPressed: widget.onBackspace),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A 36×40 tab, a 20px icon over a 16×3 underline.
class _Tabs extends StatelessWidget {
  final NusaChatEmojiCategory selected;
  final NusaChatStrings strings;
  final ValueChanged<NusaChatEmojiCategory> onSelect;

  const _Tabs({required this.selected, required this.strings, required this.onSelect});

  static const _icons = {
    NusaChatEmojiCategory.recent: BaseIcons.clock,
    NusaChatEmojiCategory.smileys: BaseIcons.moodSmile,
    NusaChatEmojiCategory.people: BaseIcons.user,
    NusaChatEmojiCategory.animals: BaseIcons.paw,
    NusaChatEmojiCategory.food: BaseIcons.pizza,
    NusaChatEmojiCategory.activities: BaseIcons.ballFootball,
    NusaChatEmojiCategory.travel: BaseIcons.car,
    NusaChatEmojiCategory.objects: BaseIcons.bulb,
  };

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final category in NusaChatEmojiCategory.values)
            Semantics(
              button: true,
              selected: category == selected,
              label: strings.emojiCategory(category),
              excludeSemantics: true,
              child: InkResponse(
                onTap: () => onSelect(category),
                radius: 20,
                child: SizedBox(
                  width: 36,
                  height: 40,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WidgetSvgIcon(
                        _icons[category]!,
                        size: 20,
                        color: category == selected ? theme.emojiTabActiveColor : theme.emojiTabColor,
                      ),
                      const SizedBox(height: BaseSpacing.xs),
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: category == selected ? theme.primaryColor : null,
                          borderRadius: BaseRadius.fullAll,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A 36px white pill, 1px border, search icon and hint.
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  const _SearchField({required this.controller, required this.focusNode, required this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md),
      decoration: BoxDecoration(
        color: theme.composerColor,
        borderRadius: BaseRadius.fullAll,
        border: Border.all(color: focusNode.hasFocus ? theme.inputFocusedBorderColor : theme.inputBorderColor),
      ),
      child: Row(
        children: [
          WidgetSvgIcon(BaseIcons.search, size: 16, color: theme.inputHintStyle.color),
          const SizedBox(width: BaseSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 1,
              textInputAction: TextInputAction.search,
              onTapOutside: (_) => focusNode.unfocus(),
              onSubmitted: (_) => focusNode.unfocus(),
              style: theme.inputTextStyle,
              cursorColor: theme.cursorColor,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: theme.inputHintStyle,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: controller.clear,
              child: WidgetSvgIcon(BaseIcons.close, size: 16, color: theme.inputHintStyle.color),
            ),
        ],
      ),
    );
  }
}

/// 8 columns of 34×32 keys.
class _Grid extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onPick;

  const _Grid({super.key, required this.emojis, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return _KeepAlive(child: _buildGrid());
  }

  Widget _buildGrid() {
    return GridView.builder(
      // Room under the last row so the backspace never hides a key.
      padding: const EdgeInsets.fromLTRB(BaseSpacing.md, 0, BaseSpacing.md, 52),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: NusaChatEmojiPanel._columns,
        mainAxisExtent: NusaChatEmojiPanel._keyHeight,
        mainAxisSpacing: NusaChatEmojiPanel._rowGap,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) => _EmojiKey(emoji: emojis[index], onPick: onPick),
    );
  }
}

/// Keeps a swiped-away category page (and its scroll position) built.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// One row of results while the keyboard is up for search.
class _ResultRow extends StatelessWidget {
  final List<String> emojis;
  final String empty;
  final ValueChanged<String> onPick;

  const _ResultRow({required this.emojis, required this.empty, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return SizedBox(
      height: NusaChatEmojiPanel._keyHeight + BaseSpacing.sm,
      child: emojis.isEmpty
          ? Center(child: Text(empty, style: theme.statusTextStyle))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.md),
              itemCount: emojis.length,
              separatorBuilder: (_, _) => const SizedBox(width: BaseSpacing.sm),
              itemBuilder: (context, index) => SizedBox(
                width: 34,
                child: _EmojiKey(emoji: emojis[index], onPick: onPick),
              ),
            ),
    );
  }
}

class _EmojiKey extends StatelessWidget {
  final String emoji;
  final ValueChanged<String> onPick;

  const _EmojiKey({required this.emoji, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return InkResponse(
      onTap: () => onPick(emoji),
      radius: 22,
      child: Center(
        child: Text(emoji, style: theme.emojiStyle, textScaler: TextScaler.noScaling),
      ),
    );
  }
}

/// A 44×36 white pill with a 1px border. Holding it keeps
/// deleting.
class _BackspaceButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _BackspaceButton({required this.label, required this.onPressed});

  @override
  State<_BackspaceButton> createState() => _BackspaceButtonState();
}

class _BackspaceButtonState extends State<_BackspaceButton> {
  Timer? _repeat;

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: (_) {
          widget.onPressed();
          _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) => widget.onPressed());
        },
        onLongPressEnd: (_) => _stop(),
        onLongPressCancel: _stop,
        child: Material(
          color: theme.composerColor,
          shape: StadiumBorder(side: BorderSide(color: theme.inputBorderColor)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 44,
              height: 36,
              child: Center(child: WidgetSvgIcon(BaseIcons.backspace, size: 18, color: theme.statusTextStyle.color)),
            ),
          ),
        ),
      ),
    );
  }
}
