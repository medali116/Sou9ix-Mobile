import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StockBar extends StatelessWidget {
  final double quantite;
  final double seuil;

  const StockBar({super.key, required this.quantite, required this.seuil});

  @override
  Widget build(BuildContext context) {
    final ratio = seuil <= 0 ? 1.0 : (quantite / (seuil * 4)).clamp(0.04, 1.0);
    final low = quantite <= seuil;
    final color = low ? AppColors.warning : AppColors.success;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => LinearProgressIndicator(
          value: value,
          minHeight: 7,
          backgroundColor: AppColors.surfaceMuted,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}
