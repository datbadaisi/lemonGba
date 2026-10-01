import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/emulation/emulator_input.dart';
import '../theme/play_tokens.dart';
import 'pad_interaction_scope.dart';
import 'pad_types.dart';

/// Cross-shaped D-pad with continuous 8-way tracking (slide / swirl finger).
///
/// Under [PadInteractionScope] with `interactive: false`, paints only (editor).
class VirtualDpad extends StatefulWidget {
  const VirtualDpad({
    super.key,
    required this.onKey,
    this.size = PlaySizes.dpadDefault,
  });

  final KeyHandler onKey;
  final double size;

  @override
  State<VirtualDpad> createState() => _VirtualDpadState();
}

class _VirtualDpadState extends State<VirtualDpad> {
  static const _dirs = [
    EmulatorInput.up,
    EmulatorInput.down,
    EmulatorInput.left,
    EmulatorInput.right,
  ];

  /// pointerId → keys that pointer currently holds (supports multi-touch).
  final Map<int, Set<EmulatorInput>> _byPointer = {};
  Set<EmulatorInput> _pressed = {};

  @override
  void dispose() {
    for (final id in _byPointer.keys.toList()) {
      GestureBinding.instance.pointerRouter.removeRoute(id, _onGlobalPointer);
    }
    _byPointer.clear();
    for (final k in _dirs) {
      if (_pressed.contains(k)) widget.onKey(k, false);
    }
    super.dispose();
  }

  /// Map local touch → 0–2 GBA direction keys (cardinal or diagonal).
  Set<EmulatorInput> _keysAt(Offset local) {
    final size = widget.size;
    final dx = local.dx - size / 2;
    final dy = local.dy - size / 2;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Dead zone at the hub — release while resting on center.
    if (dist < size * PlaySizes.dpadDeadZone) return {};

    final nx = dx / dist;
    final ny = dy / dist;
    // Component threshold: near pure axes stay single-direction;
    // corners engage two keys (true GBA diagonal).
    const t = PlaySizes.dpadCornerThreshold;

    final keys = <EmulatorInput>{};
    if (ny < -t) keys.add(EmulatorInput.up);
    if (ny > t) keys.add(EmulatorInput.down);
    if (nx < -t) keys.add(EmulatorInput.left);
    if (nx > t) keys.add(EmulatorInput.right);

    if (keys.isEmpty) {
      if (ny.abs() >= nx.abs()) {
        keys.add(ny < 0 ? EmulatorInput.up : EmulatorInput.down);
      } else {
        keys.add(nx < 0 ? EmulatorInput.left : EmulatorInput.right);
      }
    }
    return keys;
  }

  void _syncFromPointers() {
    final next = <EmulatorInput>{};
    for (final s in _byPointer.values) {
      next.addAll(s);
    }
    var changed = false;
    for (final k in _dirs) {
      final was = _pressed.contains(k);
      final now = next.contains(k);
      if (was != now) {
        widget.onKey(k, now);
        changed = true;
      }
    }
    if (changed) {
      setState(() => _pressed = next);
    }
  }

  void _applyLocal(int pointer, Offset local) {
    final next = _keysAt(local);
    final prev = _byPointer[pointer];
    if (prev != null && next.length == prev.length && next.containsAll(prev)) {
      return;
    }
    _byPointer[pointer] = next;
    _syncFromPointers();
  }

