import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only: creates a Flutter [Texture] whose Surface is owned by native
/// (ANativeWindow). Pixels are presented inside `gba_run_frame` — Dart never
/// uploads frame bitmaps.
class GbaVideoTexture {
  GbaVideoTexture._();

  static const MethodChannel _channel = MethodChannel('gba_emulator/video');

  static int? _textureId;
  static bool _ready = false;

  static int? get textureId => _textureId;
  static bool get isReady => _ready && _textureId != null;
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<int?> ensureCreated({int width = 240, int height = 160}) async {
    if (!isSupported) return null;
    if (_ready && _textureId != null) return _textureId;
    try {
      final map = await _channel.invokeMapMethod<String, dynamic>('create', {
        'width': width,
        'height': height,
      });
      if (map == null) {
        _ready = false;
        return null;
      }
      _textureId = (map['textureId'] as num?)?.toInt();
      _ready = _textureId != null;
      return _textureId;
    } catch (e) {
      debugPrint('GbaVideoTexture.create failed: $e');
      _ready = false;
      _textureId = null;
      return null;
    }
  }

  static Future<void> dispose() async {
    if (!isSupported) return;
    _ready = false;
    _textureId = null;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
  }
}
