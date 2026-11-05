import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../services/backup_service.dart';
import '../services/file_actions.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});
  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  File? _latest;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final f = await BackupService.latestAutomaticBackup();
    if (mounted) setState(() => _latest = f);
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _export(BuildContext c) => _run(() async {
        try {
          final bytes = await BackupService.buildBackupBytes();
          if (c.mounted) {
            await FileActions.exportFile(c, bytes: bytes, fileName: 'ImportantDatesBackup.json', mimeType: 'application/json');
          }
        } catch (e) {
          if (mounted) await showMessage(context, 'Backup Failed', e.toString());
        }
      });

  Future<void> _restoreFromFile() => _run(() async {
        try {
          final picked = await FileActions.pickBackupFile();
          if (picked == null || !mounted) return;
          final ok = await confirmAction(context,
              title: 'Restore this backup?',
              message: 'Your current data will be replaced by the contents of ${picked.name}.',
              confirmLabel: 'Restore Backup');
          if (!ok) return;
          await BackupService.restoreFromBytes(picked.bytes);
          if (mounted) await showMessage(context, 'Restore Complete', 'Your data has been restored successfully.');
        } catch (e) {
          if (mounted) await showMessage(context, 'Restore Failed', e is FormatException ? e.message : e.toString());
        }
      });

  Future<void> _backupNow() => _run(() async {
        try {
          await BackupService.createAutomaticBackup();
          if (mounted) await showMessage(context, 'Backup Complete', 'A new automatic backup was created successfully.');
        } catch (e) {
          if (mounted) await showMessage(context, 'Backup Failed', e.toString());
        }
      });

  Future<void> _restoreLatest() => _run(() async {
        final ok = await confirmAction(context,
            title: 'Restore latest automatic backup?',
            message: 'Your current data will be replaced by the latest automatic backup.',
            confirmLabel: 'Restore Backup');
        if (!ok) return;
        try {
          await BackupService.restoreLatestAutomatic();
          if (mounted) await showMessage(context, 'Restore Complete', 'Your latest automatic backup was restored successfully.');
        } catch (e) {
          if (mounted) await showMessage(context, 'Restore Failed', e.toString());
        }
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        final last = s.lastBackupDate;
        return AppPage(
          title: 'Backup & Restore',
          spacing: 20,
          children: [
            if (_busy) const LinearProgressIndicator(),
            AppCard(
              accent: AppTheme.backupAccent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Backup', subtitle: 'Create or restore a complete app backup', icon: Icons.storage_rounded),
                const SizedBox(height: 12),
                Builder(
                  builder: (c) => QuickActionButton(
                    title: 'Export Backup',
                    icon: Icons.ios_share_rounded,
                    color: AppTheme.primary,
                    subtitle: 'Save all dates, items and names',
                    onTap: () => _export(c),
                  ),
                ),
                const SizedBox(height: 12),
                QuickActionButton(
                  title: 'Restore Backup',
                  icon: Icons.download_rounded,
                  color: AppTheme.success,
                  subtitle: 'Restore data from a saved backup',
                  onTap: _restoreFromFile,
                ),
                const SizedBox(height: 10),
                Text(
                  'Backup files use the same format as the native iOS Important Dates app, so a backup from either app can be restored in the other.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            AppCard(
              accent: AppTheme.backupAccent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle(
                  title: 'Automatic Backup',
                  subtitle: s.autoBackupEnabled ? 'Backups are created automatically when due' : 'Enable automatic backup in App Settings',
                  icon: Icons.sync_rounded,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text('Latest Backup'),
                  const Spacer(),
                  Text(last == null ? 'Not yet created' : DateFormatting.dateTimeShort(last),
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 12),
                QuickActionButton(
                  title: 'Back Up Now',
                  icon: Icons.add_to_drive_rounded,
                  color: AppTheme.primary,
                  subtitle: 'Create a new automatic backup immediately',
                  onTap: _backupNow,
                ),
                const SizedBox(height: 12),
                QuickActionButton(
                  title: 'Restore Latest Automatic Backup',
                  icon: Icons.restore_rounded,
                  color: AppTheme.success,
                  subtitle: _latest == null ? 'No automatic backup is available' : 'Replace current data with the newest backup',
                  enabled: _latest != null,
                  onTap: _restoreLatest,
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
