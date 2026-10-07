import 'package:flutter/widgets.dart';
import 'package:nusa_chat/src/core/util/styles/colors.dart';
import 'package:nusa_chat/src/core/util/styles/typography.dart';

/// Every colour and text style of the chat screen. [NusaChatTheme.fallback]
/// is the default look; pass a `copyWith` of it to restyle the chat without
/// replacing components.
@immutable
class NusaChatTheme {
  // ---- page ----
  final Color backgroundColor;

  // ---- app bar ----
  final Color appBarColor;
  final TextStyle appBarTitleStyle;

  /// Icon colour of the round app bar buttons.
  final Color appBarIconColor;

  /// Disc fill of the round app bar buttons.
  final Color appBarButtonColor;

  // ---- my bubble ----
  final Color myBubbleColor;
  final TextStyle myTextStyle;
  final TextStyle myTimeStyle;
  final Color myStatusColor;

  // ---- agent ----
  final Color agentBubbleColor;
  final TextStyle agentTextStyle;
  final TextStyle agentTimeStyle;
  final TextStyle agentNameStyle;
  final Color agentAvatarColor;
  final Color agentAvatarIconColor;
  final List<BoxShadow> agentBubbleShadow;

  // ---- bubble shape ----
  final double bubbleRadius;

  /// Radius of the corner pointing at the sender.
  final double bubbleTailRadius;
  final double bubbleMaxWidth;

  // ---- composer ----
  final Color composerColor;
  final Color inputFillColor;
  final Color inputBorderColor;
  final Color inputFocusedBorderColor;
  final TextStyle inputTextStyle;
  final TextStyle inputHintStyle;
  final Color cursorColor;

  // ---- send button ----
  final Gradient sendButtonGradient;
  final Color sendIconColor;

  /// Opacity of the send button while there is nothing to send.
  final double sendButtonDisabledOpacity;

  // ---- media ----
  /// Background of the image/document preview and the camera (`neutral/900`).
  final Color previewBackgroundColor;

  /// Caption field, file card and round buttons on the preview.
  final Color previewSurfaceColor;
  final TextStyle previewTextStyle;

  /// Behind an image while it loads.
  final Color mediaPlaceholderColor;

  /// The dot shown while a voice note records.
  final Color recordingColor;

  /// Attachment menu: icon and its tinted disc.
  final Color galleryIconColor;
  final Color documentIconColor;
  final Color locationIconColor;

  /// Pen colours of the photo editor; the third (red) is picked first.
  final List<Color> editorColors;

  // ---- emoji ----
  /// Background of the emoji panel (`neutral/50`).
  final Color emojiPanelColor;

  /// Icon of an inactive emoji tab (`text/subtle`).
  final Color emojiTabColor;

  /// Icon of the active emoji tab; its underline uses [primaryColor].
  final Color emojiTabActiveColor;

  /// "Sering Digunakan" and the other section labels.
  final TextStyle emojiSectionStyle;

  /// An emoji key. The design draws Noto Emoji (monochrome); the default
  /// uses the system emoji font so the panel matches what bubbles show —
  /// set a `fontFamily` here to bundle another.
  final TextStyle emojiStyle;

  // ---- day dividers ----
  /// The "Hari ini" pill between days and floating while scrolling.
  final Color dateChipColor;
  final TextStyle dateChipTextStyle;

  // ---- states ----
  final Color errorColor;
  final TextStyle statusTextStyle;
  final Color primaryColor;

  const NusaChatTheme({
    required this.backgroundColor,
    required this.appBarColor,
    required this.appBarTitleStyle,
    required this.appBarIconColor,
    required this.appBarButtonColor,
    required this.myBubbleColor,
    required this.myTextStyle,
    required this.myTimeStyle,
    required this.myStatusColor,
    required this.agentBubbleColor,
    required this.agentTextStyle,
    required this.agentTimeStyle,
    required this.agentNameStyle,
    required this.agentAvatarColor,
    required this.agentAvatarIconColor,
    required this.agentBubbleShadow,
    required this.bubbleRadius,
    required this.bubbleTailRadius,
    required this.bubbleMaxWidth,
    required this.composerColor,
    required this.inputFillColor,
    required this.inputBorderColor,
    required this.inputFocusedBorderColor,
    required this.inputTextStyle,
    required this.inputHintStyle,
    required this.cursorColor,
    required this.sendButtonGradient,
    required this.sendIconColor,
    required this.sendButtonDisabledOpacity,
    required this.errorColor,
    required this.statusTextStyle,
    required this.primaryColor,
    required this.previewBackgroundColor,
    required this.previewSurfaceColor,
    required this.previewTextStyle,
    required this.mediaPlaceholderColor,
    required this.recordingColor,
    required this.galleryIconColor,
    required this.documentIconColor,
    required this.locationIconColor,
    required this.editorColors,
    required this.dateChipColor,
    required this.dateChipTextStyle,
    required this.emojiPanelColor,
    required this.emojiTabColor,
    required this.emojiTabActiveColor,
    required this.emojiSectionStyle,
    required this.emojiStyle,
  });

