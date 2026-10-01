/// Buttons understood by a Game Boy Advance emulator.
///
/// This is an application/core value type. It deliberately does not mention
/// mGBA, Flutter gestures, or a platform key code.
enum EmulatorInput {
  a(1 << 0),
  b(1 << 1),
  select(1 << 2),
  start(1 << 3),
  right(1 << 4),
  left(1 << 5),
  up(1 << 6),
  down(1 << 7),
  r(1 << 8),
  l(1 << 9);

  const EmulatorInput(this.bit);
  final int bit;
}
