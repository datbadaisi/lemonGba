import 'package:flutter/material.dart';

import '../../core/emulation/emulator_input.dart';
import '../theme/play_tokens.dart';
import 'pad_interaction_scope.dart';
import 'pad_types.dart';

/// Single face button (A or B). Used by play surface and layout editor.
class VirtualFaceButton extends StatelessWidget {
  const VirtualFaceButton({
    super.key,
    required this.label,
    required this.keyId,
    required this.onKey,
    this.size = PlaySizes.faceDefault,
  });

  final String label;
  final EmulatorInput keyId;
  final KeyHandler onKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PadShellButton(
      label: label,
      keyId: keyId,
      onKey: onKey,
      width: size,
      height: size,
      circle: true,
      fontSize: size * PlaySizes.faceFontRatio,
      fontWeight: FontWeight.w800,
    );
  }
}

/// Select / Start pill (placed under D-pad or under A/B).
class VirtualMetaButton extends StatelessWidget {
  const VirtualMetaButton({
    super.key,
    required this.label,
    required this.keyId,
    required this.onKey,
    this.width = PlaySizes.metaWDefault,
    this.height = PlaySizes.metaHDefault,
  });

  final String label;
  final EmulatorInput keyId;
  final KeyHandler onKey;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return PadShellButton(
      label: label,
      keyId: keyId,
      onKey: onKey,
      width: width,
      height: height,
      radius: height / 2,
      fontSize: height * PlaySizes.metaFontRatio,
      letterSpacing: PlaySizes.metaLetterSpacing,
      fontWeight: FontWeight.w700,
      sink: PlaySizes.pressSinkLight,
    );
  }
}

/// Shoulder L / R — same plastic shell as D-pad.
class VirtualShoulder extends StatelessWidget {
  const VirtualShoulder({
    super.key,
    required this.label,
    required this.keyId,
    required this.onKey,
    this.width = PlaySizes.shoulderWDefault,
    this.height = PlaySizes.shoulderHDefault,
  });

  final String label;
  final EmulatorInput keyId;
  final KeyHandler onKey;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Radius tracks height so scaled shoulders keep the same pill silhouette.
    final radius =
        (height * (PlaySizes.shoulderRadius / PlaySizes.shoulderHDefault))
            .clamp(PlaySpacing.sm, PlaySpacing.md + PlaySpacing.xs);

    return PadShellButton(
      label: label,
      keyId: keyId,
      onKey: onKey,
      width: width,
      height: height,
      radius: radius,
      fontSize: (height * (PlaySizes.shoulderFont / PlaySizes.shoulderHDefault))
          .clamp(11.0, 16.0),
      letterSpacing: PlaySizes.shoulderLetterSpacing,
      fontWeight: FontWeight.w700,
    );
  }
}

/// Shared plastic button: D-pad shell gradient, soft shadow, rim, press shade.
class PadShellButton extends StatefulWidget {
  const PadShellButton({
    super.key,
    required this.label,
    required this.keyId,
    required this.onKey,
    required this.width,
    required this.height,
    this.circle = false,
    this.radius = 0,
    this.fontSize = 14,
    this.letterSpacing = 0.5,
    this.fontWeight = FontWeight.w700,
    this.sink = PlaySizes.pressSink,
  });

  final String label;
  final EmulatorInput keyId;
  final KeyHandler onKey;
  final double width;
  final double height;
  final bool circle;
  final double radius;
  final double fontSize;
  final double letterSpacing;
  final FontWeight fontWeight;
  final double sink;

  @override
  State<PadShellButton> createState() => _PadShellButtonState();
}

class _PadShellButtonState extends State<PadShellButton> {
  bool _down = false;

  void _set(bool pressed) {
    if (_down == pressed) return;
    setState(() => _down = pressed);
    widget.onKey(widget.keyId, pressed);
  }

  @override
  void dispose() {
    // Avoid sticky keys if the pad is removed mid-press (route pop, rebuild).
    if (_down) widget.onKey(widget.keyId, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.circle ? widget.width / 2 : widget.radius;
    final interactive = PadInteractionScope.interactiveOf(context);
    final down = interactive ? _down : false;

    final shell = AnimatedContainer(
      duration: PlaySizes.pressDuration,
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      transform: playPressTransform(down: down, sink: widget.sink),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.circle ? null : BorderRadius.circular(r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PlayColors.shellGradient(down: down),
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: PlayColors.plasticEdge.withValues(alpha: down ? 0.22 : 0.4),
          width: 1,
        ),
        boxShadow: playShellShadow(down: down),
      ),
      child: ClipPath(
        clipper: widget.circle ? const _CircleClipper() : _RRectClipper(r),
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
              child: Text(
                widget.label,
                style: TextStyle(
                  color: down
                      ? PlayColors.labelOn.withValues(alpha: 0.55)
                      : (widget.circle
                            ? PlayColors.labelOn
                            : PlayColors.labelDim),
                  fontWeight: widget.fontWeight,
                  fontSize: widget.fontSize,
                  letterSpacing: widget.letterSpacing,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!interactive) return shell;

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: shell,
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RRectClipper extends CustomClipper<Path> {
  _RRectClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  @override
  bool shouldReclip(covariant _RRectClipper oldClipper) =>
      oldClipper.radius != radius;
}
