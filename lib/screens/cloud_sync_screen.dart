import 'package:flutter/material.dart';

import '../services/attachment_sync.dart';
import '../services/cloud_sync.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';

/// Manage › Cloud Sync: sign in, turn sync on/off, see status.
class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _working = false;
  String _message = '';

  CloudSync get sync => CloudSync.instance;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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

  /// Asks for the password (and a new value), runs [action] and closes when it
  /// succeeds. Returns true when done.
  Future<bool> _passwordDialog({
    required String title,
    required String message,
    required String actionLabel,
    String? valueLabel,
    bool valueIsPassword = false,
    bool destructive = false,
    required Future<String?> Function(String password, String value) action,
  }) async {
    final password = TextEditingController();
    final value = TextEditingController();
    final confirmValue = TextEditingController();
    String error = '';
    bool working = false;
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (message.isNotEmpty) ...[Text(message), const SizedBox(height: 12)],
                TextField(controller: password, obscureText: true, decoration: const InputDecoration(hintText: 'Current password')),
                if (valueLabel != null) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: value,
                    obscureText: valueIsPassword,
                    keyboardType: valueIsPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
                    decoration: InputDecoration(hintText: valueLabel),
                  ),
                  if (valueIsPassword) ...[
                    const SizedBox(height: 10),
                    TextField(controller: confirmValue, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm new password')),
                  ],
                ],
                if (working) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (error.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text(error, style: const TextStyle(color: AppTheme.warning))),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: working ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
              onPressed: working
                  ? null
                  : () async {
                      if (password.text.isEmpty || (valueLabel != null && value.text.trim().isEmpty)) {
                        setDialog(() => error = 'Please fill in every field.');
                        return;
                      }
                      if (valueIsPassword && value.text != confirmValue.text) {
                        setDialog(() => error = 'The new passwords do not match.');
                        return;
                      }
                      setDialog(() {
                        working = true;
                        error = '';
                      });
                      final result = await action(password.text, value.text);
                      if (!context.mounted) return;
                      if (result == null) {
                        Navigator.pop(context, true);
                      } else {
                        setDialog(() {
                          working = false;
                          error = result;
                        });
                      }
                    },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
    return done == true;
  }

  Future<void> _changeEmail() async {
    String newEmail = '';
    final done = await _passwordDialog(
      title: 'Change Email',
      message: '',
      actionLabel: 'Send Confirmation',
      valueLabel: 'New email address',
      action: (p, v) {
        newEmail = v.trim();
        return sync.changeEmail(p, v);
      },
    );
    if (done && mounted) {
      setState(() => _message = 'A confirmation link has been sent to $newEmail. Open it to finish the change, then '
          'sign in with the new email on each device. Your data stays with your account.');
    }
  }

  Future<void> _changePassword() async {
    final done = await _passwordDialog(
      title: 'Change Password',
      message: '',
      actionLabel: 'Change Password',
      valueLabel: 'New password (at least 6 characters)',
      valueIsPassword: true,
      action: sync.changePassword,
    );
    if (done && mounted) {
      setState(() => _message = 'Password changed. Use the new password when signing in on your other devices.');
    }
  }

  Future<void> _deleteAccount() async {
    final done = await _passwordDialog(
      title: 'Delete Account?',
      message: 'This permanently deletes your Important Dates account and everything it keeps in the cloud: your '
          'dates, item types, names, settings and attachment files.\n\nThe data on this device is kept, and sync is '
          'switched off. Other devices signed in to this account lose their synced copies. This cannot be undone. '
          'Make a backup first if unsure (Manage › Backup & Restore).',
      actionLabel: 'Delete Account',
      destructive: true,
      action: (p, _) => sync.deleteAccount(p),
    );
    if (done && mounted) {
      setState(() => _message = 'Your account and its cloud data have been deleted. Your dates are still on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sync, AttachmentSync.instance]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final user = sync.user;
        Widget note(String text) => Text(text, style: t.bodySmall);
        final children = <Widget>[
          const AppPageHeader(
            title: 'Cloud Sync',
            subtitle: 'Keep Important Dates the same on your iPhone, iPad, Mac and Android devices.',
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
                message: 'Cloud Sync needs the Firebase project to be connected to this app. Follow the steps in '
                    'CLOUD_SYNC_SETUP.md in the project folder, then run the app again.',
              ),
            ),
            if (sync.setupError.isNotEmpty) note(sync.setupError),
          ]);
        } else if (user == null) {
          children.add(AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(title: 'Sign In', subtitle: 'Use the same account on every device', icon: Icons.login_rounded),
              const SizedBox(height: 10),
              note('Your data stays on this device as well. The first device you sign in on uploads its data; '
                  'other devices then download it.'),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(hintText: 'Password'),
                onSubmitted: (_) => _run(() => sync.signIn(_email.text, _password.text)),
              ),
              const SizedBox(height: 12),
              if (_working) const Padding(padding: EdgeInsets.only(bottom: 10), child: LinearProgressIndicator()),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(
                  onPressed: _working ? null : () => _run(() => sync.signIn(_email.text, _password.text)),
                  child: const Text('Sign In'),
                ),
                OutlinedButton(
                  onPressed: _working ? null : () => _run(() => sync.createAccount(_email.text, _password.text)),
                  child: const Text('Create Account'),
                ),
                TextButton(
                  onPressed: _working
                      ? null
                      : () => _run(() => sync.resetPassword(_email.text),
                          success: 'A password reset email has been sent to ${_email.text.trim()}.'),
                  child: const Text('Forgot Password'),
                ),
              ]),
              if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_message)),
            ]),
          ));
        } else {
          final docs = AttachmentSync.instance;
          children.addAll([
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Account', icon: Icons.account_circle_rounded),
                ListTile(contentPadding: EdgeInsets.zero, title: Text(user.email ?? 'Signed in')),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sync this device', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Keep dates, item types, names, attachments and Home settings the same on all your devices.'),
                  value: sync.enabled,
                  activeTrackColor: AppTheme.primary,
                  onChanged: (v) => sync.setEnabled(v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alternate_email_rounded),
                  title: const Text('Change Email'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _changeEmail,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _changePassword,
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
                  const Text('This account already has data in the cloud, and this device has its own data. '
                      'How should they be combined?'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.merge_rounded),
                    label: const Text('Merge (keep both)'),
                    onPressed: sync.busy ? null : () => sync.resolveFirstSync(useCloud: false),
                  ),
                  const SizedBox(height: 4),
                  note('Everything from both is kept. Where the same record is on both, the cloud version is used.'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('Use Cloud Data on This Device'),
                    onPressed: sync.busy
                        ? null
                        : () async {
                            if (await confirmAction(context,
                                title: "Replace This Device's Data?",
                                message: 'All dates, item types and names on this device are replaced by the cloud data. '
                                    'Make a backup first if unsure.',
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
                if (sync.busy) const LinearProgressIndicator(),
                if (sync.error.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_rounded, color: AppTheme.warning),
                    title: Text(sync.error),
                  ),
                if (docs.lastError.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file_rounded, color: AppTheme.warning),
                    title: Text('Attachments: ${docs.lastError}'),
                  ),
                if (sync.running) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sync_rounded),
                    title: const Text('Sync Now'),
                    onTap: () {
                      sync.pushNow();
                      docs.uploadPending();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_for_offline_rounded),
                    title: const Text('Download All Attachments'),
                    subtitle: Text(docs.cloudOnlyCount == 0
                        ? 'Every attachment is on this device.'
                        : '${docs.cloudOnlyCount} attachment${docs.cloudOnlyCount == 1 ? ' is' : 's are'} only in the cloud.'),
                    onTap: docs.cloudOnlyCount == 0
                        ? null
                        : () async {
                            final (ok, failed) = await docs.downloadAll();
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
                  subtitle: const Text('Data stays on this device; it stops syncing.'),
                  onTap: () => sync.signOut(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.danger),
                  title: const Text('Delete Account', style: TextStyle(color: AppTheme.danger)),
                  subtitle: const Text('Deletes your account and everything it keeps in the cloud.'),
                  onTap: _working ? null : _deleteAccount,
                ),
              ]),
            ),
            note('Synced: Important Dates with their reminders, notes and attachment list; the attachment files themselves '
                '(downloaded to a device when first opened, and automatically for dates due within 30 days); item types; '
                'names; Home title and appearance; Tools shortcuts. Kept on each device: passcodes, automatic backup '
                'settings, the Home photo and the disclaimer.'),
          ]);
        }
        return AppPage(title: 'Cloud Sync', children: children);
      },
    );
  }
}
