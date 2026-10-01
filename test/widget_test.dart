import 'package:flutter_test/flutter_test.dart';

import 'package:gba_emulator/core/emulation/emulator_input.dart';

void main() {
  test('GBA key bits match mGBA order', () {
    expect(EmulatorInput.a.bit, 1 << 0);
    expect(EmulatorInput.b.bit, 1 << 1);
    expect(EmulatorInput.start.bit, 1 << 3);
    expect(EmulatorInput.l.bit, 1 << 9);
  });
}
