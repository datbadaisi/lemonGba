# Contributing

Thanks for helping improve lemonGba. Please open an issue for a bug or proposed
change before starting a large patch.

## Set up

Use Flutter stable, the Android SDK and NDK, and CMake 3.22.1. From the repo
root, run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <android-device-id>
```

The Android build compiles the native mGBA core and bridge automatically.

## Pull requests

- Keep changes focused and explain how you tested them.
- Do not commit commercial game ROMs, proprietary BIOS files, personal saves,
  copyrighted game artwork or screenshots containing it, signing keys, or
  service credentials. Do not add the optional upstream mGBA cinema test ROMs.
- Contributions to project-authored files are submitted under GPL-3.0-only.
  Changes to MPL-covered files in `native/mgba` must preserve their MPL-2.0
  notices and remain available under MPL-2.0.
- Preserve copyright and license notices in third-party files.

For security issues, follow [SECURITY.md](SECURITY.md) instead of opening a
public issue.
