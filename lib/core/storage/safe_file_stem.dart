/// Pure filename stem sanitizer for ROM names and pack export filenames.
///
/// Strips path segments and aggressive non-ASCII-friendly punctuation; used
/// for on-disk ROM stems under app storage.
String safeFileStem(String name, {int maxLength = 48}) {
  var stem = name.trim();
  // Drop path segments if a path-like string is passed.
  final slash = stem.replaceAll('\\', '/').lastIndexOf('/');
  if (slash >= 0) stem = stem.substring(slash + 1);
  // Strip a single extension if present.
  final dot = stem.lastIndexOf('.');
  if (dot > 0) stem = stem.substring(0, dot);

  stem = stem.replaceAll(RegExp(r'[^\w\-. ]+'), '_').trim();
  // Collapse runs of underscores and strip edge underscores from punctuation.
  stem = stem.replaceAll(RegExp(r'_+'), '_');
  stem = stem.replaceAll(RegExp(r'^_+|_+$'), '');
  stem = stem.trim();
  if (stem.isEmpty) stem = 'game';
  if (stem.length > maxLength) stem = stem.substring(0, maxLength);
  return stem;
}

/// Human-facing pack export title segment.
///
/// Keeps spaces and normal letters (including accents) so the user clearly
/// sees the game name. Only strips characters illegal in common filesystems:
/// `<>:"/\|?*` and control chars. Does **not** inject content hashes.
///
/// Examples:
/// - `Pokémon Emerald 2026-08-05_143052.saves.lemongba.zip`
/// - `Fire Emblem 2026-08-05_143052.full.lemongba.zip`
String safePackTitleStem(String name, {int maxLength = 64}) {
  var stem = name.trim();
  final slash = stem.replaceAll('\\', '/').lastIndexOf('/');
  if (slash >= 0) stem = stem.substring(slash + 1);

  // Drop a trailing known pack extension if the user pasted a filename.
  final lower = stem.toLowerCase();
  for (final ext in [
    '.saves.multi.lemongba.zip',
    '.full.multi.lemongba.zip',
    '.saves.lemongba.zip',
    '.full.lemongba.zip',
    '.lemongba.zip',
    '.zip',
  ]) {
    if (lower.endsWith(ext)) {
      stem = stem.substring(0, stem.length - ext.length).trim();
      break;
    }
  }

  // Illegal path characters + controls → space, then collapse whitespace.
  stem = stem.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
  stem = stem.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Avoid trailing dots/spaces (Windows).
  stem = stem.replaceAll(RegExp(r'[. ]+$'), '').trim();
  if (stem.isEmpty) stem = 'Game';
  if (stem.length > maxLength) {
    stem = stem.substring(0, maxLength).replaceAll(RegExp(r'[. ]+$'), '').trim();
    if (stem.isEmpty) stem = 'Game';
  }
  return stem;
}

/// Local wall-clock stamp safe for filenames (no `:` — Windows rejects it).
///
/// Example: `2026-08-05_143052`
String packFileTimestamp([DateTime? at]) {
  final t = (at ?? DateTime.now()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-'
      '${two(t.month)}-'
      '${two(t.day)}_'
      '${two(t.hour)}'
      '${two(t.minute)}'
      '${two(t.second)}';
}

/// Suggested export filename for a Lemon pack.
///
/// - Save: `{Game Title} 2026-08-05_143052.saves.lemongba.zip`
/// - Full: `{Game Title} 2026-08-05_143052.full.lemongba.zip`
String packSuggestedFileName({
  required String title,
  required bool fullPack,
  DateTime? at,
}) {
  final stem = safePackTitleStem(title);
  final stamp = packFileTimestamp(at);
  final kind = fullPack ? 'full' : 'saves';
  return '$stem $stamp.$kind.lemongba.zip';
}

/// Suggested export filename for a multi Lemon pack.
///
/// - Save: `Multi 3 games 2026-08-05_143052.saves.multi.lemongba.zip`
/// - Full: `Multi 3 games 2026-08-05_143052.full.multi.lemongba.zip`
String multiPackSuggestedFileName({
  required int gameCount,
  required bool fullPack,
  DateTime? at,
}) {
  final stamp = packFileTimestamp(at);
  final kind = fullPack ? 'full' : 'saves';
  final n = gameCount == 1 ? '1 game' : '$gameCount games';
  return 'Multi $n $stamp.$kind.multi.lemongba.zip';
}
