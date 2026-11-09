import 'package:flutter/material.dart';

import '../services/drive_sync.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';

/// Manage › Cloud Sync in the public edition: sync through the user's own
/// Google Drive.
class DriveSyncScreen extends StatefulWidget {
  const DriveSyncScreen({super.key});

  @override
  State<DriveSyncScreen> createState() => _DriveSyncScreenState();
}

class _DriveSyncScreenState extends State<DriveSyncScreen> {
  bool _working = false;
  String _message = '';

  DriveSync get sync => DriveSync.instance;

  Future<void> _run(Future<String?> Function() action, {String? success}) async {
    setState(() {
      _working = true;
      _message = '';
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = error ?? success ?? '';
    });
  }

  Future<void> _deleteDriveData() async {
    final ok = await confirmAction(
      context,
      title: 'Delete Your Google Drive Data?',
      message: 'This permanently deletes everything Important Dates keeps in your Google Drive: your dates, item '
          'types, names, settings and attachment files. Important Dates is also disconnected from your Google '
          'account.\n\nThe data on this device is kept, and sync is switched off. Your other devices lose their '
          'synced copies. This cannot be undone. Make a backup first if unsure (Manage › Backup & Restore).',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    await _run(sync.deleteDriveData,
        success: 'Your Google Drive data has been deleted. Your dates are still on this device.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        Widget note(String text) => Text(text, style: t.bodySmall);
        final children = <Widget>[
          const AppPageHeader(
            title: 'Cloud Sync',
            subtitle: 'Keep Important Dates the same on your iPhone, iPad, Mac and Android devices, through your own '
                'Google Drive.',
            icon: Icons.cloud_sync_rounded,
          ),
        ];

        if (!sync.configured) {
          children.addAll([
            const AppCard(
              accent: AppTheme.warning,
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Not Set Up Yet',
                message: 'Google Drive Sync is not available in this build yet.',
              ),
            ),
            if (sync.setupError.isNotEmpty) note(sync.setupError),
          ]);
        } else if (!sync.signedIn) {
          children.add(AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(
                title: 'Sign In with Google',
                subtitle: 'Use the same Google account on every device',
                icon: Icons.login_rounded,
              ),
              const SizedBox(height: 10),
              note('Your dates are saved in a hidden Important Dates folder in your own Google Drive. Only this app '
                  'can open it, it does not appear among your Drive files, and nobody else – including the app\'s '
                  'developer – can see it. Your data also stays on this device.'),
              const SizedBox(height: 12),
              if (_working) const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In with Google'),
                onPressed: _working ? null : () => _run(sync.signIn),
              ),
              if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message)),
            ]),
          ));
        } else {
          children.addAll([
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Google Account', icon: Icons.account_circle_rounded),
                ListTile(contentPadding: EdgeInsets.zero, title: Text(sync.email ?? 'Signed in')),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sync this device', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Keep dates, item types, names, attachments and Home settings the same on all '
                      'your devices.'),
                  value: sync.enabled,
                  activeTrackColor: AppTheme.primary,
                  onChanged: (v) => sync.setEnabled(v),
                ),
              ]),
            ),
            if (_message.isNotEmpty) Text(_message),
            if (sync.needsFirstSyncChoice)
              AppCard(
                accent: AppTheme.warning,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle(title: 'First Sync', icon: Icons.merge_rounded),
                  const SizedBox(height: 10),
                  const Text('Your Google Drive already has Important Dates data, and this device has its own data. '
                      'How should they be combined?'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.merge_rounded),
                    label: const Text('Merge (keep both)'),
                    onPressed: sync.busy ? null : () => sync.resolveFirstSync(useCloud: false),
                  ),
                  const SizedBox(height: 4),
                  note('Everything from both is kept. Where the same record is on both, the Google Drive version is '
                      'used.'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('Use Google Drive Data on This Device'),
                    onPressed: sync.busy
                        ? null
                        : () async {
                            if (await confirmAction(context,
                                title: "Replace This Device's Data?",
                                message: 'All dates, item types and names on this device are replaced by the data '
                                    'in your Google Drive. Make a backup first if unsure.',
                                confirmLabel: 'Replace')) {
                              await sync.resolveFirstSync(useCloud: true);
                            }
                          },
                  ),
                ]),
              ),
            AppCard(
              accent: sync.running ? AppTheme.success : Colors.grey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Status', icon: Icons.info_rounded),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(sync.running ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: sync.running ? AppTheme.success : null),
                  title: Text(sync.status.isEmpty ? (sync.enabled ? 'Starting…' : 'Sync is off') : sync.status),
                  subtitle: sync.lastSync == null ? null : Text('Last sync ${DateFormatting.dateTimeShort(sync.lastSync!)}'),
                ),
                if (sync.busy || _working) const LinearProgressIndicator(),
                if (sync.error.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_rounded, color: AppTheme.warning),
                    title: Text(sync.error),
                  ),
                if (sync.attachmentError.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file_rounded, color: AppTheme.warning),
                    title: Text('Attachments: ${sync.attachmentError}'),
                  ),
                if (sync.running) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('Sync Now'),
                    onTap: sync.busy ? null : sync.syncNow,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_for_offline_rounded),
                    title: const Text('Download All Attachments'),
                    subtitle: Text(sync.cloudOnlyCount == 0
                        ? 'Every attachment is on this device.'
                        : '${sync.cloudOnlyCount} attachment${sync.cloudOnlyCount == 1 ? ' is' : 's are'} only in '
                            'Google Drive.'),
                    onTap: sync.cloudOnlyCount == 0
                        ? null
                        : () async {
                            final (ok, failed) = await sync.downloadAll();
                            if (context.mounted) {
                              await showMessage(context, 'Download Finished',
                                  '$ok downloaded${failed > 0 ? ', $failed could not be downloaded' : ''}.');
                            }
                          },
                  ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign Out'),
                  subtitle: const Text('Data stays on this device and in your Google Drive; this device stops syncing.'),
                  onTap: _working ? null : () => sync.signOut(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
                  title: const Text('Delete My Google Drive Data', style: TextStyle(color: AppTheme.danger)),
                  subtitle: const Text('Deletes everything Important Dates keeps in your Google Drive.'),
                  onTap: _working || sync.busy ? null : _deleteDriveData,
                ),
              ]),
            ),
            note('Synced: Important Dates with their reminders, notes and attachment list; the attachment files '
                'themselves (downloaded to a device when first opened, and automatically for dates due within 30 '
                'days); item types; names; Home title and appearance; Tools shortcuts. Kept on each device: '
                'passcodes, automatic backup settings, the Home photo and the disclaimer. Sync runs when the app '
                'opens, a few seconds after each change, and every few minutes while it is open.'),
          ]);
        }
        return AppPage(title: 'Cloud Sync', children: children);
      },
    );
  }
}
