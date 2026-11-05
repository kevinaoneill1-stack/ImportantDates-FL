# Important Dates — Flutter (Version 3, Build 61)

A Flutter rebuild of the native iOS **ImportantDates** app (v3 / Build 61) for
**iOS, iPadOS, macOS and Android** from one codebase.

## First run

```bash
cd ImportantDates_v3_Build61
flutter pub get
flutter run -d ios        # or: -d macos, -d android, or pick a device
```

`flutter pub get` fetches packages and creates `ios/Podfile`, `macos/Podfile`,
`android/local.properties` and the generated plugin files automatically.

* **iOS / macOS** – open `ios/Runner.xcworkspace` (or `macos/Runner.xcworkspace`)
  in Xcode once to confirm signing. Team `C62Q8V6ZP5` is already set for iOS;
  pick it under *Signing & Capabilities* for macOS.
* **Android** – needs JDK 17+ (Android Studio's bundled JDK is fine). Release
  builds are signed with the debug key until you add your own keystore in
  `android/app/build.gradle.kts`.

## Identifiers

| Platform | Identifier |
|---|---|
| iOS / macOS | `com.kevinaoneill.ImportantDates` (same App Store record as the native app) |
| Android | `com.kevinaoneill.importantdates` |

This build replaces the native app on the App Store. Records stored by the native
app (SwiftData/iCloud) are not read automatically: export a backup in the native
app before updating, then use Manage → Backup & Restore → Restore Backup.

## Version numbers

`pubspec.yaml` → `version: 3.0.0+61` (Flutter requires a three-part version;
the app UI shows "Version 3 • Build 61" from `lib/app_info.dart`). Bump both
together for the next build.

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
| Automatic backups (daily…monthly, change-triggered, keep 10) | ✅ |
| App passcode lock, Delete-All passcode | ✅ |
| Launch disclaimer, Developer Controls (707 / 1028) | ✅ Debug & Profile builds only (see `lib/data/developer_access.dart`) |
| SwiftData + iCloud/CloudKit sync | ⚠️ Local storage on each device; move data with Backup & Restore |
| Home Screen widget, Apple Watch app | ❌ Not included (native-only targets) |

## Project layout

```
lib/
  main.dart, app_info.dart
  models/      ImportantDate, ItemAttachment
  data/        AppStore (records), AppSettings (preferences), DeveloperAccess
  services/    notifications, backups, PDF reports, file share/pick/open
  theme/       colours, category icons, status colours
  widgets/     cards, headers, page scaffolding
  screens/     every screen of the app
assets/        default Home image, DejaVu fonts for PDF reports
```
