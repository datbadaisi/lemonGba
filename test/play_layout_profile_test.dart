import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/models/play_layout_profile.dart';
import 'package:gba_emulator/shell/play/layout/play_layout.dart';
import 'package:gba_emulator/shell/theme/play_tokens.dart';

void main() {
  group('PlayLayoutProfile JSON', () {
    test('defaults round-trip', () {
      final json = PlayLayoutProfile.defaults.toJson();
      final back = PlayLayoutProfile.fromJson(json);
      expect(back.isDefault, isTrue);
      expect(back, PlayLayoutProfile.defaults);
    });

    test('custom element round-trip', () {
      final profile = PlayLayoutProfile.defaults.withElement(
        PlayElementId.dpad,
        const PlayElementTransform(centerX: 0.2, centerY: 0.6, scale: 1.25),
      );
      final back = PlayLayoutProfile.fromJson(profile.toJson());
      expect(back.isDefault, isFalse);
      final t = back.of(PlayElementId.dpad);
      expect(t.centerX, closeTo(0.2, 1e-9));
      expect(t.centerY, closeTo(0.6, 1e-9));
      expect(t.scale, closeTo(1.25, 1e-9));
      expect(back.of(PlayElementId.faceA).isDefault, isTrue);
    });

    test('legacy face key migrates scale to A and B', () {
      final back = PlayLayoutProfile.fromJson({
        'version': 1,
        'elements': {
          'face': {'scale': 1.2},
        },
      });
      expect(back.of(PlayElementId.faceA).scale, closeTo(1.2, 1e-9));
      expect(back.of(PlayElementId.faceB).scale, closeTo(1.2, 1e-9));
    });

    test('withElement clears default transform', () {
      final profile = PlayLayoutProfile.defaults
          .withElement(
            PlayElementId.menu,
            const PlayElementTransform(scale: 1.1),
          )
          .withElement(PlayElementId.menu, PlayElementTransform.empty);
      expect(profile.isDefault, isTrue);
    });
  });

  group('PlayLayout.resolve', () {
    const w = 800.0;
    const h = 360.0;

    test('empty profile matches stock defaults', () {
      final a = PlayLayout.resolve(width: w, height: h, bottomSafe: 0);
      final b = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults,
      );
      expect(a.gameRect, b.gameRect);
      expect(a.dpadRect, b.dpadRect);
      expect(a.faceARect, b.faceARect);
      expect(a.faceBRect, b.faceBRect);
      expect(a.shoulderLRect, b.shoulderLRect);
      expect(a.shoulderRRect, b.shoulderRRect);
      expect(a.selectRect, b.selectRect);
      expect(a.startRect, b.startRect);
      expect(a.menuRect, b.menuRect);
      expect(a.speedRect, b.speedRect);
    });

    test('dpad scale enlarges from default center', () {
      final base = PlayLayout.resolve(width: w, height: h, bottomSafe: 0);
      final scaled = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults.withElement(
          PlayElementId.dpad,
          const PlayElementTransform(scale: 1.5),
        ),
      );
      expect(scaled.dpadSize, closeTo(base.dpadSize * 1.5, 0.01));
      expect(scaled.dpadRect.center.dx, closeTo(base.dpadRect.center.dx, 0.01));
      expect(scaled.dpadRect.center.dy, closeTo(base.dpadRect.center.dy, 0.01));
    });

    test('A and B move independently', () {
      final moved = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults
            .withElement(
              PlayElementId.faceA,
              const PlayElementTransform(centerX: 0.9, centerY: 0.3),
            )
            .withElement(
              PlayElementId.faceB,
              const PlayElementTransform(centerX: 0.7, centerY: 0.7),
            ),
      );
      expect(moved.faceARect.center.dx, closeTo(w * 0.9, 0.01));
      expect(moved.faceARect.center.dy, closeTo(h * 0.3, 0.01));
      expect(moved.faceBRect.center.dx, closeTo(w * 0.7, 0.01));
      expect(moved.faceBRect.center.dy, closeTo(h * 0.7, 0.01));
    });

    test('game keeps aspect when scaled', () {
      final base = PlayLayout.resolve(width: w, height: h, bottomSafe: 0);
      final scaled = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults.withElement(
          PlayElementId.game,
          const PlayElementTransform(scale: 0.8),
        ),
      );
      expect(
        scaled.gameWidth / scaled.gameHeight,
        closeTo(base.gameWidth / base.gameHeight, 1e-6),
      );
      expect(scaled.gameWidth, closeTo(base.gameWidth * 0.8, 0.01));
    });

    test('stock rects are captured in the same resolve pass', () {
      final layout = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults.withElement(
          PlayElementId.dpad,
          const PlayElementTransform(scale: 1.5),
        ),
      );
      // Applied is scaled; stock is default size.
      expect(
        layout.dpadRect.width,
        closeTo(layout.stockOf(PlayElementId.dpad).width * 1.5, 0.01),
      );
      // Unedited elements share stock geometry with applied rects.
      expect(layout.stockOf(PlayElementId.game), layout.gameRect);
    });

    test('game max scale fills play height or width', () {
      final base = PlayLayout.resolve(width: w, height: h, bottomSafe: 0);
      final maxS = PlayLayout.maxScaleFor(
        PlayElementId.game,
        base.stockOf(PlayElementId.game),
        w,
        h,
      );
      // At max, height or width should touch play edges.
      final full = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults.withElement(
          PlayElementId.game,
          PlayElementTransform(scale: maxS),
        ),
      );
      // maxS is relative to stock, not to already-applied gameRect.
      final touchesH =
          (full.gameRect.top - 0).abs() < 1.0 &&
          (full.gameRect.bottom - h).abs() < 1.0;
      final touchesW =
          (full.gameRect.left - 0).abs() < 1.0 &&
          (full.gameRect.right - w).abs() < 1.0;
      expect(touchesH || touchesW, isTrue);
      // Cannot exceed play area.
      expect(full.gameRect.top, greaterThanOrEqualTo(-0.01));
      expect(full.gameRect.bottom, lessThanOrEqualTo(h + 0.01));
      expect(full.gameRect.left, greaterThanOrEqualTo(-0.01));
      expect(full.gameRect.right, lessThanOrEqualTo(w + 0.01));
    });

    test('overlap opacity when control covers game', () {
      final layout = PlayLayout.resolve(
        width: w,
        height: h,
        bottomSafe: 0,
        profile: PlayLayoutProfile.defaults.withElement(
          PlayElementId.dpad,
          const PlayElementTransform(centerX: 0.5, centerY: 0.5),
        ),
      );
      expect(layout.dpadRect.overlaps(layout.gameRect), isTrue);
      expect(layout.opacityFor(layout.dpadRect), PlaySizes.overlapOpacity);
    });
  });
}
