import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/developer_access.dart';
import '../data/passcode_store.dart';
import '../services/app_log.dart';
import '../services/backup_service.dart';
import '../services/biometric_unlock.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'disclaimer_screen.dart';
import 'main_tabs.dart';

/// Launch flow: mandatory disclaimer -> optional passcode lock -> tabs.
///
/// With an app passcode, the app also locks again after it has been in the
/// background for [relockAfter]. The lock screen then covers the tabs, which
/// stay alive underneath, so nothing the user was doing is lost.
class LockGate extends StatefulWidget {
  const LockGate({super.key});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _settings = AppSettings.instance;
  final _controller = TextEditingController();
  static const relockAfter = Duration(minutes: 1);

  bool _unlocked = false;
  bool _everUnlocked = false;
  bool _showError = false;
  String _errorText = 'Incorrect passcode';
  DateTime? _backgroundedAt;
  bool _biometricInProgress = false;
  bool _disclaimerAcknowledgedThisLaunch = false;
  bool _lastDisclaimerEnabled = AppSettings.instance.developerDisclaimerEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    _runAutomaticBackupIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometric());
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

  bool get _passcodeActive => _settings.passcodeEnabled && PasscodeStore.instance.has(PasscodeKind.app);

  bool get _locked => _passcodeActive && !_unlocked;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Face ID itself briefly sends the app to the background on some
        // devices; that must not count as leaving the app.
        if (!_biometricInProgress) _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _backgroundedAt;
        _backgroundedAt = null;
        if (away != null && _passcodeActive && _unlocked && DateTime.now().difference(away) >= relockAfter) {
          setState(() {
            _unlocked = false;
            _showError = false;
            _controller.clear();
          });
          _offerBiometric();
        }
        _runAutomaticBackupIfNeeded();
      default:
        break;
    }
  }

  Future<void> _runAutomaticBackupIfNeeded() async {
    try {
      await BackupService.performIfNeeded();
    } catch (e, st) {
      AppLog.error('Automatic backup failed', e, st);
    }
  }

  /// Shows Face ID / fingerprint straight away when the lock screen appears.
  Future<void> _offerBiometric() async {
    if (!mounted || !_locked || _shouldShowDisclaimer || !_settings.biometricUnlockEnabled || _biometricInProgress) return;
    if (!await BiometricUnlock.isAvailable()) return;
    _biometricInProgress = true;
    final ok = await BiometricUnlock.authenticate();
    _biometricInProgress = false;
    if (ok && mounted) {
      await PasscodeStore.instance.recordAttempt(success: true);
      setState(_markUnlocked);
    }
  }

  void _markUnlocked() {
    _showError = false;
    _unlocked = true;
    _everUnlocked = true;
    _controller.clear();
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometric());
  }

  Future<void> _unlock() async {
    final store = PasscodeStore.instance;
    final entered = _controller.text;
    final waitUntil = store.lockedUntil;
    if (waitUntil != null && !DeveloperAccess.isOverride(entered)) {
      setState(() {
        _errorText = 'Too many wrong passcodes. ${PasscodeStore.waitText(waitUntil)}';
        _showError = true;
        _controller.clear();
      });
      return;
    }
    final ok = DeveloperAccess.matchesUserOrDeveloperPasscode(entered, PasscodeKind.app);
    await store.recordAttempt(success: ok);
    if (!mounted) return;
    setState(() {
      if (ok) {
        _markUnlocked();
      } else {
        final until = store.lockedUntil;
        _errorText = until == null ? 'Incorrect passcode' : 'Incorrect passcode. ${PasscodeStore.waitText(until)}';
        _showError = true;
        _controller.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShowDisclaimer) return DisclaimerScreen(onAcknowledge: _acknowledge);
    if (!_locked) {
      // No passcode (or already unlocked): count as unlocked, so turning the
      // passcode on in App Settings does not lock the app on the spot.
      _unlocked = true;
      _everUnlocked = true;
      return const _Tabs();
    }
    // Locked before the first unlock: the tabs are not built at all.
    if (!_everUnlocked) return _lockScreen(context);
    // Locked again after the background: cover the tabs, keep them alive.
    return Stack(children: [
      const Offstage(child: _Tabs()),
      Positioned.fill(child: _lockScreen(context)),
    ]);
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
                  if (_settings.biometricUnlockEnabled) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _offerBiometric,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Use Face ID / Fingerprint'),
                    ),
                  ],
                  if (_showError) ...[
                    const SizedBox(height: 16),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_rounded, color: AppTheme.danger, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_errorText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                      ),
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

/// The tabs, always under the same key so that locking again (which wraps
/// them in a Stack) does not throw away their navigation and state.
class _Tabs extends StatelessWidget {
  const _Tabs();
  static final _key = GlobalKey();
  @override
  Widget build(BuildContext context) => MainTabs(key: _key);
}
