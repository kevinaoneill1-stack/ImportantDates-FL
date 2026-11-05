import 'package:flutter/material.dart';

import '../app_info.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

Widget _textCard(BuildContext context, String title, IconData icon, String text, {Color accent = AppTheme.primary, String? subtitle}) {
  final t = Theme.of(context).textTheme;
  return AppCard(
    accent: accent,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title: title, subtitle: subtitle, icon: icon),
      const SizedBox(height: 12),
      Text(text, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
    ]),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: 'About',
      spacing: 18,
      children: [
        const AppPageHeader(
          title: 'About Important Dates',
          subtitle: 'A private organiser for dates, reminders and supporting documents.',
          icon: Icons.info_rounded,
          accent: Colors.blue,
        ),
        _textCard(
          context,
          'Important Dates',
          Icons.event_available_rounded,
          'Important Dates is designed to keep renewal dates, expiry dates, travel documents and other time-sensitive information '
              'together in one easy-to-manage app.',
          accent: Colors.blue,
          subtitle: 'Purpose',
        ),
        _textCard(
          context,
          'Data Storage',
          Icons.phone_iphone_rounded,
          'Your records, names, item types and attachments are stored privately on this device in the app\'s own storage. '
              'Nothing is uploaded to a server. Appearance and passcode preferences are also stored locally on each device. '
              'Backup & Restore creates an independent, portable backup that can be restored on your other iPhone, iPad, Mac or '
              'Android devices - and is compatible with the native iOS Important Dates app. PDF reports are readable exports and do '
              'not replace a restorable backup.',
          accent: AppTheme.backupAccent,
          subtitle: 'Local store active',
        ),
        QuickActionButton(
          title: 'Privacy Policy',
          icon: Icons.front_hand_rounded,
          color: Colors.indigo,
          subtitle: 'Read how the app handles your information',
          onTap: () => pushPage(context, const PrivacyPolicyScreen()),
        ),
        Center(child: Text(AppInfo.versionString, style: t.bodySmall)),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Widget _helpRow(BuildContext context, IconData icon, String title, String text) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(text, style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Help & Instructions',
      spacing: 18,
      children: [
        const AppPageHeader(
          title: 'Help & Instructions',
          subtitle: 'A practical guide to using Important Dates.',
          icon: Icons.help_rounded,
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle(title: 'Getting Around', icon: Icons.dashboard_rounded),
            _helpRow(context, Icons.home_rounded, 'Home', 'See your most relevant upcoming dates and shortcuts at a glance.'),
            _helpRow(context, Icons.view_list_rounded, 'Items', 'View, search and filter all Important Dates records.'),
            _helpRow(context, Icons.calendar_month_rounded, 'Calendar', 'Browse due dates in a calendar-based view.'),
            _helpRow(context, Icons.grid_view_rounded, 'Tools', 'Open search, timeline, reports and statistics.'),
            _helpRow(context, Icons.tune_rounded, 'Manage', 'Maintain reusable lists, create backups and adjust app settings.'),
          ]),
        ),
        _textCard(
          context,
          'Adding & Updating Records',
          Icons.add_circle_rounded,
          'Add an Important Date, choose the item type and person/name, set the due date, add notes and optionally mark it as a '
              'travel document. Open any saved record to review, edit, complete or manage its attachments. In lists, long-press '
              '(or right-click on a Mac) a record to complete, duplicate or delete it.',
        ),
        _textCard(
          context,
          'Reminders',
          Icons.notifications_active_rounded,
          'Reminder choices are set on each Important Date. Notification permission must be allowed for reminders to appear. '
              'If a reminder is changed, save the record so its scheduled notifications can be refreshed.',
        ),
        _textCard(
          context,
          'Backup & Restore',
          Icons.storage_rounded,
          'Use Manage → Backup & Restore for a complete portable backup of your app data. Automatic Backup can also be configured '
              'in App Settings. Use PDF reports for readable records; use app backup files when you need data that can be restored '
              'into Important Dates on any of your devices.',
        ),
        _textCard(
          context,
          'Passcodes',
          Icons.shield_rounded,
          'App Settings can protect app access and Delete All Data with separate numeric user passcodes. Keep a backup before '
              'making major changes or deleting information.',
        ),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget card(String title, IconData icon, String text) => _textCard(context, title, icon, text, accent: Colors.indigo);
    return AppPage(
      title: 'Privacy Policy',
      spacing: 18,
      children: [
        const AppPageHeader(
          title: 'Privacy Policy',
          subtitle: 'How Important Dates handles your information',
          icon: Icons.front_hand_rounded,
          accent: Colors.indigo,
        ),
        card('Information You Add', Icons.edit_note_rounded,
            'Important Dates stores information that you choose to enter, including names, item types, dates, notes, reminder '
                'settings and attachments. The app does not use advertising or third-party tracking SDKs.'),
        card('Storage', Icons.phone_iphone_rounded,
            'Your Important Dates information is stored in the app\'s private storage on each device. It is not uploaded to any '
                'server operated by the developer. App preferences such as appearance and passcodes are stored locally.'),
        card('Notifications', Icons.notifications_rounded,
            'If you choose reminders, Important Dates asks for notification permission when it first needs to schedule a reminder. '
                'Notification permission is optional and can be changed at any time in your device settings.'),
        card('Backups & Exports', Icons.storage_rounded,
            'Backups and PDF reports are created only when the app\'s backup or export features are used. Files that you export are '
                'then controlled by the destination you choose in the share or save interface.'),
        card('Retention & Deletion', Icons.delete_rounded,
            'Your information remains in the app until you edit or delete it, restore another backup, delete all app data, or remove '
                'the app. The app includes Delete All Data controls for removing its saved Important Dates information.'),
        card('Tracking & Sale of Data', Icons.visibility_off_rounded,
            'Important Dates does not track you across other companies\' apps or websites, does not display advertising, and does '
                'not sell your personal information.'),
        Text(
          'For App Store and Google Play publication, the same privacy policy must also be published at the Privacy Policy URL '
          'supplied in App Store Connect and Play Console.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
