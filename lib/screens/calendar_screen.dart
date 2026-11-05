import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selected = DateFormatting.startOfDay(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        if (_selected.year != _month.year || _selected.month != _month.month) _selected = _month;
      });

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final items = AppStore.instance.dates;
      final dueDays = {for (final i in items) DateFormatting.startOfDay(i.dueDate)};
      final selectedItems = items.where((i) => DateFormatting.sameDay(i.dueDate, _selected)).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final active = items.where((i) => !i.isAccomplished);
      final overdue = active.where((i) => i.daysRemaining < 0).length;
      final thisMonth = active.where((i) => i.dueDate.year == _month.year && i.dueDate.month == _month.month).length;
      final summary = overdue > 0
          ? '$thisMonth active this month • $overdue overdue'
          : '$thisMonth active item${thisMonth == 1 ? '' : 's'} this month';

      return AppPage(
        title: 'Calendar',
        children: [
          AppPageHeader(title: 'Calendar', subtitle: summary, icon: Icons.calendar_month_rounded),
          AppCard(child: _calendar(context, dueDays)),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(title: DateFormatting.long(_selected), subtitle: 'Items due on this date', icon: Icons.event_rounded),
              const SizedBox(height: 12),
              if (selectedItems.isEmpty)
                const EmptyState(icon: Icons.event_available_rounded, title: 'No Items Due', message: 'No items are due on this date.')
              else
                for (final i in selectedItems)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: ImportantDateCard(item: i)),
            ]),
          ),
        ],
      );
    });
  }

  Widget _calendar(BuildContext context, Set<DateTime> dueDays) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Monday-first week (Irish / European convention).
    final first = DateTime(_month.year, _month.month, 1);
    final leading = (first.weekday - DateTime.monday) % 7;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final today = DateFormatting.startOfDay(DateTime.now());
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(children: [
      Row(children: [
        IconButton(tooltip: 'Previous month', onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text(DateFormat('MMMM yyyy').format(_month),
              textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
        IconButton(tooltip: 'Next month', onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (final w in weekdays)
          Expanded(child: Center(child: Text(w, style: t.labelMedium?.copyWith(color: t.bodySmall?.color, fontWeight: FontWeight.w600)))),
      ]),
      const SizedBox(height: 4),
      for (var row = 0; row < totalCells ~/ 7; row++)
        Row(children: [
          for (var col = 0; col < 7; col++)
            Expanded(child: _dayCell(context, DateTime(_month.year, _month.month, 1 + row * 7 + col - leading), today, dueDays, scheme)),
        ]),
      const SizedBox(height: 8),
      Row(children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text('Item due', style: t.bodySmall),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            _selected = today;
            _month = DateTime(today.year, today.month);
          }),
          child: const Text('Today'),
        ),
      ]),
    ]);
  }

  Widget _dayCell(BuildContext context, DateTime day, DateTime today, Set<DateTime> dueDays, ColorScheme scheme) {
    final inMonth = day.month == _month.month;
    final isSelected = DateFormatting.sameDay(day, _selected);
    final isToday = DateFormatting.sameDay(day, today);
    final hasDue = dueDays.contains(day);
    final color = isSelected ? Colors.white : (inMonth ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.35));
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() {
        _selected = day;
        if (!inMonth) _month = DateTime(day.year, day.month);
      }),
      child: SizedBox(
        height: 46,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 34,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppTheme.primary : null,
              border: !isSelected && isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
            ),
            child: Text('${day.day}',
                style: TextStyle(color: color, fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.normal)),
          ),
          const SizedBox(height: 2),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: hasDue ? AppTheme.primary : Colors.transparent),
          ),
        ]),
      ),
    );
  }
}
