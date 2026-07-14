import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/stats/viewmodel/statistics_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/date_range_picker_sheet.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/section_header.dart';

/// Trend fragment for a KPI card: a real "±X% vs période préc." when there's
/// a prior-period figure to compare against, a neutral "Nouveau" note when
/// the metric only has activity in the current period (previous was zero —
/// a percentage there would be a meaningless "+∞%"), or nothing at all when
/// neither period has anything to show.
({String? trend, bool trendUp, String? subtitle}) _trendFor(double? changePct, num current) {
  if (changePct != null) {
    return (
      trend: '${changePct.abs().toStringAsFixed(1)}% vs période préc.',
      trendUp: changePct >= 0,
      subtitle: null,
    );
  }
  if (current != 0) {
    return (trend: null, trendUp: true, subtitle: 'Nouveau');
  }
  return (trend: null, trendUp: true, subtitle: null);
}

Widget _kpiCard({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
  required double? changePct,
  required num current,
}) {
  final t = _trendFor(changePct, current);
  return StatCard(
    compact: true,
    label: label,
    value: value,
    icon: icon,
    color: color,
    trend: t.trend,
    trendUp: t.trendUp,
    subtitle: t.subtitle,
  );
}

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showAppDateRangeSheet(
      context,
      initialRange: ref.read(statsCustomRangeProvider),
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
    );
    if (range != null) {
      ref.read(statsCustomRangeProvider.notifier).state = range;
      ref.read(statsPeriodProvider.notifier).state = StatsPeriod.personnalise;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final customRange = ref.watch(statsCustomRangeProvider);
    final kpis = ref.watch(statsKpisProvider);
    final financial = ref.watch(statsFinancialBreakdownProvider);
    final categoryMetric = ref.watch(statsCategoryMetricProvider);
    final categoryBreakdown = ref.watch(statsCategoryBreakdownProvider);
    final evolutionMetric = ref.watch(statsEvolutionMetricProvider);
    final evolution = ref.watch(statsEvolutionProvider);
    final compareEvolution = ref.watch(statsCompareEvolutionProvider);
    final payments = ref.watch(statsPaymentBreakdownProvider);
    final insights = ref.watch(statsInsightsProvider);
    final isLoss = kpis.netProfit < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          PressScale(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export PDF généré')),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.ios_share_rounded, size: 15, color: AppColors.textSecondary),
                  SizedBox(width: 5),
                  Text(
                    'Exporter',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in StatsPeriod.values.where((p) => p != StatsPeriod.personnalise))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PeriodChip(
                      label: p.label,
                      selected: period == p,
                      onTap: () => ref.read(statsPeriodProvider.notifier).state = p,
                    ),
                  ),
                _PeriodChip(
                  icon: Icons.calendar_month_rounded,
                  label: period == StatsPeriod.personnalise && customRange != null
                      ? '${customRange.start.day}/${customRange.start.month} → ${customRange.end.day}/${customRange.end.month}'
                      : 'Personnalisé',
                  selected: period == StatsPeriod.personnalise,
                  onTap: () => _pickCustomRange(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  label: 'Chiffre d\'affaires',
                  value: AppFormat.dtGrouped(kpis.revenue),
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                  changePct: kpis.revenueChangePct,
                  current: kpis.revenue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  label: isLoss ? 'Perte nette' : 'Bénéfice net',
                  value: AppFormat.dtGrouped(kpis.netProfit),
                  icon: isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  color: isLoss ? AppColors.danger : AppColors.success,
                  changePct: kpis.netProfitChangePct,
                  current: kpis.netProfit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  label: 'Tickets',
                  value: '${kpis.tickets}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.info,
                  changePct: kpis.ticketsChangePct,
                  current: kpis.tickets,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  label: 'Panier moyen',
                  value: kpis.avgBasket != null ? AppFormat.dtShortGrouped(kpis.avgBasket!) : '—',
                  icon: Icons.shopping_basket_outlined,
                  color: AppColors.tealDark,
                  changePct: kpis.avgBasketChangePct,
                  current: kpis.avgBasket ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Évolution'),
          const SizedBox(height: 12),
          _MetricSelector<StatsEvolutionMetric>(
            options: StatsEvolutionMetric.values,
            selected: evolutionMetric,
            labelOf: (m) => m.label,
            onChanged: (m) => ref.read(statsEvolutionMetricProvider.notifier).state = m,
          ),
          const SizedBox(height: 10),
          PressScale(
            onTap: () => ref.read(statsCompareEvolutionProvider.notifier).state = !compareEvolution,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: compareEvolution,
                    onChanged: (v) =>
                        ref.read(statsCompareEvolutionProvider.notifier).state = v ?? false,
                    activeColor: AppColors.teal,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Comparer à la période précédente',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EvolutionChart(
            values: evolution.values,
            previousValues: evolution.previousValues,
            showComparison: compareEvolution,
            labels: evolution.labels,
            points: evolution.points,
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: '${categoryMetric == StatsCategoryMetric.ca ? 'Chiffre d\'affaires' : categoryMetric.label} par catégorie',
          ),
          const SizedBox(height: 12),
          _MetricSelector<StatsCategoryMetric>(
            options: StatsCategoryMetric.values,
            selected: categoryMetric,
            labelOf: (m) => m.label,
            onChanged: (m) => ref.read(statsCategoryMetricProvider.notifier).state = m,
          ),
          const SizedBox(height: 14),
          _CategoryBreakdownCard(breakdown: categoryBreakdown, metric: categoryMetric),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Modes de paiement'),
          const SizedBox(height: 14),
          _PaymentBreakdownCard(payments: payments),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Résultat financier'),
          const SizedBox(height: 14),
          _FinancialBreakdownCard(data: financial),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 28),
            _InsightsCard(insights: insights),
          ],
          const SizedBox(height: 28),
          PressScale(
            onTap: () => context.push('/analytics'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.tealGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centre d\'analyse',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Explorez la rentabilité, le stock, l\'équipe et les clients →',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetricSelector<T> extends StatelessWidget {
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _MetricSelector({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: options.map((o) {
          final isSelected = o == selected;
          return Expanded(
            child: PressScale(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: isSelected ? AppShadows.card : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labelOf(o),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: isSelected ? AppColors.teal : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EvolutionChart extends StatelessWidget {
  final List<double> values;
  final List<double> previousValues;
  final bool showComparison;
  final List<String> labels;
  final List<EvolutionPoint> points;

  const _EvolutionChart({
    required this.values,
    required this.previousValues,
    required this.showComparison,
    required this.labels,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || values.every((v) => v == 0)) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: const Text(
          'Aucune vente sur cette période.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        ),
      );
    }

    final compareValues = showComparison ? previousValues : const <double>[];
    final maxRaw = [...values, ...compareValues].fold<double>(0, (m, v) => v > m ? v : m);
    final maxY = maxRaw <= 0 ? 1.0 : maxRaw * 1.3;
    final interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

    return Container(
      height: 230,
      padding: const EdgeInsets.fromLTRB(4, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: interval,
                getTitlesWidget: (v, meta) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString(),
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textFaint),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length || labels[i].isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[i],
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textFaint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              // Only the current-period line (barIndex 0) gets a tooltip —
              // the muted comparison line is a visual reference only.
              getTooltipItems: (spots) => spots.map((s) {
                if (s.barIndex != 0) return null;
                final i = s.x.toInt();
                if (i < 0 || i >= points.length) return null;
                final p = points[i];
                final avgBasket = p.tickets > 0 ? p.revenue / p.tickets : null;
                return LineTooltipItem(
                  '${p.tooltipLabel}\n'
                  'Chiffre d\'affaires : ${AppFormat.dtShortGrouped(p.revenue)}\n'
                  'Bénéfice : ${AppFormat.dtShortGrouped(p.profit)}\n'
                  '${p.tickets} ticket${p.tickets > 1 ? 's' : ''}'
                  '${avgBasket != null ? '\nPanier moyen : ${AppFormat.dtShortGrouped(avgBasket)}' : ''}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: AppColors.teal,
              barWidth: 3,
              dotData: FlDotData(show: values.length <= 12),
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
              spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            ),
            if (showComparison)
              LineChartBarData(
                isCurved: true,
                color: AppColors.textFaint,
                barWidth: 2,
                dashArray: const [6, 4],
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
                spots: [
                  for (var i = 0; i < previousValues.length; i++)
                    FlSpot(i.toDouble(), previousValues[i]),
                ],
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 380.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  final List<CategoryStat> breakdown;
  final StatsCategoryMetric metric;

  const _CategoryBreakdownCard({required this.breakdown, required this.metric});

  String _format(double v) => switch (metric) {
    StatsCategoryMetric.quantite => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1),
    _ => AppFormat.dtShortGrouped(v),
  };

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: const Text(
          'Aucune vente sur cette période.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        ),
      );
    }

    final total = breakdown.fold<double>(0, (sum, c) => sum + c.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 32,
                sections: [
                  for (var i = 0; i < breakdown.length; i++)
                    PieChartSectionData(
                      value: breakdown[i].value,
                      color: AppColors.categoryColor(i),
                      title: '',
                      radius: 20,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < breakdown.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.categoryColor(i),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            breakdown[i].category.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              total > 0 ? '${(breakdown[i].value / total * 100).toStringAsFixed(0)}%' : '0%',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                            ),
                            Text(
                              _format(breakdown[i].value),
                              style: const TextStyle(fontSize: 10, color: AppColors.textFaint),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0);
  }
}

class _PaymentMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _PaymentMeta(this.label, this.icon, this.color);
}

const _paymentMetaByMode = {
  ModePaiement.especes: _PaymentMeta('Espèces', Icons.payments_rounded, AppColors.teal),
  ModePaiement.carte: _PaymentMeta('Carte', Icons.credit_card_rounded, AppColors.info),
  ModePaiement.credit: _PaymentMeta('Crédit', Icons.menu_book_rounded, AppColors.goldDark),
};

class _PaymentBreakdownCard extends StatelessWidget {
  final Map<ModePaiement, double> payments;

  const _PaymentBreakdownCard({required this.payments});

  @override
  Widget build(BuildContext context) {
    final total = payments.values.fold<double>(0, (sum, v) => sum + v);
    if (total <= 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: const Text(
          'Aucune vente sur cette période.',
          style: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        ),
      );
    }

    // Crédit is a recorded sale, not cash actually collected — spelling
    // this out avoids an admin reading "Crédit 25%" as money already in
    // the till.
    final encaisse = (payments[ModePaiement.especes] ?? 0) + (payments[ModePaiement.carte] ?? 0);
    final credit = payments[ModePaiement.credit] ?? 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CA réalisé', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(AppFormat.dtShortGrouped(total), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 13, color: AppColors.success),
                      SizedBox(width: 5),
                      Text('Encaissé (espèces + carte)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                  Text(
                    AppFormat.dtShortGrouped(encaisse),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: AppColors.goldDark),
                      SizedBox(width: 5),
                      Text('Ventes à crédit (non encaissées)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                  Text(
                    AppFormat.dtShortGrouped(credit),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.goldDark),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: [
              for (final mode in ModePaiement.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _PaymentRow(
                    meta: _paymentMetaByMode[mode]!,
                    amount: payments[mode] ?? 0,
                    pct: (payments[mode] ?? 0) / total,
                  ),
                ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0);
  }
}

class _PaymentRow extends StatelessWidget {
  final _PaymentMeta meta;
  final double amount;
  final double pct;

  const _PaymentRow({required this.meta, required this.amount, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(meta.icon, size: 15, color: meta.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(meta.label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(
              '${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontWeight: FontWeight.w800, color: meta.color, fontSize: 12.5),
            ),
            const SizedBox(width: 8),
            Text(
              AppFormat.dtShortGrouped(amount),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(meta.color),
          ),
        ),
      ],
    );
  }
}

class _FinancialBreakdownCard extends StatelessWidget {
  final FinancialBreakdown data;

  const _FinancialBreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final marginRate = data.revenue > 0 ? data.grossMargin / data.revenue * 100 : null;
    final isLoss = data.netProfit < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _FinancialRow('Chiffre d\'affaires', AppFormat.dtGrouped(data.revenue)),
          _FinancialRow('Coût des marchandises', '- ${AppFormat.dtGrouped(data.cogs)}'),
          const Divider(height: 20),
          _FinancialRow('Marge brute', AppFormat.dtGrouped(data.grossMargin), bold: true),
          _FinancialRow(
            'Taux de marge',
            marginRate != null ? '${marginRate.toStringAsFixed(1)}%' : '—',
            muted: true,
          ),
          _FinancialRow('Dépenses', '- ${AppFormat.dtGrouped(data.expenses)}'),
          const Divider(height: 20),
          _FinancialRow(
            isLoss ? 'Perte nette' : 'Bénéfice net',
            AppFormat.dtGrouped(data.netProfit),
            bold: true,
            valueColor: isLoss ? AppColors.danger : AppColors.success,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0);
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool muted;
  final Color? valueColor;

  const _FinancialRow(
    this.label,
    this.value, {
    this.bold = false,
    this.muted = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 14.5 : 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15.5 : (muted ? 12.5 : 13.5),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? (bold ? AppColors.textPrimary : (muted ? AppColors.textFaint : AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  final List<StatInsight> insights;

  const _InsightsCard({required this.insights});

  Color _colorOf(InsightSeverity s) => switch (s) {
    InsightSeverity.success => AppColors.success,
    InsightSeverity.warning => AppColors.warning,
    InsightSeverity.danger => AppColors.danger,
    InsightSeverity.info => AppColors.info,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text('À retenir', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          for (final insight in insights)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(insight.icon, size: 15, color: _colorOf(insight.severity)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight.text,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0);
  }
}
