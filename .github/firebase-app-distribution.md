# Firebase App Distribution (Android)

GitHub Actions builds the current Android **release APK** (`flutter build apk --release --dart-define=API_BASE_URL=...`) and uploads it for the testers group Money maintains in Firebase App Distribution.

The app **will not open** in a release APK if `API_BASE_URL` is not HTTPS. `lib/main.dart` calls `ApiConfig.ensureSafeBaseUrl()` before `runApp()`; non-debug builds throw `StateError` on `http://` (including the debug default `http://127.0.0.1:8000`). App Distribution therefore passes production:

`https://meu-agente-de-emprego.onrender.com`

This uses the app **as-is**: `android/app/build.gradle.kts` still signs `release` with the **debug** keystore. That is OK for internal beta. Do not put a keystore or `key.properties` in this repo.

**Follow-up fatia (not required to merge this PR):** real Play/upload signing via `ANDROID_KEYSTORE_*` secrets + `key.properties`. **iOS** IPA is also follow-up (no certs/Fastlane in this repo).

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

## API base URL (required for the APK to launch)

Not a secret — this is the public production API. The workflow passes it as `--dart-define=API_BASE_URL=...` so the HTTPS-only release gate in `lib/data/api_config.dart` succeeds.

| Name | Where | Purpose |
| --- | --- | --- |
| `API_BASE_URL` | Optional **Actions variable** (Settings → Secrets and variables → Actions → Variables). Not a secret. | Override the production API. If unset, CI uses `https://meu-agente-de-emprego.onrender.com`. Must be `https://` with a host; the workflow fails otherwise. |

Do **not** set this to `http://127.0.0.1:8000` (or any `http://` URL). That compiles, then the APK crashes on launch.

Release/profile Dart also falls back to the same production HTTPS URL when `--dart-define` is omitted. Debug still defaults to `http://127.0.0.1:8000` for local API work. The HTTPS-only gate is unchanged.

## Follow-up secrets (signing fatia — not required now)

`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Unused by this workflow.

## Money: tester group

1. Firebase Console → MAE project → register Android app if needed (`br.com.meuagentedeemprego.app`) → copy App ID into `FIREBASE_APP_ID`.
2. Release & Monitor → App Distribution → Testers & Groups → create a group, add emails.
3. Put the group **alias** in `FIREBASE_TESTER_GROUPS`.
