import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../models/important_date.dart';
import '../services/pdf_report.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';
import 'all_items_screen.dart' show sortActiveFirst;
import 'pdf_preview_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final s = AppSettings.instance;
        return AppPage(
          title: 'Tools',
          spacing: 14,
          children: [
            const SectionTitle(
              title: 'Tools & Reports',
              subtitle: 'Search, review and report on your important dates',
              icon: Icons.grid_view_rounded,
            ),
            if (s.showTimeline)
              QuickActionButton(
                title: 'Timeline',
                icon: Icons.view_timeline_rounded,
                color: Colors.purple,
                subtitle: 'Review upcoming dates month by month',
                onTap: () => pushPage(context, const TimelineScreen()),
              ),
            if (s.showReports)
              QuickActionButton(
                title: 'Reports',
                icon: Icons.description_rounded,
                color: Colors.teal,
                subtitle: 'Create useful PDF summaries',
                onTap: () => pushPage(context, const ReportsScreen()),
              ),
            if (s.showStatistics)
              QuickActionButton(
                title: 'Statistics',
                icon: Icons.bar_chart_rounded,
                color: Colors.green,
                subtitle: 'Review counts, status and backup information',
                onTap: () => pushPage(context, const StatisticsScreen()),
              ),
            if (s.showSearch)
              QuickActionButton(
                title: 'Search Everything',
                icon: Icons.search_rounded,
                color: Colors.indigo,
                subtitle: 'Find items, people, notes and dates',
                onTap: () => pushPage(context, const GlobalSearchScreen()),
              ),
            if (!s.showSearch && !s.showTimeline && !s.showReports && !s.showStatistics)
              const AppCard(
                child: EmptyState(
                  icon: Icons.visibility_off_rounded,
                  title: 'All Tools Hidden',
                  message: 'Turn tools back on in Manage → App Settings → Tools Shortcuts.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final all = [...AppStore.instance.dates]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final q = _q.text.trim().toLowerCase();
      final results = q.isEmpty
          ? all.where((i) => !i.isAccomplished).toList()
          : all.where((i) =>
              i.item.toLowerCase().contains(q) ||
              i.name.toLowerCase().contains(q) ||
              i.notes.toLowerCase().contains(q) ||
              DateFormatting.long(i.dueDate).toLowerCase().contains(q) ||
              DateFormatting.abbreviated(i.dueDate).toLowerCase().contains(q)).toList();
      return AppPage(
        title: 'Search',
        spacing: 13,
        children: [
          TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Item, name, notes or date', prefixIcon: Icon(Icons.search_rounded)),
          ),
          if (results.isEmpty)
            AppCard(child: EmptyState(icon: Icons.search_off_rounded, title: 'No Results', message: 'No results for "${_q.text}".'))
          else
            for (final i in results) ImportantDateCard(item: i),
        ],
      );
    });
  }
}

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final active = AppStore.instance.dates.where((i) => !i.isAccomplished).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final groups = <String, List<ImportantDate>>{};
      for (final i in active) {
        groups.putIfAbsent(DateFormatting.monthYear(i.dueDate), () => []).add(i);
      }
      final t = Theme.of(context).textTheme;
      return AppPage(
        title: 'Timeline',
        spacing: 18,
        children: [
          if (groups.isEmpty)
            const AppCard(child: EmptyState(icon: Icons.view_timeline_rounded, title: 'Nothing Upcoming', message: 'Active Important Dates appear here month by month.')),
          for (final e in groups.entries)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(e.key, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              for (final i in e.value) Padding(padding: const EdgeInsets.only(bottom: 10), child: ImportantDateCard(item: i)),
            ]),
        ],
      );
    });
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget report(String title, String subtitle, IconData icon, Color color, bool Function(ImportantDate) filter) => Builder(
          builder: (c) => QuickActionButton(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            onTap: () async {
              final items = [...AppStore.instance.dates.where(filter)]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final bytes = await PdfReport.createItemsPdf(title, items);
              if (c.mounted) {
                await previewPdf(c, title: title, bytes: bytes, fileName: '${title.replaceAll(' ', '')}.pdf');
              }
            },
          ),
        );
    return AppPage(
      title: 'Reports',
      spacing: 13,
      children: [
        const AppPageHeader(
          title: 'Reports',
          subtitle: 'Create clean PDF summaries from your important dates',
          icon: Icons.description_rounded,
        ),
        report('All Active Items', 'Every current record', Icons.view_list_rounded, Colors.blue, (i) => !i.isAccomplished),
        report('Due Within 30 Days', 'Urgent upcoming dates', Icons.error_rounded, Colors.amber,
            (i) => !i.isAccomplished && i.daysRemaining >= 0 && i.daysRemaining <= 30),
        report('Due Within 90 Days', 'Full short-term outlook', Icons.event_note_rounded, Colors.green,
            (i) => !i.isAccomplished && i.daysRemaining >= 0 && i.daysRemaining <= 90),
        report('Overdue Items', 'Dates that need attention', Icons.warning_rounded, Colors.red,
            (i) => !i.isAccomplished && i.daysRemaining < 0),
        report('Travel Documents', 'Passports, visas and travel records', Icons.flight_rounded, Colors.cyan, (i) => i.isTravelDocument),
        report('Completed Items', 'Your completion history', Icons.verified_rounded, Colors.green, (i) => i.isAccomplished),
      ],
    );
  }
}

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return StoreBuilder(
      listenables: [AppSettings.instance],
      builder: (context) {
        final store = AppStore.instance;
        final active = store.dates.where((i) => !i.isAccomplished).toList();
        final year = DateTime.now().year;
        final completedThisYear =
            store.dates.where((i) => i.isAccomplished && (i.accomplishedDate ?? i.dueDate).year == year).length;
        final last = AppSettings.instance.lastBackupDate;
        final stats = [
          ('Active', active.length, Icons.calendar_today_rounded, Colors.blue),
          ('Overdue', active.where((i) => i.daysRemaining < 0).length, Icons.warning_rounded, Colors.red),
          ('Due 30 Days', active.where((i) => i.daysRemaining >= 0 && i.daysRemaining <= 30).length, Icons.schedule_rounded, Colors.amber),
          ('Due 90 Days', active.where((i) => i.daysRemaining >= 0 && i.daysRemaining <= 90).length, Icons.event_note_rounded, Colors.green),
          ('Completed This Year', completedThisYear, Icons.verified_rounded, Colors.green),
          ('Travel', active.where((i) => i.isTravelDocument).length, Icons.flight_rounded, Colors.cyan),
          ('People', store.people.length, Icons.people_rounded, Colors.purple),
          ('Categories', store.items.length, Icons.folder_rounded, Colors.orange),
        ];
        final t = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return AppPage(
          title: 'Statistics',
          children: [
            GridView.count(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
              children: [
                for (final s in stats)
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: s.$4.withValues(alpha: 0.28)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(s.$3, color: s.$4, size: 26),
                      const SizedBox(height: 8),
                      Text('${s.$2}', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(s.$1, textAlign: TextAlign.center, style: t.bodySmall),
                    ]),
                  ),
              ],
            ),
            if (last != null)
              Center(child: Text('Last backup: ${DateFormatting.dateTimeShort(last)}', style: t.bodySmall)),
          ],
        );
      },
    );
  }
}

