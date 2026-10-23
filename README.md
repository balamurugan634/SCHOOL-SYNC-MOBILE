# SchoolSync mobile

The Flutter app (Android + iOS) for **SchoolSync**, a multi-tenant school ERP. One app binary serves every school: the
person enters their school once ("site"), the app brands itself with the school's name, logo and colour, and shows one of
four role experiences: **Student, Parent, Teacher, Management**.

* API + web monorepo: `/home/bala/SCHOOL-SYNC` (see `docs/ARCHITECTURE.md`, `docs/PRODUCT-BLUEPRINT.md`, `docs/DESIGN.md`)
* This repo: `/home/bala/SCHOOL-SYNC-MOBILE`
* Status: Phase 1 (foundation, onboarding, auth, role shells, security, push plumbing) is done, and the **Student and Parent
  experiences are built end to end on the real API** (section 13). Teacher and Management screens are built separately
  (`lib/features/teacher`, `lib/features/management`); tabs without a screen yet show a quiet "coming soon" placeholder.

## Adding a feature screen (conventions for parallel work)

Several people/agents add screens at the same time, so the layout is built to avoid shared files:

| What | Where | Rule |
|---|---|---|
| A feature's screens, widgets, providers | `lib/features/<area>/` | One folder per area (`homework`, `fees`, `attendance`, ...). Nothing outside it should import its private widgets. |
| API calls | `lib/data/repositories/<area>_repository.dart` | One repository per API area, plus its provider (`xRepositoryProvider`) at the bottom of the same file. Repositories only use `ApiClient` and only throw `AppException`. |
| Models | `lib/data/models/<area>.dart` | Hand-written `fromJson` (no codegen). Tolerate missing/extra fields; never trust a type. |
| Shared widgets | `lib/core/design/` | Cards, chips, states, buttons, illustrations. Reuse them; add new generic widgets here and export them from `design.dart`. Do not copy styling into a feature. |
| Role wiring | `lib/router/routes_<role>.dart` | **One file per role** (`routes_student.dart`, `routes_parent.dart`, `routes_teacher.dart`, `routes_management.dart`). Each exports a `RoleModule` with its bottom-bar `tabs` and its pushed `routes`. `lib/router/app_router.dart` composes them; you normally never edit it. |

Steps to add a screen for a role:

1. Create `lib/features/<area>/<thing>_screen.dart` (a `ConsumerWidget`). Load data with a `FutureProvider`/`AsyncNotifier` that calls your repository, and handle **loading** (`SkeletonList`/`Skeletonizer`), **empty** (`EmptyState` with an illustration), **error** (`ErrorState`, with Retry) and **offline** (cached/last data plus the shell's offline banner).
2. Add the repository + model files under `lib/data/`.
3. In the role's `routes_<role>.dart`: add a path constant to `<Role>Routes`, add a `GoRoute` to `routes:` (pushed screens cover the bottom bar), and, for a tab, give the `TabSpec` a `builder: (context) => const YourScreen()`.
4. Gate by permission/feature flag where relevant: `me.can('fees:view')`, `siteInfo.features.fees` (the API still enforces everything).
5. Sensitive screens (fees, results, profile, passwords): wrap in `SecureScope()` so screenshots are blocked.
6. Test: a model test (`test/<area>_models_test.dart`) and a repository test with a fake HTTP adapter (see `test/support/fake_api.dart`, which replays real recorded responses, and `test/learner_repositories_test.dart` for the pattern). `flutter analyze` must stay clean and `flutter test` green.
7. Design: follow `/home/bala/SCHOOL-SYNC/design.md` (tokens come from `context.tokens`/`context.text`; never raw hex).

## Contents

1. [What Phase 1 contains](#1-what-phase-1-contains)
2. [Project layout](#2-project-layout)
3. [Setup](#3-setup)
4. [Running](#4-running) (emulator, **physical phone**, dart-defines)
5. [Firebase / push notifications](#5-firebase--push-notifications)
6. [Security](#6-security)
7. [Release signing and builds](#7-release-signing-and-builds)
8. [Tests and verification](#8-tests-and-verification)
9. [Store publishing checklist](#9-store-publishing-checklist)
10. [iOS (macOS steps)](#10-ios-macos-steps)
11. [Working on the shared dev machine](#11-working-on-the-shared-dev-machine)
12. [Phase 2 assumptions](#12-phase-2-assumptions)
13. [Student and Parent experiences](#13-student-and-parent-experiences)

## 1. What Phase 1 contains

Flow: splash -> intro carousel (once) -> **find your school** (until a site is saved) -> login -> forced password change
(if `mustChangePassword`) -> permission primers (notifications, then app lock) -> role home. The welcome tour is a small
dialog shown once per user over the real home screen.

* **Find your school**: accepts a code (`greenvalley` -> `https://greenvalley.<BASE_DOMAIN>`) or a URL
  (`https://greenvalley.schoolsync.app`, bare hosts too). Validates with `GET /api/v1/site/info`, shows the school's
  name/logo for confirmation, then saves the site in secure storage and applies the branding. Errors: bad URL,
  unreachable, 404 `SITE_NOT_FOUND`, 403 `SITE_SUSPENDED`, TLS failure, not-a-SchoolSync server, and
  `api.minAppVersion` above the installed version (full-screen "update required").
* **Login**: identifier + password, show/hide, forgot password (`POST /auth/forgot-password`, always 202), friendly
  messages for `INVALID_CREDENTIALS`, `ACCOUNT_LOCKED` (with a live countdown from `retryAfterSeconds`),
  `ACCOUNT_DISABLED`, `STUDENT_LOGIN_DISABLED`, and a banner when the school is `readOnly` (subscription lapsed).
  Sends `device: {platform, name, appVersion, pushToken?}`.
* **Role shells**: bottom navigation per `Me.experience`
  (Student: Home, My Tasks, Calendar, Learning, Profile. Parent: Home, Attendance, Academics, Fees, More with a child
  selector. Teacher: Home, Classes, Attendance, Homework, More. Management: Home, Academics, People, Finance, More).
  Tabs are gated by `Me.permissions` (permission key -> scope) and by the school's feature flags.
* **Account**: profile, signed-in devices (list + revoke + "sign out others"), change password (policy: 10+ chars, upper,
  lower, digit), notification + app-lock toggles, theme (system/light/dark), replay tour, **change school** (signs out,
  wipes tokens + site), sign out.
* **Networking**: Dio with tenant/identity headers, bearer auth, **single-flight rotating refresh** (409
  `REFRESH_RACE` re-reads the latest stored token; `SESSION_EXPIRED`/`INVALID_REFRESH`/`ACCOUNT_DISABLED` sign out),
  one bounded retry of idempotent GETs, RFC 9457 `problem+json` parsed into `AppException`, offline banner.

## 2. Project layout

```
lib/
  main.dart, app.dart            entry point, MaterialApp.router, theme from the saved school
  core/
    config/env.dart              compile-time dart-defines          config/dev_options.dart  debug-only API override
    design/                      the design-system layer (theme tokens, cards, chips, states, nav, buttons ...)
    network/                     api_client (interceptors), token_manager (single-flight refresh),
                                 app_exception (problem+json), cert_pinning (SPKI), device_meta
    storage/                     secure_store (Keystore/Keychain: site, tokens, cached profile), prefs
    security/                    platform_bridge (FLAG_SECURE, root check), biometric_service
    push/                        firebase_bootstrap, push_service, local_notifications, background_handler
    util/                        site_address (URL/code normalisation), app_version
  data/                          models (hand-written fromJson, no codegen) + repositories
  features/                      splash, onboarding, auth (session controller), shell, home, more, profile, security,
                                 and one folder per learner area: dashboard, homework, tasks, schedule, attendance, exams,
                                 fees, announcements, events, meetings, leave, notifications, learning, learner (shared)
  router/                        routes (gate paths), guard (pure function, unit-tested), go_router config,
                                 role_module + routes_student/parent/teacher/management (one file per role)
android/                         network security config, backup rules, R8 rules, MainActivity.kt (secure flag, root check)
ios/                            Info.plist (Face ID, push), entitlements, privacy manifest
scripts/                        build_apk.sh, verify_release_security.sh, sync_design_assets.sh
test/                           unit + widget tests; fixtures/ = real /auth/me and (fixtures/api) real API responses;
                                support/ = fake HTTP server, real-font loader, learner test harness
assets/                         Inter + Manrope fonts, the shared illustrations, brand/launcher-icon sources
```

State is Riverpod 3 (Notifier providers), routing is go_router (one pure `redirectFor(session, location)` guard drives
the whole onboarding order), HTTP is Dio. There is no build_runner / codegen.

## 3. Setup

Requirements: Flutter 3.47 (Dart 3.13), JDK 21, Android SDK (platform 36, build-tools 35/36, NDK is auto-installed by
Gradle), an emulator or a phone. On this machine:

```bash
export PATH=/home/bala/development/flutter/bin:$PATH
export JAVA_HOME=/home/bala/sols-android-tools/jdk21
export ANDROID_HOME=/home/bala/sols-android-tools/android-sdk
flutter config --android-sdk $ANDROID_HOME
cd /home/bala/SCHOOL-SYNC-MOBILE && flutter pub get
```

Design assets (see `/home/bala/SCHOOL-SYNC/design.md` and `design/README.md`):

* Fonts **Inter** (400/500/600) and **Manrope** (variable, pinned to 600; display/titles/figures) are bundled in `assets/fonts` (SIL OFL licences next to them); nothing is fetched at runtime.
* Illustrations: `scripts/sync_design_assets.sh` copies `design/illustrations/*.svg` into `assets/illustrations/`. They are re-themed at runtime with the school colour (`IllustrationView`, `lib/core/design/illustration.dart`).
* Launcher icon: `assets/brand/*` come from `design/brand/`; regenerate the Android/iOS icons with `dart run flutter_launcher_icons`.
* Theme: explicit `ColorScheme` + `SchoolSyncTheme` extension (paper & ink neutrals, accent, role tints, status and chart colours); the school colour is normalised in OKLCH (`lib/core/design/theme.dart`, tested in `test/theme_test.dart`).

## 4. Running

### 4.1 Against the local API on the Android emulator

The emulator reaches the host at `10.0.2.2`. The API listens on `0.0.0.0:4000`; the demo school's code is `demo`.

```bash
flutter run --dart-define=DEV_API=http://10.0.2.2:4000
# Find your school: type  demo
```

With a dev API every school code is sent to that one address as the `X-Tenant: <code>` header (so `demo` works).
Demo logins on site `demo`, password `Demo@12345`:

| Role | Identifier |
|---|---|
| Student | `gv20260001` |
| Parent | `9000000001` |
| Teacher | `t001` (class teacher) |
| Principal (management) | `principal` |
| Super admin (management) | `admin@greenvalley.edu` |

### 4.2 On a physical phone (no rebuild needed)

Debug builds contain a collapsed **Developer options** section on the *Find your school* screen with an editable
**API address** field (prefilled from `--dart-define=DEV_API` if the build had one; saved on the device). Release builds do
not contain it (see [section 8](#8-tests-and-verification)).

1. Build/obtain the debug APK: `scripts/build_apk.sh debug` produces `build/app/outputs/flutter-apk/app-debug.apk`
   (arm64 + x86_64, about 180 MB because it is a debug build). A copy lives in `dist/schoolsync-debug-arm64-x64.apk`.
2. Find the laptop's LAN IP: `hostname -I | awk '{print $1}'` (for example `192.168.1.20`).
3. Make sure the API is up and reachable on that IP. It already listens on `0.0.0.0:4000`; check from the phone's browser
   at `http://192.168.1.20:4000/api/v1/healthz` (should show `{"ok":true}`). Allow port 4000 in the laptop firewall
   (`sudo ufw allow from 192.168.1.0/24 to any port 4000` if ufw is on).
4. Put the phone and the laptop on the **same Wi-Fi** (not a guest network; some routers isolate clients).
5. Install: `adb install -r dist/schoolsync-debug-arm64-x64.apk` (USB debugging on), or copy the file to the phone and open
   it (allow "install unknown apps" for the app you opened it with).
6. Open SchoolSync, tap through the intro, expand **Developer options**, type `http://192.168.1.20:4000` into
   **API address**, then enter `demo` as the school and continue.

Cleartext HTTP is only permitted by the *debug* network security config (`android/app/src/debug/res/xml/`), which Gradle
never packages into release builds.

### 4.3 Dart-defines (all optional)

| Define | Default | Meaning |
|---|---|---|
| `BASE_DOMAIN` | `schoolsync.app` | school code `x` becomes `https://x.<BASE_DOMAIN>` |
| `DEV_API` | none | send every school code to this API as `X-Tenant` (debug; prefills Developer options) |
| `PIN_SHA256` | none | comma list of base64 SHA-256 SPKI pins; pinning is a no-op when unset (see 6.3) |
| `STORE_URL` | Play Store page of `com.schoolsync.app` | where "update required" sends people |
| `LOCK_MINUTES` | `1` | default minutes in the background before the app lock engages |
| `SCREEN_PRIVACY` | on in profile/release, off in debug | `true`/`false` forces FLAG_SECURE on sensitive screens (off in debug so `adb screencap` works) |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET` (optional) | none | Firebase options without committing secrets (section 5) |

## 5. Firebase / push notifications

Push is **optional**. Without Firebase config the app works fully; push is simply off (Settings says so).

Server contract: the API stores FCM registration tokens (`POST /api/v1/devices`, `POST /api/v1/devices/unregister`) and
sends through firebase-admin. Message `data` keys: `notificationId`, `type`, optional `route` (an in-app path such as
`/tab/2`; unsafe or onboarding routes are ignored). Either a `notification` block or data-only messages work.

### Option A: dart-defines (no files, nothing secret in git)

Take the values from the Firebase console (Project settings -> Your apps -> Android) and pass them on every build:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_APP_ID=1:1234567890:android:abc123 \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_PROJECT_ID=my-project
```

### Option B: `google-services.json` / `GoogleService-Info.plist`

Download `google-services.json` into `android/app/` (gitignored). The Gradle build applies the google-services plugin
**only if that file exists**. For iOS put `GoogleService-Info.plist` into `ios/Runner/` (also gitignored) and add it to the
Runner target in Xcode. With neither files nor defines the app skips Firebase.

`flutterfire configure` also works (it generates `firebase_options.dart` and the same native files). This project reads
options from dart-defines or the native files instead, so you do not need to commit `firebase_options.dart`; if you prefer
it, call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in
`lib/core/push/firebase_bootstrap.dart`.

### How it behaves

* Android notification channels `general` (default) and `urgent` (max) are created at start. Foreground messages are shown
  with flutter_local_notifications; a top-level background handler draws data-only messages. Notification contents are
  `private` on the lock screen.
* Tapping a notification (foreground, background or cold start) deep-links with go_router using `data.route`, held until the
  person is past login/lock/onboarding.
* The token is registered after login (if push is enabled and permitted), re-registered on token refresh, and unregistered
  on sign-out. The first-run primer explains the value before the OS prompt.
* Note: firebase_messaging 17 marks `getToken/onTokenRefresh/deleteToken` deprecated in favour of Installation-ID
  registration. The SchoolSync server sends to classic FCM registration tokens, so the app keeps them (with an
  `ignore` comment) until the server moves to the new model.

## 6. Security

Checklist (all implemented in Phase 1; items marked * need your input before store release):

| Area | What is done |
|---|---|
| Transport | Android `network_security_config.xml` with `cleartextTrafficPermitted=false`; debug-only override in `src/debug`. Release also rejects non-https site addresses in code. iOS App Transport Security is left at its defaults (no exceptions). |
| Pinning | Optional SPKI pinning via `PIN_SHA256` (6.3). |
| Tokens | Only in `flutter_secure_storage` (Android Keystore-wrapped AES, iOS Keychain `first_unlock_this_device`). Never logged. Debug logging prints method + path + status only, and `debugPrint` is silenced in release. |
| Sessions | Rotating refresh token, single-flight refresh, reuse-safe `REFRESH_RACE` handling, revoke from "Signed-in devices", server-side logout + push unregister on sign-out, "Change school" wipes tokens, cached profile and the site. |
| Backups | `allowBackup=false`, `dataExtractionRules` and `fullBackupContent` exclude everything. |
| Hardening | R8 minify + resource shrink with keep rules (`android/app/proguard-rules.pro`); Dart `--obfuscate --split-debug-info`. |
| Screen privacy | `FLAG_SECURE` (Kotlin `MainActivity`) toggled for sensitive tabs/screens (fees, results, finance, profile/settings, sessions, password); the UI is replaced by a neutral cover whenever the app is not in the foreground (recents thumbnail, screen mirroring). |
| App lock | Optional biometric (face/fingerprint, device PIN as fallback) lock after N minutes in the background (default 1; Immediately/1/5/15 in Settings) and on cold start. |
| Device integrity | Lightweight root/jailbreak signal (su paths, test-keys / known jailbreak files) shown as a dismissible warning on Home, never a hard block. |
| Notifications | No private details on the lock screen. |
| Signing * | Release signing reads `android/key.properties` (7.1). |
| Identity * | Change the application id before publishing (9.1). |

### 6.3 Certificate pinning

```bash
# SPKI hash of your server certificate (leaf) and of a backup key:
openssl s_client -connect greenvalley.schoolsync.app:443 -servername greenvalley.schoolsync.app </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
flutter build apk --release --dart-define=PIN_SHA256=<primary>,<backup>
```

Pinned connections trust **only** the pinned public key (the trust store is emptied and the handshake is accepted when the
leaf's SPKI is in the list and the certificate is currently valid), so nothing is sent to an impostor. Pins apply to hosts
under `BASE_DOMAIN` only; schools on a custom domain use normal system trust. Plan for key rotation (always ship a backup
pin) because a wrong pin locks every user out until they update. The SPKI extractor is unit-tested against openssl.

## 7. Release signing and builds

### 7.1 Create the upload keystore (once, keep it out of git)

```bash
keytool -genkeypair -v -storetype JKS -keystore ~/schoolsync-upload.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
cat > android/key.properties <<'PROPS'
storeFile=/home/you/schoolsync-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
PROPS
```

`android/key.properties`, `*.jks` and `*.keystore` are gitignored. With Play App Signing enrolled (recommended) this is only
the *upload* key. **If `key.properties` is absent the release build falls back to the debug key** so you can still install
and test locally; the build prints a warning. Never upload a debug-signed build.

### 7.2 Build

```bash
scripts/build_apk.sh            # split-per-abi release APKs (obfuscated + R8)  -> build/app/outputs/flutter-apk/
scripts/build_apk.sh aab        # Play Store App Bundle                        -> build/app/outputs/bundle/release/
scripts/build_apk.sh debug      # debug APK for phone testing (arm64 + x86_64)
# extra flags pass through, e.g. production defines:
scripts/build_apk.sh apk --dart-define=BASE_DOMAIN=myschool.app --dart-define=PIN_SHA256=...
```

Release builds run `flutter build ... --release --obfuscate --split-debug-info=build/symbols/<version>`.
**Archive `dist/symbols/<version>+<build>/`** (the Dart symbol files and the R8 `r8-mapping.txt`, copied there by the
script) with every release you ship: without them crash reports and stack traces cannot be de-obfuscated
(`flutter symbolize -i trace.txt -d dist/symbols/<version>`). Choose the right APK per device ABI: `arm64-v8a` for almost
every modern phone, `armeabi-v7a` for old 32-bit devices, `x86_64` for emulators.

## 8. Tests and verification

```bash
flutter analyze        # clean
flutter test           # unit + widget tests
scripts/verify_release_security.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

* Unit: site URL/code normalisation (code, URL, bare host, ports, dev API, http rejected in release, junk), version
  comparison, problem+json parsing (401/402/422 `errors[]`/423 `retryAfterSeconds`/429 `Retry-After`/HTML bodies), friendly
  messages, password policy, SPKI pin extraction (RSA + EC certificates checked against openssl), brand colour
  normalisation and contrast, the onboarding routing guard (every state of the splash -> intro -> connect -> login ->
  password -> primers -> home order), token manager (single-flight refresh with 6 concurrent 401s, proactive refresh,
  `REFRESH_RACE`, session end, network failure keeps the session), role shells against **real `/auth/me` payloads** of the
  student, parent, teacher, principal and super-admin demo users.
* Student/Parent data layer (all against **real API responses** recorded from the demo school in `test/fixtures/api/`):
  `learner_models_test.dart` (every model, including state variants), `learner_repositories_test.dart` (a fake HTTP
  adapter asserts the exact requests: query strings, JSON bodies, multipart upload, error mapping, the dashboard's
  encrypted offline cache and its wipe on sign-out), `learner_state_test.dart` (whose data a screen shows, tab gating by
  permission and school feature, infinite lists, loading/empty/error/"offline, showing last data" states) and
  `format_test.dart` (money, dates, deep-link route mapping).
* Student/Parent screens: `learner_screens_test.dart` builds **every** screen for the student and the parent against the
  fixtures on a 360x800 phone at 100% and 200% text size (layout overflows fail the test), in dark mode, and in the
  offline / empty / server-error states; `learner_flows_test.dart` drives the write flows through the real screens
  (submit homework, add a task, give trip consent, acknowledge an announcement, apply for leave, request a meeting, pay on
  the mock gateway and open the receipt) and checks what went over the wire. The real Inter/Manrope fonts are loaded
  in those tests (`test/support/fonts.dart`), otherwise flutter_test's wide placeholder glyphs report overflows that never
  happen on a phone.
* Widget: Developer options appear in debug builds, collapsed, and persist the API address; they are absent when disabled.
* `verify_release_security.sh` proves the **release** APK: merged manifest has `usesCleartextTraffic=false`,
  `allowBackup=false`, a network security config, no `debuggable`; the packaged network security config contains no
  `cleartextTrafficPermitted="true"` and no `domain-config`; the compiled Dart code (`libapp.so`) contains no
  "Developer options" strings (the section is compiled out because `kDebugMode` is a constant `false`), and no
  `kernel_blob.bin` debug payload ships.

## 9. Store publishing checklist

### 9.1 Before you publish: where the app id lives

The placeholder id is `com.schoolsync.app`. Change it in:

* `android/app/build.gradle.kts` (`namespace` and `applicationId`) and the Kotlin package folder
  `android/app/src/main/kotlin/com/schoolsync/app/` (plus `package` line and the `CHANNEL` name in `MainActivity.kt` and
  `lib/core/security/platform_bridge.dart` if you rename the channel)
* `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`, or in Xcode: Runner -> Signing & Capabilities)
* Firebase: register the Android and iOS apps with the **new** id and re-download `google-services.json` /
  `GoogleService-Info.plist`, or update the dart-defines
* `STORE_URL` dart-define (the store listing URL contains the id)

### 9.2 Google Play

* Build the `.aab`, enrol in Play App Signing, upload with your upload key.
* App content: **Data safety** form (account info, optional push token/device id, no ads, no tracking; data encrypted in
  transit), privacy policy URL (the app links `https://schoolsync.app/privacy`; change it in
  `lib/features/profile/settings_screen.dart`), target audience (a school app is typically 13+ / parents; if students
  under 13 sign in, follow Families policy), content rating questionnaire.
* Permissions used: `INTERNET`, `POST_NOTIFICATIONS`, `USE_BIOMETRIC`, `VIBRATE`.
* Test on a real device with a release build (obfuscated + R8) before submitting; upload the symbol/mapping archive.
* Set the API's `MIN_APP_VERSION` after a release that must be forced.

### 9.3 Apple App Store

* Needs macOS + Xcode (section 10). Sign-in: provide a **review account** (a demo school login) in App Review notes.
* Privacy: `ios/Runner/PrivacyInfo.xcprivacy` is included (no tracking, required-reason APIs declared); fill the App Privacy
  "nutrition label" consistently (contact info/user content linked to the user, no tracking).
* Capabilities: Push Notifications (+ upload your APNs auth key to Firebase), Face ID usage string is set.
* `ITSAppUsesNonExemptEncryption` is `false` (HTTPS only); revisit if you add custom crypto.

## 10. iOS (macOS steps)

`ios/` is scaffolded but cannot be built on Linux. On a Mac with Xcode 16+ and CocoaPods:

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

1. Runner target -> Signing & Capabilities: choose your team; set the bundle identifier (9.1). Confirm **Push Notifications**
   and **Background Modes -> Remote notifications** are enabled (the entitlements file and `UIBackgroundModes` are already
   set; Xcode may add the capability entry for you).
2. Drag `ios/Runner/PrivacyInfo.xcprivacy` into the Runner group and tick the Runner target (it is on disk but Xcode must
   reference it to bundle it).
3. Firebase: add `GoogleService-Info.plist` to the Runner target, or use the dart-defines. In Firebase console upload an APNs
   authentication key (Project settings -> Cloud Messaging).
4. Info.plist already has `NSFaceIDUsageDescription`, portrait-only orientation and ATS defaults (do not add exceptions).
5. Run: `flutter run --dart-define=DEV_API=http://<Mac LAN IP>:4000` (iOS ATS blocks plain http outside local-network
   exceptions; for local dev add `NSAllowsLocalNetworking` temporarily or use an https tunnel).
6. Release: `scripts/build_apk.sh` is Android only; use `flutter build ipa --release --obfuscate
   --split-debug-info=build/symbols/<version>` and archive the symbols the same way.
7. iOS has no `FLAG_SECURE`; screen privacy there is the background cover plus the app lock.

## 11. Working on the shared dev machine

This machine is shared and has frozen before. Run every heavy command through the limiter and one at a time (see
`/home/bala/SCHOOL-SYNC/docs/CONVENTIONS.md` section 13):

```bash
/home/bala/SCHOOL-SYNC/scripts/dev/heavy.sh -m 3G -- flutter analyze      # also: flutter test, flutter pub get
/home/bala/SCHOOL-SYNC/scripts/dev/heavy.sh -m 5G -- flutter build apk ...  # then:  (cd android && ./gradlew --stop)
```

`android/gradle.properties` caps Gradle at 2 GB / 2 workers / in-process Kotlin; do not raise it. Emulator: one at a time,
`-gpu guest -skin 720x1600` and kill it by PID when finished (it maps 2.5 GB of guest RAM whatever `-memory` says).

## 12. Phase 2 assumptions

* Feature endpoints arrive from the API; each screen is built on the existing session, `ApiClient`, `AppException` and
  design-system layer. Student and Parent are done (section 13); Teacher and Management follow the same conventions.
* The tabs and Home cards are wired to `Me.experience`, `Me.permissions` and the school feature flags, so a screen
  replaces a placeholder without touching navigation.
* Parent screens read the child from `selectedChildProvider` (persisted) through `learnerQueryIdProvider`.

## 13. Student and Parent experiences

Both roles use the same screens; what differs is **whose data** they show (`lib/features/learner/learner_context.dart`).
A student sees themselves (the API infers the student, so no `studentId` is sent). A parent sees the selected child and
every request carries `studentId=<child>`; switching the child on the child selector refreshes every screen.

| Area | Screens (`lib/features/...`) | API |
|---|---|---|
| Home | `dashboard/student_home_screen`, `parent_home_screen` (today's classes, attendance, homework, tasks, exams, announcements, calendar; parent adds fees due, meetings, leave) | `GET /dashboard/student`, `/dashboard/parent` |
| Homework | `homework/` list with filters, detail, **submit** a written answer and/or **upload files** (progress, retry, remove), resubmit when returned, teacher feedback and marks | `/homework`, `/homework/:id/submission`, `/homework/:id/submit`, `POST /files` |
| Tasks | `tasks/` my tasks (open, done), add / edit / complete / delete, reminder time, homework mixed into the feed | `/tasks`, `/tasks/feed` |
| Calendar and timetable | `schedule/` month grid with dots, filters, day list; weekly timetable with substitutions | `/calendar`, `/timetable/me` |
| Attendance | `attendance/` percentage, below-threshold warning, monthly chart/table, history with filters | `/attendance/students/:id/summary|records` |
| Results | `exams/` exam list with papers, results with a progress chart, report card (+ PDF) | `/exams`, `/results`, `/results/progress`, `/report-cards/...` |
| Fees (a parent tab; students reach it from the Learning tab) | `fees/` invoices, invoice detail, **pay** (mock gateway), payments, receipts (+ PDF) | `/fees/invoices`, `/fees/invoices/:id/pay`, `/payments`, `/payments/:id/receipt` |
| Announcements | `announcements/` list, detail, read tracking, **acknowledge** | `/announcements` |
| Events | `events/` list, detail, **register / give or decline consent** per child | `/events`, `/events/:id/respond` |
| Meetings (parents) | `meetings/` list, **request** with a teacher and a suggested time, cancel | `/meetings`, `/meetings/teachers` |
| Leave | `leave/` history, **apply** (type, dates, reason, optional note), cancel | `/leave` |
| Notifications | `notifications/` inbox with unread badge in the home header, mark read / all read / delete, tap opens the target screen, per-category push and email settings | `/notifications`, `/notifications/preferences` |
| Learning extras | `learning/` study materials (open/download), syllabus progress, library loans and fines, school bus | `/materials`, `/syllabus/topics`, `/library/my-books`, `/transport/my-bus` |
| Profile | `profile/profile_details_screen` (contact details, emergency contacts, change phone/address, avatar) | `/me/profile` |

How it holds together:

* **Loading, empty, error, offline.** Every list/detail goes through `AsyncBody` (`lib/core/design/async_body.dart`): a
  skeleton while loading, a friendly `ErrorState` with *Try again* when there is nothing to show, and when a refresh
  fails **the last data stays on screen** with an "offline / could not refresh" note. The two home dashboards are also
  kept in the encrypted store (`dash.<user>.<child>`) and open offline with an "You are offline. Showing what was saved at <time>" note. The cache is wiped
  on sign-out and *Change school*.
* **Infinite lists** use `PagedNotifier` / `CursorNotifier` (`lib/core/paged.dart`); a failed "load more" keeps the list.
* **Uploads** go through `FilesRepository.upload` (`POST /files`, multipart `file` + `purpose`), which returns the
  attachment record embedded in the submission or leave request. Files open with the system viewer after an
  authenticated download.
* **Money** is always minor units on the wire; `formatMinor` groups digits the Indian way and handles other currencies.
* **Sensitive screens** (fees, receipts, results, report card, profile) are wrapped in `SecureScope` (screenshots blocked).
* **Deep links** from notifications use the server's `data.route`; `mapServerRoute` maps the web route to the app route and
  ignores anything it does not know.

Known limitations (be honest with testers):

* Online payment works with the school's **mock gateway** (development/demo). A live Razorpay checkout needs its native
  SDK, which this build does not ship: the app says so and points to paying at the school or on the web.
* Push notifications need Firebase configured (section 5). Without it the in-app inbox still works (pull to refresh).
* The student role has no Fees tab by design (the product gives students My Tasks, Calendar, Learning, Profile); students
  with `fees:view` or `payments:view` reach fees from the Learning tab.
* The screens were verified by **tests and static analysis only** in this pass (no screenshots were allowed): the
  widget tests build every screen against real responses at 100% and 200% text and drive the write flows; they do not
  replace a run on a device.

Refreshing the recorded API fixtures (needs the API running locally): log in as `gv20260001` or `9000000001`
(site `demo`, password `Demo@12345`), then save the JSON of the endpoints above into `test/fixtures/api/<name>.json`.
Keep them free of tokens.


## 14. Teacher and Management experiences

Both roles are built on live API data (`GET /dashboard/teacher`, `/dashboard/management` and the module endpoints). The
API enforces scope; the app hides what the role cannot use (`Me.permissions`, `FeatureGate`) and degrades gracefully when
a call is refused (403 hides that block, 404 is "not found or outside your access").

| Area | Where |
|---|---|
| Role wiring | `lib/router/routes_teacher.dart`, `routes_management.dart` (path helpers: `TeacherRoutes.rollCall(id)`, `ManagementRoutes.approval(kind)` ...) |
| Teacher screens | `lib/features/teacher/{home,classes,attendance,homework,marks,more}` |
| Management screens | `lib/features/management/{home,approvals,attendance,academics,people,finance,more,charts}` |
| Shared staff screens and kit | `lib/features/workspace/` (section and student profile, announcements, meetings, check-in, my leave, `runWrite`, `showDecisionSheet`, `AttachmentEditor`, `FeatureGate`, `RefreshOnFocus`) |
| Data | `lib/data/models/staff/*`, `lib/data/repositories/staff/*` (learner-side models and repositories stay in `lib/data/`) |

* **Teacher tabs:** Home (attendance still to mark, today's timetable with the current period, homework to review, marks
  to enter, student leave, meetings, announcements), Classes (roster, syllabus coverage, attendance), Attendance (roll
  call tuned for one hand, history, corrections, student leave), Homework (create/edit, publish/close, roster, review),
  More (timetable, syllabus progress, marks entry, announcements, meetings, my check-in and leave).
* **Management tabs:** Home (KPIs, alerts, approvals queue, attendance with a 7-day `fl_chart` trend, finance, exams,
  enrolment, licence warning for administrators), Academics, People (student lookup, staff directory, admissions),
  Finance (read-only: outstanding, defaulters with tap-to-call, collection), More. **Approvals** (student leave, staff
  leave, attendance corrections, mark sheets, concessions, refunds, expenses, admissions) use one two-step sheet
  (choose, then confirm; reject needs a note).
* **Writes** go through `runWrite` / `showDecisionSheet`: nothing is sent while the school is in view-only mode (402), and
  API problem codes become plain sentences (`friendlyError`, e.g. `EDIT_WINDOW_CLOSED`, `INCOMPLETE_ROLL_CALL`).
* **Attachments** use `image_picker` (camera, photo library) and `file_picker`, uploaded with `purpose=homework|announcement`.
* **Large text:** `ListRow`, `PersonTile` and `ChipLine` move a trailing chip under the text above 135% text scale, and
  every staff screen is covered by a 200% text-scale test.
* Tests: `test/staff_*`, `test/teacher_*`, `test/management_*`, `test/workspace_*`, `test/section_student_profile_test.dart`
  (models and repositories against real captured responses in `test/fixtures/staff/`, fake-HTTP repository tests, widget tests).
