import 'config/flavor.dart';
import 'main.dart';

/// Personal edition: Firebase Cloud Sync.
/// flutter run --flavor personal -t lib/main_personal.dart
Future<void> main() => runImportantDates(AppFlavor.personal);
