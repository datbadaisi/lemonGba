import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Full-bleed black frame with content inset by **viewPadding** (notch / camera).
///
/// With [SystemUiMode.immersiveSticky], [MediaQuery.padding] is often zero so
/// [SafeArea] alone will not reserve the cutout. [MediaQuery.viewPadding] still
/// reports the display cutout — padding with that leaves a solid black bezel
/// (same professional look as the play surface).
class ConsoleChrome extends StatelessWidget {
  const ConsoleChrome({
    super.key,
    required this.child,
    this.backgroundColor = HomeColors.bg,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
  });

  final Widget child;
  final Color backgroundColor;
  final bool left;
  final bool top;
  final bool right;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final vp = MediaQuery.viewPaddingOf(context);
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.only(
          left: left ? vp.left : 0,
          top: top ? vp.top : 0,
          right: right ? vp.right : 0,
          bottom: bottom ? vp.bottom : 0,
        ),
        child: child,
      ),
    );
  }
}
