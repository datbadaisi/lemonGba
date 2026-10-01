import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/core/entitlements/free_limits.dart';

void main() {
  group('FreeLimits', () {
    test('product caps', () {
      expect(FreeLimits.maxAvatars, 2);
      expect(FreeLimits.maxCovers, 2);
      expect(FreeLimits.maxGroups, 1);
    });
  });
}
