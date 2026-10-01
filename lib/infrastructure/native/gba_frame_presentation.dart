import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Flutter presentation surfaces for one [GbaCore] instance.
///
/// Kept outside [EmulatorSession]: cores need not know about textures or
/// [ui.Image]. The shell consumes these via [EmulatorRenderer].
class GbaFramePresentation {
  final ValueNotifier<int?> textureId = ValueNotifier<int?>(null);
  final ValueNotifier<ui.Image?> frame = ValueNotifier<ui.Image?>(null);
  final ValueNotifier<String?> status = ValueNotifier<String?>(null);

  ui.Image? _fallbackImage;
  Uint8List? pixelScratch;

  ui.Image? get fallbackImage => _fallbackImage;

  set fallbackImage(ui.Image? next) {
    final old = _fallbackImage;
    _fallbackImage = next;
    frame.value = next;
    if (old != null) {
      // Dispose previous frame off the critical path.
      scheduleMicrotask(old.dispose);
    }
  }

  void dispose() {
    _fallbackImage?.dispose();
    _fallbackImage = null;
    frame.value = null;
    textureId.value = null;
    pixelScratch = null;
    frame.dispose();
    textureId.dispose();
    status.dispose();
  }
}
