# Important Dates – Flutter Changelog

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
