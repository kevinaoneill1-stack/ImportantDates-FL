import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key, required this.onAcknowledge});
  final VoidCallback onAcknowledge;
  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final body = t.bodyMedium?.copyWith(color: t.bodySmall?.color);
    return AppPage(
      title: 'Important Disclaimer',
      showAppBar: false,
      spacing: 18,
      children: [
        const AppPageHeader(
          title: 'Important Disclaimer',
          subtitle: 'Please read and acknowledge before using Important Dates.',
          icon: Icons.gpp_maybe_rounded,
          accent: Colors.orange,
        ),
        AppCard(
          accent: Colors.orange,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
              'Important Dates is an organisational aid. Dates, reminders, notifications, documents and reports should always be '
              'checked against the original source or issuing authority.',
              style: body,
            ),
            const SizedBox(height: 14),
            Text(
              'Notifications can be delayed, disabled or unavailable because of device settings, system conditions or permissions. '
              'Do not rely on this app as the sole reminder for passports, insurance, licences, medical appointments, legal deadlines '
              'or other critical dates.',
              style: body,
            ),
            const SizedBox(height: 14),
            Text(
              'Backups are provided for convenience. You remain responsible for keeping independent copies of important information '
              'and documents.',
              style: body,
            ),
          ]),
        ),
        AppCard(
          onTap: () => setState(() => _accepted = !_accepted),
          child: Row(children: [
            Icon(_accepted ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 28, color: _accepted ? AppTheme.primary : t.bodySmall?.color),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('I have read and acknowledge this disclaimer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ]),
        ),
        FilledButton(
          onPressed: _accepted ? widget.onAcknowledge : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Acknowledge & Continue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }
}
