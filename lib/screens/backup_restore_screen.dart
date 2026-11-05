import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../services/attachment_sync.dart';
import '../services/backup_service.dart';
import '../services/cloud_sync.dart';
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
  List<File> _daily = [];
  bool _busy = false;

  /// Extra sentence for restore confirmations while Cloud Sync is on.
  String get _syncNote => CloudSync.instance.running
      ? '\n\nCloud Sync is on, so the restored data also replaces the data on your other signed-in devices.'
      : '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final f = await BackupService.latestAutomaticBackup();
    final daily = await BackupService.dailyBackups();
    if (mounted) {
      setState(() {
        _latest = f;
        _daily = daily;
      });
    }
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
          // Attachments that are only in the cloud are downloaded first, so
          // the exported file is complete (and restorable in the iOS app).
          final sync = AttachmentSync.instance;
          if (sync.cloudOnlyCount > 0) {
            final (_, failed) = await sync.downloadAll();
            if (failed > 0 && mounted) {
              final go = await confirmAction(context,
                  title: 'Some Files Not Downloaded',
                  message: '$failed attachment${failed == 1 ? ' is' : 's are'} only in the cloud and could not be '
                      'downloaded. They will be listed in the backup without their files. Export anyway?',
                  confirmLabel: 'Export',
                  destructive: false);
              if (!go) return;
            }
          }
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
              message: 'Your current data will be replaced by the contents of ${picked.name}.$_syncNote',
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
          final file = await BackupService.createAutomaticBackup();
          if (mounted) {
            await showMessage(
              context,
              file == null ? 'Backup Skipped' : 'Backup Complete',
              file == null
                  ? 'There is no data to back up, so the latest backup (which has data) was kept.'
                  : 'A new automatic backup was created successfully.',
            );
          }
        } catch (e) {
          if (mounted) await showMessage(context, 'Backup Failed', e.toString());
        }
      });

  Future<void> _restoreLatest() => _run(() async {
        final ok = await confirmAction(context,
            title: 'Restore latest automatic backup?',
            message: 'Your current data will be replaced by the latest automatic backup.$_syncNote',
            confirmLabel: 'Restore Backup');
        if (!ok) return;
        try {
          await BackupService.restoreLatestAutomatic();
          if (mounted) await showMessage(context, 'Restore Complete', 'Your latest automatic backup was restored successfully.');
        } catch (e) {
          if (mounted) await showMessage(context, 'Restore Failed', e.toString());
        }
      });

  Future<void> _restoreDaily(File f) => _run(() async {
        final day = BackupService.dailyBackupDate(f);
        final ok = await confirmAction(context,
            title: 'Restore daily backup?',
            message: 'Your current data will be replaced by the backup from '
                '${day == null ? 'this day' : DateFormatting.long(day)}.$_syncNote',
            confirmLabel: 'Restore Backup');
        if (!ok) return;
        try {
          await BackupService.restoreFromBytes(await f.readAsBytes());
          if (mounted) await showMessage(context, 'Restore Complete', 'The daily backup was restored successfully.');
        } catch (e) {
          if (mounted) await showMessage(context, 'Restore Failed', e is FormatException ? e.message : e.toString());
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
            AppCard(
              accent: AppTheme.backupAccent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(
                  title: 'Daily Backups',
                  subtitle: 'One copy for each of the last ${BackupService.dailyBackupsKept} days. Tap one to restore it.',
                  icon: Icons.calendar_view_week_rounded,
                ),
                const SizedBox(height: 8),
                if (_daily.isEmpty)
                  Text('No daily backups yet. One is made with the first automatic backup each day.',
                      style: Theme.of(context).textTheme.bodySmall)
                else
                  for (final f in _daily)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(BackupService.dailyBackupDate(f) == null
                          ? f.uri.pathSegments.last
                          : DateFormatting.long(BackupService.dailyBackupDate(f)!)),
                      subtitle: Text('Saved ${DateFormatting.dateTimeShort(f.lastModifiedSync())}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _restoreDaily(f),
                    ),
                const SizedBox(height: 6),
                Text(
                  'An automatic backup is never made from an empty data set while an earlier backup has data, '
                  'so an emptied or unreadable app never replaces a good backup.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
