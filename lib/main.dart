import 'package:flutter/material.dart';

import 'app_info.dart';
import 'config/flavor.dart';
import 'data/app_settings.dart';
import 'data/app_store.dart';
import 'data/passcode_store.dart';
import 'screens/lock_gate.dart';
import 'services/attachment_sync.dart';
import 'services/cloud_sync.dart';
import 'services/drive_sync.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

/// Default entry point (no -t): the personal edition, as before flavors.
/// Prefer lib/main_personal.dart or lib/main_public.dart with --flavor.
Future<void> main() => runImportantDates(AppFlavor.personal);

Future<void> runImportantDates(AppFlavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  Flavor.current = flavor;
  await AppSettings.load();
  await PasscodeStore.load();
  await AppStore.instance.load();
  await NotificationService.init();
  if (Flavor.usesFirebase) {
    await CloudSync.instance.init();
    AttachmentSync.instance.init();
  } else {
    await DriveSync.instance.init();
  }
  runApp(const ImportantDatesApp());
}

class ImportantDatesApp extends StatelessWidget {
  const ImportantDatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const LockGate(),
    );
  }
}
