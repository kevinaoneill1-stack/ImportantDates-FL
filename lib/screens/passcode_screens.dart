import 'package:flutter/material.dart';

import '../data/developer_access.dart';
import '../theme/app_theme.dart';

/// Set / change a numeric passcode (min four digits, entered twice).
/// Returns the new passcode, or null if cancelled.
Future<String?> showPasscodeSetup(BuildContext context, {required String title, required String explanation}) =>
    showDialog<String>(context: context, builder: (_) => _PasscodeSetupDialog(title: title, explanation: explanation));

class _PasscodeSetupDialog extends StatefulWidget {
  const _PasscodeSetupDialog({required this.title, required this.explanation});
  final String title;
  final String explanation;
  @override
  State<_PasscodeSetupDialog> createState() => _PasscodeSetupDialogState();
}

class _PasscodeSetupDialogState extends State<_PasscodeSetupDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _save() {
    final p = _a.text.trim();
    final c = _b.text.trim();
    String error = '';
    if (p.length < 4) {
      error = 'The passcode must contain at least four digits.';
    } else if (!RegExp(r'^\d+$').hasMatch(p)) {
      error = 'Use numbers only for the passcode.';
    } else if (p != c) {
      error = 'The two passcodes do not match.';
    }
    if (error.isEmpty) {
      Navigator.pop(context, p);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: _a,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter Passcode'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _b,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Confirm Passcode'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Text(widget.explanation, style: Theme.of(context).textTheme.bodySmall),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.error_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_error, style: const TextStyle(color: AppTheme.danger))),
            ]),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _a.text.isEmpty || _b.text.isEmpty ? null : _save,
          child: const Text('Save Passcode'),
        ),
      ],
    );
  }
}

/// Generic passcode prompt. [verify] decides whether the entry is accepted.
/// Returns true when verified.
Future<bool> showPasscodePrompt(
  BuildContext context, {
  required String title,
  required String hint,
  required String footer,
  required String actionLabel,
  required bool Function(String) verify,
  required String errorText,
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _PasscodePromptDialog(
      title: title,
      hint: hint,
      footer: footer,
      actionLabel: actionLabel,
      verify: verify,
      errorText: errorText,
      destructive: destructive,
    ),
  );
  return r ?? false;
}

class _PasscodePromptDialog extends StatefulWidget {
  const _PasscodePromptDialog({
    required this.title,
    required this.hint,
    required this.footer,
    required this.actionLabel,
    required this.verify,
    required this.errorText,
    required this.destructive,
  });
  final String title, hint, footer, actionLabel, errorText;
  final bool Function(String) verify;
  final bool destructive;
  @override
  State<_PasscodePromptDialog> createState() => _PasscodePromptDialogState();
}

class _PasscodePromptDialogState extends State<_PasscodePromptDialog> {
  final _c = TextEditingController();
  String _error = '';
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.verify(_c.text.trim())) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = widget.errorText;
        _c.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _c,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: widget.hint),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 10),
        Text(widget.footer, style: Theme.of(context).textTheme.bodySmall),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(_error, style: const TextStyle(color: AppTheme.danger)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: widget.destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.danger) : null,
          onPressed: _c.text.isEmpty ? null : _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

Future<bool> verifyDeletePasscode(BuildContext context, String expected) => showPasscodePrompt(
      context,
      title: 'Passcode Required',
      hint: 'Enter Delete Passcode',
      footer: 'Enter the Delete All passcode configured in App Settings.',
      actionLabel: 'Permanently Delete All Data',
      errorText: 'The passcode is incorrect. No data was deleted.',
      destructive: true,
      verify: (v) => DeveloperAccess.matchesUserOrDeveloperPasscode(v, expected),
    );

Future<bool> verifyDeveloperPasscode(BuildContext context) => showPasscodePrompt(
      context,
      title: 'Developer Access',
      hint: 'Developer Passcode',
      footer: 'Enter the developer passcode to open Developer Controls.',
      actionLabel: 'Open Developer Controls',
      errorText: 'Incorrect developer passcode.',
      verify: (v) => DeveloperAccess.isEnabled && v == DeveloperAccess.controlsPasscode,
    );
