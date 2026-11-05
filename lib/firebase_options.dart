// Placeholder until the Firebase project is connected.
//
// Run `flutterfire configure` as described in CLOUD_SYNC_SETUP.md: it
// replaces this whole file with the real settings for iOS, macOS and Android.
// Until then the app works normally and Cloud Sync shows "Not set up yet".
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not connected yet. Run flutterfire configure (see CLOUD_SYNC_SETUP.md).',
      );
}
