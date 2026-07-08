import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/dashboard/model/dashboard_mock.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _period = 1; // 0 jour, 1 semaine, 2 mois

  static const _categoryBreakdown = [
    (label: 'Fruits secs', value: 46.0, color: AppColors.teal),
    (label: 'Torréfaction', value: 22.0, color: AppColors.gold),
    (label: 'Épices', value: 16.0, color: AppColors.info),
    (label: 'Épicerie', value: 16.0, color: AppColors.tealDark),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export PDF généré')),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: List.generate(3, (i) {
                const labels = ['Jour', 'Semaine', 'Mois'];
                final selected = _period == i;
                return Expanded(
                  child: PressScale(
                    onTap: () => setState(() => _period = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: selected ? AppShadows.card : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? AppColors.teal : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Chiffre d\'affaires',
                  value: AppFormat.dt(5720),
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Bénéfice net',
                  value: AppFormat.dt(1840),
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('Répartition par catégorie', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 34,
                      sections: _categoryBreakdown
                          .map((c) => PieChartSectionData(
                                value: c.value,
                                color: c.color,
                                title: '',
                                radius: 20,
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _categoryBreakdown
                        .map((c) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                        color: c.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(c.label,
                                        style: Theme.of(context).textTheme.bodyLarge),
                                  ),
                                  Text('${c.value.toInt()}%',
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 26),
          Text('Historique des recettes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: true),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppColors.teal,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.teal.withValues(alpha: 0.22),
                          AppColors.teal.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    spots: List.generate(
                      DashboardMock.weeklyRevenue.length,
                      (i) => FlSpot(i.toDouble(), DashboardMock.weeklyRevenue[i]),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 380.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
