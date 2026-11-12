# Two editions: personal (Firebase) and public (Google Drive)

From 3.0.66FL the app builds as two **flavors** from one code base. A bug fix or
feature goes into both.

| | **personal** | **public** |
|---|---|---|
| For | You (TestFlight / Play internal testing) | Everyone (App Store / Play Store) |
| Sync | Firebase Cloud Sync, as before (`CloudSync`, `AttachmentSync`) | Each user's own Google Drive (`DriveSync`) |
| Entry point | `lib/main_personal.dart` | `lib/main_public.dart` |
| iOS / macOS id | `com.kevinaoneill.ImportantDates.personal` | `com.kevinaoneill.ImportantDates` (existing App Store record) |
| Android id | `com.kevinaoneill.importantdates.personal` | `com.kevinaoneill.importantdates` |
| Home-screen name | Important Dates Personal | Important Dates |

Always pass both `--flavor` and `-t`:

```bash
cd "/Users/kevinoneill/Kevin/Flutter Apps/ImportantDates/ImportantDates_FL"
flutter pub get

flutter run --flavor personal -t lib/main_personal.dart          # iPhone / Android
flutter run -d macos --flavor personal -t lib/main_personal.dart

flutter run --flavor public -t lib/main_public.dart

flutter build ipa --flavor public -t lib/main_public.dart         # App Store
flutter build appbundle --flavor public -t lib/main_public.dart   # Play Store
flutter build ipa --flavor personal -t lib/main_personal.dart     # TestFlight, for you
```

In Android Studio: Run › Edit Configurations › add two Flutter configurations,
Dart entrypoint `lib/main_personal.dart` / `lib/main_public.dart`, Build flavor
`personal` / `public`. In Xcode: pick the **personal** or **public** scheme.

### Uploads to TestFlight / App Store: always with `flutter build ipa`

Make every upload with `flutter build ipa --flavor <personal|public> -t
lib/main_<flavor>.dart`, not with **Product › Archive** in Xcode. Then upload
`build/ios/ipa/*.ipa` with the Transporter app, or open the archive from
`build/ios/archive/` in Xcode's Organizer › **Distribute App**.

Why: the Xcode scheme only chooses the bundle id, icon, App Group and
signing. Which Dart code goes in (`main_personal.dart` or `main_public.dart`)
comes from `ios/Flutter/Generated.xcconfig`, which is written by the **last
`flutter` command you ran**, whatever its flavor. Archiving the personal
scheme after a public `flutter run` or `--config-only` build gives a personal
app running the public code. That happened with build 73 (personal): signing
in crashed (the public edition's Google sign-in has no URL scheme in the
personal app) and the widget stayed empty (the public code writes to the
public App Group).

Running from Xcode (⌘R) has the same catch: first run
`flutter build ios --config-only --flavor <flavor> -t lib/main_<flavor>.dart`
for the scheme you are about to use.

## Developer access codes (kept out of git)

Developer Controls (tap **App Information** in Manage › App Settings) and the
developer passcode override only work in Debug and Profile builds, and only when
the build is given the codes. The codes are not in the source code, because the
repository is public.

1. Copy `dev_codes.example.json` to `dev_codes.json` in the project root (it is
   git-ignored) and fill in `DEV_OVERRIDE_PASSCODE` and `DEV_CONTROLS_PASSCODE`.
2. Add `--dart-define-from-file=dev_codes.json` to development runs, e.g.

```bash
flutter run --flavor personal -t lib/main_personal.dart --dart-define-from-file=dev_codes.json
```

In Android Studio, put `--dart-define-from-file=dev_codes.json` in the run
configuration's *Additional run args*. Builds started from Xcode, or without the
file, simply have no developer access. Release builds (TestFlight, App Store, Play)
never have it unless `DEV_FORCE_ENABLE_IN_RELEASE` is `"true"` in the file for
that build — set it back to `"false"` afterwards.

