import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'pages/categories_page.dart';
import 'pages/latest_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/updates_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _destinations = [
    (icon: Icons.new_releases_outlined, selected: Icons.new_releases, label: 'Latest'),
    (icon: Icons.grid_view_outlined, selected: Icons.grid_view, label: 'Categories'),
    (icon: Icons.search_outlined, selected: Icons.search, label: 'Search'),
    (icon: Icons.system_update_alt_outlined, selected: Icons.system_update_alt, label: 'Updates'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  static const _pages = [
    LatestPage(),
    CategoriesPage(),
    SearchPage(),
    UpdatesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final updatesCount = state.updates.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: state.selectedTab,
                  onDestinationSelected: state.selectTab,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: _maybeBadge(d.icon, d.label == 'Updates' ? updatesCount : 0),
                        selectedIcon: _maybeBadge(d.selected, d.label == 'Updates' ? updatesCount : 0),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: state.selectedTab,
                    children: _pages,
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(
            index: state.selectedTab,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: state.selectedTab,
            onDestinationSelected: state.selectTab,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: _maybeBadge(d.icon, d.label == 'Updates' ? updatesCount : 0),
                  selectedIcon: _maybeBadge(d.selected, d.label == 'Updates' ? updatesCount : 0),
                  label: d.label,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _maybeBadge(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge.count(count: count, child: Icon(icon));
  }
}
