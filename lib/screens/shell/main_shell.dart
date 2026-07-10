import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/animated_bottom_nav.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../pos/scan_sale_screen.dart';
import '../products/products_screen.dart';
import '../profile/profile_screen.dart';
import '../stats/statistics_screen.dart';
import '../stock/stock_screen.dart';

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

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: AnimatedBottomNav(
        items: items,
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
