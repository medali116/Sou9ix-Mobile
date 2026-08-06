import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/purchase_invoices_provider.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final todaySalesProvider = Provider<List<Sale>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(salesProvider)
      .where((s) => _isSameDay(s.dateHeure, now))
      .toList();
});

/// Best-effort profit: sale price minus current catalogue cost per line —
/// mirrors [Product.marge], the same simplification used everywhere else
/// in the app (no per-sale cost snapshot, no discount adjustment).
final todayProfitProvider = Provider<double>((ref) {
  final sales = ref.watch(todaySalesProvider);
  return sales.fold<double>(
    0,
    (sum, s) =>
        sum +
        s.lignes.fold<double>(
          0,
          (lsum, l) => lsum + l.product.marge * l.quantite,
        ),
  );
});

final yesterdayRevenueProvider = Provider<double>((ref) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return ref
      .watch(salesProvider)
      .where((s) => _isSameDay(s.dateHeure, yesterday))
      .fold(0.0, (sum, s) => sum + s.total);
});

final yesterdayProfitProvider = Provider<double>((ref) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final sales = ref
      .watch(salesProvider)
      .where((s) => _isSameDay(s.dateHeure, yesterday));
  return sales.fold<double>(
    0,
    (sum, s) =>
        sum +
        s.lignes.fold<double>(
          0,
          (lsum, l) => lsum + l.product.marge * l.quantite,
        ),
  );
});

/// Today's revenue split by [ModePaiement] — feeds the "Résumé aujourd'hui"
/// card's Espèces/Carte/Crédit breakdown.
final todayPaymentBreakdownProvider = Provider<Map<ModePaiement, double>>((
  ref,
) {
  final map = <ModePaiement, double>{};
  for (final s in ref.watch(todaySalesProvider)) {
    map[s.modePaiement] = (map[s.modePaiement] ?? 0) + s.total;
  }
  return map;
});

final todayExpensesTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(expensesProvider)
      .where((e) => _isSameDay(e.date, now))
      .fold(0.0, (sum, e) => sum + e.montant);
});

/// The one "Bénéfice net" figure the whole dashboard shows — margin
/// (revenue − cost of goods sold, see [todayProfitProvider]) minus today's
/// expenses. Every widget that shows a profit number for today (KPI card,
/// Résumé aujourd'hui) reads this single provider so they can never
/// disagree with each other.
final todayNetProfitProvider = Provider<double>((ref) {
  return ref.watch(todayProfitProvider) - ref.watch(todayExpensesTotalProvider);
});

final yesterdayExpensesTotalProvider = Provider<double>((ref) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return ref
      .watch(expensesProvider)
      .where((e) => _isSameDay(e.date, yesterday))
      .fold(0.0, (sum, e) => sum + e.montant);
});

final yesterdayNetProfitProvider = Provider<double>((ref) {
  return ref.watch(yesterdayProfitProvider) -
      ref.watch(yesterdayExpensesTotalProvider);
});

/// Revenue on this same weekday last week (exactly 7 days ago) — a real,
/// non-fabricated comparison point for the forecast card.
final lastWeekSameDayRevenueProvider = Provider<double>((ref) {
  final lastWeek = DateTime.now().subtract(const Duration(days: 7));
  return ref
      .watch(salesProvider)
      .where((s) => _isSameDay(s.dateHeure, lastWeek))
      .fold(0.0, (sum, s) => sum + s.total);
});

enum RevenuePeriod { j7, j30, m12 }

extension RevenuePeriodLabel on RevenuePeriod {
  String get label => switch (this) {
    RevenuePeriod.j7 => '7 jours',
    RevenuePeriod.j30 => '30 jours',
    RevenuePeriod.m12 => '12 mois',
  };
}

final revenuePeriodProvider = StateProvider<RevenuePeriod>(
  (ref) => RevenuePeriod.j7,
);

/// Which figure the dashboard's chart plots — the period toggle above
/// still controls the time window either way.
enum ChartMetric { recettes, benefices, tickets }

extension ChartMetricLabel on ChartMetric {
  String get label => switch (this) {
    ChartMetric.recettes => 'Recettes',
    ChartMetric.benefices => 'Bénéfices',
    ChartMetric.tickets => 'Tickets',
  };
}

final chartMetricProvider = StateProvider<ChartMetric>(
  (ref) => ChartMetric.recettes,
);

double _saleMetricValue(Sale s, ChartMetric metric) => switch (metric) {
  ChartMetric.recettes => s.total,
  ChartMetric.benefices => s.lignes.fold<double>(
    0,
    (sum, l) => sum + l.product.marge * l.quantite,
  ),
  ChartMetric.tickets => 1,
};

const _weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _monthLabels = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

