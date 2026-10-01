import 'dart:async';
import 'dart:ffi';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../core/emulation/emulator_input.dart';
import '../../core/emulation/emulator_session.dart';
import 'gba_audio.dart';
import 'gba_bindings.dart';
import 'frame_pacer.dart';
import 'gba_frame_presentation.dart';
import 'gba_video_texture.dart';

/// High-level wrapper around the mGBA bridge (`libgba_core`).
///
/// Implements [EmulatorSession] for load/run/input/state. Flutter presentation
/// lives on [presentation] and is adapted by [MgbaRendererAdapter].
///
/// **Video (Android):** Flutter [Texture] + native `ANativeWindow`. Each
/// `runFrame` presents inside C — no Dart bitmap upload.
///
/// **Audio (Android):** AAudio callback drains the native ring buffer.
class GbaCore implements EmulatorSession {
  GbaCore._(this._b)
      : _audio = GbaAudioPlayer(_b),
        presentation = GbaFramePresentation();

  final GbaBindings _b;
  final GbaAudioPlayer _audio;
  final GbaFramePresentation presentation;
  bool _created = false;
  bool _running = false;
  int _keys = 0;
  String? _romPath;
  final FramePacer _pacer = FramePacer();

  // Compatibility accessors used by older call sites / adapter.
  ValueNotifier<int?> get textureIdListenable => presentation.textureId;
  ValueNotifier<ui.Image?> get frameListenable => presentation.frame;
  ValueNotifier<String?> get statusListenable => presentation.status;

  bool get useExternalTexture => GbaVideoTexture.isSupported;

  @override
  int get width => _created ? _b.frameWidth() : 240;
  @override
  int get height => _created ? _b.frameHeight() : 160;
  @override
  bool get isLoaded => _created && _b.isLoaded() != 0;
  @override
  bool get isRunning => _running;
  @override
  String? get romPath => _romPath;

  @override
  String get coreVersion {
    if (!_created) return 'not loaded';
    return _b.coreVersion().toDartString();
  }

  int get bridgeVersion => _created ? _b.bridgeVersion() : 0;

  static Future<GbaCore> create() async {
    final bindings = GbaBindings.open();
    final core = GbaCore._(bindings);
    final ok = bindings.create();
    if (ok == 0) {
      throw StateError('gba_create failed');
    }
    core._created = true;
    core.presentation.status.value =
        'Core ready (${core.coreVersion}, bridge v${core.bridgeVersion})';
    try {
      await core._audio.setup();
    } catch (e) {
      debugPrint('Audio setup deferred/failed: $e');
    }
    if (core.useExternalTexture) {
      final id = await GbaVideoTexture.ensureCreated(width: 240, height: 160);
      core.presentation.textureId.value = id;
    }
    return core;
  }

  @override
  Future<void> loadRom(String path, {String? savPath}) async {
    _ensureCreated();
    await stop();
    await flushSave();

    final cRom = path.toNativeUtf8();
    final cSav = savPath != null ? savPath.toNativeUtf8() : nullptr;
    try {
      final ok = savPath != null ? _b.loadRomEx(cRom, cSav) : _b.loadRom(cRom);
      if (ok == 0) {
        throw StateError('Failed to load ROM: $path');
      }
    } finally {
      malloc.free(cRom);
      if (cSav != nullptr) {
        malloc.free(cSav);
      }
    }

    _romPath = path;
    final title = gameTitle();
    presentation.status.value =
        title.isEmpty ? 'ROM loaded' : 'Playing: $title';

    // One frame so the texture shows something before start().
    if (isLoaded) {
      _b.runFrame();
      if (!useExternalTexture) {
        await _presentFallbackFromNative();
      }
    }
  }

  @override
  Future<void> flushSave() async {
    if (!_created || !isLoaded) return;
    _b.flushSave();
  }

  @override
  Future<bool> wipeCartridgeSave() async {
    if (!_created || !isLoaded) return false;
    return _b.wipeCartridgeSave() != 0;
  }

  /// Soft-reset the loaded ROM (title/boot) without unloading it.
  ///
  /// Clears held keys and presents one frame so the screen updates immediately.
  /// Does not touch savestates or battery `.sav` files.
  @override
  Future<void> reset() async {
    _ensureCreated();
    if (!isLoaded) return;
    _clearKeys();
    _b.reset();
    _b.runFrame();
    if (useExternalTexture) {
      _b.presentFrame();
    } else {
      await _presentFallbackFromNative();
    }
  }

  @override
  String gameTitle() {
    if (!isLoaded) return '';
    final buf = malloc.allocate<Uint8>(32);
    try {
      _b.gameTitle(buf.cast<Utf8>(), 32);
      return buf.cast<Utf8>().toDartString();
    } finally {
      malloc.free(buf);
    }
  }

