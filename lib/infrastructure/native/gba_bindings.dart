import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Low-level dart:ffi bindings for [libgba_core].
class GbaBindings {
  GbaBindings._(DynamicLibrary lib)
    : create = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_create',
      ),
      destroy = lib.lookupFunction<Void Function(), void Function()>(
        'gba_destroy',
      ),
      bridgeVersion = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_bridge_version',
      ),
      loadRom = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf8>),
            int Function(Pointer<Utf8>)
          >('gba_load_rom'),
      loadRomEx = lib
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)
          >('gba_load_rom_ex'),
      flushSave = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_flush_save',
      ),
      wipeCartridgeSave = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_wipe_cartridge_save',
      ),
      runFrame = lib.lookupFunction<Void Function(), void Function()>(
        'gba_run_frame',
      ),
      runFrames = lib.lookupFunction<Void Function(Int32), void Function(int)>(
        'gba_run_frames',
      ),
      reset = lib.lookupFunction<Void Function(), void Function()>('gba_reset'),
      setKeys = lib.lookupFunction<Void Function(Uint32), void Function(int)>(
        'gba_set_keys',
      ),
      frameWidth = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_frame_width',
      ),
      frameHeight = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_frame_height',
      ),
      frameBytes = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_frame_bytes',
      ),
      frameBuffer = lib
          .lookupFunction<Pointer<Uint8> Function(), Pointer<Uint8> Function()>(
            'gba_frame_buffer',
          ),
      copyFrame = lib
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Int32),
            int Function(Pointer<Uint8>, int)
          >('gba_copy_frame'),
      setNativeWindow = lib
          .lookupFunction<Void Function(Int64), void Function(int)>(
            'gba_set_native_window',
          ),
      hasNativeWindow = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_has_native_window',
      ),
      presentFrame = lib.lookupFunction<Void Function(), void Function()>(
        'gba_present_frame',
      ),
      audioSampleRate = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_audio_sample_rate',
      ),
      audioAvailable = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_audio_available',
      ),
      audioRead = lib
          .lookupFunction<
            Int32 Function(Pointer<Int16>, Int32),
            int Function(Pointer<Int16>, int)
          >('gba_audio_read'),
      setVolume = lib
          .lookupFunction<Void Function(Float), void Function(double)>(
            'gba_set_volume',
          ),
      setMuted = lib.lookupFunction<Void Function(Int32), void Function(int)>(
        'gba_set_muted',
      ),
      stateSize = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_state_size',
      ),
      saveState = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('gba_save_state'),
      loadState = lib
          .lookupFunction<
            Int32 Function(Pointer<Void>, Int32),
            int Function(Pointer<Void>, int)
          >('gba_load_state'),
      isLoaded = lib.lookupFunction<Int32 Function(), int Function()>(
        'gba_is_loaded',
      ),
      gameTitle = lib
          .lookupFunction<
            Void Function(Pointer<Utf8>, Int32),
            void Function(Pointer<Utf8>, int)
          >('gba_game_title'),
      coreVersion = lib
          .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
            'gba_core_version',
          );

  final int Function() create;
  final void Function() destroy;
  final int Function() bridgeVersion;
  final int Function(Pointer<Utf8>) loadRom;
  final int Function(Pointer<Utf8>, Pointer<Utf8>) loadRomEx;
  final int Function() flushSave;
  final int Function() wipeCartridgeSave;
  final void Function() runFrame;
  final void Function(int) runFrames;
  final void Function() reset;
  final void Function(int) setKeys;
  final int Function() frameWidth;
  final int Function() frameHeight;
  final int Function() frameBytes;
  final Pointer<Uint8> Function() frameBuffer;
  final int Function(Pointer<Uint8>, int) copyFrame;
  final void Function(int) setNativeWindow;
  final int Function() hasNativeWindow;
  final void Function() presentFrame;
  final int Function() audioSampleRate;
  final int Function() audioAvailable;
  final int Function(Pointer<Int16>, int) audioRead;
  final void Function(double) setVolume;
  final void Function(int) setMuted;
  final int Function() stateSize;
  final int Function(Pointer<Void>, int) saveState;
  final int Function(Pointer<Void>, int) loadState;
  final int Function() isLoaded;
  final void Function(Pointer<Utf8>, int) gameTitle;
  final Pointer<Utf8> Function() coreVersion;

  static GbaBindings open() => GbaBindings._(_openLibrary());

  static DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libgba_core.so');
    }
    if (Platform.isWindows) {
      try {
        return DynamicLibrary.open('gba_core.dll');
      } catch (_) {
        return DynamicLibrary.open('libgba_core.dll');
      }
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libgba_core.so');
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('libgba_core.dylib');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
