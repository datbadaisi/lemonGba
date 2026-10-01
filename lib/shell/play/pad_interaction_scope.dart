import 'package:flutter/material.dart';

/// When [interactive] is false, pad widgets paint but skip Listeners / timers.
///
/// Prefer this over a `preview:` flag on every pad constructor.
class PadInteractionScope extends InheritedWidget {
  const PadInteractionScope({
    super.key,
    required this.interactive,
    required super.child,
  });

  final bool interactive;

  static bool interactiveOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PadInteractionScope>();
    return scope?.interactive ?? true;
  }

  @override
  bool updateShouldNotify(PadInteractionScope oldWidget) =>
      interactive != oldWidget.interactive;
}
