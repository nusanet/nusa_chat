import 'package:flutter/painting.dart';

import 'package:nusa_chat/src/core/util/styles/colors.dart';

/// Type scale of the design system, copied
/// from nusa_selecta. Poppins is bundled with this package, so every style
/// names `package: 'nusa_chat'` — the host app does not need the font.
class BaseTypography {
  const BaseTypography._();

  static const fontFamily = 'Poppins';
  static const fontPackage = 'nusa_chat';

  static TextStyle _style(double size, double lineHeight, FontWeight weight) => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: BaseColor.textPrimary,
  );

  // ---- Body 1 · 16/24 ----
  static final p1Regular = _style(16, 24, FontWeight.w400);
  static final p1Medium = _style(16, 24, FontWeight.w500);
  static final p1SemiBold = _style(16, 24, FontWeight.w600);

  // ---- Body 2 · 14/22 ----
  static final p2Regular = _style(14, 22, FontWeight.w400);
  static final p2Medium = _style(14, 22, FontWeight.w500);
  static final p2SemiBold = _style(14, 22, FontWeight.w600);

  // ---- Body 3 · 12/20 ----
  static final p3Regular = _style(12, 20, FontWeight.w400);
  static final p3Medium = _style(12, 20, FontWeight.w500);
  static final p3SemiBold = _style(12, 20, FontWeight.w600);

  // ---- Body 4 · 10/18 ----
  static final p4Regular = _style(10, 18, FontWeight.w400);
  static final p4Medium = _style(10, 18, FontWeight.w500);
}

extension BaseTextStyleX on TextStyle {
  /// `style.withColor(token)` reads better than `copyWith(color: token)` when a
  /// widget only changes the colour.
  TextStyle withColor(Color value) => copyWith(color: value);
}