/// The full breakdown behind one chart bar — shown in the tap-detail popup
/// regardless of which [ChartMetric] is currently plotted.
class ChartBarDetail {
  final DateTime date;
  final bool isMonth;
  final double revenue;
  final double profit;
  final int tickets;

  /// Revenue on the same weekday last week (day bars) or the same month
  /// last year (month bars) — the comparison point for "↑X% vs …" in the
  /// popup. Null when that reference period has no sales to compare to.
  final double? previousRevenue;

  const ChartBarDetail({
    required this.date,
    required this.isMonth,
    required this.revenue,
    required this.profit,
    required this.tickets,
    this.previousRevenue,
  });
}

ChartBarDetail _detailFor(
  Iterable<Sale> sales,
  DateTime date,
  bool isMonth,
  double? previousRevenue,
) {
  double revenue = 0;
  double profit = 0;
  var tickets = 0;
  for (final s in sales) {
    tickets++;
    revenue += s.total;
    profit += s.lignes.fold<double>(
      0,
      (lsum, l) => lsum + l.product.marge * l.quantite,
    );
  }
  return ChartBarDetail(
    date: date,
    isMonth: isMonth,
    revenue: revenue,
    profit: profit,
    tickets: tickets,
    previousRevenue: previousRevenue != null && previousRevenue > 0
        ? previousRevenue
        : null,
  );
}

/// Chart bars + labels for the currently selected [RevenuePeriod] and
/// [ChartMetric], plus per-bar [ChartBarDetail] (independent of the metric)
/// for the tap-to-inspect popup.
final revenueChartDataProvider =
    Provider<
      ({List<double> values, List<String> labels, List<ChartBarDetail> details})
    >((ref) {
      final period = ref.watch(revenuePeriodProvider);
      final metric = ref.watch(chartMetricProvider);
      final sales = ref.watch(salesProvider);
      final now = DateTime.now();

      switch (period) {
        case RevenuePeriod.j7:
        case RevenuePeriod.j30:
          final days = period == RevenuePeriod.j7 ? 7 : 30;
          final values = <double>[];
          final labels = <String>[];
          final details = <ChartBarDetail>[];
          for (var i = days - 1; i >= 0; i--) {
            final day = now.subtract(Duration(days: i));
            final daySales = sales.where((s) => _isSameDay(s.dateHeure, day));
            values.add(
              daySales.fold(0.0, (sum, s) => sum + _saleMetricValue(s, metric)),
            );
            labels.add(
              days == 7 ? _weekdayLabels[day.weekday - 1] : '${day.day}',
            );
            final weekAgo = day.subtract(const Duration(days: 7));
            final weekAgoRevenue = sales
                .where((s) => _isSameDay(s.dateHeure, weekAgo))
                .fold(0.0, (sum, s) => sum + s.total);
            details.add(_detailFor(daySales, day, false, weekAgoRevenue));
          }
          return (values: values, labels: labels, details: details);
        case RevenuePeriod.m12:
          final values = <double>[];
          final labels = <String>[];
          final details = <ChartBarDetail>[];
          for (var i = 11; i >= 0; i--) {
            final month = DateTime(now.year, now.month - i, 1);
            final monthSales = sales.where(
              (s) =>
                  s.dateHeure.year == month.year &&
                  s.dateHeure.month == month.month,
            );
            values.add(
              monthSales.fold(
                0.0,
                (sum, s) => sum + _saleMetricValue(s, metric),
              ),
            );
            labels.add(_monthLabels[month.month - 1]);
            final yearAgo = DateTime(month.year - 1, month.month, 1);
            final yearAgoRevenue = sales
                .where(
                  (s) =>
                      s.dateHeure.year == yearAgo.year &&
                      s.dateHeure.month == yearAgo.month,
                )
                .fold(0.0, (sum, s) => sum + s.total);
            details.add(_detailFor(monthSales, month, true, yearAgoRevenue));
          }
          return (values: values, labels: labels, details: details);
      }
    });

class TopProductStat {
  final Product product;
  final double revenue;
  final double quantite;
  final int ventes;

  const TopProductStat({
    required this.product,
    required this.revenue,
    required this.quantite,
    required this.ventes,
  });
}

/// Products ranked by revenue across every recorded sale.
final topProductsProvider = Provider<List<TopProductStat>>((ref) {
  final totals = <String, TopProductStat>{};
  for (final s in ref.watch(salesProvider)) {
    for (final l in s.lignes) {
      final existing = totals[l.product.id];
      totals[l.product.id] = TopProductStat(
        product: l.product,
        revenue: (existing?.revenue ?? 0) + l.sousTotal,
        quantite: (existing?.quantite ?? 0) + l.quantite,
        ventes: (existing?.ventes ?? 0) + 1,
      );
    }
  }
  final list = totals.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return list.take(5).toList();
});

