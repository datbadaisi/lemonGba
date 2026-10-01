import '../../core/emulation/emulator_input.dart';

/// Pad → session input callback. Uses the core [EmulatorInput] type directly.
typedef KeyHandler = void Function(EmulatorInput key, bool pressed);
