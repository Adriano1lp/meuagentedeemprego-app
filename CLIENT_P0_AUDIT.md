# Client P0 audit — Meu Agente de Emprego (Flutter)

**Scope:** investigation only. This document records what exists in the Flutter client (`agente_emprego`) as of commit `bbfbf1c` (`Task-017`) on `app-release-1.4.1`. No feature work is implied or started.

**Method:** full-repo search of Dart UI/repos, `pubspec.yaml` / `pubspec.lock`, Android manifests, iOS/macOS plists and entitlements, plus `README.md`. Workspace contains this Flutter app only (no API server). Backend contract beyond the client’s own HTTP calls is **UNKNOWN**.

**Status key**

| Status | Meaning |
| --- | --- |
| **DONE** | The P0 control is implemented in this client with file evidence. |
| **PARTIAL** | Related code exists, but the P0 control is incomplete or uses a weaker substitute. |
| **MISSING** | No UI, call, dependency, or config for the P0 control. |
| **UNKNOWN** | Cannot be confirmed from this repo (usually needs the API or a store listing). |

---

## Summary

| # | P0 item | Status | One-line finding |
| --- | --- | --- | --- |
| 1 | Signup terms + privacy checkboxes | **MISSING** | Register tab is name/email/password only; no `Checkbox` widgets and no consent fields on `/auth/register`. |
| 2 | Account delete + export UI/calls | **MISSING** | Drawer has local logout only. No delete/export screens or HTTP methods. |
| 3 | Billing / upgrade UI | **MISSING** | No billing screens, IAP/Stripe deps, or payment endpoints. |
| 4 | JWT / token storage (Hive vs secure) | **PARTIAL** | Access token is persisted in an unencrypted Hive `Box<String>`. `flutter_secure_storage` (or equivalent) is absent. |
| 5 | Cleartext HTTP / `usesCleartextTraffic` / ATS exceptions | **PARTIAL** | Default API URL is `http://`. Android and iOS explicitly allow cleartext / arbitrary loads. No Android network-security config. |
| 6 | How the app points to the API | **DONE** | Compile-time `--dart-define=API_BASE_URL=...` via `String.fromEnvironment`, default `http://127.0.0.1:8000`. |

---

## 1. Signup terms + privacy checkboxes — MISSING

### What was checked

- Auth / signup UI: `lib/presentation/screens/auth_screen.dart`
- Register HTTP payload: `lib/data/repositories/auth_repository_impl.dart`
- CV onboarding (post-signup, not legal consent): `lib/presentation/screens/user_registration_screen.dart`
- Widget search across `lib/` for `Checkbox`, `CheckboxListTile`, `termos`, `privacidade`, `privacy`, `consent`, `terms`

### Evidence

Signup is a second tab on `AuthScreen`. Fields are **Nome**, **Email**, and **Senha**. Submit calls `_register()` with no boolean gates and no legal copy/links.

```215:258:lib/presentation/screens/auth_screen.dart
  Widget _buildRegisterTab(ThemeData theme) {
    return SingleChildScrollView(
      // ...
              TextField(
                controller: _registerNameController,
                decoration: const InputDecoration(hintText: 'Nome'),
              ),
              // Email + senha TextFields only
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _register,
                  label: Text(_isSubmitting ? 'Criando...' : 'Criar conta'),
                ),
              ),
```

`_register()` validates non-empty name/email/password only, then posts to the API:

```44:60:lib/presentation/screens/auth_screen.dart
  Future<void> _register() async {
    final displayName = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Preencha nome, email e senha.');
      return;
    }

    await _authenticate(
      action: () => _repository.register(
        displayName: displayName,
        email: email,
        password: password,
      ),
    );
  }
```

```41:54:lib/data/repositories/auth_repository_impl.dart
  Future<AuthSessionData> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/register',
      data: {
        'display_name': displayName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return _parseAuthSession(response.data);
  }
```

Repo-wide search in `lib/`:

- No `Checkbox` / `CheckboxListTile` / `SwitchListTile`
- No strings for termos de uso, política de privacidade, LGPD, or consent
- The only “aceitos” hit is file-format copy on CV upload (`Formatos aceitos: .txt e .pdf` in `user_registration_screen.dart`), not legal acceptance
- `UserRegistrationScreen` is CV upload + embeddings after auth, not account signup

### Gaps

- No required terms checkbox
- No required privacy checkbox
- No in-app links to policy documents
- Register body does not send `accepted_terms`, `accepted_privacy`, timestamps, or version IDs

