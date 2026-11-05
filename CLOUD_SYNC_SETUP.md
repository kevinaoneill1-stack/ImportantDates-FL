# Cloud Sync set-up (one time)

Cloud Sync uses its own Google Firebase project for Important Dates (separate
from MyTravelApp). You only do this once; later builds keep the settings.

## 1. Create the Firebase project (in a web browser)

1. Go to https://console.firebase.google.com and sign in with your Google account.
2. **Create a project** called `ImportantDates`. Google Analytics is not needed.
3. **Build › Authentication › Get started › Sign-in method › Email/Password › Enable › Save.**
4. **Build › Firestore Database › Create database**
   * Location: `eur3 (europe-west)` (same as MyTravelApp). This can't be changed later.
   * Start in **production mode**.
   * Open the **Rules** tab, replace everything with the contents of
     `firestore.rules` from this folder, and press **Publish**.
5. **Build › Storage › Get started** (needed for attachment files)
   * Storage needs the **Blaze (pay as you go)** plan, as for MyTravelApp. Normal
     use stays inside the free allowance; set a budget alert (e.g. €5) under
     Google Cloud › Billing.
   * Same location as Firestore.
   * Open the **Rules** tab, replace everything with the contents of
     `storage.rules` from this folder, and press **Publish**.

## 2. Connect the app (in Terminal on the Mac)

The tools are already installed from MyTravelApp (`firebase`, `flutterfire`).
If not: `curl -sL https://firebase.tools | bash`, then
`dart pub global activate flutterfire_cli` and `firebase login`.

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
cd "/Users/kevinoneill/Kevin/Flutter Apps/ImportantDates/ImportantDates_FL"
flutterfire configure \
  --project=<the ImportantDates project id, e.g. importantdates-1a2b3> \
  --platforms=ios,macos,android \
  --ios-bundle-id=com.kevinaoneill.ImportantDates \
  --macos-bundle-id=com.kevinaoneill.ImportantDates \
  --android-package-name=com.kevinaoneill.importantdates
flutter pub get
flutter run
```

If you leave out `--project`, choose the **ImportantDates** project when asked
(not MyTravelApp). iPhone/iPad and Mac use the same bundle identifier, so
flutterfire uses one Apple app for both; that is fine.

`flutterfire configure` replaces `lib/firebase_options.dart` (the placeholder
in git) and writes `ios/Runner/GoogleService-Info.plist`,
`macos/Runner/GoogleService-Info.plist`, `android/app/google-services.json`
and `firebase.json`. Commit them:

```bash
git add -A && git commit -m "Connect Firebase project ImportantDates" && git push
```

## 3. Turn it on in the app

Manage › **Cloud Sync** (or App Settings › Data & Sync Status) › **Create
Account** on the first device, **Sign In** on the others, with the same email
and password. This account is separate from the Travel one (separate Firebase
project), but you can use the same email.

* The first device uploads its data and attachment files.
* Each further device asks whether to **Merge** its own data with the cloud or
  **Use Cloud Data** (replacing what is on that device).

Before signing in on an iPhone that still has records from the native iOS app:
export a backup there first (native app › Manage › Backup & Restore), then
restore it in this app before turning on Cloud Sync.

## What syncs

| Synced | Kept on each device |
| --- | --- |
| Important Dates (all fields, reminders, notes) | App passcode and Delete All passcode |
| Attachment files (Firebase Storage, via `document_store`) | Automatic backup settings and backup files |
| Item types and names | The Home photo |
| Home title, image position, brightness, blur | The disclaimer acknowledgement |
| Tools shortcuts | Developer controls |

Reminders are scheduled on every device from the synced dates.

## The `document-store` folder

Attachments use the shared package in `Flutter Apps/document-store`
(the `document-store` GitHub repo), the same as MyTravelApp. The project expects:

```
Flutter Apps/
  document-store/          <- git clone https://github.com/kevinaoneill1-stack/document-store
  ImportantDates/
    ImportantDates_FL/     <- this project
```

Files are stored under `users/{uid}/important-dates/docs/…` with records in
`users/{uid}/documents` (appId `important-dates`). See
`document-store/DOCUMENT_STORE_SPEC.md`.
