import 'dart:ui';

/// Primitive colour palette of the NusaSelecta design system
/// — the subset the chat uses,
/// copied from nusa_selecta `core/util/styles/colors.dart`.
///
/// Widgets should not read these directly — go through [BaseColor] or, for
/// anything a host app may recolour, through `NusaChatTheme`.
class BasePalette {
  const BasePalette._(); // coverage:ignore-line

  static const blue50 = Color(0xFFF2F6FD);
  static const blue500 = Color(0xFF287BCF);
  static const blue600 = Color(0xFF1A61B2);
  static const blue800 = Color(0xFF164276);

  static const royal50 = Color(0xFFEFF7FF);

  static const blue200 = Color(0xFFB9D3F2);

  static const emerald50 = Color(0xFFECFDF3);
  static const emerald600 = Color(0xFF16A34A);
  static const emerald700 = Color(0xFF098C34);

  static const orange50 = Color(0xFFFFF4ED);
  static const orange500 = Color(0xFFF97316);

  static const red50 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFFDA1B21);

  static const neutral0 = Color(0xFFFFFFFF);
  static const neutral50 = Color(0xFFF9FAFB);
  static const neutral100 = Color(0xFFF3F4F6);
  static const neutral200 = Color(0xFFE5E7EB);
  static const neutral300 = Color(0xFFD2D5DA);
  static const neutral400 = Color(0xFF8A929E);

  /// `text/subtle`.
  static const slate300 = Color(0xFFAEBAC8);
  static const neutral500 = Color(0xFF6C737F);
  static const neutral700 = Color(0xFF364152);
  static const neutral800 = Color(0xFF202939);
  static const neutral900 = Color(0xFF121926);

  static const black50 = Color(0xFFF7F8FA);
  static const black950 = Color(0xFF212630);

  /// Chat action button wash: `#40FF76 → #03A9F4`.
  static const chatGradientStart = Color(0xFF40FF76);
  static const chatGradientEnd = Color(0xFF03A9F4);
}

/// Semantic colour tokens, named after the design-token paths
/// (`text/primary` → [textPrimary], `surface/brand` → [surfaceBrand]).
class BaseColor {
  const BaseColor._(); // coverage:ignore-line

  static const textPrimary = BasePalette.black950;
  static const textSecondary = BasePalette.blue800;
  static const textMuted = BasePalette.neutral500;
  static const textDisabled = BasePalette.neutral400;
  static const textSubtle = BasePalette.slate300;
  static const textInverse = BasePalette.neutral0;
  static const textLink = BasePalette.blue500;
  static const textError = BasePalette.red600;

  static const background = BasePalette.black50;

  static const surfaceDefault = BasePalette.neutral0;
  static const surfaceBrand = BasePalette.royal50;
  static const surfaceSubtle = BasePalette.neutral50;
  static const surfaceError = BasePalette.red50;

  static const borderSubtle = BasePalette.neutral100;
  static const borderDefault = BasePalette.neutral200;
  static const borderStrong = BasePalette.neutral300;

  static const actionPrimaryBg = BasePalette.blue600;
  static const actionPrimaryFg = BasePalette.neutral0;
  static const actionDisabledBg = BasePalette.neutral300;

  static const statusDangerFg = BasePalette.red600;

  /// Agent avatar disc (`emerald/700`).
  static const avatarAgent = BasePalette.emerald700;
}