Whether the API independently records consent is **UNKNOWN** (API not in this workspace). The client does not collect or send it.

---

## 2. Account delete + export UI/calls — MISSING

### What was checked

- Navigation / account actions: `lib/presentation/widgets/app_drawer.dart`
- Session lifecycle: `lib/presentation/providers/session_provider.dart`
- HTTP surface: `lib/data/repositories/*.dart`
- Search for delete/export/LGPD/GDPR/`dio.delete`/excluir/exportar

### Evidence — local logout only

The only account action in the drawer is **Sair**. It clears the local Hive session and returns to `AuthScreen`. It does not call the API.

```209:230:lib/presentation/widgets/app_drawer.dart
            if (userId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(sessionProvider.notifier).clear();
                    // ... navigate to AuthScreen
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair'),
                ),
              ),
```

`SessionNotifier.clear()` deletes **local** Hive keys (`auth_token`, `user_id`, `email`, `display_name`, `has_cv`) and chat history. That is session wipe, not account deletion or data export.

```103:111:lib/presentation/providers/session_provider.dart
  Future<void> clear() async {
    await Hive.box<MessageModel>('chat_history').clear();
    await _box.delete(_authTokenKey);
    await _box.delete(_userIdKey);
    await _box.delete(_emailKey);
    await _box.delete(_displayNameKey);
    await _box.delete(_hasCvKey);
    state = const SessionState();
  }
```

### Client HTTP surface (no delete/export)

| Call | File | Purpose |
| --- | --- | --- |
| `POST /auth/register` | `auth_repository_impl.dart` | Signup |
| `POST /auth/login` | `auth_repository_impl.dart` | Login |
| `GET /auth/me` | `auth_repository_impl.dart` | Session bootstrap |
| `GET /users/me/status` | `auth_repository_impl.dart` | CV / embeddings flags |
| `POST /users/me/upload-cv` | `user_repository_impl.dart` | CV upload |
| `POST /users/me/rebuild-embeddings` | `user_repository_impl.dart` | Embeddings |
| `POST /users/me/cover-letter` | `cover_letter_repository_impl.dart` | Cover letter |
| `POST /processar` | `chat_repository_impl.dart` | Job analysis |
| `GET` user file URLs | `authenticated_pdf_opener.dart` | Authenticated PDF download |

No `DELETE`, no `/export`, no account-erasure path. Drawer destinations are Home, Análise de vaga, Histórico, Carta, Buscar vagas, Currículo — no Conta / Privacidade / Dados screen.

`HistoryScreen` is local Hive chat history (`Mensagens salvas localmente`), not a user-data export package.

### Gaps

- No “excluir conta” UI or confirmation flow
- No “exportar / baixar meus dados” UI
- No repository methods that would hit delete/export APIs
- Logout does not notify the server (token revocation **UNKNOWN** / not called)

Whether such endpoints exist on the backend is **UNKNOWN**.

---

## 3. Billing / upgrade UI — MISSING

### What was checked

- All screens under `lib/presentation/screens/`
- Drawer tiles in `app_drawer.dart`
- `pubspec.yaml` / `pubspec.lock` for IAP / Stripe / RevenueCat / billing
- Search for billing, upgrade, assinatura, subscription, premium, plano, pagamento, stripe, purchase

### Evidence

Screens present: `AuthScreen`, `HomeScreen`, `UserRegistrationScreen` (CV), `ChatScreen`, `HistoryScreen`, `CoverLetterScreen`, `JobSearchScreen`.

No settings, paywall, plan picker, restore-purchases, or “upgrade” affordance. `pubspec.yaml` dependencies are UI/network/storage only (`dio`, `hive`, `file_picker`, `url_launcher`, etc.). `pubspec.lock` has **no** `in_app_purchase`, `purchases_flutter`, `flutter_stripe`, or similar.

The only “subscription” hits are Riverpod `ProviderSubscription` in `chat_screen.dart` and Xcode `LastUpgradeVersion` metadata — not billing.

### Gaps

- No client billing/upgrade UI
- No payment SDK
- No billing HTTP calls

Whether monetization is web-only, server-only, or not started is **UNKNOWN**. From this client: not implemented.

---

## 4. JWT / token storage: Hive vs `flutter_secure_storage` — PARTIAL

**P0 expectation (secure at-rest token):** **MISSING**  
**Token persistence (any store):** **DONE**, via Hive

### What was checked

