# Important Dates — Flutter edition

**Version 3.0.74FL** (Version 3 • Build 74FL)

A Flutter version of the native iOS **ImportantDates** app for **iPhone, iPad,
Mac and Android** from one code base. It replaces the native app on the App
Store (same bundle identifier).

The build number goes up by one with every change set
(`dart run tool/bump_build.dart`). The project lives in one fixed folder,
`Flutter Apps/ImportantDates/ImportantDates_FL`, which is a git repository
(GitHub: `kevinaoneill1-stack/ImportantDates-FL`): every build is a commit with
a tag such as `v3.0.64FL` (see **Versions with git** below).

## Getting started

Requires Flutter 3.35 or newer. The shared `document_store` package is fetched
from its (private) GitHub repo by `flutter pub get`, so git must be signed in to
GitHub. To build against a local `document-store` folder instead, copy
`pubspec_overrides.example.yaml` to `pubspec_overrides.yaml` (see CLOUD_SYNC_SETUP.md).

```bash
cd "/Users/kevinoneill/Kevin/Flutter Apps/ImportantDates/ImportantDates_FL"
flutter pub get
flutter run                 # pick a connected device / simulator
flutter run -d macos
flutter test
```

* **iOS / macOS** – open `ios/Runner.xcworkspace` (or `macos/Runner.xcworkspace`)
  in Xcode once to confirm signing. Team `C62Q8V6ZP5` is set for both.
  macOS is signed with "Apple Development" because Firebase sign-in uses the keychain.
* **Android** – needs JDK 17+ (Android Studio's bundled JDK is fine). Release
  builds are signed with the debug key until you add your own keystore in
  `android/app/build.gradle.kts`. Minimum Android 6.0 (API 23) for Firebase.

## Two editions (from 3.0.66FL)

One code base, two build flavors. Always build with `--flavor` and the matching
entry point (details and one-time set-up: **FLAVORS_SETUP.md**):

| Edition | Sync | iOS / macOS id | Android id | Build |
|---|---|---|---|---|
| **public** (App Store / Play) | each user's own Google Drive | `com.kevinaoneill.ImportantDates` | `com.kevinaoneill.importantdates` | `--flavor public -t lib/main_public.dart` |
| **personal** (TestFlight / internal testing) | Firebase Cloud Sync | `com.kevinaoneill.ImportantDates.personal` | `com.kevinaoneill.importantdates.personal` | `--flavor personal -t lib/main_personal.dart` |

```bash
flutter run --flavor personal -t lib/main_personal.dart
flutter run -d macos --flavor public -t lib/main_public.dart
flutter build ipa --flavor public -t lib/main_public.dart
flutter build appbundle --flavor public -t lib/main_public.dart
```

## Identifiers

| Platform | Identifier |
|---|---|
| iOS / macOS | `com.kevinaoneill.ImportantDates` (public edition; same App Store record as the native app) |
| Android | `com.kevinaoneill.importantdates` (public edition) |

Records stored by the native app (SwiftData/iCloud) are not read automatically:
export a backup in the native app before updating, then use Manage → Backup &
Restore → Restore Backup.

## Cloud Sync (from 3.0.64FL)

Dates, item types, names, Home settings and attachment files sync between
iPhone, iPad, Mac and Android through the **ImportantDates** Firebase project
(Firestore for records, Storage for files through the shared `document_store`
package, appId `important-dates`). One-time set-up: **CLOUD_SYNC_SETUP.md**.
Until it is done the app works exactly as before, with Cloud Sync shown as
"Not set up yet".

* Attachments added on any device upload in the background; a file is
  downloaded to another device the first time it is opened, and automatically
  for dates due within 30 days. **Download All Attachments** on the Cloud Sync
  page keeps every file offline; Export Backup downloads them first so the
  backup is complete.
* **Safer sync** (as in MyTravelApp 4.6.142FL): a record is only deleted in the
  cloud when it was on this device and you deleted it. A device whose data is
  empty (reinstalled, restored, unreadable) downloads everything again instead.
  Deleting more than 10 records and more than half of everything at once is
  blocked, except for Delete All Data and Restore Backup, which ask first.
* **Daily backups**: the latest automatic backup is never replaced by an empty
  data set, and a copy is kept for each of the last 7 days (Manage › Backup &
  Restore › Daily Backups, tap one to restore it).

## Versions with git (from 3.0.63FL)

After making changes:

```bash
dart run tool/bump_build.dart          # e.g. 64FL -> 65FL
git add -A
git commit -m "ImportantDates 3.0.65FL: what changed"
git tag v3.0.65FL
git push && git push --tags
```

Useful commands:

```bash
git log --oneline                      # list builds
git diff v3.0.63FL v3.0.64FL           # what changed between two builds
git switch --detach v3.0.63FL          # look at / build an old version
git switch main                        # back to the latest
```

The folder name no longer changes between builds, so Xcode caches keep working.

## Feature parity with the native app

| Native feature | Flutter version |
|---|---|
| 5 tabs: Home, Items, Calendar, Tools, Manage | ✅ (bottom bar; side rail on wide Mac/iPad windows) |
| Home hero image, custom title, Fill/Fit/Center, brightness, blur | ✅ |
| 30 / 31–60 / 61–90 day summary, next three due, shortcuts | ✅ |
| Add / edit records, travel document & accomplished flags, notes | ✅ |
| 90/60/30/7-day reminders at 9:00 am, contextual permission | ✅ (`flutter_local_notifications`) |
| All Items search, quick filters, item/name menus, date range, PDF export | ✅ |
| Item detail, attachments (PDF/images), complete / duplicate / delete | ✅ (swipe actions → long-press or right-click menu) |
| Calendar with due-date dots, Timeline, Global Search, Statistics | ✅ |
| PDF reports (6 report types, branded layout, page numbers) | ✅ (`pdf` package) |
| Travel Documents with search & show-completed | ✅ |
| Manage Items / Names with duplicate check & delete confirmation | ✅ |
| Backup & Restore (JSON incl. attachments & Home appearance) | ✅ **same file format as the iOS app — backups restore in either app** |
| Automatic backups (daily…monthly, change-triggered, keep 10) | ✅ plus a copy for each of the last 7 days; never replaced by an empty data set |
| App passcode lock, Delete-All passcode | ✅ |
| Launch disclaimer, Developer Controls | ✅ Debug & Profile builds only, codes from the git-ignored `dev_codes.json` (see FLAVORS_SETUP.md) |
| SwiftData + iCloud/CloudKit sync | ✅ **Cloud Sync through Firebase** (from 3.0.64FL), including attachment files |
| Home Screen widget | ✅ "Upcoming Dates" on iPhone/iPad (home + lock screen) and Android, from 3.0.73FL (see WIDGET_SETUP.md); not on Mac |
| Apple Watch app | ❌ Not included (native-only target) |

## Project layout

```
lib/
  main.dart, app_info.dart
  models/      ImportantDate, ItemAttachment
  data/        AppStore (records), AppSettings (preferences), DeveloperAccess
  services/    Cloud Sync, attachment sync, notifications, backups, PDF reports,
               file share/pick/open
  firebase_options.dart   placeholder until `flutterfire configure`
  theme/       colours, category icons, status colours
  widgets/     cards, headers, page scaffolding
  screens/     every screen of the app
assets/        default Home image, DejaVu fonts for PDF reports
tool/          bump_build.dart, flavorize_xcode.py, add_ios_widget.py
ios/ImportantDatesWidget/   iOS widget extension (WidgetKit)
firestore.rules, storage.rules   Firebase security rules (publish in the console)
```
