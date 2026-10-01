import '../../application/play/play_session_controller.dart';
import '../../shell/play/emulator_renderer.dart';
import '../native/gba_core.dart';
import '../storage/file_save_state_repository.dart';
import '../storage/save_paths.dart';
import 'mgba_renderer_adapter.dart';

/// Builds a ready-to-play session for the shell without path math in UI code.
///
/// Owns composition of [PlaySessionController] + renderer + cartridge save path
/// so [HomeScreen] only navigates with a prepared bundle.
class PlaySessionFactory {
  PlaySessionFactory({
    required this.core,
    required this.paths,
  });

  final GbaCore core;
  final SavePaths paths;

  PlaySessionBundle open({
    required String romPath,
    required String gameId,
  }) {
    return PlaySessionBundle(
      controller: PlaySessionController(
        emulator: core,
        saveStates: FileSaveStateRepository(paths),
        romPath: romPath,
        gameId: gameId,
        cartridgeSavePath: paths.savPathForGame(gameId),
      ),
      renderer: MgbaRendererAdapter(core),
    );
  }
}

/// Controller + presentation port for one push of [GameScreen].
class PlaySessionBundle {
  const PlaySessionBundle({
    required this.controller,
    required this.renderer,
  });

  final PlaySessionController controller;
  final EmulatorRenderer renderer;
}
