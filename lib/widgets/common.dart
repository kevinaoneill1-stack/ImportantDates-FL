import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft gradient page background with two blurred colour orbs.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF0E1424), Color(0xFF15122A), Color(0xFF0B0B0F)]
              : const [Color(0xFFEDF5FF), Color(0xFFF5F0FF), Color(0xFFFFFFFF)],
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        Positioned(right: -110, top: -60, child: _orb(AppTheme.primary.withValues(alpha: 0.14), 280)),
        Positioned(left: -110, bottom: -40, child: _orb(AppTheme.secondary.withValues(alpha: 0.11), 240)),
        Positioned.fill(child: child),
      ]),
    );
  }

  Widget _orb(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 60, spreadRadius: 30)]),
        ),
      );
}

/// Centres content and keeps it comfortably narrow on iPad, Mac and tablets.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// Standard scrolling page: background, app bar, centred column of cards.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showAppBar = true,
    this.spacing = 16,
    this.leading,
  });

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showAppBar;
  final double spacing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: showAppBar
            ? AppBar(title: Text(title), actions: actions, leading: leading, leadingWidth: leading == null ? null : 96)
            : null,
        body: SafeArea(
          top: !showAppBar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(height: spacing),
                      children[i],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent rounded card with a coloured accent capsule on the left.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.accent = AppTheme.primary, this.padding = 16, this.onTap});
  final Widget child;
  final Color accent;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(24);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: scheme.surface.withValues(alpha: dark ? 0.55 : 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.65)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Padding(padding: EdgeInsets.all(padding), child: child),
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withValues(alpha: 0.7)],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 58, this.radius = 19, this.iconSize = 28});
  final IconData icon;
  final Color color;
  final double size;
  final double radius;
  final double iconSize;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.15)!, color],
          ),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 5))],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({super.key, required this.title, required this.subtitle, required this.icon, this.accent = AppTheme.primary});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      accent: accent,
      child: Row(children: [
        const SizedBox(width: 4),
        IconTile(icon: icon, color: accent),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
          ]),
        ),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle, this.icon, this.trailing});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      if (icon != null) ...[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withValues(alpha: 0.12)),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Large tappable row used on Tools, Manage, Reports and Backup pages.
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({super.key, required this.title, required this.icon, required this.color, this.subtitle, this.onTap, this.enabled = true});
  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: scheme.surface.withValues(alpha: dark ? 0.55 : 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.08 : 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              IconTile(icon: icon, color: color, size: 46, radius: 15, iconSize: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surfaceContainerHighest.withValues(alpha: 0.6)),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: t.bodySmall?.color),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Grouped field background used inside cards.
class FieldBox extends StatelessWidget {
  const FieldBox({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 6)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: child,
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Icon(icon, size: 44, color: t.bodySmall?.color),
        const SizedBox(height: 10),
        Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: t.bodySmall?.color)),
      ]),
    );
  }
}

Future<void> showMessage(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppTheme.danger) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
