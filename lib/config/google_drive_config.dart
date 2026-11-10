import 'dart:io';

/// Google sign-in settings for the public (Google Drive) edition.
///
/// Fill these in once, from Google Cloud Console › APIs & Services ›
/// Credentials of the ImportantDates project (see FLAVORS_SETUP.md, part B).
/// They are not secret: OAuth client ids of mobile apps ship inside the app.
class GoogleDriveConfig {
  GoogleDriveConfig._();

  /// OAuth client of type **iOS** for bundle id `com.kevinaoneill.ImportantDates`
  /// (also used by the Mac app), e.g.
  /// `1234567890-abc123def456.apps.googleusercontent.com`.
  ///
  /// Its "iOS URL scheme" (the reversed id, `com.googleusercontent.apps.…`)
  /// must also go into GOOGLE_REVERSED_CLIENT_ID in
  /// ios/Flutter/Flavor-public.xcconfig and macos/Runner/Configs/AppInfo.xcconfig.
  static const String iosClientId = '461991683844-d5tbnv41ls4imlcvg1ubp3maa1scevhd.apps.googleusercontent.com';

  /// OAuth client of type **Web application** (Android needs it as the
  /// "server client id"). Google sign-in on Android also needs an OAuth
  /// client of type **Android** for package `com.kevinaoneill.importantdates`
  /// with your SHA-1 fingerprints; that one is matched automatically and is
  /// not entered here.
  static const String webClientId = '461991683844-1nfaerr80il31vgsbflq5hnvbu7675bk.apps.googleusercontent.com';

  static bool get isConfigured =>
      Platform.isAndroid ? webClientId.isNotEmpty : (Platform.isIOS || Platform.isMacOS) && iosClientId.isNotEmpty;

  static String? get clientId => (Platform.isIOS || Platform.isMacOS) && iosClientId.isNotEmpty ? iosClientId : null;

  static String? get serverClientId => Platform.isAndroid && webClientId.isNotEmpty ? webClientId : null;
}
