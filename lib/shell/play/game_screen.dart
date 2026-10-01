import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../application/play/play_session_controller.dart';
import '../../core/emulation/emulator_input.dart';
import '../../core/emulation/emulator_session.dart';
import '../../core/emulation/game_speed.dart';
import '../../infrastructure/play/play_layout_store.dart';
import '../common/dock_chiptune.dart' show AppSfx;
import '../common/lemon_loading.dart';
import '../common/app_toast.dart';
import '../common/console_chrome.dart';
import '../theme/play_tokens.dart';
import 'emulator_renderer.dart';
import 'layout/play_layout.dart';
import 'pause_menu_sheet.dart';
import 'play_surface.dart';

/// Returned to the home shelf when the user leaves play.
class GameSessionResult {
  const GameSessionResult({
    this.headerTitle,
    this.playDuration = Duration.zero,
  });

  final String? headerTitle;

  /// Active play time this session (excludes pause menu / app background).
  final Duration playDuration;
}

/// Play shell: boots a [PlaySessionController], shows the virtual pad, and
/// routes pause-menu intents. Persistence and emulation stay outside this
/// widget.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.renderer,
    required this.playLayout,
    this.onCheckpointPlayTime,
  });

  final PlaySessionController controller;
  final EmulatorRenderer renderer;
  final PlayLayoutStore playLayout;

  /// Persist a closed play-time delta (lifecycle pause / background) so a
  /// process kill does not lose the session total. Home should call
  /// [GameLibrary.addPlayTime]. [GameSessionResult.playDuration] only reports
  /// time not yet flushed through this callback.
  final Future<void> Function(Duration delta)? onCheckpointPlayTime;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  String? _error;

  /// ROM boot finished (success or failure). Loader may still be animating.
  bool _bootReady = false;

  /// Overlay still in the tree (opaque or fading).
  bool _showLoader = true;

  /// Opacity driver for the dock layer; false starts the dissolve.
  bool _loaderOpaque = true;

  /// Session emulation rate (snapped to [GameSpeed.steps]).
  double _speed = GameSpeed.normal;

  /// Top snackbar visibility (speed button / drag).
  bool _speedHudVisible = false;
  Timer? _speedHudTimer;

  /// True after a double-tap pause until the user double-taps resume (or leaves).
  /// Keeps lifecycle resume from auto-starting while the player wants pause.
  bool _userPaused = false;

  /// Closed play segments (pause / background already folded in).
  Duration _playAccumulated = Duration.zero;

  /// Wall clock start of the current running segment, if any.
  DateTime? _playSegmentStart;

  /// Portion of [_playAccumulated] already handed to [onCheckpointPlayTime].
  Duration _playCheckpointed = Duration.zero;

  EmulatorSession get _session => widget.controller.emulator;

  void _setKey(EmulatorInput key, bool pressed) =>
      _session.setInput(key, pressed);

  void _clearKeys() => _session.setInputMask(0);

  void _beginPlaySegment() {
    _playSegmentStart ??= DateTime.now();
  }

  void _endPlaySegment() {
    final start = _playSegmentStart;
    if (start == null) return;
    _playAccumulated += DateTime.now().difference(start);
    _playSegmentStart = null;
  }

  Duration get _sessionPlayDuration {
    var total = _playAccumulated;
    final start = _playSegmentStart;
    if (start != null) {
      total += DateTime.now().difference(start);
    }
    return total;
  }

  /// Unflushed session play time (excludes open segment after [_endPlaySegment]).
  Duration get _uncheckpointedPlayDuration {
    final remaining = _sessionPlayDuration - _playCheckpointed;
    return remaining < Duration.zero ? Duration.zero : remaining;
  }

  /// Flush closed-segment play time to the library (no double-count on exit).
  ///
  /// Only whole seconds are checkpointed so [addPlayTime] rounding cannot
  /// over-count; sub-second remainder stays for a later flush or route exit.
  Future<void> _flushPlayTimeCheckpoint() async {
    final cb = widget.onCheckpointPlayTime;
    if (cb == null) return;
    final delta = _playAccumulated - _playCheckpointed;
    final addSec = delta.inMilliseconds ~/ 1000;
    if (addSec <= 0) return;
    final flushed = Duration(seconds: addSec);
    try {
      await cb(flushed);
      _playCheckpointed += flushed;
    } catch (_) {
      // Leave [_playCheckpointed] so exit can retry via [GameSessionResult].
    }
  }

  GameSessionResult _sessionResult() {
    final title = _session.gameTitle().trim();
    return GameSessionResult(
      headerTitle: title.isEmpty ? null : title,
      playDuration: _uncheckpointedPlayDuration,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speed = GameSpeed.snap(_session.speed);
    _boot();
  }

  void _applySpeed(double next, {bool showHud = false}) {
    final snapped = GameSpeed.snap(next);
    final changed = snapped != _speed;
    if (changed) {
      _speed = snapped;
      _session.setSpeed(snapped);
    }
    if (showHud) {
      // Always reveal (even at min/max) so the user sees current speed.
      _revealSpeedHud();
    } else if (changed && mounted) {
      setState(() {});
    }
  }

  void _revealSpeedHud() {
    _speedHudTimer?.cancel();
    if (!mounted) return;
    setState(() => _speedHudVisible = true);
    _speedHudTimer = Timer(PlayModal.speedHudDuration, () {
      if (!mounted) return;
      setState(() => _speedHudVisible = false);
    });
  }

  void _cycleSpeed() {
    final next = GameSpeed.cycle(_speed);
    unawaited(HapticFeedback.selectionClick());
    _applySpeed(next, showHud: true);
  }

  void _peekSpeedHud() {
    unawaited(HapticFeedback.selectionClick());
    _revealSpeedHud();
  }

  void _onSpeedSliderChanged(double next) {
    unawaited(HapticFeedback.selectionClick());
    _applySpeed(next, showHud: true);
  }

  Future<void> _boot() async {
    try {
      // Load only — do not start AAudio yet. Starting during the lemon dock
      // suspends shell SFX and races lifecycle pauses.
      await widget.controller.load();
      if (!mounted) return;
      setState(() => _bootReady = true);
      _maybeStartPlay();
    } catch (e) {
      if (mounted) {
        setState(() {
          _bootReady = true;
          _error = e.toString();
        });
      }
    }
  }

  void _onLoaderFinished() {
    if (!mounted || !_loaderOpaque) return;
    setState(() => _loaderOpaque = false);
  }

  void _onLoaderFadeEnd() {
    if (!mounted || _loaderOpaque || !_showLoader) return;
    setState(() => _showLoader = false);
    _maybeStartPlay();
    unawaited(_autoLoadQuickSaveIfPresent());
  }

  void _maybeStartPlay() {
    if (!mounted || _showLoader || !_bootReady || _error != null) return;
    if (_userPaused) return;
    if (_session.isRunning || !_session.isLoaded) return;
    unawaited(_startPlay());
  }

  /// Double-tap the game frame: pause if running, resume if user-paused.
  Future<void> _toggleUserPause() async {
    if (_error != null || !_bootReady || _showLoader) return;
    if (!_session.isLoaded) return;

    unawaited(HapticFeedback.selectionClick());

    if (_session.isRunning) {
      await _stopSession();
      if (!mounted) return;
      setState(() => _userPaused = true);
      return;
    }

    // Resume only when this pause was intentional (not mid-boot / menu).
    if (!_userPaused) return;
    setState(() => _userPaused = false);
    await _startPlay();
    if (mounted) setState(() {});
  }

  Future<void> _startPlay() async {
    await widget.controller.start();
    if (!mounted) return;
    if (_session.isRunning) _beginPlaySegment();
  }

  Future<void> _autoLoadQuickSaveIfPresent() async {
    if (!mounted || _error != null) return;
    await widget.controller.loadMostRecentQuick();
  }

  Future<void> _stopSession() async {
    _endPlaySegment();
    _clearKeys();
    await widget.controller.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // End the active segment and checkpoint so OS kill does not lose play time.
      unawaited(() async {
        if (_session.isRunning) {
          await _stopSession();
        } else {
          _endPlaySegment();
        }
        await _flushPlayTimeCheckpoint();
      }());
    } else if (state == AppLifecycleState.resumed) {
      // Honor double-tap pause — do not auto-unpause on app foreground.
      if (!_userPaused) _maybeStartPlay();
    }
  }

  @override
  void dispose() {
    _speedHudTimer?.cancel();
    AppToast.dismiss();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_stopSession());
    super.dispose();
  }

  void _sfxTap() => AppSfx.playTap();

  /// Resume mGBA AAudio after the pause sheet. Caller must already have
  /// awaited [AppSfx.waitTapSettle] so dismiss SFX is not cut off.
  Future<void> _resumePlayAfterMenu() async {
    if (!mounted) return;
    if (_session.isLoaded && !_session.isRunning) {
      await _startPlay();
      if (mounted) setState(() {});
    }
  }

  Future<bool> _performCircularQuickSave({bool showToast = true}) async {
    final ok = await widget.controller.saveNextQuick();
    if (mounted && showToast) {
      AppToast.show(
        context,
        message: ok ? 'Quick Save saved' : 'Save state failed',
        isSuccess: ok,
      );
    }
    return ok;
  }

  Future<void> _onMenuLongPressQuickSave() async {
    if (_error != null || !_bootReady) return;
    if (!_session.isLoaded) return;
    unawaited(HapticFeedback.mediumImpact());
    _sfxTap();
    await _performCircularQuickSave(showToast: true);
  }

  Future<void> _loadQuickSlot(int slot) async {
    final ok = await widget.controller.loadQuick(slot);
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok ? 'Loaded Quick Save $slot' : 'No state in Quick Save $slot',
      isSuccess: ok,
    );
  }

  Future<bool> _saveManualSlot(int slot, {bool showToast = true}) async {
    final ok = await widget.controller.saveManual(slot);
    if (!mounted) return ok;
    if (showToast) {
      AppToast.show(
        context,
        message: ok ? 'Saved slot $slot' : 'Save state failed',
        isSuccess: ok,
      );
    }
    return ok;
  }

  Future<void> _loadManualSlot(int slot) async {
    final ok = await widget.controller.loadManual(slot);
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok ? 'Loaded slot $slot' : 'No state in slot $slot',
      isSuccess: ok,
    );
  }

  Future<void> _exitGame() async {
    await _stopSession();
    if (!mounted) return;
    Navigator.pop(context, _sessionResult());
  }

  Future<void> _startNewGame() async {
    final ok = await widget.controller.startNewGame();
    if (!mounted) return;
    AppToast.show(
      context,
      message: ok ? 'New game started' : 'Could not erase in-game save',
      isSuccess: ok,
    );
  }

  /// Applies [action]. Returns true when the play route was popped (Save & Exit).
  Future<bool> _applyPauseAction(PauseMenuAction action) async {
    switch (action) {
      case PauseExit():
        final saved = await _performCircularQuickSave(showToast: true);
        if (!mounted) return true;
        if (!saved) return false;
        await _exitGame();
        return true;
      case PauseNewGame():
        await _startNewGame();
        return false;
      case PauseLoadQuick(:final slot):
        await _loadQuickSlot(slot);
        return false;
      case PauseSaveManual(:final slot):
        await _saveManualSlot(slot);
        return false;
      case PauseLoadManual(:final slot):
        await _loadManualSlot(slot);
        return false;
    }
  }

  Future<void> _showMenu() async {
    final wasRunning = _session.isRunning;
    // Opening the menu from a user-pause keeps pause after the sheet closes.
    final resumeAfterClose = wasRunning && !_userPaused;
    if (wasRunning) {
      await _stopSession();
      if (mounted) setState(() {});
    } else {
      _clearKeys();
    }
    unawaited(AppSfx.preload());
    AppSfx.warm();
    _sfxTap();
    final timestamps = await Future.wait([
      widget.controller.quickSlotTimes(),
      widget.controller.manualSlotTimes(),
      widget.controller.mostRecentQuickSlot(),
    ]);
    if (!mounted) return;

    final action = await showPauseMenuSheet(
      context: context,
      manualSlotCount: widget.controller.saveStates.manualSlotCount,
      quickSlotCount: widget.controller.saveStates.quickSlotCount,
      quickTimestamps: timestamps[0] as List<DateTime?>,
      manualTimestamps: timestamps[1] as List<DateTime?>,
      lastQuickSlot: timestamps[2] as int?,
      speed: _speed,
      onSpeedChanged: (s) {
        // Apply live while the sheet is open so resume uses the new rate.
        _applySpeed(s, showHud: false);
      },
      onSfxTap: _sfxTap,
    );

    if (!mounted) return;

    // Wait only the remainder of [AppSfx.tapSettle] since the last tap.
    // Sheet reverse animation usually already covers most of the budget;
    // a fixed full delay made every dismiss feel laggy.
    await AppSfx.waitTapSettle();
    if (!mounted) return;

    if (action != null) {
      final leftPlay = await _applyPauseAction(action);
      if (!mounted || leftPlay) return;
    }

    if (resumeAfterClose) await _resumePlayAfterMenu();
  }

  Widget _playOrErrorBody() {
    if (_error != null) {
      return ConsoleChrome(
        backgroundColor: PlayColors.playBg,
        child: _ErrorPane(
          message: _error!,
          onBack: () => Navigator.pop(context, _sessionResult()),
        ),
      );
    }

    return ConsoleChrome(
      backgroundColor: PlayColors.playBg,
      bottom: false,
      child: ListenableBuilder(
        listenable: widget.playLayout,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final layout = PlayLayout.resolve(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                bottomSafe: MediaQuery.viewPaddingOf(context).bottom,
                profile: widget.playLayout.profile,
              );
              return PlaySurface(
                layout: layout,
                renderer: widget.renderer,
                onKey: _setKey,
                onMenu: _showMenu,
                onQuickSave: () {
                  unawaited(_onMenuLongPressQuickSave());
                },
                onGameDoubleTap: () {
                  unawaited(_toggleUserPause());
                },
                userPaused: _userPaused,
                speed: _speed,
                speedHudVisible: _speedHudVisible,
                onSpeedChanged: _onSpeedSliderChanged,
                onSpeedCycle: _cycleSpeed,
                onSpeedHudPeek: _peekSpeedHud,
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showContent = !_loaderOpaque;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_exitGame());
      },
      child: Scaffold(
        backgroundColor: PlayColors.playBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: PlayColors.playBg),
            if (showContent) _playOrErrorBody(),
            if (_showLoader)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _loaderOpaque ? 1 : 0,
                  duration: LemonBootMotion.handoffFade,
                  curve: LemonBootMotion.handoffCurve,
                  onEnd: _onLoaderFadeEnd,
                  child: ColoredBox(
                    color: LemonBrand.bg,
                    child: LemonLoadingScreen(
                      message: 'Loading game…',
                      isReady: _bootReady,
                      onFinished: _onLoaderFinished,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PlaySpacing.content),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert01,
              color: PlayColors.error,
              size: PlaySizes.errorIcon,
            ),
            const SizedBox(height: PlaySpacing.stackTight),
            Text(
              message,
              style: const TextStyle(color: PlayModal.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PlaySpacing.stack),
            FilledButton(onPressed: onBack, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}
