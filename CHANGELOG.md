# Important Dates – Flutter Changelog

## 3.0.74FL
- The public edition's name under its icon is now **My Dates** (iPhone/iPad and Android). The personal edition
  stays "Important Dates Personal"; the Mac app and the name inside the app, reports and backups are unchanged.

## 3.0.73FL
- **Home screen widget "Upcoming Dates"** on iPhone/iPad and Android: the next items due, days left, and how many
  are due within 30 days or overdue. iOS: small, medium and large home screen sizes plus lock screen (inline,
  circular, rectangular), iOS 17+. Android: resizable, 1–4 items. Days left move on daily without opening the app.
  Data goes through `home_widget` (`lib/services/home_widget_sync.dart`); per-flavor App Groups on iOS.
- App Settings › Home Screen Widget › **Show Item Names** (on by default): off, the widget shows only dates and
  counts, as it can be seen without unlocking the app.
- iOS project: new target ImportantDatesWidgetExtension and Runner entitlements (`tool/add_ios_widget.py`).
  One-time App Group setup on developer.apple.com: see WIDGET_SETUP.md. No widget on macOS yet.

## 3.0.72FL
- Attachments: the + button offers Photo Library, Take Photo or Files on iOS and Android (before, only Files,
  which does not show the photo library on iPhone). Photos are saved as JPEG named "Photo <date> <time>.jpg".
  macOS still opens the Files dialog. Uses image_picker.
- PDF reports (Reports, All Items, Travel Documents) open in a preview first, with Export in the top bar.
  Uses printing (PdfPreview).

## 3.0.71FL
- New ready-made Item: Health Insurance (added once on devices that already had the first 15).
- Picking Passport, Passport Card, Travel Insurance, Driving Licence or Health Insurance on Add / Edit Item
  switches on Travel Document (it can still be switched off). Lists in `lib/data/default_items.dart`.

## 3.0.70FL
- 15 ready-made Items (Boiler Service, Car Insurance, Car NCT, Car Service, Car Tax, Driving Licence, Drugs Payment
  Scheme Card, House Insurance, LPT, Passport, Passport Card, Public Service Card, Travel Insurance, TV Licence, VHI)
  are added to Manage › Items once on each device, new or existing; ones already there are not duplicated, and ones
  the user deletes are not added back. List in `lib/data/default_items.dart`.

## 3.0.69FL
- Fix: no keyboard anywhere in the public iOS app. Removed `EXCLUDED_SOURCE_FILE_NAMES` (which left
  GoogleService-Info.plist out of public iOS/macOS builds); the file is back in both editions, unused by public.

## 3.0.68FL
- **App lock.** Passcodes are stored as salted, hashed values in the keychain / Android keystore
  (flutter_secure_storage) instead of plain text; existing passcodes move over on first start. The app locks again
  after a minute in the background (the screens underneath are kept). After 5 wrong passcodes, entry waits 1, 2,
  4 … up to 60 minutes (app lock and Delete All). Optional Face ID / Touch ID / fingerprint unlock in App Settings
  (local_auth; Android MainActivity is now a FlutterFragmentActivity with AppCompat themes).
- **Builds anywhere.** `document_store` comes from its GitHub repo instead of `../../document-store`;
  `pubspec_overrides.example.yaml` switches back to a local copy. GitHub Actions workflow runs analyze and tests
  once the DOCUMENT_STORE_TOKEN secret is added.
- **Sync tests.** The Cloud Sync and Drive Sync record rules (bulk-delete guard, deletes only for records that were
  on the device, conflict handling, tombstones) moved into `lib/services/sync_rules.dart`, unchanged, with tests.
- **No silent errors.** Problems the app recovers from are logged (AppLog) and listed under App Settings ›
  Recent Problems.
- **Public edition without Firebase config.** Its builds leave out google-services.json and GoogleService-Info.plist.

## 3.0.67FL
- Developer codes are no longer in the source code. They come from the git-ignored `dev_codes.json` at build time
  (`--dart-define-from-file=dev_codes.json`, template `dev_codes.example.json`); without it developer access is off.
  See FLAVORS_SETUP.md.
