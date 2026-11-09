import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../data/developer_access.dart';
import '../services/backup_service.dart';
import '../services/file_actions.dart';
import '../services/sync_backend.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import 'developer_controls_screen.dart';
import 'home_screen.dart' show HomeHero;
import 'passcode_screens.dart';
import 'sync_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettings.instance, AppStore.instance]),
      builder: (context, _) => AppPage(
        title: 'App Settings',
        spacing: 18,
        children: [
          const AppPageHeader(
            title: 'App Settings',
            subtitle: 'Security, appearance, shortcuts and backup preferences in one place.',
            icon: Icons.settings_rounded,
            accent: AppTheme.managementAccent,
          ),
          const AppPageHeader(
            title: 'Privacy & Security',
            subtitle: 'Protect app access and permanent deletion with separate numeric passcodes.',
            icon: Icons.shield_rounded,
          ),
          const _AppPasscodeCard(),
          const _HomeAppearanceCard(),
          const _ToolsShortcutsCard(),
          const _AutomaticBackupCard(),
          const _StorageCard(),
          const _DeleteAllCard(),
          _versionCard(context),
          Text(
            'Changes to appearance, shortcuts and backup preferences are saved automatically on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _versionCard(BuildContext context) {
    final content = Row(children: [
      const Icon(Icons.info_rounded, color: AppTheme.managementAccent),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('App Information', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(AppInfo.versionString, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ]);
    return AppCard(
      accent: AppTheme.managementAccent,
      onTap: DeveloperAccess.isEnabled
          ? () async {
              final ok = await verifyDeveloperPasscode(context);
              if (ok && context.mounted) pushPage(context, const DeveloperControlsScreen());
            }
          : null,
      child: content,
    );
  }
}

class _AppPasscodeCard extends StatelessWidget {
  const _AppPasscodeCard();
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    Future<void> setup() async {
      final p = await showPasscodeSetup(
        context,
        title: s.appPasscode.isEmpty ? 'Set App Passcode' : 'Change App Passcode',
        explanation: 'Choose a numeric passcode you will remember. You will use it to unlock Important Dates.',
      );
      if (p != null) {
        s.appPasscode = p;
        s.passcodeEnabled = true;
      }
    }

    return AppCard(
      accent: s.passcodeEnabled ? AppTheme.success : Colors.grey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(title: 'App Passcode', subtitle: 'Require a passcode whenever the app is opened', icon: Icons.lock_rounded),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require App Passcode', style: TextStyle(fontWeight: FontWeight.w600)),
          value: s.passcodeEnabled,
          activeTrackColor: AppTheme.primary,
          onChanged: (v) {
            if (v) {
              setup();
            } else {
              s.passcodeEnabled = false;
              s.appPasscode = '';
            }
          },
        ),
        if (s.passcodeEnabled) ...[
          const Divider(),
          const Row(children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 18),
            SizedBox(width: 6),
            Text('Passcode is active', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: setup, icon: const Icon(Icons.key_rounded), label: const Text('Change App Passcode')),
        ],
      ]),
    );
  }
}

class _HomeAppearanceCard extends StatefulWidget {
  const _HomeAppearanceCard();
  @override
  State<_HomeAppearanceCard> createState() => _HomeAppearanceCardState();
}

