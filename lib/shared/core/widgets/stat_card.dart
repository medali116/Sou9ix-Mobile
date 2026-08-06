import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool trendUp;
  final String? subtitle;
  final Color? subtitleColor;

  /// Denser padding/icon size — used on the dashboard's KPI grid where four
  /// cards need to fit above the fold without a tall empty band underneath.
  final bool compact;

  /// Tighter still than [compact] — for a value+label pair with no
  /// trend/subtitle line, where [compact]'s own padding leaves a visible
  /// empty band under the text (Centre d'analyse's Performance grid).
  final bool dense;

  /// Icon beside the text block instead of above it — for a wide grid cell
  /// (tablet/desktop, 4-across) where there's width to spare and a flatter
  /// card reads better than a tall one.
  final bool horizontal;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp = true,
    this.subtitle,
    this.subtitleColor,
    this.compact = false,
    this.dense = false,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = dense ? 22.0 : (compact ? 26.0 : 40.0);
    final iconBox = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: dense ? 13 : (compact ? 14 : 20)),
    );

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: compact
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                )
              : Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (trend != null) ...[
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                trendUp
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 12,
                color: trendUp ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  trend!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: trendUp ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: subtitleColor ?? AppColors.textFaint,
            ),
          ),
        ],
      ],
    );

    return Container(
          padding: EdgeInsets.all(dense ? 12 : (compact ? 16 : 18)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconBox,
                    const SizedBox(width: 10),
                    Expanded(child: textBlock),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconBox,
                    SizedBox(height: dense ? 3 : (compact ? 4 : 14)),
                    textBlock,
                  ],
                ),
        )
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}