  /// The default look.
  factory NusaChatTheme.fallback() {
    final myMeta = BaseColor.textInverse.withValues(alpha: 0.75);
    return NusaChatTheme(
      backgroundColor: BaseColor.background,
      appBarColor: BaseColor.surfaceBrand,
      appBarTitleStyle: BaseTypography.p1SemiBold,
      appBarIconColor: BaseColor.actionPrimaryBg,
      appBarButtonColor: BaseColor.surfaceDefault.withValues(alpha: 0.8),
      myBubbleColor: BaseColor.textSecondary,
      myTextStyle: BaseTypography.p2Regular.withColor(BaseColor.textInverse),
      myTimeStyle: BaseTypography.p4Regular.withColor(myMeta),
      myStatusColor: myMeta,
      agentBubbleColor: BaseColor.surfaceDefault,
      agentTextStyle: BaseTypography.p2Regular,
      agentTimeStyle: BaseTypography.p4Regular.withColor(BaseColor.textMuted),
      agentNameStyle: BaseTypography.p3Medium.withColor(BaseColor.textMuted),
      agentAvatarColor: BaseColor.avatarAgent,
      agentAvatarIconColor: BaseColor.textInverse,
      agentBubbleShadow: [
        BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.04), offset: const Offset(0, 1), blurRadius: 4),
      ],
      bubbleRadius: 16,
      bubbleTailRadius: 4,
      bubbleMaxWidth: 240,
      composerColor: BaseColor.surfaceDefault,
      inputFillColor: BaseColor.surfaceSubtle,
      inputBorderColor: BaseColor.borderDefault,
      inputFocusedBorderColor: BaseColor.actionPrimaryBg,
      inputTextStyle: BaseTypography.p3Regular,
      inputHintStyle: BaseTypography.p3Regular.withColor(BaseColor.textDisabled),
      cursorColor: BaseColor.actionPrimaryBg,
      sendButtonGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BasePalette.chatGradientStart, BasePalette.chatGradientEnd],
      ),
      sendIconColor: BaseColor.textInverse,
      sendButtonDisabledOpacity: 0.5,
      errorColor: BaseColor.statusDangerFg,
      statusTextStyle: BaseTypography.p3Regular.withColor(BaseColor.textMuted),
      primaryColor: BaseColor.actionPrimaryBg,
      previewBackgroundColor: BasePalette.neutral900,
      previewSurfaceColor: BasePalette.neutral800,
      previewTextStyle: BaseTypography.p3Medium.withColor(BaseColor.textInverse),
      mediaPlaceholderColor: BasePalette.blue200,
      recordingColor: BasePalette.red600,
      galleryIconColor: BasePalette.emerald600,
      documentIconColor: BasePalette.orange500,
      locationIconColor: BasePalette.blue600,
      dateChipColor: BaseColor.surfaceDefault,
      dateChipTextStyle: BaseTypography.p4Medium.withColor(BaseColor.textMuted),
      editorColors: const [
        Color(0xFFFFFFFF),
        Color(0xFF121926),
        Color(0xFFDA1B21),
        Color(0xFFF6A229),
        Color(0xFFFFD93D),
        Color(0xFF37BE68),
        Color(0xFF1A61B2),
        Color(0xFF7F6AF5),
      ],
      emojiPanelColor: BaseColor.surfaceSubtle,
      emojiTabColor: BaseColor.textSubtle,
      emojiTabActiveColor: BaseColor.textPrimary,
      emojiSectionStyle: BaseTypography.p4Medium.withColor(BaseColor.textMuted),
      emojiStyle: const TextStyle(fontSize: 26, height: 32 / 26),
    );
  }

  NusaChatTheme copyWith({
    Color? backgroundColor,
    Color? appBarColor,
    TextStyle? appBarTitleStyle,
    Color? appBarIconColor,
    Color? appBarButtonColor,
    Color? myBubbleColor,
    TextStyle? myTextStyle,
    TextStyle? myTimeStyle,
    Color? myStatusColor,
    Color? agentBubbleColor,
    TextStyle? agentTextStyle,
    TextStyle? agentTimeStyle,
    TextStyle? agentNameStyle,
    Color? agentAvatarColor,
    Color? agentAvatarIconColor,
    List<BoxShadow>? agentBubbleShadow,
    double? bubbleRadius,
    double? bubbleTailRadius,
    double? bubbleMaxWidth,
    Color? composerColor,
    Color? inputFillColor,
    Color? inputBorderColor,
    Color? inputFocusedBorderColor,
    TextStyle? inputTextStyle,
    TextStyle? inputHintStyle,
    Color? cursorColor,
    Gradient? sendButtonGradient,
    Color? sendIconColor,
    double? sendButtonDisabledOpacity,
    Color? errorColor,
    TextStyle? statusTextStyle,
    Color? primaryColor,
    Color? previewBackgroundColor,
    Color? previewSurfaceColor,
    TextStyle? previewTextStyle,
    Color? mediaPlaceholderColor,
    Color? recordingColor,
    Color? galleryIconColor,
    Color? documentIconColor,
    Color? locationIconColor,
    List<Color>? editorColors,
    Color? dateChipColor,
    TextStyle? dateChipTextStyle,
    Color? emojiPanelColor,
    Color? emojiTabColor,
    Color? emojiTabActiveColor,
    TextStyle? emojiSectionStyle,
    TextStyle? emojiStyle,
  }) {
    return NusaChatTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      appBarColor: appBarColor ?? this.appBarColor,
      appBarTitleStyle: appBarTitleStyle ?? this.appBarTitleStyle,
      appBarIconColor: appBarIconColor ?? this.appBarIconColor,
      appBarButtonColor: appBarButtonColor ?? this.appBarButtonColor,
      myBubbleColor: myBubbleColor ?? this.myBubbleColor,
      myTextStyle: myTextStyle ?? this.myTextStyle,
      myTimeStyle: myTimeStyle ?? this.myTimeStyle,
      myStatusColor: myStatusColor ?? this.myStatusColor,
      agentBubbleColor: agentBubbleColor ?? this.agentBubbleColor,
      agentTextStyle: agentTextStyle ?? this.agentTextStyle,
      agentTimeStyle: agentTimeStyle ?? this.agentTimeStyle,
      agentNameStyle: agentNameStyle ?? this.agentNameStyle,
      agentAvatarColor: agentAvatarColor ?? this.agentAvatarColor,
      agentAvatarIconColor: agentAvatarIconColor ?? this.agentAvatarIconColor,
      agentBubbleShadow: agentBubbleShadow ?? this.agentBubbleShadow,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      bubbleTailRadius: bubbleTailRadius ?? this.bubbleTailRadius,
      bubbleMaxWidth: bubbleMaxWidth ?? this.bubbleMaxWidth,
      composerColor: composerColor ?? this.composerColor,
      inputFillColor: inputFillColor ?? this.inputFillColor,
      inputBorderColor: inputBorderColor ?? this.inputBorderColor,
      inputFocusedBorderColor: inputFocusedBorderColor ?? this.inputFocusedBorderColor,
      inputTextStyle: inputTextStyle ?? this.inputTextStyle,
      inputHintStyle: inputHintStyle ?? this.inputHintStyle,
      cursorColor: cursorColor ?? this.cursorColor,
      sendButtonGradient: sendButtonGradient ?? this.sendButtonGradient,
      sendIconColor: sendIconColor ?? this.sendIconColor,
      sendButtonDisabledOpacity: sendButtonDisabledOpacity ?? this.sendButtonDisabledOpacity,
      errorColor: errorColor ?? this.errorColor,
      statusTextStyle: statusTextStyle ?? this.statusTextStyle,
      primaryColor: primaryColor ?? this.primaryColor,
      previewBackgroundColor: previewBackgroundColor ?? this.previewBackgroundColor,
      previewSurfaceColor: previewSurfaceColor ?? this.previewSurfaceColor,
      previewTextStyle: previewTextStyle ?? this.previewTextStyle,
      mediaPlaceholderColor: mediaPlaceholderColor ?? this.mediaPlaceholderColor,
      recordingColor: recordingColor ?? this.recordingColor,
      galleryIconColor: galleryIconColor ?? this.galleryIconColor,
      documentIconColor: documentIconColor ?? this.documentIconColor,
      locationIconColor: locationIconColor ?? this.locationIconColor,
      editorColors: editorColors ?? this.editorColors,
      dateChipColor: dateChipColor ?? this.dateChipColor,
      dateChipTextStyle: dateChipTextStyle ?? this.dateChipTextStyle,
      emojiPanelColor: emojiPanelColor ?? this.emojiPanelColor,
      emojiTabColor: emojiTabColor ?? this.emojiTabColor,
      emojiTabActiveColor: emojiTabActiveColor ?? this.emojiTabActiveColor,
      emojiSectionStyle: emojiSectionStyle ?? this.emojiSectionStyle,
      emojiStyle: emojiStyle ?? this.emojiStyle,
    );
  }
}

/// Makes the [NusaChatTheme] of the current chat available to its widgets,
/// including any custom component a host app builds.
class NusaChatThemeScope extends InheritedWidget {
  final NusaChatTheme theme;

  const NusaChatThemeScope({super.key, required this.theme, required super.child});

  /// The nearest theme, or [NusaChatTheme.fallback] outside a chat.
  static NusaChatTheme of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NusaChatThemeScope>()?.theme ?? _fallback;
  }

  static final _fallback = NusaChatTheme.fallback();

  @override
  bool updateShouldNotify(NusaChatThemeScope oldWidget) => theme != oldWidget.theme;
}
