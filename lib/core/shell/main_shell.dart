import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/shell/animated_bottom_nav.dart';
import 'package:sou9ix/core/shell/bottom_nav_visibility_provider.dart';
import 'package:sou9ix/core/shell/tab_navigation_provider.dart';
import 'package:sou9ix/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/features/dashboard/view/dashboard_screen.dart';
import 'package:sou9ix/features/sales/view/history_screen.dart';
import 'package:sou9ix/features/pos/view/scan_sale_screen.dart';
import 'package:sou9ix/features/products/view/products_screen.dart';
import 'package:sou9ix/features/profile/view/profile_screen.dart';
import 'package:sou9ix/features/stats/view/statistics_screen.dart';
import 'package:sou9ix/features/stock/view/stock_screen.dart';

/// Bottom-tab shell. Tabs (and their order) depend on the signed-in role:
/// the Administrator gets a management-oriented set (Dashboard, Stock,
/// Stats), while the Caissier gets a sales-first set (Caisse, Produits,
/// Stock, Historique). Both share Caisse and Profil, and both can see and
/// manage stock levels.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _adminItems = [
    NavItemData(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Accueil',
    ),
    NavItemData(
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
      label: 'Caisse',
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

  static const _caissierItems = [
    NavItemData(
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
      label: 'Caisse',
    ),
    NavItemData(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      label: 'Produits',
    ),
    NavItemData(
      icon: Icons.warehouse_outlined,
      activeIcon: Icons.warehouse_rounded,
      label: 'Stock',
    ),
    NavItemData(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Historique',
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
    // Watched purely so every tab (Dashboard, Caisse, Stats…) rebuilds when
    // the currency/ticket settings change, since AppFormat itself is a
    // plain static utility with no reactivity of its own.
    ref.watch(companySettingsProvider);
    final isAdmin = ref.watch(authProvider)?.role == UserRole.admin;
    final items = isAdmin ? _adminItems : _caissierItems;
    // The Caisse tab holds the only persistent camera session; every other
    // tab is inert, so it only needs to know whether it's the visible one.
    final caisseTabIndex = isAdmin ? 1 : 0;
    final index = _index >= items.length ? 0 : _index;
    final pages = isAdmin
        ? [
            const DashboardScreen(),
            ScanSaleScreen(isActive: index == caisseTabIndex),
            const StockScreen(),
            const StatisticsScreen(),
            const ProfileScreen(),
          ]
        : [
            ScanSaleScreen(isActive: index == caisseTabIndex),
            const ProductsScreen(),
            const StockScreen(),
            const HistoryScreen(),
            const ProfileScreen(),
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
              items: items,
              currentIndex: index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ),
      ),
    );
  }
}
