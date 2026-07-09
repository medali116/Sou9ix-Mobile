import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';

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

/// Revenue chart bars + labels for the currently selected [RevenuePeriod].
final revenueChartDataProvider =
    Provider<({List<double> values, List<String> labels})>((ref) {
      final period = ref.watch(revenuePeriodProvider);
      final sales = ref.watch(salesProvider);
      final now = DateTime.now();

      switch (period) {
        case RevenuePeriod.j7:
        case RevenuePeriod.j30:
          final days = period == RevenuePeriod.j7 ? 7 : 30;
          final values = <double>[];
          final labels = <String>[];
          for (var i = days - 1; i >= 0; i--) {
            final day = now.subtract(Duration(days: i));
            values.add(
              sales
                  .where((s) => _isSameDay(s.dateHeure, day))
                  .fold(0.0, (sum, s) => sum + s.total),
            );
            labels.add(
              days == 7 ? _weekdayLabels[day.weekday - 1] : '${day.day}',
            );
          }
          return (values: values, labels: labels);
        case RevenuePeriod.m12:
          final values = <double>[];
          final labels = <String>[];
          for (var i = 11; i >= 0; i--) {
            final month = DateTime(now.year, now.month - i, 1);
            values.add(
              sales
                  .where(
                    (s) =>
                        s.dateHeure.year == month.year &&
                        s.dateHeure.month == month.month,
                  )
                  .fold(0.0, (sum, s) => sum + s.total),
            );
            labels.add(_monthLabels[month.month - 1]);
          }
          return (values: values, labels: labels);
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
  return list.take(4).toList();
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
