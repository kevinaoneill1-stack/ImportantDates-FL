import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/important_date.dart';
import '../services/file_actions.dart';
import '../services/pdf_report.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';
import 'add_edit_screen.dart';

enum QuickFilter { all, thirty, ninety, overdue, travel, completed }

extension on QuickFilter {
  String get label => const ['All', '30 Days', '90 Days', 'Overdue', 'Travel', 'Completed'][index];
  bool matches(ImportantDate i) => switch (this) {
        QuickFilter.all => true,
        QuickFilter.thirty => !i.isAccomplished && i.daysRemaining >= 0 && i.daysRemaining <= 30,
        QuickFilter.ninety => !i.isAccomplished && i.daysRemaining >= 0 && i.daysRemaining <= 90,
        QuickFilter.overdue => !i.isAccomplished && i.daysRemaining < 0,
        QuickFilter.travel => i.isTravelDocument,
        QuickFilter.completed => i.isAccomplished,
      };
}

/// Sorts active records first, then by due date.
List<ImportantDate> sortActiveFirst(Iterable<ImportantDate> items) => items.toList()
  ..sort((a, b) {
    if (a.isAccomplished != b.isAccomplished) return a.isAccomplished ? 1 : -1;
    return a.dueDate.compareTo(b.dueDate);
  });

class AllItemsScreen extends StatefulWidget {
  const AllItemsScreen({super.key});
  @override
  State<AllItemsScreen> createState() => _AllItemsScreenState();
}

class _AllItemsScreenState extends State<AllItemsScreen> {
  final _search = TextEditingController();
  String _selectedItem = 'All';
  String _selectedName = 'All';
  QuickFilter _quick = QuickFilter.all;
  bool _useDateRange = false;
  DateTime _start = DateFormatting.startOfDay(DateTime.now());
  DateTime _end = DateTime(DateTime.now().year, DateTime.now().month + 3, DateTime.now().day);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _search.text.isNotEmpty || _selectedItem != 'All' || _selectedName != 'All' || _quick != QuickFilter.all || _useDateRange;

  void _reset() => setState(() {
        _search.clear();
        _selectedItem = 'All';
        _selectedName = 'All';
        _quick = QuickFilter.all;
        _useDateRange = false;
      });

  List<ImportantDate> _filtered(List<ImportantDate> all) {
    final q = _search.text.trim().toLowerCase();
    final lo = DateFormatting.startOfDay(_start.isBefore(_end) ? _start : _end);
    final hi = DateFormatting.startOfDay(_start.isBefore(_end) ? _end : _start);
    return sortActiveFirst(all.where((i) {
      final matchesSearch = q.isEmpty ||
          i.item.toLowerCase().contains(q) ||
          i.name.toLowerCase().contains(q) ||
          i.notes.toLowerCase().contains(q);
      final matchesMenus = (_selectedItem == 'All' || i.item == _selectedItem) && (_selectedName == 'All' || i.name == _selectedName);
      final d = DateFormatting.startOfDay(i.dueDate);
      final matchesRange = !_useDateRange || (!d.isBefore(lo) && !d.isAfter(hi));
      return matchesSearch && matchesMenus && _quick.matches(i) && matchesRange;
    }));
  }

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final all = AppStore.instance.dates;
      final filtered = _filtered(all);
      final itemOptions = ['All', ...({for (final i in all) i.item}.toList()..sort())];
      final nameOptions = ['All', ...({for (final i in all) i.name}.toList()..sort())];
      if (!itemOptions.contains(_selectedItem)) _selectedItem = 'All';
      if (!nameOptions.contains(_selectedName)) _selectedName = 'All';
      final t = Theme.of(context).textTheme;

      return AppPage(
        title: 'Items',
        spacing: 14,
        actions: [
          IconButton(
            tooltip: 'Add Item',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => pushPage(context, const AddEditScreen()),
          ),
          Builder(
            builder: (c) => IconButton(
              tooltip: 'Export PDF',
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: () async {
                final bytes = await PdfReport.createItemsPdf('All Items Report', filtered);
                if (c.mounted) {
                  await FileActions.exportFile(c, bytes: bytes, fileName: 'AllItemsReport.pdf', mimeType: 'application/pdf');
                }
              },
            ),
          ),
        ],
        children: [
          const AppPageHeader(
            title: 'All Items',
            subtitle: 'Search, filter and manage every important date',
            icon: Icons.view_list_rounded,
            accent: AppTheme.allItemsAccent,
          ),
          AppCard(
            accent: AppTheme.allItemsAccent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(
                title: 'Filters',
                subtitle: 'Search and narrow your records',
                icon: Icons.filter_list_rounded,
                trailing: _filtersActive ? OutlinedButton(onPressed: _reset, child: const Text('Reset')) : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search item, name or notes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_search.clear)),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in QuickFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _quick == f,
                        onSelected: (_) => setState(() => _quick = f),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              FieldBox(
                child: Row(children: [
                  Expanded(child: _menu('Item', _selectedItem, itemOptions, (v) => setState(() => _selectedItem = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _menu('Name', _selectedName, nameOptions, (v) => setState(() => _selectedName = v))),
                ]),
              ),
              const SizedBox(height: 12),
              FieldBox(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    secondary: const Icon(Icons.date_range_rounded, color: AppTheme.primary),
                    title: const Text('Filter Between Dates', style: TextStyle(fontWeight: FontWeight.w600)),
                    value: _useDateRange,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (v) => setState(() => _useDateRange = v),
                  ),
                  if (_useDateRange) ...[
                    _dateRow('From', _start, (d) => _start = d),
                    const Divider(),
                    _dateRow('To', _end, (d) => _end = d),
                    Row(children: [
                      Expanded(
                        child: Text(
                          'Showing due dates from ${DateFormatting.abbreviated(_start.isBefore(_end) ? _start : _end)} '
                          'to ${DateFormatting.abbreviated(_start.isBefore(_end) ? _end : _start)}',
                          style: t.bodySmall,
                        ),
                      ),
                      TextButton(onPressed: () => setState(() => _useDateRange = false), child: const Text('Clear')),
                    ]),
                  ],
                ]),
              ),
            ]),
          ),
          FieldBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(filtered.isEmpty ? Icons.inbox_rounded : Icons.checklist_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text('${filtered.length} ${filtered.length == 1 ? 'item' : 'items'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (_filtersActive) ...[const SizedBox(width: 6), Text('matching filters', style: t.bodySmall)],
            ]),
          ),
          if (filtered.isEmpty)
            const AppCard(
              accent: AppTheme.allItemsAccent,
              child: EmptyState(icon: Icons.inbox_rounded, title: 'No Items Found', message: 'Try changing your search or filters.'),
            )
          else ...[
            for (final i in filtered) ImportantDateCard(item: i),
            Center(child: Text('Tip: long-press an item to complete, duplicate or delete it.', style: t.bodySmall)),
          ],
        ],
      );
    });
  }

  Widget _menu(String label, String value, List<String> options, ValueChanged<String> onChanged) =>
      DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          borderRadius: BorderRadius.circular(14),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(o == 'All' ? '$label: All' : o, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => onChanged(v ?? 'All'),
        ),
      );

  Widget _dateRow(String label, DateTime value, void Function(DateTime) set) => Row(children: [
        Text(label),
        const Spacer(),
        TextButton(
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(1900), lastDate: DateTime(2200));
            if (d != null) setState(() => set(d));
          },
          child: Text(DateFormatting.abbreviated(value)),
        ),
      ]);
}
