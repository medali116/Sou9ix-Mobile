import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/features/products/model/category.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';

/// Period-aware statistics for the Statistiques screen: every figure here
/// is scoped to a selected window and paired with the equivalent-length
/// window right before it, so every KPI can show a real "vs période
/// précédente" comparison instead of a static snapshot.
enum StatsPeriod { jour, j7, j30, m12, personnalise }

extension StatsPeriodLabel on StatsPeriod {
  String get label => switch (this) {
    StatsPeriod.jour => 'Aujourd\'hui',
    StatsPeriod.j7 => '7 jours',
    StatsPeriod.j30 => '30 jours',
    StatsPeriod.m12 => '12 mois',
    StatsPeriod.personnalise => 'Personnalisé',
  };
}

final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.j7);

/// Only meaningful when [statsPeriodProvider] is [StatsPeriod.personnalise].
final statsCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _inWindow(DateTime d, DateTime start, DateTime endExclusive) =>
    !d.isBefore(start) && d.isBefore(endExclusive);

/// The `[start, endExclusive)` window for the selected period, plus the
/// equivalent-length window immediately preceding it.
class StatsWindow {
  final DateTime start;
  final DateTime endExclusive;
  final DateTime previousStart;
  final DateTime previousEndExclusive;

  const StatsWindow({
    required this.start,
    required this.endExclusive,
    required this.previousStart,
    required this.previousEndExclusive,
  });
}

final statsWindowProvider = Provider<StatsWindow>((ref) {
  final period = ref.watch(statsPeriodProvider);
  final today = _dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));

  switch (period) {
    case StatsPeriod.jour:
      final yesterday = today.subtract(const Duration(days: 1));
      return StatsWindow(
        start: today,
        endExclusive: tomorrow,
        previousStart: yesterday,
        previousEndExclusive: today,
      );
    case StatsPeriod.j7:
      final start = today.subtract(const Duration(days: 6));
      return StatsWindow(
        start: start,
        endExclusive: tomorrow,
        previousStart: start.subtract(const Duration(days: 7)),
        previousEndExclusive: start,
      );
    case StatsPeriod.j30:
      final start = today.subtract(const Duration(days: 29));
      return StatsWindow(
        start: start,
        endExclusive: tomorrow,
        previousStart: start.subtract(const Duration(days: 30)),
        previousEndExclusive: start,
      );
    case StatsPeriod.m12:
      final start = DateTime(today.year - 1, today.month, today.day);
      final spanDays = tomorrow.difference(start).inDays;
      return StatsWindow(
        start: start,
        endExclusive: tomorrow,
        previousStart: start.subtract(Duration(days: spanDays)),
        previousEndExclusive: start,
      );
    case StatsPeriod.personnalise:
      final range = ref.watch(statsCustomRangeProvider);
      final start = range != null
          ? _dateOnly(range.start)
          : today.subtract(const Duration(days: 6));
      final endExclusive = range != null
          ? _dateOnly(range.end).add(const Duration(days: 1))
          : tomorrow;
      final spanDays = endExclusive.difference(start).inDays;
      return StatsWindow(
        start: start,
        endExclusive: endExclusive,
        previousStart: start.subtract(Duration(days: spanDays)),
        previousEndExclusive: start,
      );
  }
});

final _periodSalesProvider = Provider<List<Sale>>((ref) {
  final w = ref.watch(statsWindowProvider);
  return ref
      .watch(salesProvider)
      .where((s) => _inWindow(s.dateHeure, w.start, w.endExclusive))
      .toList();
});

final _previousPeriodSalesProvider = Provider<List<Sale>>((ref) {
  final w = ref.watch(statsWindowProvider);
  return ref
      .watch(salesProvider)
      .where((s) => _inWindow(s.dateHeure, w.previousStart, w.previousEndExclusive))
      .toList();
});

final _periodExpensesTotalProvider = Provider<double>((ref) {
  final w = ref.watch(statsWindowProvider);
  return ref
      .watch(expensesProvider)
      .where((e) => _inWindow(e.date, w.start, w.endExclusive))
      .fold(0.0, (sum, e) => sum + e.montant);
});

