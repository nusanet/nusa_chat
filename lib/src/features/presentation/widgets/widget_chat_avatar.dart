import 'package:flutter/widgets.dart';
import 'package:nusa_chat/src/core/theme/nusa_chat_theme.dart';
import 'package:nusa_chat/src/core/util/icons.dart';
import 'package:nusa_chat/src/features/presentation/widgets/widget_svg_icon.dart';

/// The agent avatar: a 36px
/// `emerald/700` disc with a 20px white headset.
class NusaChatAvatar extends StatelessWidget {
  final double size;

  /// Replaces the headset icon, e.g. an `Image` of the agent or brand logo.
  final Widget? child;

  const NusaChatAvatar({super.key, this.size = 36, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = NusaChatThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: theme.agentAvatarColor, shape: BoxShape.circle),
      child: child ?? WidgetSvgIcon(BaseIcons.headset, size: size * 20 / 36, color: theme.agentAvatarIconColor),
    );
  }
}
