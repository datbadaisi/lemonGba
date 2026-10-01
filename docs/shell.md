# Shell standards

UI lives under `lib/shell/`. Prefer importing shell modules directly;
`lib/ui/` is a thin re-export shim for older paths.

## Art architecture (disk thumbs + RAM warm)

### On disk (`covers/`)

| File | Role |
|------|------|
| `{id}_avatar_{stamp}.jpg` (etc.) | **Original** import (any size); stamp changes on each pick |
| `{id}_avatar_{stamp}_tile.png` | Tile paint ≤768px edge |
| `{id}_avatar_{stamp}_bg.png` | Backdrop paint ≤1280px edge |
| `{id}_cover_{stamp}.*` + `_tile` / `_bg` | Same for banner |

Each replace mints a **new path** so Flutter `ImageCache` does not keep the
previous decode under a stable file name. Written by `ArtThumbnailer` on
import (`GameLibrary._setArt`) and migrated by `ensureArtThumbnails()` for
older libraries.

UI paths:
- `avatarAbsolutePath` → `*_tile.png`
- `backdropAbsolutePath` → cover/avatar `*_bg.png`

### In RAM (session)

| Phase | What | Who |
|-------|------|-----|
| **Boot dock** | Decode first ~24 **tile** PNGs into ImageCache | `ShellArtWarmer.warmBootPage` |
| **Home shelf** | Shelf tiles + backdrop thumbs | `ShellArtWarmer.warmShelf` |
| **Background** | Rest of library, chunks of 8 | `ShellArtWarmer.scheduleBackgroundFill` |
| **Library scroll** | Visible window + lookahead (ad-aware rows) | `ShellArtWarmer.warmFromLibraryLayout` |

Thumbs are small → warm is cheap; ImageCache hit ⇒ paint is instant.

### Rules

1. **Never paint full-res originals** on tiles / backdrop.
2. **One memCache key** via `ShellArt.avatarMemCacheWidth` (≤768).
3. **Never** block handoff on full-library work.
4. Paint only `ShellFileImage` / `ShellCoverImage` (`ResizeImagePolicy.fit`).
5. No `File.existsSync` in `build()`.

## Shared chrome

| Widget / API | Use for |
|--------------|---------|
| `ShellPageHeader` | Sub-page headers |
| `showShellConfirmDialog` | Destructive confirms |
| `ShellSheet*` | Library bottom sheets |
| `ShellPressable` | Press-scale chrome |
| `ShellArt` / `ShellArtWarmer` | Paint sizes + warm schedule |

## Play composition

Use `PlaySessionFactory` → `PlaySessionBundle`, then push `GameScreen`.

Play control geometry lives in `shell/play/layout/play_layout.dart`
(`PlayLayout.resolve` + optional `PlayLayoutProfile` from `PlayLayoutStore` /
`play_layout.json`). Users edit it under **Settings → Control layout**.
Resolve stores stock rects once per frame; the editor uses `PlayLayoutDraft` +
`LayoutResizeSession` (corners / pinch share one scale model). Pad widgets
honor `PadInteractionScope(interactive: false)` in the editor.
Controls that overlap the game frame render at `PlaySizes.overlapOpacity`.

Pad input uses core `EmulatorInput` (no parallel `GbaKey` enum). Pause menu
returns a sealed `PauseMenuAction`. Virtual pad is split across
`virtual_dpad.dart`, `virtual_pad_buttons.dart`, and `virtual_circle_controls.dart`.

Home shelf session state (absolute `focusedId`, busy gate, import chrome) is
owned by `HomeShelfController`. Pack import/export UI helpers live in
`game_pack_ui.dart`; `backup_restore_sheet.dart` is the per-game sheet only.
Library grid is split across `library_grid_screen` / `library_grid_body` /
`library_header` / `library_empty_body` / `library_group_sheets`.
Long-press actions (home + library) share `showLibraryGameActions`.
`GameLibrary` is split into catalog + mixins (`game_library_groups` /
`game_library_art` / `game_library_pack`).

## Out of scope

- Play pad / pause session semantics  
- Native mGBA bridge  
