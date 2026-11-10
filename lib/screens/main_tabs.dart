import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../data/app_store.dart';
import 'all_items_screen.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'info_screens.dart';
import 'management_screen.dart';
import 'tools_screen.dart';

/// Persistent five-tab shell: Home, Items, Calendar, Tools, Manage.
/// Each tab keeps its own navigation stack, like the SwiftUI TabView.
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;
  final _keys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHelpOnFirstLaunch());
  }

  /// The first time the app opens, Help & Instructions is shown on top of
  /// Home (Back returns to Home). Existing installs that already hold dates
  /// are not new users, so they are only marked as done.
  void _showHelpOnFirstLaunch() {
    final s = AppSettings.instance;
    if (s.firstLaunchHelpShown) return;
    s.firstLaunchHelpShown = true;
    if (AppStore.instance.dates.isNotEmpty) return;
    if (!mounted) return;
    _keys[0].currentState?.push(MaterialPageRoute(builder: (_) => const HelpScreen()));
  }

  static const _destinations = [
    (Icons.home_rounded, 'Home'),
    (Icons.view_list_rounded, 'Items'),
    (Icons.calendar_month_rounded, 'Calendar'),
    (Icons.grid_view_rounded, 'Tools'),
    (Icons.tune_rounded, 'Manage'),
  ];

  Widget _root(int i) => switch (i) {
        0 => const HomeScreen(),
        1 => const AllItemsScreen(),
        2 => const CalendarScreen(),
        3 => const ToolsScreen(),
        _ => const ManagementScreen(),
      };

  void _select(int i) {
    if (i == _index) {
      _keys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final stack = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < 5; i++)
          Navigator(
            key: _keys[i],
            onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _root(i)),
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _keys[_index].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: wide
            ? Row(children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations) NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: stack),
              ])
            : stack,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                height: 66,
                destinations: [
                  for (final d in _destinations) NavigationDestination(icon: Icon(d.$1), label: d.$2),
                ],
              ),
      ),
    );
  }
}
