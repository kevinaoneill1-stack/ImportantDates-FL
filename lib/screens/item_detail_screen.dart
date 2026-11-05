import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/important_date.dart';
import '../services/file_actions.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';
import 'add_edit_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(builder: (context) {
      final store = AppStore.instance;
      final item = store.byId(itemId);
      if (item == null) {
        return const AppPage(title: 'Item', children: [
          AppCard(child: EmptyState(icon: Icons.delete_outline_rounded, title: 'Item Removed', message: 'This record no longer exists.')),
        ]);
      }
      final accent = ItemPresentation.accent(item);
      final t = Theme.of(context).textTheme;
      final reminders = item.selectedReminderDays;
      final attachments = [...item.attachments]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return AppPage(
        title: item.item,
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => pushPage(context, AddEditScreen(editing: item)),
          ),
        ],
        children: [
          AppCard(
            accent: accent,
            child: Row(children: [
              const SizedBox(width: 4),
              IconTile(icon: ItemPresentation.icon(item), color: accent, size: 68, radius: 22, iconSize: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.item, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(item.name, style: t.titleSmall?.copyWith(color: t.bodySmall?.color)),
                  const SizedBox(height: 4),
                  Text(ItemPresentation.statusText(item), style: t.titleSmall?.copyWith(color: accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          AppCard(
            accent: accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(title: 'Details', subtitle: 'Dates and classification', icon: Icons.info_rounded),
              const SizedBox(height: 14),
              _row(context, 'Due Date', DateFormatting.long(item.dueDate), Icons.calendar_today_rounded),
              _row(context, 'Travel Document', item.isTravelDocument ? 'Yes' : 'No', Icons.flight_rounded),
              _row(context, 'Status', item.isAccomplished ? 'Completed' : 'Active',
                  item.isAccomplished ? Icons.check_circle_rounded : Icons.schedule_rounded),
              if (item.accomplishedDate != null)
                _row(context, 'Completed On', DateFormatting.long(item.accomplishedDate!), Icons.verified_rounded),
            ]),
          ),
          AppCard(
            accent: AppTheme.warning,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(title: 'Reminders', subtitle: 'Notifications before the due date', icon: Icons.notifications_active_rounded),
              const SizedBox(height: 12),
              Text(reminders.isEmpty ? 'No reminders selected' : '${reminders.join(' / ')} days',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
          AppCard(
            accent: AppTheme.secondary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(title: 'Notes', subtitle: 'Additional information', icon: Icons.sticky_note_2_rounded),
              const SizedBox(height: 10),
              SelectableText(
                item.notes.trim().isEmpty ? 'No notes added.' : item.notes,
                style: item.notes.trim().isEmpty ? t.bodyMedium?.copyWith(color: t.bodySmall?.color) : t.bodyMedium,
              ),
            ]),
          ),
          AppCard(
            accent: Colors.indigo,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(
                title: 'Attachments',
                subtitle: 'Photos, scans, PDFs and receipts',
                icon: Icons.attach_file_rounded,
                trailing: IconButton(
                  tooltip: 'Add Attachment',
                  icon: const Icon(Icons.add_circle_rounded, size: 30, color: AppTheme.primary),
                  onPressed: () => _addAttachments(context, item),
                ),
              ),
              const SizedBox(height: 10),
              if (attachments.isEmpty)
                Text('No attachments added.', style: t.bodyMedium?.copyWith(color: t.bodySmall?.color))
              else
                for (final a in attachments) _attachmentRow(context, item, a),
            ]),
          ),
          AppCard(
            accent: Colors.grey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: item.isAccomplished ? Colors.blue : AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(item.isAccomplished ? Icons.undo_rounded : Icons.check_circle_rounded),
                label: Text(item.isAccomplished ? 'Mark Active' : 'Mark Complete'),
                onPressed: () => store.toggleComplete(item),
              ),
              const SizedBox(height: 11),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Duplicate Item'),
                onPressed: () async {
                  await store.duplicate(item);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item duplicated')));
                  }
                },
              ),
              const SizedBox(height: 11),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(Icons.delete_rounded),
                label: const Text('Delete Item'),
                onPressed: () async {
                  final ok = await confirmAction(context,
                      title: 'Delete this item?', message: 'This record and its attachments will be removed.', confirmLabel: 'Delete Item');
                  if (!ok || !context.mounted) return;
                  Navigator.of(context).pop();
                  await store.delete(item);
                },
              ),
            ]),
          ),
        ],
      );
    });
  }

  Widget _row(BuildContext context, String title, String value, IconData icon) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: t.bodySmall?.color),
        const SizedBox(width: 8),
        Text(title, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _attachmentRow(BuildContext context, ImportantDate item, ItemAttachment a) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _preview(context, a),
          onLongPress: () => _confirmRemove(context, item, a),
          onSecondaryTap: () => _confirmRemove(context, item, a),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(children: [
              Icon(a.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(DateFormatting.abbreviated(a.createdAt), style: t.bodySmall),
                ]),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                onPressed: () => _confirmRemove(context, item, a),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _addAttachments(BuildContext context, ImportantDate item) async {
    try {
      final files = await FileActions.pickAttachments();
      for (final f in files) {
        await AppStore.instance.addAttachment(item, f.name, f.bytes);
      }
    } catch (e) {
      if (context.mounted) await showMessage(context, 'Attachment Not Added', e.toString());
    }
  }

  Future<void> _confirmRemove(BuildContext context, ImportantDate item, ItemAttachment a) async {
    final ok = await confirmAction(context, title: 'Delete attachment?', message: a.fileName, confirmLabel: 'Delete');
    if (ok) await AppStore.instance.removeAttachment(item, a);
  }

  Future<void> _preview(BuildContext context, ItemAttachment a) async {
    final file = AppStore.instance.attachmentFile(a.id);
    if (a.isImage && !a.fileName.toLowerCase().endsWith('.heic')) {
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(a.fileName, style: const TextStyle(color: Colors.white)),
            actions: [
              IconButton(
                tooltip: 'Open in another app',
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => FileActions.openWithSystem(file.path, a.fileName),
              ),
            ],
          ),
          body: InteractiveViewer(maxScale: 6, child: Center(child: Image.file(file))),
        ),
      ));
      return;
    }
    try {
      await FileActions.openWithSystem(file.path, a.fileName);
    } catch (e) {
      if (context.mounted) await showMessage(context, 'Cannot Open File', e.toString());
    }
  }
}
