# Home screen widget: "Upcoming Dates"

From 3.0.73FL the app has a widget on **iPhone/iPad** (home screen and lock
screen) and **Android** (home screen). It shows the next items due, the days
left, and how many are due within 30 days or overdue. Tapping it opens the app.
macOS has no widget yet.

| | iOS | Android |
|---|---|---|
| Sizes | Small (next item), Medium (3 items), Large (totals + 6 items); lock screen: inline, circular, rectangular | 4×2 by default, resizable; shows 1–4 items depending on height |
| Code | `ios/ImportantDatesWidget/ImportantDatesWidget.swift` (WidgetKit, iOS 17+) | `android/app/src/main/kotlin/com/kevinaoneill/importantdates/UpcomingDatesWidgetProvider.kt`, `res/layout/upcoming_dates_widget.xml` |
| Data | App Group `UserDefaults` | `HomeWidgetPreferences` (SharedPreferences) |

## How it works

`lib/services/home_widget_sync.dart` (package `home_widget`) listens to
`AppStore` and `AppSettings`. After any change (on this device or from sync) it
saves a small JSON summary under the key `upcoming_dates` and asks the system to
redraw the widget:

```json
{"version": 1, "showDetails": true,
 "items": [{"due": "2027-03-09", "item": "Passport", "name": "Me", "travel": true}]}
```

Only active (not completed) items are sent, soonest first, at most 40. The
widget works out the days left itself, so it stays right from day to day
without the app being opened (iOS: a timeline entry for each of the next 7
midnights; Android: redrawn every 6 hours).

**Manage › App Settings › Home Screen Widget › Show Item Names.** The widget can
be seen without unlocking the app. Switched off, item and name never leave the
app: the widget shows only due dates, days left and counts.

## Flavors

| | personal | public |
|---|---|---|
| iOS App Group | `group.com.kevinaoneill.ImportantDates.personal` | `group.com.kevinaoneill.ImportantDates` |
| iOS widget bundle id | `com.kevinaoneill.ImportantDates.personal.Widgets` | `com.kevinaoneill.ImportantDates.Widgets` |
| Android | same widget in both (the provider is found by its full class name, `com.kevinaoneill.importantdates.UpcomingDatesWidgetProvider`) | |

The App Group is `APP_GROUP_ID` in `ios/Flutter/Flavor-<flavor>.xcconfig`. It is
used by both entitlements files (`Runner/Runner.entitlements`,
`ImportantDatesWidget/ImportantDatesWidget.entitlements`) and by the widget's
Info.plist (`AppGroupId`). The Dart side picks the same id from the flavor
(`HomeWidgetSync.appGroupId`); change both together.

iOS builds without `--flavor` use the public App Group but the personal Dart
code, so their widget stays empty. Always pass a flavor.

## One-time setup (iOS)

The Xcode target is already in the project (added by
`tool/add_ios_widget.py`). Apple needs to know the two App Groups once:

1. **developer.apple.com › Certificates, Identifiers & Profiles › Identifiers ›
   + › App Groups**: add `group.com.kevinaoneill.ImportantDates` and
   `group.com.kevinaoneill.ImportantDates.personal`.
2. In Terminal:

   ```bash
   cd "/Users/kevinoneill/Kevin/Flutter Apps/ImportantDates/ImportantDates_FL"
   flutter pub get
   cd ios && pod install && cd ..
   ```

3. Open `ios/Runner.xcworkspace`. For the **Runner** and
   **ImportantDatesWidgetExtension** targets, open **Signing & Capabilities**:
   automatic signing with your team should now list **App Groups** with the
   right group ticked. If it shows a signing error, press **Try Again**, or
   tick the group under App Groups (once for each target and edition).
4. Build as usual, e.g. `flutter run --flavor personal -t lib/main_personal.dart`,
   then touch and hold the home screen › **+** › **Important Dates**.

If Xcode reports a **build cycle** mentioning "Thin Binary": in the Runner
target's Build Phases, **Embed Foundation Extensions** must come before
**Thin Binary** (the script already places it there).

App Store / TestFlight: the widget is inside the app, so nothing else to upload.
App Store Connect needs no change; the new widget bundle ids are created by
automatic signing.

## Android

Nothing to set up: `flutter run --flavor <flavor> -t lib/main_<flavor>.dart`,
then long-press the home screen › Widgets › **Important Dates**.
