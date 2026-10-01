import 'package:flutter_test/flutter_test.dart';
import 'package:gba_emulator/core/storage/safe_file_stem.dart';

void main() {
  test('sanitizes and truncates', () {
    expect(safeFileStem('Hello World!!'), 'Hello World');
    expect(safeFileStem('a' * 60, maxLength: 40).length, 40);
    expect(safeFileStem(''), 'game');
    expect(safeFileStem('path/to/My Game.gba'), 'My Game');
    expect(safeFileStem('   '), 'game');
  });

  test('pack titles keep game name and spaces', () {
    expect(safePackTitleStem('Pokémon Emerald'), 'Pokémon Emerald');
    expect(safePackTitleStem('Fire Emblem: The Sacred Stones'), 'Fire Emblem The Sacred Stones');
    final at = DateTime(2026, 8, 5, 14, 30, 52);
    expect(
      packSuggestedFileName(title: 'Pokémon Emerald', fullPack: false, at: at),
      'Pokémon Emerald 2026-08-05_143052.saves.lemongba.zip',
    );
    expect(
      packSuggestedFileName(title: 'Pokémon Emerald', fullPack: true, at: at),
      'Pokémon Emerald 2026-08-05_143052.full.lemongba.zip',
    );
  });
}
