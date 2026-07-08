import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/dashboard/model/dashboard_mock.dart';
import 'package:sou9ix/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final totalAlerts = ref.watch(totalAlertsCountProvider);
    final trendUp = DashboardMock.todayRevenue >= DashboardMock.yesterdayRevenue;
    final trendPct = ((DashboardMock.todayRevenue - DashboardMock.yesterdayRevenue) /
            DashboardMock.yesterdayRevenue *
            100)
        .abs();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initiales ?? 'S9',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonjour, ${user?.nom.split(' ').first ?? ''} 👋',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(user?.magasin ?? '', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  label: 'Recette du jour',
                  value: AppFormat.dt(DashboardMock.todayRevenue),
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                  trend: '${trendPct.toStringAsFixed(0)}%',
                  trendUp: trendUp,
                ),
                StatCard(
                  label: 'Bénéfice net',
                  value: AppFormat.dt(DashboardMock.todayProfit),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.goldDark,
                ),
                StatCard(
                  label: 'Tickets émis',
                  value: '${DashboardMock.todayTickets}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.info,
                ),
                PressScale(
                  onTap: () => context.push('/alerts'),
                  child: StatCard(
                    label: 'Alertes',
                    value: '$totalAlerts',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const SectionHeader(title: 'Recettes — 7 derniers jours'),
            const SizedBox(height: 14),
            Container(
              height: 190,
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: _WeeklyBarChart(values: DashboardMock.weeklyRevenue),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Top produits',
              actionLabel: 'Statistiques',
              onAction: () => context.push('/statistics'),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: List.generate(DashboardMock.topProducts.length, (i) {
                  final p = DashboardMock.topProducts[i];
                  final maxRevenue = DashboardMock.topProducts.first.revenue;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: i == 0 ? AppColors.goldDark : AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 10),
                        Text(p.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: p.revenue / maxRevenue),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, _) => LinearProgressIndicator(
                                    value: value,
                                    minHeight: 6,
                                    backgroundColor: AppColors.surfaceMuted,
                                    valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(AppFormat.dtShort(p.revenue),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  );
                }),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<double> values;
  const _WeeklyBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final isLast = i == values.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    days[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                      color: isLast ? AppColors.teal : AppColors.textFaint,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              AppFormat.dt(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ),
        barGroups: List.generate(values.length, (i) {
          final isLast = i == values.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLast
                      ? [AppColors.tealDark, AppColors.tealLight]
                      : [AppColors.surfaceMuted, AppColors.border],
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }
}
