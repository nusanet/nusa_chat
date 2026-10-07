import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nusa_chat/src/config/nusa_chat_config.dart';
import 'package:nusa_chat/src/core/service/media_service.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_strings.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/date_helper.dart';
import 'package:nusa_chat/src/core/util/emoji/emoji.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/core/util/media_helper.dart';
import 'package:nusa_chat/src/core/util/styles/spacing.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_attachment.dart';
import 'package:nusa_chat/src/features/domain/entities/chat_message.dart';
import 'package:nusa_chat/src/features/presentation/bloc/chat/bloc.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_camera_page.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_image_viewer_page.dart';
import 'package:nusa_chat/src/features/presentation/pages/nusa_chat_media_preview_page.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_app_bar.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_attachment_menu.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_avatar.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_bubble.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_emoji_panel.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_icon_button.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_input_bar.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_location_sheet.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_media.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_message.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_chat_status_view.dart';
import 'package:nusa_chat/src/injection_container.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which attachments the composer offers. All are on by default; each needs
/// its platform setup in the host app (see the README).
class NusaChatAttachmentOptions {
  /// Photos from the system photo picker — no permission needed.
  final bool gallery;

  /// The in-app camera — needs the camera permission.
  final bool camera;

  /// PDF, Word and Excel files from the system file picker.
  final bool document;

  /// The current position — needs the location permission.
  final bool location;

  /// Voice notes — needs the microphone permission.
  final bool voice;

  /// Photos per send.
  final int maxImages;

  /// Google Static Maps for the location previews; null (the default)
  /// draws a placeholder map. Tapping a location opens Google Maps either way.
  final NusaChatGoogleMap? googleMap;

  const NusaChatAttachmentOptions({
    this.gallery = true,
    this.camera = true,
    this.document = true,
    this.location = true,
    this.voice = true,
    this.maxImages = 10,
    this.googleMap,
  });

  /// Text only, as before media support.
  const NusaChatAttachmentOptions.none()
    : gallery = false,
      camera = false,
      document = false,
      location = false,
      voice = false,
      maxImages = 0,
      googleMap = null;

  List<NusaChatAttachmentKind> get menuKinds => [
    if (gallery) NusaChatAttachmentKind.gallery,
    if (document) NusaChatAttachmentKind.document,
    if (location) NusaChatAttachmentKind.location,
  ];
}

/// What a custom app bar gets from the chat page.
class NusaChatAppBarData {
  final String title;
  final ChatConnectionStatus connection;

  /// Pops the chat (or calls `NusaChatPage.onBack`).
  final VoidCallback onBack;

  const NusaChatAppBarData({required this.title, required this.connection, required this.onBack});
}

/// What a custom message row gets from the chat page.
class NusaChatMessageData {
  final ChatMessage message;

  /// The bubble text — [ChatMessage.text], or a label for non-text messages.
  final String displayText;

  /// `HH:mm`.
  final String time;

  /// False for an agent message directly after another agent message.
  final bool showSender;

  /// Resends a failed message; null otherwise.
  final VoidCallback? onRetry;

  const NusaChatMessageData({
    required this.message,
    required this.displayText,
    required this.time,
    required this.showSender,
    this.onRetry,
  });
}

typedef NusaChatAppBarBuilder = PreferredSizeWidget Function(BuildContext context, NusaChatAppBarData data);
typedef NusaChatMessageBuilder = Widget Function(BuildContext context, NusaChatMessageData data, Widget defaultWidget);
typedef NusaChatBubbleBuilder = Widget Function(BuildContext context, NusaChatMessageData data);
typedef NusaChatInputBarBuilder = Widget Function(BuildContext context, NusaChatComposer composer);
typedef NusaChatSendButtonBuilder = Widget Function(BuildContext context, VoidCallback? onSend);
typedef NusaChatErrorBuilder = Widget Function(BuildContext context, String message, VoidCallback retry);
typedef NusaChatConnectionBuilder = Widget Function(BuildContext context, ChatConnectionStatus connection);

