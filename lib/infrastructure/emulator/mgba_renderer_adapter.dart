import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../shell/play/emulator_renderer.dart';
import '../native/gba_core.dart';

/// Adapts mGBA frame presentation to the shell [EmulatorRenderer] port.
class MgbaRendererAdapter implements EmulatorRenderer {
  MgbaRendererAdapter(this._core);

  final GbaCore _core;

  @override
  bool get usesExternalTexture => _core.useExternalTexture;

  @override
  ValueListenable<int?> get textureId => _core.presentation.textureId;

  @override
  ValueListenable<ui.Image?> get frame => _core.presentation.frame;
}
