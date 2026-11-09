import 'package:flutter/widgets.dart';

import '../config/flavor.dart';
import 'cloud_sync_screen.dart';
import 'drive_sync_screen.dart';

/// Manage › Cloud Sync for this build: Firebase (personal) or Google Drive
/// (public).
Widget syncScreen() => Flavor.usesGoogleDrive ? const DriveSyncScreen() : const CloudSyncScreen();
