import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/shell/animated_bottom_nav.dart';
import 'package:sou9ix/shared/core/shell/bottom_nav_visibility_provider.dart';
import 'package:sou9ix/shared/core/shell/tab_navigation_provider.dart';
import 'package:sou9ix/caissier/features/caisse/view/caisse_gate.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/shared/features/sales/view/history_screen.dart';
import 'package:sou9ix/shared/features/pos/view/scan_sale_screen.dart';
import 'package:sou9ix/caissier/features/products/view/products_screen.dart';
import 'package:sou9ix/caissier/features/profile/view/profile_screen.dart';
import 'package:sou9ix/caissier/features/stock/view/stock_screen.dart';

/// Bottom-tab shell for the Caissier app — a sales-first tab set (Caisse,
/// Produits, Stock, Historique, Profil). Caisse is a persistent tab (index
/// 0) that holds the live camera session for the whole time this shell is
/// mounted, unlike the admin app which only ever reaches the same selling
/// screen as a one-off pushed route.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _items = [
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

  static const _caisseTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(requestedTabIndexProvider, (previous, next) {
      if (next != null) {
        setState(() => _index = next);
        ref.read(requestedTabIndexProvider.notifier).state = null;
      }
    });
    // Watched purely so every tab (Caisse, Stock…) rebuilds when the
    // currency/ticket settings change, since AppFormat itself is a plain
    // static utility with no reactivity of its own.
    ref.watch(companySettingsProvider);
    final index = _index >= _items.length ? 0 : _index;
    final pages = [
      CaisseGate(child: ScanSaleScreen(isActive: index == _caisseTabIndex)),
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