final _previousPeriodExpensesTotalProvider = Provider<double>((ref) {
  final w = ref.watch(statsWindowProvider);
  return ref
      .watch(expensesProvider)
      .where((e) => _inWindow(e.date, w.previousStart, w.previousEndExclusive))
      .fold(0.0, (sum, e) => sum + e.montant);
});

double _revenueOf(List<Sale> sales) => sales.fold(0.0, (sum, s) => sum + s.total);

double _marginOf(List<Sale> sales) => sales.fold<double>(
  0,
  (sum, s) => sum + s.lignes.fold<double>(0, (lsum, l) => lsum + l.product.marge * l.quantite),
);

double _cogsOf(List<Sale> sales) => sales.fold<double>(
  0,
  (sum, s) => sum + s.lignes.fold<double>(0, (lsum, l) => lsum + l.product.prixAchat * l.quantite),
);

/// Null when there's no prior-period figure to compare against (avoids a
/// meaningless "+∞%"), matching the convention already used for the
/// dashboard's month-over-month comparisons.
double? _pctChange(double current, double previous) {
  if (previous == 0) return null;
  return (current - previous) / previous * 100;
}

class StatsKpis {
  final double revenue;
  final double? revenueChangePct;
  final double netProfit;
  final double? netProfitChangePct;
  final int tickets;
  final double? ticketsChangePct;
  final double? avgBasket;
  final double? avgBasketChangePct;

  const StatsKpis({
    required this.revenue,
    required this.revenueChangePct,
    required this.netProfit,
    required this.netProfitChangePct,
    required this.tickets,
    required this.ticketsChangePct,
    required this.avgBasket,
    required this.avgBasketChangePct,
  });
}

final statsKpisProvider = Provider<StatsKpis>((ref) {
  final sales = ref.watch(_periodSalesProvider);
  final prevSales = ref.watch(_previousPeriodSalesProvider);
  final expenses = ref.watch(_periodExpensesTotalProvider);
  final prevExpenses = ref.watch(_previousPeriodExpensesTotalProvider);

  final revenue = _revenueOf(sales);
  final prevRevenue = _revenueOf(prevSales);
  final netProfit = _marginOf(sales) - expenses;
  final prevNetProfit = _marginOf(prevSales) - prevExpenses;
  final tickets = sales.length;
  final prevTickets = prevSales.length;
  final avgBasket = tickets > 0 ? revenue / tickets : null;
  final prevAvgBasket = prevTickets > 0 ? prevRevenue / prevTickets : null;

  return StatsKpis(
    revenue: revenue,
    revenueChangePct: _pctChange(revenue, prevRevenue),
    netProfit: netProfit,
    netProfitChangePct: _pctChange(netProfit, prevNetProfit),
    tickets: tickets,
    ticketsChangePct: _pctChange(tickets.toDouble(), prevTickets.toDouble()),
    avgBasket: avgBasket,
    avgBasketChangePct: (avgBasket != null && prevAvgBasket != null)
        ? _pctChange(avgBasket, prevAvgBasket)
        : null,
  );
});

/// Chiffre d'affaires → coût des marchandises vendues → marge brute →
/// dépenses → bénéfice net, all for the selected period.
class FinancialBreakdown {
  final double revenue;
  final double cogs;
  final double grossMargin;
  final double expenses;
  final double netProfit;

  const FinancialBreakdown({
    required this.revenue,
    required this.cogs,
    required this.grossMargin,
    required this.expenses,
    required this.netProfit,
  });
}

final statsFinancialBreakdownProvider = Provider<FinancialBreakdown>((ref) {
  final sales = ref.watch(_periodSalesProvider);
  final expenses = ref.watch(_periodExpensesTotalProvider);
  final revenue = _revenueOf(sales);
  final cogs = _cogsOf(sales);
  final grossMargin = revenue - cogs;
  return FinancialBreakdown(
    revenue: revenue,
    cogs: cogs,
    grossMargin: grossMargin,
    expenses: expenses,
    netProfit: grossMargin - expenses,
  );
});

/// Which figure the "Ventes par catégorie" donut plots.
enum StatsCategoryMetric { ca, benefice, quantite }

