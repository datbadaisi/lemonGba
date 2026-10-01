import 'dart:typed_data';

import 'emulator_input.dart';

/// Platform-neutral contract for one loaded emulation session.
abstract interface class EmulatorSession {
  int get width;
  int get height;
  bool get isLoaded;
  bool get isRunning;
  String? get romPath;
  String get coreVersion;

  Future<void> loadRom(String path, {String? savPath});
  Future<void> flushSave();

  /// Erases the cartridge battery save in the running session (blank cart).
  Future<bool> wipeCartridgeSave();

  Future<void> start();
  Future<void> stop();
  Future<void> reset();
  void setInput(EmulatorInput input, bool pressed);
  void setInputMask(int mask);
  void setVolume(double volume);

  /// Emulation rate relative to real time (1.0 = normal). Discrete steps live
  /// in [GameSpeed]; cores should snap/clamp as needed.
  double get speed;
  void setSpeed(double speed);

  String gameTitle();
  Future<Uint8List?> captureState();
  Future<bool> applyState(Uint8List bytes);
  Future<void> dispose();
}
