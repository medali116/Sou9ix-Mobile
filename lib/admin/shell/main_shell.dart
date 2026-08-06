import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/shell/animated_bottom_nav.dart';
import 'package:sou9ix/shared/core/shell/bottom_nav_visibility_provider.dart';
import 'package:sou9ix/shared/core/shell/tab_navigation_provider.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/admin/features/dashboard/view/dashboard_screen.dart';
import 'package:sou9ix/admin/features/profile/view/profile_screen.dart';
import 'package:sou9ix/admin/features/stats/view/statistics_screen.dart';
import 'package:sou9ix/admin/features/stock/view/stock_screen.dart';

/// Bottom-tab shell for the Administrator app — a management-oriented tab
/// set (Dashboard, Stock, Stats, Profil). Daily sales is a Caissier job, so
/// Caisse isn't one of these permanent tabs; the admin can still ring up a
/// sale via the dashboard's "Vente" quick action, which pushes the shared
/// ScanSaleScreen as a one-off route instead (see `/pos` in the router).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _items = [
    NavItemData(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Accueil',
    ),
    NavItemData(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Stock',
    ),
    NavItemData(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Stats',
    ),
    NavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(requestedTabIndexProvider, (previous, next) {
      if (next != null) {
        setState(() => _index = next);
        ref.read(requestedTabIndexProvider.notifier).state = null;
      }
    });
    // Watched purely so every tab (Dashboard, Stock, Stats…) rebuilds when
    // the currency/ticket settings change, since AppFormat itself is a
    // plain static utility with no reactivity of its own.
    ref.watch(companySettingsProvider);
    final index = _index >= _items.length ? 0 : _index;
    final pages = const [
      DashboardScreen(),
      StockScreen(),
      StatisticsScreen(),
      ProfileScreen(),
    ];

    final navVisible = ref.watch(bottomNavVisibleProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: IgnorePointer(
        ignoring: !navVisible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          offset: navVisible ? Offset.zero : const Offset(0, 1.6),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            opacity: navVisible ? 1 : 0,
            child: AnimatedBottomNav(
              items: _items,
              currentIndex: index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ),
      ),
    );
  }
}
