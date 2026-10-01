import 'package:flutter/services.dart';

import 'gba_bindings.dart';

/// Android audio ownership lives in the native bridge. AAudio's realtime
/// callback consumes PCM directly from the mGBA ring, avoiding Dart/platform
/// channel traffic on every audio buffer.
class GbaAudioPlayer {
  GbaAudioPlayer(this._bindings);

  final GbaBindings _bindings;
  static const MethodChannel _channel = MethodChannel('gba_emulator/audio');
  bool _setup = false;
  bool _playing = false;

  int get sampleRate => _bindings.audioSampleRate();

  Future<void> setup() async {
    if (_setup) return;
    final available = await _channel.invokeMethod<bool>('available') ?? false;
    if (!available) {
      throw UnsupportedError(
        'This Android build requires API 26 or newer for AAudio',
      );
    }
    _setup = true;
  }

  Future<void> start() async {
    await setup();
    if (_playing) return;
    final started = await _channel.invokeMethod<bool>('start') ?? false;
    if (!started) throw StateError('Could not start native AAudio output');
    _playing = true;
  }

  Future<void> stop() async {
    if (!_setup) return;
    _playing = false;
    await _channel.invokeMethod<void>('stop');
  }

  void dispose() {
    _playing = false;
  }
}
