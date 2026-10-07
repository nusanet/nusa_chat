import 'package:flutter/painting.dart';

/// Spacing scale. 4px base, copied from nusa_selecta.
class BaseSpacing {
  const BaseSpacing._();

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;

  static const double xs = space1;
  static const double sm = space2;
  static const double md = space3;
  static const double lg = space4;
  static const double xl = space5;
  static const double xxl = space6;

  /// 24px outer margin of the 360px reference frame.
  static const double pageMargin = space6;
}

/// Border radius scale.
class BaseRadius {
  const BaseRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;

  static final fullAll = BorderRadius.circular(full);
}