/// Most recent sales, newest first — feeds the "Dernières ventes" card.
final recentSalesProvider = Provider<List<Sale>>((ref) {
  final sales = List.of(ref.watch(salesProvider))
    ..sort((a, b) => b.dateHeure.compareTo(a.dateHeure));
  return sales.take(3).toList();
});

/// Clients with an open karné balance, biggest first — feeds the "Clients
/// crédit" preview card.
final creditClientsPreviewProvider = Provider<List<Client>>((ref) {
  final clients =
      ref.watch(clientsProvider).where((c) => c.creditTotal > 0).toList()
        ..sort((a, b) => b.creditTotal.compareTo(a.creditTotal));
  return clients.take(3).toList();
});

/// Unsettled supplier invoices, biggest balance first — feeds the "Factures
/// fournisseurs à payer" preview card.
final unpaidInvoicesPreviewProvider = Provider<List<PurchaseInvoice>>((ref) {
  final list = List.of(ref.watch(unsettledInvoicesProvider))
    ..sort((a, b) => b.montantRestant.compareTo(a.montantRestant));
  return list.take(3).toList();
});

/// Average ticket size today — null with zero sales (avoids a meaningless
/// "0 / 0").
final avgTicketTodayProvider = Provider<double?>((ref) {
  final sales = ref.watch(todaySalesProvider);
  if (sales.isEmpty) return null;
  return sales.fold<double>(0, (sum, s) => sum + s.total) / sales.length;
});

/// Best-selling product today by revenue — distinct from [topProductsProvider],
/// which ranks across the whole history.
final topProductTodayProvider = Provider<TopProductStat?>((ref) {
  final totals = <String, TopProductStat>{};
  for (final s in ref.watch(todaySalesProvider)) {
    for (final l in s.lignes) {
      final existing = totals[l.product.id];
      totals[l.product.id] = TopProductStat(
        product: l.product,
        revenue: (existing?.revenue ?? 0) + l.sousTotal,
        quantite: (existing?.quantite ?? 0) + l.quantite,
        ventes: (existing?.ventes ?? 0) + 1,
      );
    }
  }
  if (totals.isEmpty) return null;
  return totals.values.reduce((a, b) => a.revenue >= b.revenue ? a : b);
});

/// The hour-of-day (0-23) with the most revenue today — null with zero
/// sales.
final busiestHourTodayProvider = Provider<int?>((ref) {
  final sales = ref.watch(todaySalesProvider);
  if (sales.isEmpty) return null;
  final byHour = <int, double>{};
  for (final s in sales) {
    byHour[s.dateHeure.hour] = (byHour[s.dateHeure.hour] ?? 0) + s.total;
  }
  return byHour.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
});

/// The dashboard's optional list sections — an admin can hide the ones
/// they don't care about via "Personnaliser le tableau de bord". KPI,
/// Résumé, Actions rapides, Alertes, Dernières ventes, Performance and Top
/// produits always show; these sit behind the "Voir plus" collapse (see
/// [dashboardExpandedProvider]) since they're the ones that make the page
/// long.
enum DashboardSection { clientsCredit, stockFaible, facturesFournisseurs }

extension DashboardSectionLabel on DashboardSection {
  String get label => switch (this) {
    DashboardSection.clientsCredit => 'Clients crédit',
    DashboardSection.stockFaible => 'Stock faible',
    DashboardSection.facturesFournisseurs => 'Factures fournisseurs à payer',
  };
}

final dashboardVisibleSectionsProvider = StateProvider<Set<DashboardSection>>(
  (ref) => DashboardSection.values.toSet(),
);

/// Whether the secondary sections (chart, top produits, stock faible,
/// clients crédit, factures fournisseurs, deeper insights) are expanded —
/// collapsed by default so the page opens short; "Voir plus" reveals them.
final dashboardExpandedProvider = StateProvider<bool>((ref) => false);

/// Distinct clients who bought something today.
final clientsTodayCountProvider = Provider<int>((ref) {
  return ref
      .watch(todaySalesProvider)
      .map((s) => s.clientId)
      .whereType<String>()
      .toSet()
      .length;
});

/// Average number of line items per ticket today — null with zero sales.
final avgBasketSizeTodayProvider = Provider<double?>((ref) {
  final sales = ref.watch(todaySalesProvider);
  if (sales.isEmpty) return null;
  return sales.fold<double>(0, (sum, s) => sum + s.lignes.length) /
      sales.length;
});

