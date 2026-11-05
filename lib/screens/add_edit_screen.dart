import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/important_date.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import 'manage_list_screen.dart';

/// Add or edit an Important Date (AddImportantDateView.swift).
class AddEditScreen extends StatefulWidget {
  const AddEditScreen({super.key, this.editing});
  final ImportantDate? editing;
  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _store = AppStore.instance;
  String _item = '';
  String _person = '';
  DateTime _dueDate = DateFormatting.startOfDay(DateTime.now());
  final _notes = TextEditingController();
  bool _travel = false;
  bool _accomplished = false;
  DateTime _accomplishedDate = DateTime.now();
  int _notificationDays = 15;
  bool _r90 = false, _r60 = false, _r30 = true, _r7 = true;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _item = e.item;
      _person = e.name;
      _dueDate = e.dueDate;
      _notes.text = e.notes;
      _travel = e.isTravelDocument;
      _accomplished = e.isAccomplished;
      _accomplishedDate = e.accomplishedDate ?? DateTime.now();
      _notificationDays = e.notificationDays;
      _r90 = e.remind90Days;
      _r60 = e.remind60Days;
      _r30 = e.remind30Days;
      _r7 = e.remind7Days;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  int get _daysRemaining => DateFormatting.daysBetween(DateTime.now(), _dueDate);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final date = widget.editing ?? ImportantDate(id: AppStore.newId(), name: _person, item: _item, dueDate: _dueDate);
    date
      ..name = _person
      ..item = _item
      ..dueDate = _dueDate
      ..notes = _notes.text
      ..isTravelDocument = _travel
      ..isAccomplished = _accomplished
      ..accomplishedDate = _accomplished ? _accomplishedDate : null
      ..notificationDays = _notificationDays
      ..remind90Days = _r90
      ..remind60Days = _r60
      ..remind30Days = _r30
      ..remind7Days = _r7;
    try {
      await _store.upsert(date, requestNotificationPermission: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await showMessage(context, 'Save Failed', e.toString());
      }
    }
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final items = {..._store.items, if (_item.isNotEmpty) _item}.toList()..sort();
        final people = {..._store.people, if (_person.isNotEmpty) _person}.toList()..sort();
        final status = AppTheme.statusColor(_daysRemaining);
        final canSave = _item.isNotEmpty && _person.isNotEmpty;

        return AppPage(
          title: _isEditing ? 'Edit Item' : 'Add Item',
          leading: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          actions: [
            TextButton(
              onPressed: canSave && !_saving ? _save : null,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
          ],
          children: [
            AppPageHeader(
              title: _isEditing ? 'Update Important Date' : 'New Important Date',
              subtitle: 'Keep the details, status and reminders together.',
              icon: _isEditing ? Icons.edit_calendar_rounded : Icons.calendar_today_rounded,
            ),
            AppCard(
              accent: AppTheme.allItemsAccent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Record Details', subtitle: 'Choose the item and person', icon: Icons.badge_rounded),
                const SizedBox(height: 14),
                _picker(
                  label: 'Item',
                  hint: 'Select an item',
                  value: _item,
                  options: items,
                  onChanged: (v) => setState(() => _item = v),
                  emptyAction: () => pushPage(context, const ManageListScreen(kind: ManageListKind.items)),
                ),
                const SizedBox(height: 12),
                _picker(
                  label: 'Name',
                  hint: 'Select a name',
                  value: _person,
                  options: people,
                  onChanged: (v) => setState(() => _person = v),
                  emptyAction: () => pushPage(context, const ManageListScreen(kind: ManageListKind.names)),
                ),
              ]),
            ),
            AppCard(
              accent: _accomplished ? AppTheme.success : AppTheme.travelDocsAccent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.flight_takeoff_rounded, color: AppTheme.primary),
                  title: const Text('Travel Document', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _travel,
                  activeTrackColor: AppTheme.primary,
                  onChanged: (v) => setState(() => _travel = v),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_accomplished ? Icons.check_circle_rounded : Icons.circle_outlined, color: AppTheme.success),
                  title: const Text('Accomplished', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _accomplished,
                  activeTrackColor: AppTheme.success,
                  onChanged: (v) => setState(() => _accomplished = v),
                ),
                if (_travel || _accomplished)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_rounded, size: 16),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _travel && _accomplished
                              ? 'This appears in Travel Documents and is shown as completed.'
                              : _travel
                                  ? 'This appears in the Travel Documents list.'
                                  : 'Completed items move below active records.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
            AppCard(
              accent: status,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Dates', subtitle: 'Set the due date and track progress', icon: Icons.calendar_month_rounded),
                const SizedBox(height: 14),
                _dateRow('Due Date', _dueDate, (d) => setState(() => _dueDate = d)),
                if (_accomplished) ...[
                  const SizedBox(height: 10),
                  _dateRow('Accomplished', _accomplishedDate, (d) => setState(() => _accomplishedDate = d)),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: status.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(15)),
                  child: Row(children: [
                    Icon(_daysRemaining < 0 ? Icons.warning_rounded : Icons.schedule_rounded, color: status, size: 18),
                    const SizedBox(width: 8),
                    Text(_daysRemaining < 0 ? 'Overdue' : 'Time Remaining',
                        style: TextStyle(color: status, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(_daysRemaining < 0 ? '${-_daysRemaining} days overdue' : '$_daysRemaining days',
                        style: TextStyle(color: status, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
              ]),
            ),
            AppCard(
              accent: AppTheme.secondary,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Notes', subtitle: 'Add any useful information', icon: Icons.sticky_note_2_rounded),
                const SizedBox(height: 12),
                TextField(controller: _notes, minLines: 5, maxLines: 12, decoration: const InputDecoration(hintText: 'Notes')),
              ]),
            ),
            AppCard(
              accent: AppTheme.warning,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle(title: 'Reminder', subtitle: 'Choose how early to notify you', icon: Icons.notifications_active_rounded),
                const SizedBox(height: 4),
                _reminderSwitch('90 days before', _r90, (v) => _r90 = v),
                _reminderSwitch('60 days before', _r60, (v) => _r60 = v),
                _reminderSwitch('30 days before', _r30, (v) => _r30 = v),
                _reminderSwitch('7 days before', _r7, (v) => _r7 = v),
                Text('Choose any combination of reminders. Notifications are scheduled for 9:00 am.',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _reminderSwitch(String label, bool value, void Function(bool) set) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        value: value,
        activeTrackColor: AppTheme.primary,
        onChanged: (v) => setState(() => set(v)),
      );

  Widget _picker({
    required String label,
    required String hint,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required VoidCallback emptyAction,
  }) {
    if (options.isEmpty) {
      return FieldBox(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text('No ${label.toLowerCase()}s saved yet'),
          trailing: TextButton(onPressed: emptyAction, child: Text('Add ${label}s')),
        ),
      );
    }
    return FieldBox(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value.isEmpty ? null : value,
          hint: Text(hint),
          borderRadius: BorderRadius.circular(14),
          items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => onChanged(v ?? ''),
          selectedItemBuilder: (c) => [
            for (final o in options)
              Row(children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(o, style: TextStyle(color: Theme.of(c).colorScheme.primary)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(String label, DateTime value, ValueChanged<DateTime> onPicked) => FieldBox(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        child: Row(children: [
          Text(label),
          const Spacer(),
          TextButton(
            onPressed: () async {
              final d = await _pickDate(value);
              if (d != null) onPicked(d);
            },
            child: Text(DateFormatting.abbreviated(value)),
          ),
        ]),
      );
}
