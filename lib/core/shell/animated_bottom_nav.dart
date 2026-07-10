import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';

class NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Bottom tab bar with a floating circular bubble that rises above the bar
/// for the active tab, following a curved notch cut into the bar itself.
class AnimatedBottomNav extends StatelessWidget {
  final List<NavItemData> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AnimatedBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedNavigationBar(
      index: currentIndex,
      color: AppColors.ink,
      buttonBackgroundColor: AppColors.teal,
      backgroundColor: AppColors.background,
      animationDuration: const Duration(milliseconds: 320),
      animationCurve: Curves.easeOutCubic,
      onTap: onTap,
      items: List.generate(items.length, (i) {
        final selected = i == currentIndex;
        final item = items[i];
        return Tooltip(
          message: item.label,
          child: Icon(
            selected ? item.activeIcon : item.icon,
            size: 24,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}
