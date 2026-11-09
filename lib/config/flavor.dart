/// Which edition of Important Dates this build is.
///
/// One code base, two build flavors:
///
/// * **personal** – Kevin's own build. Syncs through the ImportantDates
///   Firebase project (Cloud Firestore + Storage), as before. Bundle id
///   `com.kevinaoneill.ImportantDates.personal` (Android
///   `com.kevinaoneill.importantdates.personal`). Installed through
///   TestFlight / Google Play internal testing only.
/// * **public** – the store app for everyone else (existing bundle id
///   `com.kevinaoneill.ImportantDates`). Syncs through each user's own Google
///   Drive (hidden app folder), so no user data is held by the developer.
///
/// Build with e.g.
///   flutter run --flavor personal -t lib/main_personal.dart
///   flutter build ipa --flavor public -t lib/main_public.dart
/// See FLAVORS_SETUP.md.
enum AppFlavor { personal, public }

class Flavor {
  Flavor._();

  /// Set once at start-up by main_personal.dart / main_public.dart.
  static AppFlavor current = AppFlavor.personal;

  static bool get usesGoogleDrive => current == AppFlavor.public;
  static bool get usesFirebase => current == AppFlavor.personal;

  /// Shown next to the build number in App Info, e.g. "65FL · Personal".
  static String get label => switch (current) {
        AppFlavor.personal => 'Personal',
        AppFlavor.public => 'Public',
      };
}