class _HomeAppearanceCardState extends State<_HomeAppearanceCard> {
  late final TextEditingController _title = TextEditingController(text: AppSettings.instance.homeTitle);
  bool _loading = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _loading = true);
    try {
      final f = await FileActions.pickImage();
      if (f != null) await AppStore.instance.saveHomeImage(Uint8List.fromList(f.bytes));
    } catch (e) {
      if (mounted) await showMessage(context, 'Photo Not Saved', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(
          title: 'Home Appearance',
          subtitle: 'Choose the image and title shown on the Home page',
          icon: Icons.photo_library_rounded,
        ),
        const SizedBox(height: 14),
        const Text('Home Page Title', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter a name or title'),
          onChanged: (v) => s.homeTitle = v,
        ),
        const SizedBox(height: 6),
        Text('This text appears above “Important Dates” on the Home image.', style: t.bodySmall),
        const SizedBox(height: 14),
        const HomeHero(height: 150, showText: false),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _loading ? null : _choosePhoto,
          icon: const Icon(Icons.add_photo_alternate_rounded),
          label: Text(_loading ? 'Loading Photo…' : 'Choose Photo'),
        ),
        if (AppStore.instance.hasCustomHomeImage) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () => AppStore.instance.saveHomeImage(null),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset to App Icon'),
          ),
        ],
        const Divider(height: 28),
        SegmentedButton<HomeImageDisplayMode>(
          segments: const [
            ButtonSegment(value: HomeImageDisplayMode.fill, label: Text('Fill')),
            ButtonSegment(value: HomeImageDisplayMode.fit, label: Text('Fit')),
            ButtonSegment(value: HomeImageDisplayMode.center, label: Text('Center')),
          ],
          selected: {s.homeDisplayMode},
          onSelectionChanged: (v) => s.homeDisplayMode = v.first,
        ),
        const SizedBox(height: 12),
        _slider(Icons.wb_sunny_rounded, 'Brightness', '${((s.homeBrightness + 0.5) * 100).round()}%', s.homeBrightness, -0.5, 0.25, 15,
            (v) => s.homeBrightness = double.parse(v.toStringAsFixed(2))),
        _slider(Icons.blur_on_rounded, 'Blur', s.homeBlur > 0 ? '${s.homeBlur.round()}' : 'Off', s.homeBlur, 0, 12, 12,
            (v) => s.homeBlur = v.roundToDouble()),
      ]),
    );
  }

  Widget _slider(IconData icon, String title, String valueText, double value, double min, double max, int divisions,
          ValueChanged<double> onChanged) =>
      Column(children: [
        Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(title),
          const Spacer(),
          Text(valueText, style: Theme.of(context).textTheme.bodySmall),
        ]),
        Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
      ]);
}

class _ToolsShortcutsCard extends StatelessWidget {
  const _ToolsShortcutsCard();
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    Widget sw(String label, bool v, ValueChanged<bool> f) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero, dense: true, title: Text(label), value: v, activeTrackColor: AppTheme.primary, onChanged: f);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(title: 'Tools Shortcuts', subtitle: 'Choose the optional shortcuts shown on the Tools page', icon: Icons.bolt_rounded),
        const SizedBox(height: 6),
        sw('Search', s.showSearch, (v) => s.showSearch = v),
        sw('Timeline', s.showTimeline, (v) => s.showTimeline = v),
        sw('Reports', s.showReports, (v) => s.showReports = v),
        sw('Statistics', s.showStatistics, (v) => s.showStatistics = v),
      ]),
    );
  }
}