  void _clearKeys() {
    _keys = 0;
    if (_created) _b.setKeys(0);
  }

  @override
  void setInput(EmulatorInput key, bool pressed) {
    final bit = key.bit;
    if (pressed) {
      _keys |= bit;
    } else {
      _keys &= ~bit;
    }
    if (_created) {
      _b.setKeys(_keys);
    }
  }

  @override
  void setInputMask(int mask) {
    _keys = mask;
    if (_created) {
      _b.setKeys(_keys);
    }
  }

  @override
  void setVolume(double vol01) {
    if (_created) _b.setVolume(vol01.clamp(0.0, 1.0));
  }

  @override
  double get speed => _pacer.speed;

  @override
  void setSpeed(double speed) {
    _pacer.speed = speed;
  }

  @override
  Future<void> start() async {
    if (!isLoaded || _running) return;
    _running = true;
    try {
      await _audio.start();
    } catch (e) {
      debugPrint('Audio start failed: $e');
    }
    if (useExternalTexture && presentation.textureId.value == null) {
      final id = await GbaVideoTexture.ensureCreated(
        width: width,
        height: height,
      );
      presentation.textureId.value = id;
    }
    // Drive at display refresh: 1 GBA frame per vsync ≈ real-time on 60 Hz.
    _pacer.reset();
    SchedulerBinding.instance.scheduleFrameCallback(_onVsync);
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  Future<void> stop() async {
    _running = false;
    _clearKeys();
    _pacer.reset();
    try {
      await _audio.stop();
    } catch (_) {}
    await flushSave();
  }

  void stepFrame() {
    if (!isLoaded) return;
    _b.runFrame();
    if (!useExternalTexture) {
      unawaited(_presentFallbackFromNative());
    }
  }

  void _onVsync(Duration timestamp) {
    if (!_running || !isLoaded) return;

    try {
      final frames = _pacer.consume(timestamp);
      // Prefer bulk native path when catching up more than one frame.
      if (frames == 1) {
        _b.runFrame();
      } else if (frames > 1) {
        _b.runFrames(frames);
      }
    } catch (e) {
      debugPrint('runFrame failed: $e');
    }

    // Desktop-only software path (Android presents inside C).
    if (!useExternalTexture) {
      unawaited(_presentFallbackFromNative());
    }

    if (_running) {
      SchedulerBinding.instance.scheduleFrameCallback(_onVsync);
      SchedulerBinding.instance.scheduleFrame();
    }
  }

  @override
  Future<Uint8List?> captureState() async {
    if (!isLoaded) return null;
    final size = _b.stateSize();
    if (size <= 0) return null;
    final ptr = malloc.allocate<Uint8>(size);
    try {
      final written = _b.saveState(ptr.cast<Void>(), size);
      if (written <= 0) return null;
      return Uint8List.fromList(ptr.asTypedList(written));
    } finally {
      malloc.free(ptr);
    }
  }

  @override
  Future<bool> applyState(Uint8List bytes) async {
    if (!isLoaded || bytes.isEmpty) return false;
    final ptr = malloc.allocate<Uint8>(bytes.length);
    try {
      ptr.asTypedList(bytes.length).setAll(0, bytes);
      final loaded = _b.loadState(ptr.cast<Void>(), bytes.length) != 0;
      if (loaded) {
        if (useExternalTexture) {
          _b.presentFrame();
        } else {
          await _presentFallbackFromNative();
        }
      }
      return loaded;
    } finally {
      malloc.free(ptr);
    }
  }

  Future<void> _presentFallbackFromNative() async {
    if (!_created || !isLoaded) return;
    final w = _b.frameWidth();
    final h = _b.frameHeight();
    final byteCount = _b.frameBytes();
    final ptr = _b.frameBuffer();
    if (ptr.address == 0 || byteCount <= 0) return;

    final scratch = presentation.pixelScratch;
    final Uint8List pixels;
    if (scratch != null && scratch.length == byteCount) {
      pixels = scratch;
    } else {
      pixels = Uint8List(byteCount);
      presentation.pixelScratch = pixels;
    }
    pixels.setAll(0, ptr.asTypedList(byteCount));

    // mGBA 32-bit color_t is little-endian RGBA (R in the low byte), matching
    // Flutter's raw rgba8888 layout — not bgra8888.
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;
    codec.dispose();
    descriptor.dispose();

    presentation.fallbackImage = image;
  }

  void _ensureCreated() {
    if (!_created) {
      throw StateError('GbaCore not created');
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    presentation.dispose();
    await GbaVideoTexture.dispose();
    _audio.dispose();
    if (_created) {
      _b.destroy();
      _created = false;
    }
  }
}
