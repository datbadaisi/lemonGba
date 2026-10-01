# lemonGba

A Flutter Game Boy Advance emulator for Android, powered by the bundled
[mGBA](https://github.com/mgba-emu/mgba) core. Games and BIOS files are not
included.

The optional mGBA cinema test ROMs and screenshots containing third-party game
art are excluded from this repository.

## Run

Install Flutter, the Android SDK and NDK, and CMake 3.22.1. Connect an Android
device, then run:

```bash
flutter pub get
flutter run
```

The first build compiles the native core and may take several minutes.

## Configure your own links

Copy [`config/app.json.example`](config/app.json.example) to `config/app.json`.
Set `LEGAL_BASE_URL` to your HTTPS legal site and `PROJECT_SOURCE_URL` to your
public source repository. Then run or build with:

```bash
flutter run --dart-define-from-file=config/app.json
flutter build apk --dart-define-from-file=config/app.json
```

Without these values, the app hides its Privacy, Terms, and project source
links. `config/app.json` stays on your machine and is ignored by Git.

## Deploy legal pages

The legal pages are generated from [`hosting/_build_pages.py`](hosting/_build_pages.py).
To publish your own pages:

1. Copy `hosting/site_config.json.example` to `hosting/site_config.json` and set
   `CONTACT_EMAIL` to your public contact address.
2. Copy `hosting/.firebaserc.example` to `hosting/.firebaserc` and set your
   Firebase project ID.
3. Review the legal text for your app, then run `firebase deploy --only hosting`
   from `hosting/`.

Deployment needs Python 3 and Firebase CLI. The deploy hook creates the HTML
and stops if the contact email is missing. Local config files and generated
HTML are ignored by Git.

## Publish a fork

For a signed Android release, copy
[`android/key.properties.example`](android/key.properties.example) to
`android/key.properties` and use your own keystore. If you publish under a new
Android application ID, configure your own Google Play product and update
`lib/core/entitlements/pro_product.dart` if its ID differs from `pro_lifetime`.

## License

Project code is [GPL-3.0-only](LICENSE). Bundled mGBA is MPL-2.0 and Nunito is
OFL-1.1; see [NOTICE](NOTICE). Contributions are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md).
