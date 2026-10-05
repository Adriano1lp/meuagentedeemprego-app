# Firebase App Distribution (Android)

GitHub Actions builds the current Android **release APK** (`flutter build apk --release --dart-define=API_BASE_URL=...`) and uploads it for the testers group Money maintains in Firebase App Distribution.

The app **will not open** in a release APK if `API_BASE_URL` is not HTTPS. `lib/main.dart` calls `ApiConfig.ensureSafeBaseUrl()` before `runApp()`; non-debug builds throw `StateError` on `http://` (including the debug default `http://127.0.0.1:8000`). App Distribution therefore passes production:

`https://meu-agente-de-emprego.onrender.com`

Release signing uses the Play App Signing **upload key**. The release build is not debuggable. If the upload key is missing, the release build **fails**. There is no fallback to the debug keystore. Do not put a keystore, passwords, or `key.properties` in this repo, and do not print those values in logs.

Before `flutter build apk --release`, CI decodes the upload keystore from Actions secrets onto the runner and exports `ANDROID_KEYSTORE_FILE` as that absolute path. **iOS** IPA remains out of scope (no certs/Fastlane in this repo).

## Triggers

`.github/workflows/firebase-app-distribution.yml`:

- **Manual:** Actions → Firebase App Distribution (Android) → Run workflow (`release_notes` optional).
- **Push** to `app-release-*` (e.g. `app-release-1.4.1`): notes = latest commit message.
- **Tag** `v*` or `app-release-*`: notes = tag + latest commit message.

PRs do not distribute.

## Secrets required now

Repo → Settings → Secrets and variables → Actions. Workflow fails fast if these are empty.

| Secret | Purpose |
| --- | --- |
| `FIREBASE_APP_ID` | Android App ID from Firebase Console → Project settings → Your apps. Format `1:NNNN:android:HEX`. Package `br.com.meuagentedeemprego.app`. |
| `FIREBASE_SERVICE_ACCOUNT` | JSON key of a GCP service account with **Firebase App Distribution Admin**. Prefer a single-line JSON string. |
| `FIREBASE_TESTER_GROUPS` | Comma-separated App Distribution **group aliases** (e.g. `mae-testers`). Preferred. |
| `FIREBASE_TESTERS` | Optional tester emails. At least one of `FIREBASE_TESTER_GROUPS` / `FIREBASE_TESTERS` is required. |

The release APK also needs the upload-key secrets named in [Upload key](#upload-key-required-for-the-release-apk-not-stored-in-this-repo). The job fails if any of them is empty.

## API base URL (required for the APK to launch)

Not a secret — this is the public production API. The workflow passes it as `--dart-define=API_BASE_URL=...` so the HTTPS-only release gate in `lib/data/api_config.dart` succeeds.

| Name | Where | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | Optional **Actions variable** (Settings → Secrets and variables → Actions → Variables). Not a secret. | Override the production API. If unset, CI uses `https://meu-agente-de-emprego.onrender.com`. Must be `https://` with a host; the workflow fails otherwise. |

Do **not** set this to `http://127.0.0.1:8000` (or any `http://` URL). That compiles, then the APK crashes on launch.

Release/profile Dart also falls back to the same production HTTPS URL when `--dart-define` is omitted. Debug still defaults to `http://127.0.0.1:8000` for local API work. The HTTPS-only gate is unchanged.

## Upload key (required for the release APK; not stored in this repo)

Adriano creates these Actions secrets (Settings → Secrets and variables → Actions). Values stay in GitHub. This repository never contains the keystore, passwords, alias, or `key.properties`.

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the Play **upload keystore** file. CI decodes it to a temp file under `$RUNNER_TEMP` (mode `600`) and sets `ANDROID_KEYSTORE_FILE` to that absolute path. |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password. Exported to the release build step. |
| `ANDROID_KEY_ALIAS` | Upload key alias. Exported to the release build step. |
| `ANDROID_KEY_PASSWORD` | Key password. Exported to the release build step. |

Do **not** create a secret named `ANDROID_KEYSTORE_FILE`. That name is the on-disk path, not the base64 blob. Gradle reads `ANDROID_KEYSTORE_FILE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` when `android/key.properties` is absent (`android/app/build.gradle.kts`).

If any of the four secrets above is missing, the workflow fails before the release build, in the same way it fails when a Firebase secret is missing. The release build does not fall back to the debug keystore.

The workflow does not echo the keystore, passwords, alias, or base64, and the decode step must not run under `set -x`. Local release builds can still use gitignored `android/key.properties`. CI does not write that file.

## Money: tester group

1. Firebase Console → MAE project → register Android app if needed (`br.com.meuagentedeemprego.app`) → copy App ID into `FIREBASE_APP_ID`.
2. Release & Monitor → App Distribution → Testers & Groups → create a group, add emails.
3. Put the group **alias** in `FIREBASE_TESTER_GROUPS`.