/// [label] is [NusaChatStrings.dayLabel] of [date].
typedef NusaChatDateBuilder = Widget Function(BuildContext context, DateTime date, String label);

/// The NusaChat screen: a chat with a NusaContact Socket Bridge agent —
/// text, photos, documents, locations and voice notes.
///
/// Restyle it with [theme] and [strings]; swap parts with the builders. Each builder receives
/// what the default widget would use, and [messageBuilder] also receives the
/// default widget itself, so wrapping is as easy as replacing.
class NusaChatPage extends StatefulWidget {
  final NusaChatConfig config;
  final NusaChatTheme? theme;
  final NusaChatStrings strings;

  // ---- app bar ----

  /// Replaces the whole app bar.
  final NusaChatAppBarBuilder? appBarBuilder;

  /// Replaces the back button of the default app bar.
  final Widget? leading;

  /// Called by the default back button; pops the route when null.
  final VoidCallback? onBack;

  /// Trailing buttons of the default app bar. When null, the design's
  /// report button is shown if [onReportTap] is set.
  final List<Widget>? actions;

  /// The design's top-right "message-report" button.
  final VoidCallback? onReportTap;

  // ---- components ----
  final NusaChatMessageBuilder? messageBuilder;
  final NusaChatBubbleBuilder? bubbleBuilder;
  final WidgetBuilder? agentAvatarBuilder;
  final NusaChatInputBarBuilder? inputBarBuilder;
  final NusaChatSendButtonBuilder? sendButtonBuilder;
  final WidgetBuilder? loadingBuilder;
  final NusaChatErrorBuilder? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final NusaChatConnectionBuilder? connectionBuilder;

  /// Replaces the day pill, between days and floating while scrolling.
  final NusaChatDateBuilder? dateBuilder;

  // ---- media ----
  final NusaChatAttachmentOptions attachments;

  /// Pickers, location and recorder; replace it to customise or in tests.
  final NusaChatMediaService? mediaService;

  // ---- emoji ----

  /// Shows the emoji button and its panel.
  final bool emoji;

  /// Keeps "Sering Digunakan" across chats; shared preferences by default.
  final NusaChatEmojiStore? emojiStore;

  /// Called for one-off notices (e.g. rate limited). A [SnackBar] by default.
  final void Function(BuildContext context, String message)? onNotice;

  /// For tests: drive the page with this bloc instead of building one from [config].
  @visibleForTesting
  final ChatBloc? bloc;

  const NusaChatPage({
    super.key,
    required this.config,
    this.theme,
    this.strings = const NusaChatStrings(),
    this.appBarBuilder,
    this.leading,
    this.onBack,
    this.actions,
    this.onReportTap,
    this.messageBuilder,
    this.bubbleBuilder,
    this.agentAvatarBuilder,
    this.inputBarBuilder,
    this.sendButtonBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.connectionBuilder,
    this.dateBuilder,
    this.attachments = const NusaChatAttachmentOptions(),
    this.mediaService,
    this.emoji = true,
    this.emojiStore,
    this.onNotice,
    this.bloc,
  });

  @override
  State<NusaChatPage> createState() => _NusaChatPageState();
}

