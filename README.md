# agente_emprego

A new Flutter project.

## CI/CD (Firebase App Distribution)

Android release APKs (internal beta) go to Firebase App Distribution.
The release build is not debuggable and signs only with the Play App Signing upload key. If that key is absent, the release build fails. It does not use the debug key.
CI passes `--dart-define=API_BASE_URL=https://meu-agente-de-emprego.onrender.com` so the APK can launch (HTTPS-only gate).
See [`.github/firebase-app-distribution.md`](.github/firebase-app-distribution.md).

## App mobile

Telas, fluxos de currículo, carta e cota, e estados de erro: [`docs/app-mobile.md`](docs/app-mobile.md).

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