- Session bootstrap and box open: `lib/main.dart`
- Session read/write: `lib/presentation/providers/session_provider.dart`
- Auth token parse: `lib/data/repositories/auth_repository_impl.dart`
- Dependencies: `pubspec.yaml`, `pubspec.lock`
- Search for `flutter_secure_storage`, Keychain, `HiveAesCipher`, `EncryptedBox`, `SharedPreferences`

### Evidence — Hive, not secure storage

Hive is initialized without a cipher. Two boxes are opened: chat history and session strings.

```13:18:lib/main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MessageModelAdapter());
  await Hive.openBox<MessageModel>('chat_history');
  await Hive.openBox<String>('app_session');
```

The JWT (`access_token` from the API) is stored as a plaintext string under `auth_token`:

```63:87:lib/presentation/providers/session_provider.dart
  static const String _authTokenKey = 'auth_token';
  // ...
  final Box<String> _box;

  Future<void> saveSession({
    required String authToken,
    // ...
  }) async {
    // ...
    await _box.put(_authTokenKey, authToken);
    await _box.put(_userIdKey, normalizedUserId);
    await _box.put(_emailKey, email.trim().toLowerCase());
    await _box.put(_displayNameKey, displayName.trim());
    await _box.put(_hasCvKey, hasCv.toString());
```

Token source:

```133:140:lib/data/repositories/auth_repository_impl.dart
    final token = data['access_token'] as String?;
    final user = data['user'];
    // ...
    return AuthSessionData(
      authToken: token,
```

Bearer usage (in-memory after Hive restore): `Authorization: Bearer $authToken` in auth, user, chat, cover-letter, and PDF helpers.

`pubspec.yaml` lists `hive: ^2.2.3` and `hive_flutter: ^1.1.0`. It does **not** list `flutter_secure_storage` or another Keychain/Keystore wrapper. `pubspec.lock` has no `flutter_secure_storage`. Tests write `auth_token` directly into the Hive session box (`test/app_drawer_test.dart`, `test/widget_test.dart`).

No `HiveAesCipher` / encrypted box.

### Implications

- Token and PII (email, display name, user id) live in the default Hive file under the app documents directory
- On a rooted/jailbroken device, backup extraction, or shared-storage inspection, the bearer token is recoverable as a string
- Web Hive storage is also not a platform secure enclave

Equivalent secure stores **not** present: `flutter_secure_storage`, `encrypted_shared_preferences`, custom Keychain/Keystore plugins.

---

## 5. Cleartext HTTP / `usesCleartextTraffic` / ATS exceptions — PARTIAL

**Cleartext allowed in shipping Android + iOS configs:** **DONE** (explicitly enabled)  
**HTTPS-only / no ATS exceptions / no cleartext default:** **MISSING**

### 5.1 Default API URL is HTTP

```7:11:lib/data/repositories/chat_repository_impl.dart
class ChatRepositoryImpl {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
```

If the app is built without `--dart-define=API_BASE_URL=https://...`, Dio talks HTTP to loopback. That default is what a store/release binary would use unless CI injects a define (no such script is in this repo).

### 5.2 Android — `android:usesCleartextTraffic="true"`

Main application manifest (release-relevant):

```1:7:android/app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:label="agente_emprego"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
```

- Debug/profile manifests only add `INTERNET`; they do not override cleartext
- No `network_security_config.xml` and no `android:networkSecurityConfig` attribute anywhere
- Cleartext is therefore allowed for **all** domains on the merged application, not just localhost

### 5.3 iOS — ATS exception `NSAllowsArbitraryLoads`

```29:33:ios/Runner/Info.plist
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
```

This disables ATS globally (HTTP and invalid/self-signed TLS are permitted). There is no narrower `NSExceptionDomains` allowlist for a single API host.

### 5.4 macOS

- `macos/Runner/Info.plist` has **no** `NSAppTransportSecurity` block (ATS default applies; no recorded exception)
- `macos/Runner/DebugProfile.entitlements`: sandbox + `com.apple.security.network.server` (no `network.client`)
- `macos/Runner/Release.entitlements`: sandbox only (no client or server network entitlement)

macOS outbound HTTP/HTTPS under App Sandbox typically needs `com.apple.security.network.client`. That entitlement is **MISSING** on both DebugProfile and Release. This is a platform-network finding adjacent to ATS, not an ATS exception.

### 5.5 Other platforms

