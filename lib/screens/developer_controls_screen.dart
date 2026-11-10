import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/passcode_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DeveloperControlsScreen extends StatelessWidget {
  const DeveloperControlsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettings.instance, PasscodeStore.instance]),
      builder: (context, _) {
        final s = AppSettings.instance;
        final store = PasscodeStore.instance;
        final t = Theme.of(context).textTheme;
        final appSet = store.has(PasscodeKind.app);
        final deleteSet = store.has(PasscodeKind.deleteAll);
        final appActive = s.passcodeEnabled && appSet;
        final deleteActive = s.deleteAllPasscodeEnabled && deleteSet;

        Future<void> clear({required bool app}) async {
          final ok = await confirmAction(
            context,
            title: app ? 'Clear user app passcode?' : 'Clear user delete passcode?',
            message: 'This removes only the selected user passcode. It does not delete any Important Dates data.',
            confirmLabel: app ? 'Clear App Passcode' : 'Clear Delete Passcode',
          );
          if (!ok) return;
          if (app) {
            await store.clear(PasscodeKind.app);
            s.passcodeEnabled = false;
            s.biometricUnlockEnabled = false;
          } else {
            await store.clear(PasscodeKind.deleteAll);
            s.deleteAllPasscodeEnabled = false;
          }
          await store.recordAttempt(success: true); // also lifts any wrong-entry wait
        }

        Widget statusRow(String title, String status) => Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(status, style: t.bodySmall),
            ]);

        return AppPage(
          title: 'Developer Controls',
          spacing: 18,
          children: [
            const AppPageHeader(
              title: 'Developer Controls',
              subtitle: 'Hidden controls for app support and recovery.',
              icon: Icons.build_rounded,
              accent: Colors.orange,
            ),
            AppCard(
              accent: Colors.orange,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Developer Access', subtitle: 'Recovery access for passcode-protected areas', icon: Icons.key_rounded),
                const SizedBox(height: 12),
                const Row(children: [
                  Icon(Icons.verified_user_rounded, color: AppTheme.success, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Developer override is enabled for all user-passcode checks.', style: TextStyle(color: AppTheme.success)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text("The developer override does not replace or display the user's own passcodes.", style: t.bodySmall),
              ]),
            ),
            AppCard(
              accent: AppTheme.danger,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(
                  title: 'Passcode Recovery',
                  subtitle: 'Clear forgotten user passcodes without deleting app data',
                  icon: Icons.lock_reset_rounded,
                ),
                const SizedBox(height: 12),
                statusRow('App Lock', appActive ? 'User passcode active' : 'Not enabled'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  onPressed: !s.passcodeEnabled && !appSet ? null : () => clear(app: true),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Clear User App Passcode'),
                ),
                const Divider(height: 28),
                statusRow('Delete Protection', deleteActive ? 'User passcode active' : 'Not enabled'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  onPressed: !s.deleteAllPasscodeEnabled && !deleteSet ? null : () => clear(app: false),
                  icon: const Icon(Icons.key_off_rounded),
                  label: const Text('Clear User Delete Passcode'),
                ),
              ]),
            ),
            AppCard(
              accent: Colors.orange,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Launch Disclaimer', subtitle: 'Control the mandatory acknowledgement screen', icon: Icons.gpp_maybe_rounded),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show disclaimer on app launch'),
                  value: s.developerDisclaimerEnabled,
                  activeTrackColor: AppTheme.primary,
                  onChanged: (v) => s.developerDisclaimerEnabled = v,
                ),
                Text(
                  s.developerDisclaimerEnabled
                      ? 'Enabled. The disclaimer is required once on every fresh app launch before the user can enter the app.'
                      : 'Disabled. The app opens without the disclaimer.',
                  style: t.bodySmall,
                ),
              ]),
            ),
            AppCard(
              accent: Colors.grey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Build Information', subtitle: 'Current installed app', icon: Icons.hardware_rounded),
                const SizedBox(height: 10),
                Text(AppInfo.versionString, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        );
      },
    );
  }
}
