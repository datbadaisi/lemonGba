/// Side effects chosen inside the pause sheet; applied after it dismisses.
///
/// Exclusive variants — no multi-bool bags.
sealed class PauseMenuAction {
  const PauseMenuAction();
}

/// Quick-save then leave play.
final class PauseExit extends PauseMenuAction {
  const PauseExit();
}

/// Wipe cartridge battery save and soft-reset (after confirm).
final class PauseNewGame extends PauseMenuAction {
  const PauseNewGame();
}

final class PauseLoadQuick extends PauseMenuAction {
  const PauseLoadQuick(this.slot);
  final int slot;
}

final class PauseSaveManual extends PauseMenuAction {
  const PauseSaveManual(this.slot);
  final int slot;
}

final class PauseLoadManual extends PauseMenuAction {
  const PauseLoadManual(this.slot);
  final int slot;
}