class TravelDocumentsScreen extends StatefulWidget {
  const TravelDocumentsScreen({super.key});
  @override
  State<TravelDocumentsScreen> createState() => _TravelDocumentsScreenState();
}

class _TravelDocumentsScreenState extends State<TravelDocumentsScreen> {
  final _q = TextEditingController();
  bool _showCompleted = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final all = sortActiveFirst(AppStore.instance.dates.where((i) => i.isTravelDocument));
      final q = _q.text.trim().toLowerCase();
      final shown = all.where((i) {
        if (!_showCompleted && i.isAccomplished) return false;
        if (q.isEmpty) return true;
        return i.name.toLowerCase().contains(q) || i.notes.toLowerCase().contains(q) || i.item.toLowerCase().contains(q);
      }).toList();
      final activeCount = all.where((i) => !i.isAccomplished).length;
      final t = Theme.of(context).textTheme;
      return AppPage(
        title: 'Travel Documents',
        spacing: 14,
        actions: [
          Builder(
            builder: (c) => IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: shown.isEmpty
                  ? null
                  : () async {
                      final bytes = await PdfReport.createItemsPdf('Travel Documents Report', shown);
                      if (c.mounted) {
                        await previewPdf(c, title: 'Travel Documents Report', bytes: bytes, fileName: 'TravelDocumentsReport.pdf');
                      }
                    },
            ),
          ),
        ],
        children: [
          AppPageHeader(
            title: 'Travel Documents',
            subtitle: '$activeCount active • ${all.length - activeCount} completed',
            icon: Icons.flight_takeoff_rounded,
            accent: AppTheme.travelDocsAccent,
          ),
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Search travel documents', prefixIcon: Icon(Icons.search_rounded)),
          ),
          AppCard(
            accent: AppTheme.travelDocsAccent,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_showCompleted ? 'All Documents' : 'Active Documents', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text('${shown.length} document${shown.length == 1 ? '' : 's'} shown', style: t.bodySmall),
                ]),
              ),
              Text('Show completed', style: t.bodySmall),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: _showCompleted,
                activeTrackColor: AppTheme.travelDocsAccent,
                onChanged: (v) => setState(() => _showCompleted = v),
              ),
            ]),
          ),
          if (shown.isEmpty)
            const AppCard(
              accent: AppTheme.travelDocsAccent,
              child: EmptyState(
                icon: Icons.flight_rounded,
                title: 'No Travel Documents',
                message: 'Mark an item as a Travel Document in the Add or Edit screen.',
              ),
            )
          else
            for (final i in shown) ImportantDateCard(item: i),
        ],
      );
    });
  }
}
