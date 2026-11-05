import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/developer_access.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'disclaimer_screen.dart';
import 'main_tabs.dart';

/// Launch flow: mandatory disclaimer -> optional passcode lock -> tabs.
class LockGate extends StatefulWidget {
  const LockGate({super.key});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _settings = AppSettings.instance;
  final _controller = TextEditingController();
  bool _unlocked = false;
  bool _showError = false;
  bool _disclaimerAcknowledgedThisLaunch = false;
  bool _lastDisclaimerEnabled = AppSettings.instance.developerDisclaimerEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    _runAutomaticBackupIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    final enabled = _settings.developerDisclaimerEnabled;
    // Re-enabling the disclaimer in Developer Controls re-arms it immediately.
    if (DeveloperAccess.isEnabled && enabled && !_lastDisclaimerEnabled) {
      _disclaimerAcknowledgedThisLaunch = false;
    }
    _lastDisclaimerEnabled = enabled;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runAutomaticBackupIfNeeded();
  }

  Future<void> _runAutomaticBackupIfNeeded() async {
    try {
      await BackupService.performIfNeeded();
    } catch (e) {
      debugPrint('Automatic backup failed: $e');
    }
  }

  bool get _shouldShowDisclaimer {
    if (DeveloperAccess.isEnabled) {
      return _settings.developerDisclaimerEnabled && !_disclaimerAcknowledgedThisLaunch;
    }
    return _settings.disclaimerAcknowledgedVersion != AppInfo.version;
  }

  void _acknowledge() {
    setState(() {
      if (DeveloperAccess.isEnabled) {
        _disclaimerAcknowledgedThisLaunch = true;
      } else {
        _settings.disclaimerAcknowledgedVersion = AppInfo.version;
      }
    });
  }

  void _unlock() {
    setState(() {
      if (DeveloperAccess.matchesUserOrDeveloperPasscode(_controller.text, _settings.appPasscode)) {
        _showError = false;
        _unlocked = true;
      } else {
        _showError = true;
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowDisclaimer) return DisclaimerScreen(onAcknowledge: _acknowledge);
    if (!_settings.passcodeEnabled || _settings.appPasscode.isEmpty || _unlocked) return const MainTabs();
    return _lockScreen(context);
  }

  Widget _lockScreen(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const IconTile(icon: Icons.lock_rounded, color: AppTheme.primary, size: 88, radius: 28, iconSize: 42),
                  const SizedBox(height: 22),
                  Text('Important Dates', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 7),
                  Text('Enter your passcode to continue', style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _controller,
                      obscureText: true,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: t.titleLarge,
                      decoration: const InputDecoration(hintText: 'Passcode'),
                      onSubmitted: (_) => _unlock(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 280,
                    child: FilledButton(
                      onPressed: _unlock,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                  if (_showError) ...[
                    const SizedBox(height: 16),
                    const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_rounded, color: AppTheme.danger, size: 18),
                      SizedBox(width: 6),
                      Text('Incorrect passcode', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
