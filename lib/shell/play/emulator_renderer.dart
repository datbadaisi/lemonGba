import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Read-only presentation port consumed by the Flutter play shell.
///
/// It is deliberately separate from `EmulatorSession`: an emulator core has
/// no knowledge of Flutter textures or images.
abstract interface class EmulatorRenderer {
  bool get usesExternalTexture;
  ValueListenable<int?> get textureId;
  ValueListenable<ui.Image?> get frame;
}