### Firebase and the public edition

The public edition never starts Firebase. Its Android build skips
`google-services.json` (`android/app/build.gradle.kts`). On iOS and macOS,
`GoogleService-Info.plist` stays in both editions: leaving it out with
`EXCLUDED_SOURCE_FILE_NAMES` stopped the keyboard from appearing anywhere in the
public iOS app (3.0.68FL), so don't use that setting. The file is unused there.
Firebase itself is started from
`lib/firebase_options.dart`, so the personal edition does not depend on those files.

The Firebase SDK code is still compiled into the public app: Flutter links every
plugin in pubspec.yaml into every flavor, and has no per-flavor dependencies. It
is never called, so it sends nothing. Removing it completely would mean splitting
the project into a shared package plus two small apps, each with its own
pubspec.yaml.

How it is wired (already done in the project):

* Dart: `lib/config/flavor.dart` (`Flavor.usesGoogleDrive`), `lib/main.dart`
  (`runImportantDates`), `lib/services/sync_backend.dart` (`Sync.state`,
  `Sync.attachments` – the screens use these, so they work with either service),
  `lib/screens/sync_screen.dart` (Manage › Cloud Sync opens the right page).
* Android: `productFlavors` in `android/app/build.gradle.kts`; the app name comes
  from `@string/app_name`.
* iOS / macOS: build configurations `Debug-personal`, `Release-personal`,
  `Profile-personal` and the same for `-public`, schemes `personal` and
  `public` (added by `tool/flavorize_xcode.py`), per-flavor settings in
  `ios/Flutter/Flavor-*.xcconfig` and `macos/Runner/Configs/AppInfo*.xcconfig`,
  the CocoaPods mapping in `ios/Podfile`.
* Builds without `--flavor` still work on iOS/macOS (existing bundle id, Firebase
  sync), but Android needs a flavor, so get used to always passing one.

The first iOS build after this change runs `pod install` for the new
configurations. If Xcode complains about missing `Pods-Runner.debug-personal`
files, run `cd ios && pod install`.

---

## A. Personal edition: connect it to Firebase (once)

The personal app has a new bundle id, so the ImportantDates Firebase project
needs to know it. Your existing account and cloud data stay as they are: it is
the same Firebase project, you just sign in again in the personal app.

1. **Firebase console › ImportantDates › Project settings › Your apps › Add app**
   * **Apple**, bundle id `com.kevinaoneill.ImportantDates.personal`
     (one Apple app covers iPhone, iPad and Mac). Skip the download steps.
   * **Android**, package `com.kevinaoneill.importantdates.personal`. Skip the
     download steps.
2. In Terminal:

   ```bash
   export PATH="$PATH:$HOME/.pub-cache/bin"
   cd "/Users/kevinoneill/Kevin/Flutter Apps/ImportantDates/ImportantDates_FL"
   mkdir -p android/app/src/personal
   flutterfire configure \
     --project=<the ImportantDates project id> \
     --platforms=ios,macos,android \
     --ios-bundle-id=com.kevinaoneill.ImportantDates.personal \
     --macos-bundle-id=com.kevinaoneill.ImportantDates.personal \
     --android-package-name=com.kevinaoneill.importantdates.personal \
     --out=lib/firebase_options.dart \
     --android-out=android/app/src/personal/google-services.json
   ```

   If it asks whether to use a build configuration or a target for iOS/macOS,
   choose **target › Runner**.

   * `lib/firebase_options.dart` now points at the personal apps. Only the
     personal edition uses Firebase, so that is all it needs.
   * `android/app/src/personal/google-services.json` is used for personal
     Android builds; `android/app/google-services.json` stays for the public
     ones (the Gradle plugin needs it, although the public edition does not
     start Firebase).
3. Until step 2 is done, **personal Android builds stop** with "No matching
   client found for package name …personal". The iOS and Mac personal builds
   still run (Firebase may log a bundle id warning).
