import 'config/flavor.dart';
import 'main.dart';

/// Public (store) edition: sync through each user's own Google Drive.
/// flutter run --flavor public -t lib/main_public.dart
Future<void> main() => runImportantDates(AppFlavor.public);
