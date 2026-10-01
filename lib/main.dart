import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'infrastructure/entitlements/pro_access.dart';
import 'infrastructure/entitlements/pro_billing.dart';
import 'infrastructure/native/gba_core.dart';
import 'core/storage/game_pack_port.dart';
import 'infrastructure/library/game_library.dart';
import 'infrastructure/play/play_layout_store.dart';
import 'infrastructure/storage/save_paths.dart';
import 'infrastructure/storage/zip_game_pack_service.dart';
import 'shell/home/home_screen.dart';
import 'shell/common/lemon_loading.dart';
import 'shell/common/shell_art.dart';
import 'shell/common/shell_art_warmer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only (home + play). Both sides: Android MainActivity remaps
  // Flutter's USER_LANDSCAPE to SENSOR_LANDSCAPE so reverse landscape still
  // follows the phone when system auto-rotate is off.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Hide status / nav bars app-wide (home + play) for console-like chrome.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const GbaEmulatorApp());
}

class GbaEmulatorApp extends StatefulWidget {
  const GbaEmulatorApp({super.key});

  @override
  State<GbaEmulatorApp> createState() => _GbaEmulatorAppState();
}

class _GbaEmulatorAppState extends State<GbaEmulatorApp> {
  late final Future<GbaCore> _coreFuture = GbaCore.create();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lemonGba',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Nunito',
        colorScheme: ColorScheme.fromSeed(
          seedColor: LemonBrand.lemon,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _CoreBootGate(coreFuture: _coreFuture),
    );
  }

  @override
  void dispose() {
    _coreFuture.then((c) => c.dispose());
    super.dispose();
  }
}

/// Boot payload ready for home after lemon dock + async init.
class _BootData {
  const _BootData({
    required this.core,
    required this.paths,
    required this.library,
    required this.packs,
    required this.pro,
    required this.billing,
    required this.playLayout,
  });

  final GbaCore core;
  final SavePaths paths;
  final GameLibrary library;
  final GamePackPort packs;
  final ProAccess pro;
  final ProBilling billing;
  final PlayLayoutStore playLayout;
}

/// Holds the lemon dock until core **and** home library are ready, then
/// crossfades the dock away **over** an already-mounted [HomeScreen].
///
/// Important: home mounts at fade **start**, not fade **end**. Mounting only
/// after the dock is gone left a long pure-black gap (fade 560ms + home still
/// at t=0) even though loading work was already done during the dock.
class _CoreBootGate extends StatefulWidget {
  const _CoreBootGate({required this.coreFuture});

  final Future<GbaCore> coreFuture;

  @override
  State<_CoreBootGate> createState() => _CoreBootGateState();
}

class _CoreBootGateState extends State<_CoreBootGate> {
  _BootData? _boot;
  Object? _error;
  bool _ready = false;

  /// Overlay still in the tree (opaque or fading).
  bool _showLoader = true;

  /// Opacity driver for the dock layer; false starts the dissolve.
  bool _loaderOpaque = true;

  /// Mounted under the dock once handoff begins (not after fade completes).
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _bootApp();
  }

  Future<void> _bootApp() async {
    try {
      // Core + library in parallel so the dock animation covers both.
      final results = await Future.wait<Object>([
        widget.coreFuture,
        _loadLibrary(),
      ]);
      final core = results[0] as GbaCore;
      final lib =
          results[1]
              as (
                SavePaths,
                GameLibrary,
                GamePackPort,
                ProAccess,
                ProBilling,
                PlayLayoutStore,
              );
      if (!mounted) return;
      setState(() {
        _boot = _BootData(
          core: core,
          paths: lib.$1,
          library: lib.$2,
          packs: lib.$3,
          pro: lib.$4,
          billing: lib.$5,
          playLayout: lib.$6,
        );
        _ready = true;
      });
      // First page only during dock; chunked fill continues after home mounts.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _boot == null) return;
        ShellArt.configureImageCache();
        unawaited(ShellArtWarmer.warmBootPage(context, _boot!.library));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _ready = true;
      });
    }
  }

  Future<
    (
      SavePaths,
      GameLibrary,
      GamePackPort,
      ProAccess,
      ProBilling,
      PlayLayoutStore,
    )
  >
  _loadLibrary() async {
    final paths = await SavePaths.open();
    await paths.ensureDirs();
    final pro = await ProAccess.open(paths);
    final playLayout = await PlayLayoutStore.open(paths);
    final library = GameLibrary(paths, pro: pro);
    await library.load();
    final packs = ZipGamePackService(paths: paths, library: library);
    await packs.recoverInterruptedSwaps();
    final billing = ProBilling(pro);
    // Start Billing after load — purchase stream + product query + silent restore.
    unawaited(billing.start());
    return (paths, library, packs, pro, billing, playLayout);
  }

  void _onLoaderFinished() {
    if (!mounted || !_loaderOpaque) return;
    // Mount home *under* the dock, then dissolve — user never sits on an
    // empty black frame waiting for fade-out + HomeScreen first frame.
    setState(() {
      if (_boot != null) _showHome = true;
      _loaderOpaque = false;
    });
  }

  void _onLoaderFadeEnd() {
    if (!mounted || _loaderOpaque || !_showLoader) return;
    setState(() => _showLoader = false);
  }

  Widget _errorBody() {
    return Scaffold(
      backgroundColor: LemonBrand.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to start lemonGba.\n\n$_error\n\n'
            'Build/run on Android so CMake can compile mGBA + the bridge.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: LemonBrand.cream),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boot = _boot;
    final showError = _error != null && boot == null && !_showLoader;

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: LemonBrand.bg),
        if (_showHome && boot != null)
          HomeScreen(
            key: const ValueKey('home'),
            core: boot.core,
            paths: boot.paths,
            library: boot.library,
            packs: boot.packs,
            pro: boot.pro,
            billing: boot.billing,
            playLayout: boot.playLayout,
          ),
        if (showError) _errorBody(),
        if (_showLoader)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _loaderOpaque ? 1 : 0,
              duration: LemonBootMotion.handoffFade,
              curve: LemonBootMotion.handoffCurve,
              onEnd: _onLoaderFadeEnd,
              child: Scaffold(
                backgroundColor: LemonBrand.bg,
                body: LemonLoadingScreen(
                  message: 'Starting lemonGba…',
                  isReady: _ready,
                  onFinished: _onLoaderFinished,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