- Home page title defaults to "Your Name here". Tap the title on Home to enter or change it (also in
  Manage › App Settings › Home Appearance). The placeholder is never synced to other devices.
- Help & Instructions opens automatically the first time the app is opened (not for existing installs with dates).
- Tools & Reports: Search Everything moved to the bottom of the list (and of the Tools Shortcuts switches).

## 3.0.66FL
- Two editions from one code base (build flavors, see FLAVORS_SETUP.md):
  - **personal** – Firebase Cloud Sync as before; bundle id `com.kevinaoneill.ImportantDates.personal`
    (Android `com.kevinaoneill.importantdates.personal`), shown as "Important Dates Personal".
    Entry point `lib/main_personal.dart`.
  - **public** – the store app (existing bundle id). Syncs through each user's own Google Drive (hidden app data
    folder, scope `drive.appdata`): records, item types, names, Home settings and attachment files. No user data
    is held by the developer. Entry point `lib/main_public.dart`.
- New DriveSync service with the same safety rules as Cloud Sync (no deletes for missing records, emptied devices
  download again, bulk-delete guard, unreadable sync files are never overwritten), first-sync Merge / Use Drive
  choice, Delete My Google Drive Data.
- Sync-dependent screens (Data & Sync Status, Backup & Restore, attachments, Manage › Cloud Sync) use whichever
  service the build has.
- The personal edition has its own app icon with an orange "P" badge (AppIcon-personal on iOS/macOS,
  android/app/src/personal/res on Android).
- Android productFlavors; iOS and macOS Debug/Release/Profile-personal and -public configurations and schemes
  (tool/flavorize_xcode.py), Google sign-in URL scheme in Info.plist, macOS GIDSignIn keychain group.

## 3.0.65FL
- iOS: added the Face ID usage description (NSFaceIDUsageDescription). Without it iOS closed the app as soon as
  it asked for Face ID on first launch.

## 3.0.64FL
- Cloud Sync through a new Firebase project (ImportantDates): dates, item types, names, Home title/appearance and
  Tools shortcuts stay the same on iPhone, iPad, Mac and Android. Sign in under Manage › Cloud Sync.
- Attachment files sync through the shared document-store package (Firebase Storage, appId `important-dates`):
  uploaded in the background, downloaded when first opened and automatically for dates due within 30 days;
  Download All Attachments; Export Backup downloads cloud-only files first.
- Safer sync: records are only deleted in the cloud when deleted on this device; an emptied device downloads again;
  bulk deletes (more than 10 and more than half) are blocked except for Delete All Data and Restore Backup.
- Daily backups: one copy for each of the last 7 days (Backup & Restore › Daily Backups); automatic backups are
  never made from an empty data set while the latest backup has data. An unreadable data file is copied aside.
- App Settings › Data & Sync Status shows the sync state and opens Cloud Sync.
- macOS: network and keychain entitlements, Apple Development signing (needed for Firebase sign-in).
  Android: INTERNET permission, minimum API 23.
- Project moved to the fixed folder ImportantDates_FL under git (GitHub ImportantDates-FL), one tag per build;
  `dart run tool/bump_build.dart` increases the build number.

## 3.0.63FL
- In-app build number shows "FL"; NSLocationWhenInUseUsageDescription added for App Store Connect (ITMS-90683).

## Version 3, Build 61 (Flutter)
- First Flutter release, rebuilt from the native iOS ImportantDates_v3_Build61 project.
- Targets iOS, iPadOS, macOS and Android from a single codebase.
- Full feature set of the iPhone/iPad app: Home, Items, Calendar, Tools, Manage tabs; records, reminders,
  attachments, PDF reports, Travel Documents, statistics, passcodes, launch disclaimer and developer controls.
- Backup files are interchangeable with the native iOS app (same JSON format, ISO-8601 dates, base64 attachments).
- Data is stored locally per device; iCloud/CloudKit sync, the Home Screen widget and the Apple Watch companion
  remain native-only.
