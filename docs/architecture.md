# Architecture boundaries

Dependency direction (a layer must not import a layer above it):

```text
shell (Flutter screens, widgets, navigation)
        ↓ intents / view state
application (controllers and use cases)
        ↓ contracts
core (emulation and storage abstractions)
        ↑ implementations
infrastructure (mGBA FFI, filesystem, library persistence)
        ↑
native (GbaSession core + Android platform adapter)
```

## Dart layout

| Path | Role |
|------|------|
| `lib/core/` | Platform-neutral contracts only (no Flutter/FFI/`File`) |
| `lib/application/` | Use-cases (e.g. `PlaySessionController`) |
| `lib/infrastructure/` | FFI adapters, save paths, game library, repositories |
| `lib/shell/play/` | In-game UI (pad, surface, pause menu, game screen, layout) |
| `lib/shell/home/` | Home shelf, library grid, settings, display settings |
| `lib/shell/common/` | Shared chrome (toast, loading dock, SFX, art, sheets) |
| `lib/shell/theme/` | Design tokens |

See [shell.md](shell.md) for shell art pipeline, shared chrome, and play factory rules.
| `lib/ui/`, `lib/native/`, `lib/services/` | Thin re-exports for older import paths |
| `lib/models/` | Pure data types for the library shelf |

## Rules

- `lib/core` is Dart-only: no Flutter, FFI, `File`, paths, or UI.
- `lib/application` coordinates contracts. It does not know C symbols, JSON,
  Android method channels, or absolute storage paths.
- `lib/shell` sends user intent and renders results; it does not own
  savestate files or compute storage paths.
- `lib/infrastructure` implements core contracts. **Play-session** savestate I/O
  goes only through `SaveStateRepository` / `FileSaveStateRepository`.
  **Packaging** (`ZipGamePackService`, behind `GamePackPort`) is a second
  privileged writer of the same play-data trees (`.sav`, `states/<id>/*`) for
  bulk backup/restore — intentional dual-writer exception; session code must
  not grow zip concerns.
- `native/mgba` is vendored upstream. Local native code lives in
  `native/bridge` and must not modify mGBA unnecessarily.

## Native layout

| File | Role |
|------|------|
| `native/bridge/gba_bridge.h` | Public FFI ABI (session + legacy flat API) |
| `native/bridge/gba_bridge.c` | Emulation session: mGBA, video buffer, PCM ring |
| `native/bridge/gba_session_internal.h` | Shared session struct + audio pull for platform |
| `native/bridge/gba_platform_android.c` | EGL present, ANativeWindow, AAudio, JNI |
| `native/bridge/gba_platform_android.h` | Platform entry points used by the session |

Emulation state lives in an opaque `GbaSession` (`gba_session_create` /
`gba_session_destroy`). The legacy flat ABI (`gba_create` / `gba_run_frame` /
…) uses the process default session so existing Dart FFI keeps working.

Platform ownership stays out of the session core:

- EGL / GLES present and `ANativeWindow` attach
- AAudio stream + JNI surface hooks
- Flutter Texture method-channel setup (Dart side)

Do not add new UI or Flutter-only calls into the emulator ABI.