extension StatsCategoryMetricLabel on StatsCategoryMetric {
  String get label => switch (this) {
    StatsCategoryMetric.ca => 'CA',
    StatsCategoryMetric.benefice => 'Bénéfice',
    StatsCategoryMetric.quantite => 'Quantité',
  };
}

final statsCategoryMetricProvider = StateProvider<StatsCategoryMetric>(
  (ref) => StatsCategoryMetric.ca,
);

class CategoryStat {
  final ProductCategory category;
  final double value;
  const CategoryStat({required this.category, required this.value});
}

final statsCategoryBreakdownProvider = Provider<List<CategoryStat>>((ref) {
  final sales = ref.watch(_periodSalesProvider);
  final metric = ref.watch(statsCategoryMetricProvider);
  final categories = {for (final c in ref.watch(categoriesProvider)) c.id: c};

  final totals = <String, double>{};
  for (final s in sales) {
    for (final l in s.lignes) {
      final value = switch (metric) {
        StatsCategoryMetric.ca => l.sousTotal,
        StatsCategoryMetric.benefice => l.product.marge * l.quantite,
        StatsCategoryMetric.quantite => l.quantite,
      };
      totals[l.product.categorieId] = (totals[l.product.categorieId] ?? 0) + value;
    }
  }

  final list = totals.entries
      .where((e) => categories.containsKey(e.key))
      .map((e) => CategoryStat(category: categories[e.key]!, value: e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list;
});

/// Period revenue split by [ModePaiement] — "Modes de paiement".
final statsPaymentBreakdownProvider = Provider<Map<ModePaiement, double>>((ref) {
  final map = <ModePaiement, double>{};
  for (final s in ref.watch(_periodSalesProvider)) {
    map[s.modePaiement] = (map[s.modePaiement] ?? 0) + s.total;
  }
  return map;
});

/// Which figure the evolution chart plots.
enum StatsEvolutionMetric { ca, benefice, tickets }

extension StatsEvolutionMetricLabel on StatsEvolutionMetric {
  String get label => switch (this) {
    StatsEvolutionMetric.ca => 'CA',
    StatsEvolutionMetric.benefice => 'Bénéfice',
    StatsEvolutionMetric.tickets => 'Tickets',
  };
}

final statsEvolutionMetricProvider = StateProvider<StatsEvolutionMetric>(
  (ref) => StatsEvolutionMetric.ca,
);

const _monthLabelsShort = [
  'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
];
const _monthNamesFull = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// The full breakdown behind one evolution-chart point — shown in the
/// tap-to-inspect tooltip regardless of which [StatsEvolutionMetric] is
/// currently plotted.
class EvolutionPoint {
  final String tooltipLabel;
  final double revenue;
  final double profit;
  final int tickets;
  const EvolutionPoint({
    required this.tooltipLabel,
    required this.revenue,
    required this.profit,
    required this.tickets,
  });
}

double _metricValue(StatsEvolutionMetric metric, List<Sale> bucket) => switch (metric) {
  StatsEvolutionMetric.ca => _revenueOf(bucket),
  StatsEvolutionMetric.benefice => _marginOf(bucket),
  StatsEvolutionMetric.tickets => bucket.length.toDouble(),
};

/// Toggle for overlaying a second, muted line on the evolution chart
/// showing the equivalent-length previous period, bucket-for-bucket.
final statsCompareEvolutionProvider = StateProvider<bool>((ref) => false);

/// Bucketed values only (no labels/tooltip data) — shared by both the
/// current-period series (built alongside its labels below) and the
/// previous-period comparison series, which only needs the raw numbers.
List<double> _bucketedValues(
  List<Sale> sales,
  StatsPeriod period,
  DateTime start,
  DateTime endExclusive,
  StatsEvolutionMetric metric,
) {
  List<Sale> bucketFor(DateTime s, DateTime e) =>
      sales.where((sale) => _inWindow(sale.dateHeure, s, e)).toList();

  final values = <double>[];
  switch (period) {
    case StatsPeriod.jour:
      for (var h = 0; h < 24; h++) {
        final s = DateTime(start.year, start.month, start.day, h);
        values.add(_metricValue(metric, bucketFor(s, s.add(const Duration(hours: 1)))));
      }
      break;
    case StatsPeriod.j7:
    case StatsPeriod.j30:
      final days = period == StatsPeriod.j7 ? 7 : 30;
      for (var i = 0; i < days; i++) {
        final d = start.add(Duration(days: i));
        values.add(_metricValue(metric, bucketFor(d, d.add(const Duration(days: 1)))));
      }
      break;
    case StatsPeriod.m12:
      for (var i = 0; i < 12; i++) {
        final month = DateTime(start.year, start.month + i, 1);
        final next = DateTime(month.year, month.month + 1, 1);
        values.add(_metricValue(metric, bucketFor(month, next)));
      }
      break;
    case StatsPeriod.personnalise:
      final spanDays = endExclusive.difference(start).inDays;
      if (spanDays <= 31) {
        for (var d = start; d.isBefore(endExclusive); d = d.add(const Duration(days: 1))) {
          values.add(_metricValue(metric, bucketFor(d, d.add(const Duration(days: 1)))));
        }
      } else {
        var month = DateTime(start.year, start.month, 1);
        final endMonth = DateTime(endExclusive.year, endExclusive.month, 1);
        while (!month.isAfter(endMonth)) {
          final next = DateTime(month.year, month.month + 1, 1);
          final cs = month.isBefore(start) ? start : month;
          final ce = next.isAfter(endExclusive) ? endExclusive : next;
          values.add(_metricValue(metric, bucketFor(cs, ce)));
          month = next;
        }
      }
      break;
  }
  return values;
}

final statsEvolutionProvider = Provider<
    ({
      List<double> values,
      List<double> previousValues,
      List<String> labels,
      List<EvolutionPoint> points,
    })>((ref) {
  final period = ref.watch(statsPeriodProvider);
  final w = ref.watch(statsWindowProvider);
  final metric = ref.watch(statsEvolutionMetricProvider);
  final sales = ref.watch(salesProvider);

  final values = <double>[];
  final labels = <String>[];
  final points = <EvolutionPoint>[];

  void addBucket(List<Sale> bucket, String axisLabel, String tooltipLabel) {
    values.add(_metricValue(metric, bucket));
    labels.add(axisLabel);
    points.add(EvolutionPoint(
      tooltipLabel: tooltipLabel,
      revenue: _revenueOf(bucket),
      profit: _marginOf(bucket),
      tickets: bucket.length,
    ));
  }

  List<Sale> bucketFor(DateTime start, DateTime endExclusive) =>
      sales.where((s) => _inWindow(s.dateHeure, start, endExclusive)).toList();

  switch (period) {
    case StatsPeriod.jour:
      for (var h = 0; h < 24; h++) {
        final start = DateTime(w.start.year, w.start.month, w.start.day, h);
        final end = start.add(const Duration(hours: 1));
        addBucket(
          bucketFor(start, end),
          h % 3 == 0 ? '${h}h' : '',
          '${h.toString().padLeft(2, '0')}:00',
        );
      }
      break;
    case StatsPeriod.j7:
    case StatsPeriod.j30:
      final days = period == StatsPeriod.j7 ? 7 : 30;
      for (var i = 0; i < days; i++) {
        final day = w.start.add(Duration(days: i));
        addBucket(
          bucketFor(day, day.add(const Duration(days: 1))),
          days == 7
              ? AppFormat.weekday(day)
              : (i % 5 == 0 || i == days - 1 ? '${day.day}' : ''),
          AppFormat.fullDate(day),
        );
      }
      break;
    case StatsPeriod.m12:
      for (var i = 0; i < 12; i++) {
        final month = DateTime(w.start.year, w.start.month + i, 1);
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        addBucket(
          bucketFor(month, nextMonth),
          _monthLabelsShort[month.month - 1],
          '${_monthNamesFull[month.month - 1]} ${month.year}',
        );
      }
      break;
    case StatsPeriod.personnalise:
      final spanDays = w.endExclusive.difference(w.start).inDays;
      if (spanDays <= 31) {
        var i = 0;
        for (var d = w.start; d.isBefore(w.endExclusive); d = d.add(const Duration(days: 1))) {
          addBucket(
            bucketFor(d, d.add(const Duration(days: 1))),
            i % 5 == 0 ? '${d.day}' : '',
            AppFormat.fullDate(d),
          );
          i++;
        }
      } else {
        var month = DateTime(w.start.year, w.start.month, 1);
        final endMonth = DateTime(w.endExclusive.year, w.endExclusive.month, 1);
        while (!month.isAfter(endMonth)) {
          final nextMonth = DateTime(month.year, month.month + 1, 1);
          final clampedStart = month.isBefore(w.start) ? w.start : month;
          final clampedEnd = nextMonth.isAfter(w.endExclusive) ? w.endExclusive : nextMonth;
          addBucket(
            bucketFor(clampedStart, clampedEnd),
            _monthLabelsShort[month.month - 1],
            '${_monthNamesFull[month.month - 1]} ${month.year}',
          );
          month = nextMonth;
        }
      }
      break;
  }

  final previousValues =
      _bucketedValues(sales, period, w.previousStart, w.previousEndExclusive, metric);

  return (values: values, previousValues: previousValues, labels: labels, points: points);
});

enum InsightSeverity { success, warning, danger, info }

class StatInsight {
  final IconData icon;
  final InsightSeverity severity;
  final String text;
  const StatInsight({required this.icon, required this.severity, required this.text});
}

/// 2-3 automatically generated one-line takeaways for the current period —
/// only the ones with something real to say (skipped when the underlying
/// figure is zero/undefined), so the list never pads itself out with
/// meaningless filler.
final statsInsightsProvider = Provider<List<StatInsight>>((ref) {
  final financial = ref.watch(statsFinancialBreakdownProvider);
  final kpis = ref.watch(statsKpisProvider);
  final sales = ref.watch(_periodSalesProvider);
  final categories = {for (final c in ref.watch(categoriesProvider)) c.id: c};

  final insights = <StatInsight>[];

  if (financial.revenue > 0) {
    final expenseShare = financial.expenses / financial.revenue * 100;
    if (expenseShare >= 50) {
      insights.add(StatInsight(
        icon: Icons.warning_amber_rounded,
        severity: InsightSeverity.danger,
        text: 'Les dépenses représentent ${expenseShare.toStringAsFixed(0)}% du chiffre d\'affaires.',
      ));
    } else if (expenseShare >= 30) {
      insights.add(StatInsight(
        icon: Icons.warning_amber_rounded,
        severity: InsightSeverity.warning,
        text: 'Les dépenses représentent ${expenseShare.toStringAsFixed(0)}% du chiffre d\'affaires.',
      ));
    }
  }

  final netChange = kpis.netProfitChangePct;
  if (netChange != null && netChange < 0) {
    insights.add(StatInsight(
      icon: Icons.trending_down_rounded,
      severity: InsightSeverity.danger,
      text: 'Le résultat net a baissé de ${netChange.abs().toStringAsFixed(1)}% vs la période précédente.',
    ));
  } else if (netChange != null && netChange > 0) {
    insights.add(StatInsight(
      icon: Icons.trending_up_rounded,
      severity: InsightSeverity.success,
      text: 'Le résultat net a augmenté de ${netChange.toStringAsFixed(1)}% vs la période précédente.',
    ));
  }

  final caTotals = <String, double>{};
  for (final s in sales) {
    for (final l in s.lignes) {
      caTotals[l.product.categorieId] = (caTotals[l.product.categorieId] ?? 0) + l.sousTotal;
    }
  }
  if (caTotals.isNotEmpty) {
    final totalCa = caTotals.values.fold<double>(0, (a, b) => a + b);
    final topEntry = caTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final topCategory = categories[topEntry.key];
    final share = totalCa > 0 ? topEntry.value / totalCa * 100 : 0;
    if (topCategory != null && share >= 35) {
      insights.add(StatInsight(
        icon: Icons.pie_chart_rounded,
        severity: InsightSeverity.info,
        text: '${topCategory.name} génère ${share.toStringAsFixed(0)}% du chiffre d\'affaires.',
      ));
    }
  }

  return insights.take(3).toList();
});
