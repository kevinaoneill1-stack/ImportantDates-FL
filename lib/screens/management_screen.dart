import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'backup_restore_screen.dart';
import 'info_screens.dart';
import 'manage_list_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key});

  Widget _section(String title, String subtitle, IconData icon, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(title: title, subtitle: subtitle, icon: icon),
        for (final c in children) ...[const SizedBox(height: 11), c],
      ]);

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Management',
      spacing: 22,
      children: [
        const AppPageHeader(
          title: 'Management Centre',
          subtitle: 'Organise lists, protect your information and manage app preferences',
          icon: Icons.tune_rounded,
          accent: AppTheme.managementAccent,
        ),
        _section('Manage', 'Edit the lists used in forms', Icons.layers_rounded, [
          QuickActionButton(
            title: 'Manage Items',
            icon: Icons.folder_rounded,
            color: Colors.orange,
            subtitle: 'Add or remove item types',
            onTap: () => pushPage(context, const ManageListScreen(kind: ManageListKind.items)),
          ),
          QuickActionButton(
            title: 'Manage Names',
            icon: Icons.people_rounded,
            color: Colors.purple,
            subtitle: 'Maintain people linked to records',
            onTap: () => pushPage(context, const ManageListScreen(kind: ManageListKind.names)),
          ),
        ]),
        _section('Data', 'Protect and move your information', Icons.storage_rounded, [
          QuickActionButton(
            title: 'Cloud Sync',
            icon: Icons.cloud_sync_rounded,
            color: Colors.blue,
            subtitle: 'Keep your dates the same on every device',
            onTap: () => pushPage(context, syncScreen()),
          ),
          QuickActionButton(
            title: 'Backup & Restore',
            icon: Icons.sync_rounded,
            color: Colors.indigo,
            subtitle: 'Export or restore a complete app backup',
            onTap: () => pushPage(context, const BackupRestoreScreen()),
          ),
        ]),
        _section('Preferences', 'Security, appearance and app information', Icons.settings_rounded, [
          QuickActionButton(
            title: 'App Settings',
            icon: Icons.settings_rounded,
            color: Colors.grey,
            subtitle: 'Configure security, appearance and preferences',
            onTap: () => pushPage(context, const SettingsScreen()),
          ),
          QuickActionButton(
            title: 'Help & Instructions',
            icon: Icons.help_rounded,
            color: Colors.blue,
            subtitle: 'How to use records, reminders, backups and reports',
            onTap: () => pushPage(context, const HelpScreen()),
          ),
          QuickActionButton(
            title: 'About',
            icon: Icons.info_rounded,
            color: Colors.teal,
            subtitle: 'App purpose, data guidance and version information',
            onTap: () => pushPage(context, const AboutScreen()),
          ),
          QuickActionButton(
            title: 'Privacy Policy',
            icon: Icons.front_hand_rounded,
            color: Colors.indigo,
            subtitle: 'How Important Dates stores and handles your information',
            onTap: () => pushPage(context, const PrivacyPolicyScreen()),
          ),
        ]),
      ],
    );
  }
}
