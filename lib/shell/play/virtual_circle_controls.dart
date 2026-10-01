import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/play_tokens.dart';
import 'pad_interaction_scope.dart';

/// Shared circular plastic chrome (menu / speed).
class VirtualCircleChrome extends StatelessWidget {
  const VirtualCircleChrome({
    super.key,
    required this.size,
    required this.down,
    required this.icon,
  });

  final double size;
  final bool down;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final iconColor = down
        ? PlayColors.labelOn.withValues(alpha: 0.55)
        : PlayColors.labelOn.withValues(alpha: 0.85);

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedContainer(
        duration: PlaySizes.pressDuration,
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        transform: playPressTransform(down: down, sink: PlaySizes.pressSink),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: PlayColors.shellGradient(down: down),
            stops: const [0.0, 0.5, 1.0],
          ),
          border: Border.all(
            color: PlayColors.plasticEdge.withValues(alpha: down ? 0.22 : 0.4),
          ),
          boxShadow: playShellShadow(down: down),
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (down)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: PlayColors.pressScrimGradient,
                      stops: PlayColors.pressScrimStops,
                    ),
                  ),
                ),
              Center(
                child: HugeIcon(
                  icon: icon,
                  size: size * PlaySizes.menuIconRatio,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular control with tap + long-press (optional hold-repeat).
///
/// Press visuals use raw [Listener] so they sink immediately — a
/// [GestureDetector] with long-press delays [onTapDown] and feels dead.
class VirtualHoldButton extends StatefulWidget {
  const VirtualHoldButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.longPressRepeat = false,
    this.repeatInterval = const Duration(milliseconds: 380),
    this.size = PlaySizes.menuDefault,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final bool longPressRepeat;
  final Duration repeatInterval;
  final double size;
  final List<List<dynamic>> icon;
  final String? tooltip;

  @override
  State<VirtualHoldButton> createState() => _VirtualHoldButtonState();
}

class _VirtualHoldButtonState extends State<VirtualHoldButton> {
  bool _down = false;
  bool _longPressFired = false;
  Timer? _longPressTimer;
  Timer? _repeatTimer;

  void _set(bool pressed) {
    if (_down == pressed) return;
    setState(() => _down = pressed);
  }

  void _cancelTimers() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _fireLongPress() {
    if (!mounted || !_down || widget.onLongPress == null) return;
    _longPressFired = true;
    if (!widget.longPressRepeat) {
      // One-shot: release visual immediately (menu quick-save feel).
      _set(false);
    }
    widget.onLongPress!();
    if (!widget.longPressRepeat) return;

    _repeatTimer?.cancel();
    _repeatTimer = Timer.periodic(widget.repeatInterval, (_) {
      if (!mounted || !_down) {
        _repeatTimer?.cancel();
        _repeatTimer = null;
        return;
      }
      widget.onLongPress!();
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _longPressFired = false;
    _set(true);
    if (widget.onLongPress == null) return;
    _cancelTimers();
    _longPressTimer = Timer(kLongPressTimeout, _fireLongPress);
  }

  void _onPointerUp(PointerUpEvent event) {
    final shouldTap = _down && !_longPressFired;
    _cancelTimers();
    _longPressFired = false;
    _set(false);
    if (shouldTap) widget.onPressed();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelTimers();
    _longPressFired = false;
    _set(false);
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = PadInteractionScope.interactiveOf(context);
    final down = interactive ? _down : false;
    final shell = VirtualCircleChrome(
      size: widget.size,
      down: down,
      icon: widget.icon,
    );

    if (!interactive) return shell;

    final body = Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: shell,
    );

    final tip = widget.tooltip;
    if (tip == null) return body;

    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.manual,
      child: body,
    );
  }
}

/// Circular menu / quick-save control.
///
/// Tap opens the pause menu; long-press writes the next circular Quick Save.
class VirtualMenuButton extends StatelessWidget {
  const VirtualMenuButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.size = PlaySizes.menuDefault,
  });

  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return VirtualHoldButton(
      onPressed: onPressed,
      onLongPress: onLongPress,
      longPressRepeat: false,
      size: size,
      icon: HugeIcons.strokeRoundedFloppyDisk,
      tooltip: onLongPress == null ? 'Menu' : 'Menu · Hold to Quick Save',
    );
  }
}

/// Circular speed control — mirrors [VirtualMenuButton] on the right edge.
///
/// Long-press cycles emulation speed (wraps) and repeats while held.
/// Optional short tap previews the HUD without changing speed.
class VirtualSpeedButton extends StatelessWidget {
  const VirtualSpeedButton({
    super.key,
    required this.onLongPress,
    this.onPressed,
    this.size = PlaySizes.menuDefault,
  });

  final VoidCallback onLongPress;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return VirtualHoldButton(
      onPressed: onPressed ?? () {},
      onLongPress: onLongPress,
      longPressRepeat: true,
      size: size,
      icon: HugeIcons.strokeRoundedDashboardSpeed01,
      tooltip: 'Hold to cycle game speed',
    );
  }
}
