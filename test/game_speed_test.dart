import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/core/emulation/game_speed.dart';

void main() {
  test('snap picks nearest discrete step', () {
    expect(GameSpeed.snap(1.0), 1.0);
    expect(GameSpeed.snap(1.1), 1.0);
    expect(GameSpeed.snap(1.4), 1.5);
    expect(GameSpeed.snap(3.6), 4.0);
  });

  test('nudge walks notches and clamps at ends', () {
    expect(GameSpeed.nudge(1.0, 1), 1.5);
    expect(GameSpeed.nudge(1.0, -1), 1.0);
    expect(GameSpeed.nudge(4.0, 1), 4.0);
  });

  test('cycle wraps from max back to 1×', () {
    expect(GameSpeed.cycle(1.0), 1.5);
    expect(GameSpeed.cycle(1.5), 2.0);
    expect(GameSpeed.cycle(2.0), 3.0);
    expect(GameSpeed.cycle(3.0), 4.0);
    expect(GameSpeed.cycle(4.0), 1.0);
  });

  test('label formats whole and fractional speeds', () {
    expect(GameSpeed.label(1.0), '1×');
    expect(GameSpeed.label(2.0), '2×');
    expect(GameSpeed.label(1.5), '1.5×');
  });

  test('speeds below 1× snap up to normal', () {
    expect(GameSpeed.snap(0.5), 1.0);
  });
}
