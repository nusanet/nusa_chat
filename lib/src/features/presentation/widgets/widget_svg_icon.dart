import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One of the bundled `BaseIcons` SVGs, tinted with [color].
class WidgetSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const WidgetSvgIcon(this.asset, {super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      asset,
      package: 'nusa_chat',
      width: size,
      height: size,
      colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}
