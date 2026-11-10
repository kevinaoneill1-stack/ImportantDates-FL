import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../data/app_settings.dart';
import '../data/app_store.dart';
import '../models/important_date.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../widgets/common.dart';
import '../widgets/important_date_card.dart';
import 'add_edit_screen.dart';
import 'item_detail_screen.dart';
import 'travel_documents_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreBuilder(
      listenables: [AppSettings.instance],
      builder: (context) {
        final active = AppStore.instance.dates.where((d) => !d.isAccomplished).toList()
          ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
        int count(int lo, int hi) => active.where((d) => d.daysRemaining >= lo && d.daysRemaining <= hi).length;
        final nextThree = active.take(3).toList();
        final t = Theme.of(context).textTheme;

        return AppPage(
          title: 'Home',
          showAppBar: false,
          spacing: 22,
          children: [
            const HomeHero(),
            Row(children: [
              Expanded(child: _SummaryTile(value: count(0, 30), label: 'Within 30 Days', icon: Icons.alarm_rounded, color: Colors.amber)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryTile(value: count(31, 60), label: '31–60 Days', icon: Icons.event_note_rounded, color: Colors.orange)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryTile(value: count(61, 90), label: '61–90 Days', icon: Icons.event_note_rounded, color: Colors.green)),
            ]),
            if (nextThree.isNotEmpty) _UpcomingCard(items: nextThree),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle(title: 'Shortcuts', subtitle: 'Common actions from the home page', icon: Icons.bolt_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _FeatureCard(
                    title: 'Add New Item',
                    subtitle: 'Create a date or reminder',
                    icon: Icons.add_circle_rounded,
                    color: Colors.green,
                    onTap: () => pushPage(context, const AddEditScreen()),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _FeatureCard(
                    title: 'Travel Documents',
                    subtitle: 'Passports and travel dates',
                    icon: Icons.flight_takeoff_rounded,
                    color: Colors.cyan,
                    onTap: () => pushPage(context, const TravelDocumentsScreen()),
                  ),
                ),
              ]),
            ]),
            Center(
              child: Text(AppInfo.versionString,
                  style: t.labelSmall?.copyWith(color: t.bodySmall?.color?.withValues(alpha: 0.6))),
            ),
          ],
        );
      },
    );
  }
}

/// Lets the user enter or change the Home page title (also editable in
/// Manage › App Settings › Home Appearance).
Future<void> editHomeTitle(BuildContext context) async {
  final s = AppSettings.instance;
  final controller = TextEditingController(text: s.hasHomeTitle ? s.homeTitle : '');
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Home Page Title'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: AppSettings.defaultHomeTitle),
        onSubmitted: (v) => Navigator.of(c).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(c).pop(controller.text), child: const Text('Save')),
      ],
    ),
  );
  // The controller is not disposed here: the dialog may still be animating out.
  if (result != null) s.homeTitle = result.trim();
}

/// The photo hero card. Reused by the Home Appearance settings preview.
class HomeHero extends StatefulWidget {
  const HomeHero({super.key, this.height = 190, this.showText = true});
  final double height;
  final bool showText;
  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero> {
  Uint8List? _bytes;
  int _loadedVersion = -1;

  void _reloadIfNeeded() {
    final v = AppSettings.instance.homeImageVersion;
    if (v == _loadedVersion) return;
    _loadedVersion = v;
    AppStore.instance.readHomeImage().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        _reloadIfNeeded();
        final s = AppSettings.instance;
        final ImageProvider provider =
            _bytes != null ? MemoryImage(_bytes!) : const AssetImage('assets/images/default_home.png');
        Widget image = switch (s.homeDisplayMode) {
          HomeImageDisplayMode.fill => Image(image: provider, fit: BoxFit.cover, width: double.infinity, height: widget.height),
          HomeImageDisplayMode.fit => Container(
              color: Colors.black.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(8),
              child: Image(image: provider, fit: BoxFit.contain),
            ),
          HomeImageDisplayMode.center => Container(
              color: Colors.black.withValues(alpha: 0.08),
              alignment: Alignment.center,
              child: Image(image: provider, fit: BoxFit.contain, width: 150, height: 150),
            ),
        };
        final b = s.homeBrightness * 255;
        image = ColorFiltered(
          colorFilter: ColorFilter.matrix([1, 0, 0, 0, b, 0, 1, 0, 0, b, 0, 0, 1, 0, b, 0, 0, 0, 1, 0]),
          child: image,
        );
        if (s.homeBlur > 0) {
          image = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: s.homeBlur, sigmaY: s.homeBlur), child: image);
        }

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 22, offset: const Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(fit: StackFit.expand, children: [
              image,
              if (widget.showText) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Tap the title to enter or change it.
                    InkWell(
                      onTap: () => editHomeTitle(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: Text(s.displayHomeTitle,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82), fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('Important Dates', style: TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.bold)),
                    Text('Everything important, all in one place',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.value, required this.label, required this.icon, required this.color});
  final int value;
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text('$value', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        FittedBox(child: Text(label, style: t.labelSmall?.copyWith(color: t.bodySmall?.color))),
      ]),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.items});
  final List<ImportantDate> items;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle(title: 'Next Due Items', subtitle: 'Your three most urgent dates', icon: Icons.event_available_rounded),
        for (final item in items) ...[
          const SizedBox(height: 11),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => pushPage(context, ItemDetailScreen(itemId: item.id)),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.item, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text('${item.name} • ${DateFormatting.abbreviated(item.dueDate)}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                    ]),
                  ),
                  _DaysBadge(days: item.daysRemaining),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.statusColor(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Text('$days', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 16)),
        Text('days', style: TextStyle(color: c, fontSize: 10)),
      ]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Color.alphaBlend(color.withValues(alpha: 0.10), scheme.surface.withValues(alpha: 0.75)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 122),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: color, size: 26),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
                child: Icon(Icons.north_east_rounded, size: 14, color: color.withValues(alpha: 0.75)),
              ),
            ]),
            const SizedBox(height: 13),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, style: t.bodySmall),
          ]),
        ),
      ),
    );
  }
}
