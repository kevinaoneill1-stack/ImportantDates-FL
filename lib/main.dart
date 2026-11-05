import 'package:flutter/material.dart';

import 'app_info.dart';
import 'data/app_settings.dart';
import 'data/app_store.dart';
import 'screens/lock_gate.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  await AppStore.instance.load();
  await NotificationService.init();
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