/// Best-selling cashier today by revenue — null when no sale today carries
/// an [Sale.employeeId].
final bestCashierTodayProvider =
    Provider<({String name, double revenue, int tickets})?>((ref) {
      final employees = {
        for (final e in ref.watch(employeesProvider)) e.id: e.nom,
      };
      final byEmployee =
          <String, ({String name, double revenue, int tickets})>{};
      for (final s in ref.watch(todaySalesProvider)) {
        final id = s.employeeId;
        if (id == null) continue;
        final name = employees[id] ?? id;
        final existing = byEmployee[id];
        byEmployee[id] = (
          name: name,
          revenue: (existing?.revenue ?? 0) + s.total,
          tickets: (existing?.tickets ?? 0) + 1,
        );
      }
      if (byEmployee.isEmpty) return null;
      return byEmployee.values.reduce((a, b) => a.revenue >= b.revenue ? a : b);
    });

/// New clients registered this month — derived from the activity log
/// (clients don't carry their own creation date).
final newClientsThisMonthProvider = Provider<int>((ref) {
  final now = DateTime.now();
  return ref
      .watch(activityLogProvider)
      .where(
        (e) =>
            e.category == ActivityCategory.clients &&
            e.action == 'Nouveau client' &&
            e.date.year == now.year &&
            e.date.month == now.month,
      )
      .length;
});

/// Estimated loss from currently-expired stock, valued at cost.
final expiredStockLossProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(productsProvider)
      .where((p) => p.datePeremption != null && p.datePeremption!.isBefore(now))
      .fold<double>(0, (sum, p) => sum + p.stock * p.prixAchat);
});

/// Catalogue-wide average margin percentage (not sales-weighted — a plain
/// average across products, so a single premium item doesn't skew it).
final averageMarginPctProvider = Provider<double?>((ref) {
  final products = ref
      .watch(productsProvider)
      .where((p) => p.prixAchat > 0)
      .toList();
  if (products.isEmpty) return null;
  return products.fold<double>(0, (sum, p) => sum + p.margePct) /
      products.length;
});

/// Best client this month by total purchases.
final topClientThisMonthProvider = Provider<({Client client, double total})?>((
  ref,
) {
  final now = DateTime.now();
  final clients = {for (final c in ref.watch(clientsProvider)) c.id: c};
  final byClient = <String, double>{};
  for (final s in ref.watch(salesProvider)) {
    final id = s.clientId;
    if (id == null ||
        s.dateHeure.year != now.year ||
        s.dateHeure.month != now.month) {
      continue;
    }
    byClient[id] = (byClient[id] ?? 0) + s.total;
  }
  if (byClient.isEmpty) return null;
  final topEntry = byClient.entries.reduce(
    (a, b) => a.value >= b.value ? a : b,
  );
  final client = clients[topEntry.key];
  if (client == null) return null;
  return (client: client, total: topEntry.value);
});

/// Month-over-month revenue change per product, for the "Top produits"
/// trend arrow — null when there's no prior-month figure to compare
/// against.
final topProductsTrendProvider = Provider<Map<String, double?>>((ref) {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  final sales = ref.watch(salesProvider);

  double revenueFor(DateTime month, String productId) {
    var total = 0.0;
    for (final s in sales) {
      if (s.dateHeure.year != month.year || s.dateHeure.month != month.month) {
        continue;
      }
      for (final l in s.lignes) {
        if (l.product.id == productId) total += l.sousTotal;
      }
    }
    return total;
  }

  final result = <String, double?>{};
  for (final p in ref.watch(topProductsProvider)) {
    final thisMonth = revenueFor(now, p.product.id);
    final prior = revenueFor(lastMonth, p.product.id);
    result[p.product.id] = prior > 0
        ? ((thisMonth - prior) / prior * 100)
        : null;
  }
  return result;
});

/// A same-day revenue pace projection ("at this rate, today should reach
/// ~X DT") — plain arithmetic on real data (elapsed-hours extrapolation),
/// not a prediction model, so the UI must call this "Prévision du jour",
/// never "IA".
class DashboardForecast {
  final double projected;
  final double? vsLastWeekPct;
  const DashboardForecast({required this.projected, this.vsLastWeekPct});
}

/// Null before there's enough of the day elapsed to extrapolate from.
final dashboardForecastProvider = Provider<DashboardForecast?>((ref) {
  final now = DateTime.now();
  final todayRevenue = ref.watch(todayRevenueProvider);
  if (todayRevenue <= 0 || now.hour < 9) return null;
  final hoursElapsed = (now.hour - 8).clamp(1, 24);
  final projected = todayRevenue / hoursElapsed * 14; // shop day ≈ 08h-22h
  if (projected <= todayRevenue * 1.05) return null;
  final lastWeek = ref.watch(lastWeekSameDayRevenueProvider);
  final vsLastWeekPct = lastWeek > 0
      ? ((projected - lastWeek) / lastWeek * 100)
      : null;
  return DashboardForecast(projected: projected, vsLastWeekPct: vsLastWeekPct);
});
