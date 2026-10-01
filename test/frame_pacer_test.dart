import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/native/frame_pacer.dart';

void main() {
  test('frame pacing is independent from a 120 Hz display', () {
    final pacer = FramePacer();
    var frames = pacer.consume(Duration.zero);
    for (var tick = 1; tick <= 120; tick++) {
      frames += pacer.consume(
        Duration(microseconds: (tick * 1000000 / 120).round()),
      );
    }
    expect(frames, inInclusiveRange(59, 61));
  });

  test('a long pause does not create an unbounded catch-up loop', () {
    final pacer = FramePacer();
    pacer.consume(Duration.zero);
    expect(pacer.consume(const Duration(seconds: 10)), lessThanOrEqualTo(2));
  });

  test('2× speed roughly doubles frames over one second at 60 Hz', () {
    final pacer = FramePacer()..speed = 2.0;
    var frames = pacer.consume(Duration.zero);
    for (var tick = 1; tick <= 60; tick++) {
      frames += pacer.consume(
        Duration(microseconds: (tick * 1000000 / 60).round()),
      );
    }
    expect(frames, inInclusiveRange(115, 125));
  });

}