4. Run the personal app, Manage › Cloud Sync › **Sign In** with your existing
   email and password. Your data comes down from the cloud as before.

## B. Public edition: set up Google sign-in for Drive (once)

Use the Google Cloud project behind the ImportantDates Firebase project
(console.cloud.google.com, project picker › ImportantDates). Any project works,
but keep all three OAuth clients below in the same one.

1. **APIs & Services › Library › Google Drive API › Enable.**
2. **Google Auth Platform** (OAuth consent screen):
   * **Branding**: app name *Important Dates*, support email, app home page and
     privacy policy URLs (your GitHub Pages site works; the privacy policy should
     say data is stored in the user's own Google Drive app folder and is not
     collected by you), authorised domain `github.io` if you use it.
   * **Audience**: External. While it says *Testing*, only test users you add
     can sign in; press **Publish app** when ready.
   * **Data access › Add or remove scopes**: add
     `https://www.googleapis.com/auth/drive.appdata` ("See, create, and delete its
     own configuration data in your Google Drive"). Google classifies it as
     **non-sensitive**, so only the basic brand verification is needed.
3. **Clients › Create client** – three of them:
   * **iOS**, bundle id `com.kevinaoneill.ImportantDates`, Team ID `C62Q8V6ZP5`.
     Copy the **Client ID** and the **iOS URL scheme**
     (`com.googleusercontent.apps.…`). The Mac app uses the same client.
   * **Android**, package `com.kevinaoneill.importantdates`, SHA-1 of your debug
     key (`cd android && ./gradlew signingReport`). Add a second Android client
     with the SHA-1 of the **Play app signing key** (Play Console › Setup › App
     signing) before releasing on Play, and of your upload key if you sign
     release builds yourself. Nothing to copy from these.
   * **Web application** (no URLs needed). Copy its **Client ID**: Android uses
     it as the "server client id".
4. Fill them in:
   * `lib/config/google_drive_config.dart`: `iosClientId` = the iOS client id,
     `webClientId` = the Web client id.
   * `ios/Flutter/Flavor-public.xcconfig` and `macos/Runner/Configs/AppInfo.xcconfig`:
     replace `com.googleusercontent.apps.REPLACE-ME` with the iOS URL scheme.
5. Run the public edition, Manage › Cloud Sync › **Sign In with Google**. On
   another device sign in with the same Google account; the data comes down.

Until step 4 is done the public edition works fully offline and Manage › Cloud
Sync says "Not Set Up Yet".

Worth reading before release: Google's **Drive API Terms of Service** (it
restricts some backup uses of Drive) and the App Store / Play privacy forms
(data stored in the user's own Google account, not collected by you).

### How the Drive sync works

* Everything is in the hidden **app data folder** of the user's Drive: only this
  app can see it, it does not appear among their files, and it counts against
  their own storage. You have no server and see no data.
* `important_dates_sync.json` holds every record with its last-change time and
  markers for deleted records. Each attachment is its own file
  (`attachment-<id>`), and its Drive file id is stored on the attachment so the
  other devices can download it.
* Sync runs at start-up, when the app returns to the foreground, a few seconds
  after each change and every 3 minutes while open. A record changed on one
  device only takes that change; changed on two devices, the later edit wins.
* Same safety rules as Firebase Cloud Sync: missing records are never deleted
  in Drive, an emptied device downloads again, bulk deletes are blocked unless
  deliberate (Delete All Data, Restore Backup), and a sync file that cannot be
  read is never overwritten.
* **Delete My Google Drive Data** removes the app's files from Drive and
  disconnects the Google account (Apple and Google require an in-app way to
  delete cloud data).

## Moving existing public users

If any public users already sign in to Firebase Cloud Sync (3.0.64FL/65FL
builds), their data stays on their devices. After updating to the public
edition they sign in with Google once and the device uploads its data to their
Drive. Their old Firebase copy is no longer used.
