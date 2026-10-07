import 'package:flutter/painting.dart';

/// Effect styles of the design system, copied from nusa_selecta.
class Shadows {
  const Shadows._();

  static const _ink = Color(0xFF000000);

  /// `Shadow/xs` — chat bubbles from the other party.
  static final xs = [BoxShadow(color: _ink.withValues(alpha: 0.04), offset: const Offset(0, 1), blurRadius: 4)];

  /// `Shadow/sm` — top-bar icon buttons.
  static final sm = [BoxShadow(color: _ink.withValues(alpha: 0.05), offset: const Offset(0, 2), blurRadius: 8)];
}
