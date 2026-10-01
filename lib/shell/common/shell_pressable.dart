import 'package:flutter/material.dart';

import '../theme/home_tokens.dart';

/// Press-scale only — use when the parent owns the gesture detector
/// (e.g. [GameTile] double-tap window).
class ShellPressScale extends StatelessWidget {
  const ShellPressScale({
    super.key,
    required this.pressed,
    required this.child,
  });

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? HomeMotion.pressScale : 1,
      duration: HomeMotion.press,
      curve: HomeMotion.pressCurve,
      child: child,
    );
  }
}

/// Shared press-scale feedback used by shelf tiles and similar chrome.
class ShellPressable extends StatefulWidget {
  const ShellPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<ShellPressable> createState() => _ShellPressableState();
}

class _ShellPressableState extends State<ShellPressable> {
  bool _down = false;

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _active ? (_) => setState(() => _down = true) : null,
      onTapUp: _active ? (_) => setState(() => _down = false) : null,
      onTapCancel: _active ? () => setState(() => _down = false) : null,
      onTap: _active ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: ShellPressScale(pressed: _down, child: widget.child),
    );
  }
}