- Windows / Linux: no ATS/`usesCleartextTraffic` equivalents in-tree
- Web (`web/index.html`): no API URL, CSP, or mixed-content policy. A HTTPS-hosted web build calling the default `http://127.0.0.1:8000` would be mixed content in the browser — behavior **UNKNOWN** without a deployed web build

### Gaps

- Production hardening (HTTPS default, cleartext off, ATS on with optional localhost-only debug exception) is not present
- Android cleartext is app-wide, not debug-only
- iOS ATS is fully relaxed

---

## 6. How the app points to the API — DONE

### Mechanism

Single compile-time constant, then copied into every Dio client:

```7:11:lib/data/repositories/chat_repository_impl.dart
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
```

| Consumer | File |
| --- | --- |
| Chat (`POST /processar`) | `lib/data/repositories/chat_repository_impl.dart` |
| Auth | `lib/data/repositories/auth_repository_impl.dart` |
| CV upload / embeddings | `lib/data/repositories/user_repository_impl.dart` |
| Cover letter | `lib/data/repositories/cover_letter_repository_impl.dart` |
| Authenticated PDF GET | `lib/presentation/utils/authenticated_pdf_opener.dart` |
| Onboarding copy (URL shown in UI) | `lib/presentation/screens/user_registration_screen.dart` |

Override at build/run time:

```text
flutter run --dart-define=API_BASE_URL=https://api.example.com
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

`String.fromEnvironment` is resolved at **compile** time. There is no runtime `.env`, flavor file, remote config, or settings field to change the base URL after install.

### What is not present

- No `.env` / `flutter_dotenv`
- No `README.md` documentation of `API_BASE_URL` (README is still the Flutter template)
- No CI/build script in this repo that injects a production URL
- Drawer used to surface the URL; current test asserts it does **not**:

```46:59:test/app_drawer_test.dart
  testWidgets('menu nao mostra API atual e mostra analise de vaga', (
    WidgetTester tester,
  ) async {
    // ...
    expect(find.text('API atual'), findsNothing);
    expect(find.text('http://127.0.0.1:8000'), findsNothing);
```

CV onboarding still interpolates the raw base URL into user-visible text (`user_registration_screen.dart`).

Which host production builds actually use is **UNKNOWN** (no release pipeline in this repo).

---

## Screen / repository map (audit coverage)

| Path | Role |
| --- | --- |
| `lib/main.dart` | Hive init, session bootstrap via `/auth/me` + `/users/me/status` |
| `lib/presentation/screens/auth_screen.dart` | Login + signup |
| `lib/presentation/screens/user_registration_screen.dart` | CV upload (not legal signup) |
| `lib/presentation/screens/home_screen.dart` | Authenticated home |
| `lib/presentation/screens/chat_screen.dart` | Job analysis |
| `lib/presentation/screens/history_screen.dart` | Local chat history |
| `lib/presentation/screens/cover_letter_screen.dart` | Cover letter |
| `lib/presentation/screens/job_search_screen.dart` | Hardcoded LinkedIn links |
| `lib/presentation/widgets/app_drawer.dart` | Nav + logout |
| `lib/presentation/providers/session_provider.dart` | Hive session |
| `lib/data/repositories/*_impl.dart` | Dio API clients |

No other feature screens exist.

---

## Recommended follow-ups (out of scope — not implemented here)

These are pointers only; this PR does not change app code.

1. Add required terms + privacy checkboxes (and versioned links) on `AuthScreen` register; send acceptance on `/auth/register` if the API supports it.
2. Add account settings: export download and delete-account with confirmation; call matching API routes when they exist.
3. Confirm product intent for billing; if required, add UI + a payment SDK. If billing is web-only, document that explicitly.
4. Move `auth_token` (and ideally email) to `flutter_secure_storage` or a Hive box opened with `HiveAesCipher` whose key lives in the Keystore/Keychain.
5. Default `API_BASE_URL` to HTTPS; set `usesCleartextTraffic` false (or debug-only); replace `NSAllowsArbitraryLoads` with a tight exception or remove it; add `com.apple.security.network.client` on macOS if desktop is a target.
6. Document `--dart-define=API_BASE_URL` in README and pin the production value in the release build.

---

## Audit metadata

| Field | Value |
| --- | --- |
| App | `agente_emprego` (Meu Agente de Emprego Flutter client) |
| Branch audited | `app-release-1.4.1` |
| Commit | `bbfbf1c7cc04ee5ac31fadd7c6edb407a27ede1b` |
| Date | 2026-09-05 |
| Kind | Docs only — no feature implementation |
