import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';

enum ManageListKind { items, names }

/// Manage Items / Manage Names (two near-identical Swift views combined).
class ManageListScreen extends StatefulWidget {
  const ManageListScreen({super.key, required this.kind});
  final ManageListKind kind;
  @override
  State<ManageListScreen> createState() => _ManageListScreenState();
}

class _ManageListScreenState extends State<ManageListScreen> {
  final _controller = TextEditingController();
  bool get _isItems => widget.kind == ManageListKind.items;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final store = AppStore.instance;
    final ok = _isItems ? await store.addItemType(name) : await store.addPerson(name);
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      setState(() {});
    } else {
      await showMessage(context, _isItems ? 'Item Already Exists' : 'Name Already Exists', '$name is already in your list.');
    }
  }

  Future<void> _delete(String name) async {
    final ok = await confirmAction(
      context,
      title: _isItems ? 'Delete Item Type?' : 'Delete Name?',
      message: 'This removes the ${_isItems ? 'item type' : 'name'} from the management list. Existing saved records are not changed.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    final store = AppStore.instance;
    if (_isItems) {
      await store.removeItemType(name);
    } else {
      await store.removePerson(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isItems ? AppTheme.manageItemsAccent : AppTheme.manageNamesAccent;
    return StoreBuilder(builder: (context) {
      final list = _isItems ? AppStore.instance.items : AppStore.instance.people;
      final n = list.length;
      final t = Theme.of(context).textTheme;
      return AppPage(
        title: _isItems ? 'Manage Items' : 'Manage Names',
        children: [
          AppPageHeader(
            title: _isItems ? 'Item Types' : 'People',
            subtitle: _isItems
                ? '$n saved choice${n == 1 ? '' : 's'} for new records'
                : '$n saved name${n == 1 ? '' : 's'} available for records',
            icon: _isItems ? Icons.folder_rounded : Icons.people_rounded,
            accent: accent,
          ),
          AppCard(
            accent: accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(
                title: _isItems ? 'Add Item' : 'Add Name',
                subtitle: _isItems ? 'Enter a new item type' : 'Enter a person’s name',
                icon: _isItems ? Icons.add_circle_rounded : Icons.person_add_rounded,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(hintText: _isItems ? 'Item name' : 'Name'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _controller.text.trim().isEmpty ? null : _add,
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              ]),
            ]),
          ),
          AppCard(
            accent: accent,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(
                title: _isItems ? 'Saved Items' : 'Saved Names',
                subtitle: '$n ${_isItems ? 'item' : 'name'}${n == 1 ? '' : 's'} available',
                icon: _isItems ? Icons.inventory_2_rounded : Icons.how_to_reg_rounded,
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyState(
                  icon: _isItems ? Icons.create_new_folder_rounded : Icons.person_add_rounded,
                  title: _isItems ? 'No Items' : 'No Names',
                  message: _isItems ? 'Add your first item above.' : 'Add your first name above.',
                )
              else
                for (final name in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Icon(_isItems ? Icons.event_rounded : Icons.account_circle_rounded, color: accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                      IconButton(
                        tooltip: 'Delete',
                        style: IconButton.styleFrom(backgroundColor: AppTheme.danger.withValues(alpha: 0.1)),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                        onPressed: () => _delete(name),
                      ),
                    ]),
                  ),
            ]),
          ),
        ],
      );
    });
  }
}