class _NusaChatPageState extends State<NusaChatPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  NusaChatInjector? _injector;
  late final ChatBloc _bloc;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _composerKey = GlobalKey();

  late final NusaChatMediaService _media = widget.mediaService ?? NusaChatMediaServiceImpl();
  NusaChatVoiceRecorder? _recorder;
  Timer? _recordingTimer;
  final _recordingStartedAt = Stopwatch();

  /// Elapsed time while a voice note records; null otherwise.
  final _recordingElapsed = ValueNotifier<Duration?>(null);

  /// The picker or recorder is busy; ignores taps until it returns.
  bool _busy = false;

  /// The emoji panel is (or is becoming) the input: the composer shows the
  /// keyboard button and back closes it.
  final _emojiPanelOpen = ValueNotifier(false);
  late final NusaChatEmojiStore _emojiStore = widget.emojiStore ?? NusaChatEmojiStoreImpl();

  /// The panel is in the tree — also while the keyboard swaps in over it and
  /// while it slides away.
  bool _panelVisible = false;

  /// Slides the panel in and out when no keyboard covers the change.
  late final AnimationController _panelReveal;

  /// The day at the top of the conversation while it scrolls; null hides
  /// the floating pill.
  final _floatingDate = ValueNotifier<DateTime?>(null);
  Timer? _floatingDateTimer;

  /// Built message rows by local id, to find the one at the top on scroll.
  final _messageRows = <String, ({BuildContext context, DateTime date})>{};

  /// The keyboard was asked for while the panel shows; the panel stays under
  /// it until it is up, so the chat doesn't jump.
  bool _awaitingKeyboard = false;
  Timer? _keyboardSettle;
  Timer? _keyboardFallback;

  /// The panel's search field has focus (its keyboard is up).
  bool _emojiSearching = false;

  /// The last settled keyboard height, navigation bar included. The panel
  /// takes this height so swapping the two keeps the composer still.
  static double? _keyboardHeight;

  @override
  void initState() {
    super.initState();
    if (widget.bloc != null) {
      _bloc = widget.bloc!;
    } else {
      _injector = NusaChatInjector.init(widget.config);
      _bloc = _injector!.createChatBloc();
    }
    _bloc.add(const ChatStarted());
    _panelReveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    WidgetsBinding.instance.addObserver(this);
    // Typing again (tapping the field) brings the keyboard back instead of the panel.
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _emojiPanelOpen.value) _awaitKeyboard();
    });
  }

  @override
  void didChangeMetrics() {
    final view = View.maybeOf(context);
    if (view == null) return;
    double inset() => view.viewInsets.bottom / view.devicePixelRatio;
    if (_awaitingKeyboard && inset() >= _panelHeight(MediaQuery.viewPaddingOf(context).bottom)) {
      _finishKeyboardSwap();
    }
    // Insets change every frame while the keyboard animates; act once it rests.
    _keyboardSettle?.cancel();
    _keyboardSettle = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final settled = inset();
      // Below 150 it is a hardware keyboard's suggestion strip, not a keyboard.
      if (settled > 150) _keyboardHeight = settled;
      if (_awaitingKeyboard && settled > 0) _finishKeyboardSwap();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bloc.add(const ChatReconnectRequested());
    } else if (state == AppLifecycleState.paused) {
      _bloc.add(const ChatPaused());
      if (_recordingElapsed.value != null) _cancelRecording();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _recordingElapsed.dispose();
    _emojiPanelOpen.dispose();
    _panelReveal.dispose();
    _floatingDate.dispose();
    _floatingDateTimer?.cancel();
    _keyboardSettle?.cancel();
    _keyboardFallback?.cancel();
    _recorder?.dispose();
    if (widget.bloc == null) {
      _bloc.close().whenComplete(() => _injector?.dispose());
    }
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _bloc.add(ChatTextSubmitted(text: text));
    _controller.clear();
  }

  /// Hides the keyboard and the emoji panel.
  void _dismissInput() {
    _focusNode.unfocus();
    _closeEmojiPanel();
  }

  void _toggleEmojiPanel() {
    if (_emojiPanelOpen.value) {
      // The focus listener keeps the panel under the keyboard while it rises.
      _focusNode.requestFocus();
    } else {
      _openEmojiPanel();
    }
  }

  void _openEmojiPanel() {
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    _awaitingKeyboard = false;
    _focusNode.unfocus();
    _emojiPanelOpen.value = true;
    setState(() => _panelVisible = true);
    // Under a keyboard that slides down, the panel is simply there; otherwise it slides up.
    if (keyboardUp) {
      _panelReveal.value = 1;
    } else {
      _panelReveal.forward(from: _panelReveal.value);
    }
  }

  /// Slides the panel away (no keyboard takes its place).
  void _closeEmojiPanel() {
    if (!_panelVisible) return;
    _emojiPanelOpen.value = false;
    _awaitingKeyboard = false;
    if (_emojiSearching) FocusManager.instance.primaryFocus?.unfocus();
    _panelReveal.reverse().whenComplete(() {
      if (mounted && !_emojiPanelOpen.value && !_awaitingKeyboard) setState(() => _panelVisible = false);
    });
  }

  void _awaitKeyboard() {
    _emojiPanelOpen.value = false;
    _awaitingKeyboard = true;
    // A hardware keyboard never changes the insets.
    _keyboardFallback?.cancel();
    _keyboardFallback = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _awaitingKeyboard) _finishKeyboardSwap();
    });
  }

  void _finishKeyboardSwap() {
    _awaitingKeyboard = false;
    _keyboardFallback?.cancel();
    _panelReveal.value = 0;
    setState(() {
      _panelVisible = false;
      _emojiSearching = false;
    });
  }

  double _panelHeight(double navigationBar) {
    final height = _keyboardHeight ?? NusaChatEmojiPanel.defaultHeight + navigationBar;
    return math.max(height, 240 + navigationBar);
  }

  /// Puts [emoji] at the cursor (or over the selection), like a keyboard key.
  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
    if (text.length - (selection.end - selection.start) + emoji.length > _maxLength) return;
    _controller.value = TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, emoji),
      selection: TextSelection.collapsed(offset: selection.start + emoji.length),
    );
  }

  /// Deletes the selection, or the character (a whole emoji) before the cursor.
  void _backspace() {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
    var start = selection.start;
    if (selection.isCollapsed) {
      if (start == 0) return;
      start = text.substring(0, start).characters.skipLast(1).string.length;
    }
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, selection.end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  }

  /// The composer field's `maxLength`.
  static const _maxLength = 4096;

  void _back() {
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  NusaChatTheme get _theme => widget.theme ?? NusaChatTheme.fallback();

  /// Pushed pages are outside this page's theme scope, so they get their own.
  Future<T?> _push<T>(Widget page) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => NusaChatThemeScope(theme: _theme, child: page),
      ),
    );
  }

  /// Runs a picker once at a time; reports why it gave nothing.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await action();
    } on NusaChatMediaException catch (error) {
      _onMediaError(error);
    } on PlatformException catch (_) {
      _notice(widget.strings.fileNotSupported);
    } finally {
      _busy = false;
    }
    return null;
  }

  void _onMediaError(NusaChatMediaException error, {String? permissionMessage}) {
    final strings = widget.strings;
    _notice(switch (error.error) {
      NusaChatMediaError.permissionDenied => permissionMessage ?? strings.locationPermissionDenied,
      NusaChatMediaError.serviceDisabled => strings.locationServiceDisabled,
      NusaChatMediaError.unsupported => strings.fileNotSupported,
      NusaChatMediaError.tooLarge => strings.fileTooLarge.replaceAll(
        '{max}',
        MediaHelper.formatSize(error.maxBytes ?? MediaHelper.maxImageBytes),
      ),
      NusaChatMediaError.failed => strings.locationFailed,
    });
  }

  void _notice(String message) {
    if (mounted) _showNotice(context, message);
  }

  Future<void> _openAttachmentMenu() async {
    _dismissInput();
    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottom = box == null ? 80.0 : screenHeight - box.localToGlobal(Offset.zero).dy;
    final kind = await showNusaChatAttachmentMenu(
      context,
      kinds: widget.attachments.menuKinds,
      bottom: bottom,
      strings: widget.strings,
    );
    switch (kind) {
      case NusaChatAttachmentKind.gallery:
        await _pickGallery();
      case NusaChatAttachmentKind.document:
        await _pickDocument();
      case NusaChatAttachmentKind.location:
        await _shareLocation();
      case null:
        break;
    }
  }

  Future<void> _pickGallery() async {
    final images = await _guard(() => _media.pickImages(limit: widget.attachments.maxImages));
    if (images == null || images.isEmpty) return;
    await _preview(images, onAdd: (remaining) async => await _guard(() => _media.pickImages(limit: remaining)) ?? []);
  }

  Future<void> _pickDocument() async {
    final document = await _guard(_media.pickDocument);
    if (document == null) return;
    await _preview([document]);
  }

  Future<void> _openCamera() async {
    _dismissInput();
    final photo = await _takePhoto();
    if (photo == null) return;
    await _preview([photo], onAdd: (_) async => [?await _takePhoto()]);
  }

  Future<ChatAttachment?> _takePhoto() async {
    final path = await _push<String>(NusaChatCameraPage(strings: widget.strings));
    if (path == null) return null;
    return _guard(() => _media.imageFromPath(path));
  }

  Future<void> _preview(List<ChatAttachment> attachments, {NusaChatAttachmentAdder? onAdd}) async {
    final toSend = await _push<List<ChatAttachment>>(
      NusaChatMediaPreviewPage(
        attachments: attachments,
        strings: widget.strings,
        onAdd: onAdd,
        maxCount: attachments.first.type == ChatMessageType.image ? widget.attachments.maxImages : 1,
      ),
    );
    if (toSend == null || toSend.isEmpty) return;
    _bloc.add(ChatAttachmentsSubmitted(attachments: toSend));
  }

  Future<void> _shareLocation() async {
    final location = await showNusaChatLocationSheet(
      context,
      mediaService: _media,
      strings: widget.strings,
      onError: _onMediaError,
      googleMap: widget.attachments.googleMap,
    );
    if (location != null) _bloc.add(ChatLocationSubmitted(location: location));
  }

  Future<void> _startRecording() async {
    if (_busy || _recordingElapsed.value != null) return;
    _dismissInput();
    _busy = true;
    final recorder = _recorder ??= _media.createRecorder();
    try {
      await recorder.start();
    } on NusaChatMediaException catch (error) {
      _onMediaError(error, permissionMessage: widget.strings.microphonePermissionDenied);
      return;
    } finally {
      _busy = false;
    }
    HapticFeedback.mediumImpact();
    _recordingStartedAt
      ..reset()
      ..start();
    _recordingElapsed.value = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _recordingElapsed.value = _recordingStartedAt.elapsed;
    });
  }

  void _stopRecordingUi() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStartedAt.stop();
    _recordingElapsed.value = null;
  }

  Future<void> _cancelRecording() async {
    _stopRecordingUi();
    await _recorder?.cancel();
  }

  Future<void> _sendRecording() async {
    final elapsed = _recordingStartedAt.elapsed;
    _stopRecordingUi();
    final recorder = _recorder;
    if (recorder == null) return;
    if (elapsed < const Duration(seconds: 1)) {
      await recorder.cancel();
      _notice(widget.strings.recordingTooShort);
      return;
    }
    final voiceNote = await recorder.stop();
    if (voiceNote == null) return;
    if (voiceNote.size > MediaHelper.maxAudioBytes) {
      _onMediaError(const NusaChatMediaException(NusaChatMediaError.tooLarge, maxBytes: MediaHelper.maxAudioBytes));
      return;
    }
    _bloc.add(ChatAttachmentsSubmitted(attachments: [voiceNote]));
  }

  Future<void> _open(Uri? uri) async {
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) _notice(widget.strings.openFailed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return NusaChatThemeScope(
      theme: theme,
      child: BlocProvider.value(
        value: _bloc,
        child: BlocConsumer<ChatBloc, ChatState>(
          listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
          listener: (context, state) => _showNotice(context, state.notice!.message),
          buildWhen: (previous, current) => previous.connection != current.connection,
          builder: (context, state) {
            return ValueListenableBuilder(
              valueListenable: _emojiPanelOpen,
              builder: (context, emojiPanelOpen, _) => PopScope(
                // Back closes the emoji panel first, like it closes a keyboard.
                canPop: !emojiPanelOpen,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _closeEmojiPanel();
                },
                child: Scaffold(
                  // The bottom of the page is managed below, so the keyboard and
                  // the emoji panel can take turns without the chat jumping.
                  resizeToAvoidBottomInset: false,
                  backgroundColor: theme.backgroundColor,
                  appBar: _buildAppBar(context, state.connection),
                  body: Column(
                    children: [
                      // Tapping the conversation dismisses the keyboard, also for custom composers.
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _dismissInput,
                          child: _buildBody(),
                        ),
                      ),
                      // The keyboard area below takes the bottom inset.
                      MediaQuery.removeViewPadding(
                        context: context,
                        removeBottom: true,
                        child: MediaQuery.removePadding(
                          context: context,
                          removeBottom: true,
                          child: _buildComposer(context),
                        ),
                      ),
                      _buildKeyboardArea(context, theme),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showNotice(BuildContext context, String message) {
    final onNotice = widget.onNotice;
    if (onNotice != null) {
      onNotice(context, message);
      return;
    }
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ChatConnectionStatus connection) {
    final builder = widget.appBarBuilder;
    if (builder != null) {
      return builder(context, NusaChatAppBarData(title: widget.strings.title, connection: connection, onBack: _back));
    }
    final actions =
        widget.actions ??
        [
          if (widget.onReportTap != null)
            NusaChatIconButton(svgAsset: BaseIcons.messageReport, onTap: widget.onReportTap),
        ];
    return NusaChatAppBar(
      title: widget.strings.title,
      leading: widget.leading,
      onBack: widget.onBack,
      actions: actions,
    );
  }

  Widget _buildBody() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.messages != current.messages ||
          previous.connection != current.connection ||
          previous.errorMessage != current.errorMessage,
      builder: (context, state) {
        switch (state.status) {
          case ChatViewStatus.initial:
          case ChatViewStatus.loading:
            return widget.loadingBuilder?.call(context) ?? const NusaChatLoadingView();
          case ChatViewStatus.failure:
            final message = state.errorMessage ?? '';
            void retry() => _bloc.add(const ChatStarted());
            return widget.errorBuilder?.call(context, message, retry) ??
                NusaChatErrorView(message: message, retryLabel: widget.strings.retry, onRetry: retry);
          case ChatViewStatus.loaded:
            return Stack(
              children: [
                Positioned.fill(child: _buildMessages(context, state.messages)),
                if (state.connection != ChatConnectionStatus.connected)
                  Positioned(
                    top: BaseSpacing.sm,
                    left: 0,
                    right: 0,
                    child: Center(
                      child:
                          widget.connectionBuilder?.call(context, state.connection) ??
                          NusaChatConnectionBanner(
                            message: state.connection == ChatConnectionStatus.connecting
                                ? widget.strings.connecting
                                : widget.strings.reconnecting,
                          ),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }

  Widget _buildMessages(BuildContext context, List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? NusaChatEmptyView(message: widget.strings.emptyMessage);
    }
    // Reversed so the newest message sits at the bottom and new ones stay in view.
    final list = ListView.builder(
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: BaseSpacing.pageMargin, vertical: BaseSpacing.lg),
      itemCount: messages.length,
      itemBuilder: (context, reversedIndex) {
        final index = messages.length - 1 - reversedIndex;
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;
        final newDay =
            previous == null || !DateUtils.isSameDay(previous.createdAt.toLocal(), message.createdAt.toLocal());
        final sameSender = !newDay && previous.isMine == message.isMine;
        final row = _buildMessage(context, message, showSender: !message.isMine && !sameSender);
        return _TrackedRow(
          key: ValueKey(message.localId),
          id: message.localId,
          date: message.createdAt,
          rows: _messageRows,
          child: Padding(
            padding: EdgeInsets.only(top: previous == null ? 0 : (sameSender ? BaseSpacing.sm : BaseSpacing.lg)),
            child: newDay
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _buildDateChip(context, message.createdAt)),
                      const SizedBox(height: BaseSpacing.lg),
                      row,
                    ],
                  )
                : row,
          ),
        );
      },
    );

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null || notification.scrollDelta != 0) {
                _showFloatingDate(notification.context);
              }
              return false;
            },
            child: list,
          ),
        ),
        Positioned(
          top: BaseSpacing.sm,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: _floatingDate,
              builder: (context, date, _) => AnimatedOpacity(
                key: const ValueKey('nusa_chat.floating_date'),
                opacity: date == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: date == null ? const SizedBox.shrink() : Center(child: _buildDateChip(context, date)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(BuildContext context, DateTime date) {
    final label = widget.strings.dayLabel(date);
    return widget.dateBuilder?.call(context, date, label) ?? NusaChatDateChip(label: label);
  }

  /// Shows the day of the row at the top of the list, and hides it again
  /// a moment after scrolling stops — like WhatsApp.
  void _showFloatingDate(BuildContext? listContext) {
    final listBox = listContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.hasSize) return;
    final top = listBox.localToGlobal(Offset.zero).dy + BaseSpacing.lg;
    DateTime? date;
    var best = double.infinity;
    for (final row in _messageRows.values) {
      final box = row.context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final rowTop = box.localToGlobal(Offset.zero).dy;
      final rowBottom = rowTop + box.size.height;
      // The row covering the top edge, else the nearest one below it.
      final distance = rowBottom < top ? double.infinity : (rowTop <= top ? 0.0 : rowTop - top);
      if (distance < best) {
        best = distance;
        date = row.date;
      }
    }
    if (date == null) return;
    _floatingDate.value = date;
    _floatingDateTimer?.cancel();
    _floatingDateTimer = Timer(const Duration(milliseconds: 1200), () => _floatingDate.value = null);
  }

  Widget _buildMessage(BuildContext context, ChatMessage message, {required bool showSender}) {
    final failed = message.status == ChatMessageStatus.failed;
    final data = NusaChatMessageData(
      message: message,
      displayText: widget.strings.displayText(message),
      time: DateHelper.formatTime(message.createdAt),
      showSender: showSender,
      onRetry: failed ? () => _bloc.add(ChatMessageRetried(localId: message.localId)) : null,
    );

    final media = _buildMediaContent(message, interactive: !failed);
    final bubble =
        widget.bubbleBuilder?.call(context, data) ??
        NusaChatBubble(
          text: media == null ? data.displayText : message.text,
          media: media,
          time: data.time,
          isMine: message.isMine,
          status: message.isMine ? message.status : null,
          onTap: data.onRetry,
        );
    final row = NusaChatMessageRow(
      bubble: bubble,
      isMine: message.isMine,
      senderName: widget.strings.agentName,
      avatar: widget.agentAvatarBuilder?.call(context) ?? const NusaChatAvatar(),
      showSender: showSender,
      errorText: failed ? widget.strings.failedToSend : null,
    );
    return widget.messageBuilder?.call(context, data, row) ?? row;
  }

  /// The media part of a bubble, or null for a text message. Taps are off
  /// on a failed message so the tap retries it.
  Widget? _buildMediaContent(ChatMessage message, {required bool interactive}) {
    final media = message.media;
    switch (message.type) {
      case ChatMessageType.image:
        final heroTag = 'nusa_chat_image_${message.localId}';
        return NusaChatImageContent(
          media: media,
          uploadProgress: message.uploadProgress,
          heroTag: heroTag,
          onTap: !interactive || media == null
              ? null
              : () => _push<void>(NusaChatImageViewerPage(media: media, caption: message.text, heroTag: heroTag)),
        );
      case ChatMessageType.document:
        final url = media?.url;
        return NusaChatDocumentContent(
          media: media,
          isMine: message.isMine,
          uploadProgress: message.uploadProgress,
          onTap: !interactive || url == null ? null : () => _open(Uri.tryParse(url)),
        );
      case ChatMessageType.audio:
        return NusaChatAudioContent(
          media: media,
          isMine: message.isMine,
          uploadProgress: message.uploadProgress,
          onError: () => _notice(widget.strings.mediaLoadFailed),
        );
      case ChatMessageType.location:
        final location = message.location;
        if (location == null) return null;
        return NusaChatLocationContent(
          location: location,
          isMine: message.isMine,
          openLabel: widget.strings.openInMaps,
          googleMap: widget.attachments.googleMap,
          onTap: interactive ? () => _open(location.mapsUri) : null,
        );
      case ChatMessageType.text || ChatMessageType.unknown:
        return null;
    }
  }

  /// Under the composer: room for the keyboard (or the navigation bar), or
  /// the emoji panel at the keyboard's height.
  Widget _buildKeyboardArea(BuildContext context, NusaChatTheme theme) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final navigationBar = MediaQuery.viewPaddingOf(context).bottom;
    final base = math.max(navigationBar, inset);
    if (!_panelVisible) {
      return ColoredBox(
        color: theme.composerColor,
        child: SizedBox(height: base),
      );
    }

    final panelHeight = _panelHeight(navigationBar);
    final height = _emojiSearching
        ? math.max(panelHeight, NusaChatEmojiPanel.compactHeight + inset)
        : math.max(panelHeight, inset);
    return AnimatedBuilder(
      animation: _panelReveal,
      builder: (context, panel) {
        final revealed = height * Curves.easeOutCubic.transform(_panelReveal.value);
        return SizedBox(
          height: math.max(base, revealed),
          child: ClipRect(
            child: OverflowBox(alignment: Alignment.topCenter, minHeight: height, maxHeight: height, child: panel),
          ),
        );
      },
      child: NusaChatEmojiPanel(
        height: height,
        bottomPadding: navigationBar,
        strings: widget.strings,
        store: _emojiStore,
        onEmoji: _insertEmoji,
        onBackspace: _backspace,
        onSearchingChanged: (searching) => setState(() => _emojiSearching = searching),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final options = widget.attachments;
    return KeyedSubtree(
      key: _composerKey,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _recordingElapsed, _emojiPanelOpen]),
        builder: (context, _) {
          final elapsed = _recordingElapsed.value;
          final composer = NusaChatComposer(
            controller: _controller,
            focusNode: _focusNode,
            hintText: widget.strings.hintText,
            send: _send,
            canSend: _controller.text.trim().isNotEmpty,
            onAttach: options.menuKinds.isEmpty ? null : _openAttachmentMenu,
            onCamera: options.camera ? _openCamera : null,
            onRecord: options.voice ? _startRecording : null,
            onEmoji: widget.emoji ? _toggleEmojiPanel : null,
            emojiPanelOpen: _emojiPanelOpen.value,
            recording: elapsed == null
                ? null
                : NusaChatRecording(
                    elapsed: elapsed,
                    label: widget.strings.recording,
                    cancel: _cancelRecording,
                    send: _sendRecording,
                  ),
          );
          return widget.inputBarBuilder?.call(context, composer) ??
              NusaChatInputBar(composer: composer, sendButtonBuilder: widget.sendButtonBuilder);
        },
      ),
    );
  }
}

/// Registers a message row while it is built, for [_NusaChatPageState._showFloatingDate].
class _TrackedRow extends StatefulWidget {
  final String id;
  final DateTime date;
  final Map<String, ({BuildContext context, DateTime date})> rows;
  final Widget child;

  const _TrackedRow({super.key, required this.id, required this.date, required this.rows, required this.child});

  @override
  State<_TrackedRow> createState() => _TrackedRowState();
}

class _TrackedRowState extends State<_TrackedRow> {
  @override
  void initState() {
    super.initState();
    widget.rows[widget.id] = (context: context, date: widget.date);
  }

  @override
  void didUpdateWidget(covariant _TrackedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) oldWidget.rows.remove(oldWidget.id);
    widget.rows[widget.id] = (context: context, date: widget.date);
  }

  @override
  void dispose() {
    if (widget.rows[widget.id]?.context == context) widget.rows.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Convenience entry point.
class NusaChat {
  const NusaChat._();

  /// Pushes a [NusaChatPage] built with the same arguments.
  static Future<void> open(BuildContext context, {required NusaChatPage page}) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
