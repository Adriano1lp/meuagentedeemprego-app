# Firebase App Distribution (Android)

GitHub Actions builds a **signed Android release APK** and uploads it to
[Firebase App Distribution](https://firebase.google.com/docs/app-distribution)
for the testers group Money maintains in the Firebase Console.

iOS IPA distribution is **not** included. The iOS project is the default
Flutter template (no Fastlane, signing certs, provisioning profiles, or
export options). Add it later on a `macos-latest` runner once Apple signing
is set up.

## When the workflow runs

Defined in `.github/workflows/firebase-app-distribution.yml`:

| Trigger | What happens |
| --- | --- |
| **Actions → Firebase App Distribution (Android) → Run workflow** | Manual upload. Optional `release_notes` input is sent to testers. |
| Push to `app-release-*` (e.g. `app-release-1.4.1`) | Auto-upload. Notes = latest commit message. |
| Tag `v*` or `app-release-*` (e.g. `v1.4.1`) | Auto-upload. Notes = tag name + latest commit message. |

Pull requests do **not** distribute.

## Secrets Adriano must set

Repo → **Settings → Secrets and variables → Actions → New repository secret**.
Do not commit keystores, `key.properties`, or service-account JSON.

| Secret | Purpose |
| --- | --- |
| `FIREBASE_APP_ID` | Android App ID from Firebase Console → Project settings → Your apps. Format `1:NNNN:android:HEX` (placeholder only; copy the real value). Matches package `br.com.meuagentedeemprego.app`. |
| `FIREBASE_SERVICE_ACCOUNT` | Full JSON key of a GCP service account with role **Firebase App Distribution Admin** (`roles/firebaseappdistro.admin`). Prefer a single-line JSON string. |
| `FIREBASE_TESTER_GROUPS` | Comma-separated **group aliases** from App Distribution (e.g. `mae-testers`). Preferred way to target testers. |
| `FIREBASE_TESTERS` | Optional. Comma-separated tester emails in addition to (or instead of) groups. At least one of `FIREBASE_TESTER_GROUPS` / `FIREBASE_TESTERS` is required. |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the upload/release `.jks` or `.keystore` (`base64 -w 0 upload-keystore.jks`). |
| `ANDROID_KEYSTORE_PASSWORD` | Password of that keystore. |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore (often `upload`). |
| `ANDROID_KEY_PASSWORD` | Password of that key. |

The workflow **fails in the first step** with `::error::Missing required GitHub Actions secret: …` if any required secret is empty. Local `flutter run --release` still uses the debug keystore when `android/key.properties` is absent.

## Money: tester group in Firebase Console

The pipeline does not edit the tester list. Money owns membership.

1. [Firebase Console](https://console.firebase.google.com/) → select the MAE project.
2. Register the Android app if needed: package name **`br.com.meuagentedeemprego.app`**. Copy the **App ID** into `FIREBASE_APP_ID`.
3. **Release & Monitor → App Distribution → Testers & Groups**.
4. Create a group (example alias: `mae-testers`) and add tester emails.
5. Put that **alias** (not the display name) in `FIREBASE_TESTER_GROUPS`.
6. Testers install via the email invite / Firebase App Tester. Builds expire after 150 days.

## Service account (GCP)

1. Google Cloud Console for the same Firebase project → **IAM & Admin → Service accounts**.
2. Create an account used only for CI (example name: `github-app-distribution`).
3. Grant **Firebase App Distribution Admin**.
4. **Keys → Add key → JSON**. Paste the file contents into `FIREBASE_SERVICE_ACCOUNT`.
5. Delete the downloaded JSON from disk after storing the secret.

## Android signing

`android/app/build.gradle.kts` reads `android/key.properties` (gitignored) when present. CI writes that file from the `ANDROID_*` secrets. Keep using the same upload keystore for Play Console later so testers are not forced to uninstall.

## Artifact

Testers receive an **APK** (`flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`). AAB is supported by App Distribution but needs extra Play linking; APK is enough for this testers group.

## Flutter version

Pinned to **3.41.7** (stable), matching `.metadata` revision `cc0734ac716fbb8b90f3f9db8020958b1553afa7` and `pubspec.yaml` Dart `^3.11.5`.

## iOS follow-up (out of scope)

- Apple Distribution certificate + provisioning profile (or Fastlane Match).
- `macos-latest` runner, `flutter build ipa`, Firebase iOS App ID.
- Extra secrets: `FIREBASE_IOS_APP_ID`, Apple cert/profile or App Store Connect API key.