class _AutomaticBackupCard extends StatelessWidget {
  const _AutomaticBackupCard();
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final last = s.lastBackupDate;
    return AppCard(
      accent: AppTheme.backupAccent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(title: 'Automatic Backup', subtitle: 'Keep recent backups inside the app', icon: Icons.sync_rounded),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Automatic Backup', style: TextStyle(fontWeight: FontWeight.w600)),
          value: s.autoBackupEnabled,
          activeTrackColor: AppTheme.success,
          onChanged: (v) => s.autoBackupEnabled = v,
        ),
        if (s.autoBackupEnabled) ...[
          const Divider(),
          Row(children: [
            const Text('Backup Frequency'),
            const Spacer(),
            DropdownButton<int>(
              value: const [1, 3, 7, 14, 30].contains(s.autoBackupFrequencyDays) ? s.autoBackupFrequencyDays : 1,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Daily')),
                DropdownMenuItem(value: 3, child: Text('Every 3 Days')),
                DropdownMenuItem(value: 7, child: Text('Weekly')),
                DropdownMenuItem(value: 14, child: Text('Every 2 Weeks')),
                DropdownMenuItem(value: 30, child: Text('Monthly')),
              ],
              onChanged: (v) => s.autoBackupFrequencyDays = v ?? 1,
            ),
          ]),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 18),
            const SizedBox(width: 8),
            const Text('Last Backup'),
            const Spacer(),
            Text(last == null ? 'Not yet created' : DateFormatting.dateTimeShort(last), style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.backup_rounded),
            label: const Text('Back Up Now'),
            onPressed: () async {
              try {
                final file = await BackupService.createAutomaticBackup();
                if (context.mounted) {
                  await showMessage(
                    context,
                    file == null ? 'Backup Skipped' : 'Backup Complete',
                    file == null
                        ? 'There is no data to back up, so the latest backup (which has data) was kept.'
                        : 'An automatic backup was created successfully.',
                  );
                }
              } catch (e) {
                if (context.mounted) await showMessage(context, 'Backup Failed', e.toString());
              }
            },
          ),
        ],
      ]),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sync.state,
      builder: (context, _) {
        final sync = Sync.state;
        final on = sync.isSyncOn;
        final color = on ? AppTheme.success : AppTheme.warning;
        final subtitle = sync.statusSummary;
        return AppCard(
          accent: color,
          onTap: () => pushPage(context, syncScreen()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(
              title: 'Data & Sync Status',
              subtitle: subtitle,
              icon: on ? Icons.cloud_done_rounded : Icons.phone_iphone_rounded,
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Icon(on ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(on ? 'Cloud Sync On${sync.accountLabel == null ? '' : ' (${sync.accountLabel})'}' : 'Using Local Storage',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              on
                  ? 'Your dates, item types, names, Home settings and attachment files stay the same on every iPhone, '
                      'iPad, Mac and Android device signed in to this account. Tap to manage Cloud Sync.'
                  : 'Important Dates stores your records on this device. Tap to sign in to Cloud Sync and keep them the '
                      'same on all your devices, or use Manage → Backup & Restore to move data by hand.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
        );
      },
    );
  }
}

class _DeleteAllCard extends StatelessWidget {
  const _DeleteAllCard();
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    Future<void> setup() async {
      final p = await showPasscodeSetup(
        context,
        title: s.deleteAllPasscode.isEmpty ? 'Set Delete Passcode' : 'Change Delete Passcode',
        explanation: 'Choose a numeric passcode you will remember. It is used only for Delete All Data.',
      );
      if (p != null) {
        s.deleteAllPasscode = p;
        s.deleteAllPasscodeEnabled = true;
      }
    }

    Future<void> deleteAll() async {
      final ok = await confirmAction(
        context,
        title: 'Delete all app data?',
        message: 'This permanently removes every saved date, attachment, reusable item and name. '
            '${Sync.state.running ? 'Cloud Sync is on, so they are also removed from the cloud and your other devices. ' : ''}'
            'Create a backup first if you may need this information again.',
        confirmLabel: 'Continue',
      );
      if (!ok || !context.mounted) return;
      if (s.deleteAllPasscodeEnabled) {
        final verified = await verifyDeletePasscode(context, s.deleteAllPasscode);
        if (!verified) return;
      }
      try {
        // Deliberate: also delete everything from the cloud and other devices.
        Sync.state.allowBulkDeleteOnce();
        await AppStore.instance.deleteAll();
        if (context.mounted) {
          await showMessage(context, 'All Data Deleted', 'All saved dates, attachments, items and names have been permanently deleted.');
        }
      } catch (e) {
        if (context.mounted) await showMessage(context, 'Delete Failed', e.toString());
      }
    }

    return AppCard(
      accent: AppTheme.danger,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(
          title: 'Delete All Data',
          subtitle: 'Optionally protect permanent deletion with a passcode',
          icon: Icons.warning_rounded,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require Delete Passcode', style: TextStyle(fontWeight: FontWeight.w600)),
          value: s.deleteAllPasscodeEnabled,
          activeTrackColor: AppTheme.danger,
          onChanged: (v) {
            if (v) {
              setup();
            } else {
              s.deleteAllPasscodeEnabled = false;
              s.deleteAllPasscode = '';
            }
          },
        ),
        if (s.deleteAllPasscodeEnabled) ...[
          const Divider(),
          const Row(children: [
            Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 18),
            SizedBox(width: 6),
            Text('Delete protection is active', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: setup,
            icon: const Icon(Icons.key_rounded),
            label: const Text('Change Delete Passcode'),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: deleteAll,
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Delete All Data'),
        ),
      ]),
    );
  }
}