  /// Global route so sliding off the widget still updates direction.
  void _onGlobalPointer(PointerEvent event) {
    if (!_byPointer.containsKey(event.pointer) || !mounted) return;

    if (event is PointerMoveEvent) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      _applyLocal(event.pointer, box.globalToLocal(event.position));
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      GestureBinding.instance.pointerRouter.removeRoute(
        event.pointer,
        _onGlobalPointer,
      );
      if (_byPointer.remove(event.pointer) != null) {
        _syncFromPointers();
      }
    }
  }

  void _onDown(PointerDownEvent e) {
    _byPointer[e.pointer] = _keysAt(e.localPosition);
    _syncFromPointers();
    GestureBinding.instance.pointerRouter.addRoute(e.pointer, _onGlobalPointer);
  }

  /// Real D-pad rocker: pressed side sinks, opposite side lifts.
  Matrix4 _rockerTransform(Set<EmulatorInput> pressed) {
    if (pressed.isEmpty) return Matrix4.identity();

    const tilt = PlaySizes.rockerTilt;
    const shift = PlaySizes.rockerShift;
    var rx = 0.0;
    var ry = 0.0;
    var dx = 0.0;
    var dy = 0.0;

    if (pressed.contains(EmulatorInput.up)) {
      rx -= tilt;
      dy += shift;
    }
    if (pressed.contains(EmulatorInput.down)) {
      rx += tilt;
      dy -= shift;
    }
    if (pressed.contains(EmulatorInput.left)) {
      ry += tilt;
      dx += shift;
    }
    if (pressed.contains(EmulatorInput.right)) {
      ry -= tilt;
      dx -= shift;
    }

    return Matrix4.identity()
      ..setEntry(3, 2, PlaySizes.rockerPerspective)
      ..translateByDouble(dx, dy, 0, 1)
      ..rotateX(rx)
      ..rotateY(ry);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final arm = size * PlaySizes.dpadArmRatio;
    final corner = (size - arm) / 2;
    final interactive = PadInteractionScope.interactiveOf(context);
    final pressed = interactive ? _pressed : <EmulatorInput>{};

    final body = AnimatedContainer(
      duration: PlaySizes.pressDuration,
      curve: Curves.easeOutCubic,
      transform: _rockerTransform(pressed),
      transformAlignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DpadShellPainter(pressed: pressed),
          ),
          // Visual arrows only — input comes from the outer Listener.
          Positioned(
            left: corner,
            top: 0,
            width: arm,
            height: corner,
            child: IgnorePointer(
              child: _DpadArrow(
                icon: HugeIcons.strokeRoundedArrowUp01,
                role: EmulatorInput.up,
                pressed: pressed,
              ),
            ),
          ),
          Positioned(
            left: corner,
            bottom: 0,
            width: arm,
            height: corner,
            child: IgnorePointer(
              child: _DpadArrow(
                icon: HugeIcons.strokeRoundedArrowDown01,
                role: EmulatorInput.down,
                pressed: pressed,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: corner,
            width: corner,
            height: arm,
            child: IgnorePointer(
              child: _DpadArrow(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                role: EmulatorInput.left,
                pressed: pressed,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: corner,
            width: corner,
            height: arm,
            child: IgnorePointer(
              child: _DpadArrow(
                icon: HugeIcons.strokeRoundedArrowRight01,
                role: EmulatorInput.right,
                pressed: pressed,
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: interactive
          ? Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              child: body,
            )
          : body,
    );
  }
}

class _DpadArrow extends StatelessWidget {
  const _DpadArrow({
    required this.icon,
    required this.role,
    required this.pressed,
  });

  final List<List<dynamic>> icon;
  final EmulatorInput role;
  final Set<EmulatorInput> pressed;

  @override
  Widget build(BuildContext context) {
    final active = pressed.contains(role);
    const n = PlaySizes.arrowNudge;

    final nudge = active
        ? switch (role) {
            EmulatorInput.up => const Offset(0, -n),
            EmulatorInput.down => const Offset(0, n),
            EmulatorInput.left => const Offset(-n, 0),
            EmulatorInput.right => const Offset(n, 0),
            _ => Offset.zero,
          }
        : Offset.zero;

    final scale = active ? PlaySizes.pressScaleIcon : 1.0;

    return AnimatedContainer(
      duration: PlaySizes.pressDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(nudge.dx, nudge.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1),
      transformAlignment: Alignment.center,
      child: HugeIcon(
        icon: icon,
        size: PlaySizes.dpadArrowIcon,
        color: active
            ? PlayColors.dpadArrowIdle
            : PlayColors.labelDim.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Plastic + body: ground shadow follows contact side; arms sink / lift with light.
class _DpadShellPainter extends CustomPainter {
  const _DpadShellPainter({required this.pressed});

  final Set<EmulatorInput> pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final arm = size.width * PlaySizes.dpadArmRatio;
    final r = arm * PlaySizes.dpadCornerRadiusRatio;
    final any = pressed.isNotEmpty;

    final (tx, ty) = playTiltUnit(
      left: pressed.contains(EmulatorInput.left),
      right: pressed.contains(EmulatorInput.right),
      up: pressed.contains(EmulatorInput.up),
      down: pressed.contains(EmulatorInput.down),
    );

    // True + silhouette: union two bars so the center has NO inner square outline.
    Path bar(double w, double h, double radius) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
          Radius.circular(radius),
        ),
      );

    final path = Path.combine(
      PathOperation.union,
      bar(arm, size.height, r),
      bar(size.width, arm, r),
    );

    // Ground shadow slides under the sunk side.
    final shadowDx = any ? tx * PlaySizes.shadowSlide : 0.0;
    final shadowDy = any
        ? PlaySizes.shadowYPressedBase + ty * (PlaySizes.shadowSlide - 1)
        : PlaySizes.shadowY;
    canvas.drawPath(
      path.shift(Offset(shadowDx, shadowDy)),
      Paint()
        ..color = Colors.black.withValues(alpha: any ? 0.5 : 0.38)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          any ? PlaySizes.shadowBlurPressed : PlaySizes.shadowBlur,
        ),
    );

    // Body gradient: darkens toward pressed side only.
    final Alignment gBegin;
    final Alignment gEnd;
    if (!any) {
      gBegin = Alignment.topLeft;
      gEnd = Alignment.bottomRight;
    } else {
      gBegin = Alignment(-tx, -ty);
      gEnd = Alignment(tx, ty);
    }

    final fill = Paint()
      ..shader = LinearGradient(
        begin: gBegin,
        end: gEnd,
        colors: PlayColors.shellGradient(down: any),
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, fill);

    // Soft recessed groove — also a real union (no square at the hub).
    final inset = arm * PlaySizes.dpadInsetRatio;
    final inner = Path.combine(
      PathOperation.union,
      bar(arm - inset * 2, size.height - inset * 2, r * 0.65),
      bar(size.width - inset * 2, arm - inset * 2, r * 0.65),
    );
    canvas.drawPath(
      inner,
      Paint()..color = PlayColors.dpadFace.withValues(alpha: any ? 0.55 : 0.42),
    );

    // Press shade: linear fade tip → hub on the unified + path only.
    void shadePressedArm(Alignment tip, Alignment hub) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: tip,
            end: hub,
            colors: [
              Colors.black.withValues(alpha: 0.32),
              Colors.black.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 0.72],
          ).createShader(Offset.zero & size),
      );
    }

    if (pressed.contains(EmulatorInput.up)) {
      shadePressedArm(Alignment.topCenter, Alignment.center);
    }
    if (pressed.contains(EmulatorInput.down)) {
      shadePressedArm(Alignment.bottomCenter, Alignment.center);
    }
    if (pressed.contains(EmulatorInput.left)) {
      shadePressedArm(Alignment.centerLeft, Alignment.center);
    }
    if (pressed.contains(EmulatorInput.right)) {
      shadePressedArm(Alignment.centerRight, Alignment.center);
    }

    // Outer rim only on the unified + silhouette (no internal square edges).
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = PlayColors.plasticEdge.withValues(alpha: any ? 0.22 : 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _DpadShellPainter oldDelegate) =>
      oldDelegate.pressed.length != pressed.length ||
      !oldDelegate.pressed.containsAll(pressed);
}
