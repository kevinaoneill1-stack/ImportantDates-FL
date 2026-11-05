import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/important_date.dart';
import '../screens/item_detail_screen.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import 'common.dart';

/// Row card for one Important Date. Tap opens details; long-press (or
/// right-click on Mac) offers Complete / Duplicate / Delete, standing in for
/// the iOS swipe actions.
class ImportantDateCard extends StatelessWidget {
  const ImportantDateCard({super.key, required this.item, this.enableActions = true});
  final ImportantDate item;
  final bool enableActions;

  @override
  Widget build(BuildContext context) {
    final accent = ItemPresentation.accent(item);
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: scheme.surface.withValues(alpha: dark ? 0.55 : 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.65)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pushPage(context, ItemDetailScreen(itemId: item.id)),
        onLongPress: enableActions ? () => _showActions(context) : null,
        onSecondaryTap: enableActions ? () => _showActions(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
              child: Icon(ItemPresentation.icon(item), color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.item, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(item.name, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
                Text(DateFormatting.abbreviated(item.dueDate), style: t.bodySmall),
                if (item.notes.isNotEmpty)
                  Text(item.notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(color: t.bodySmall?.color?.withValues(alpha: 0.7))),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                item.isAccomplished ? 'Done' : ItemPresentation.statusText(item),
                textAlign: TextAlign.right,
                style: t.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.bodySmall?.color?.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final store = AppStore.instance;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(item.item, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(item.name)),
          ListTile(
            leading: Icon(item.isAccomplished ? Icons.undo_rounded : Icons.check_circle_rounded, color: AppTheme.success),
            title: Text(item.isAccomplished ? 'Mark Active' : 'Mark Complete'),
            onTap: () => Navigator.pop(c, 'complete'),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: Colors.blue),
            title: const Text('Duplicate'),
            onTap: () => Navigator.pop(c, 'duplicate'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: AppTheme.danger),
            title: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
        ]),
      ),
    );
    switch (action) {
      case 'complete':
        await store.toggleComplete(item);
      case 'duplicate':
        await store.duplicate(item);
      case 'delete':
        await store.delete(item);
    }
  }
}

/// Rebuilds [builder] whenever records or settings change.
class StoreBuilder extends StatelessWidget {
  const StoreBuilder({super.key, required this.builder, this.listenables = const []});
  final WidgetBuilder builder;
  final List<Listenable> listenables;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([AppStore.instance, ...listenables]),
        builder: (c, _) => builder(c),
      );
}
