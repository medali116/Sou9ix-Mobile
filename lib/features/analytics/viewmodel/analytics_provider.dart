import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';

/// "Centre d'analyse" — the deeper, decision-support layer above the
/// dashboard: who's selling, when, what's dead stock, what's actually
/// profitable, and a simple stockout forecast. Everything here is
/// computed from real recorded data (sales/expenses/invoices), nothing
/// fabricated.
class CashierStat {
  final String employeeName;
  final double revenue;
  final int tickets;
  const CashierStat({
    required this.employeeName,
    required this.revenue,
    required this.tickets,
  });
}

final topCashiersProvider = Provider<List<CashierStat>>((ref) {
  final employees = {for (final e in ref.watch(employeesProvider)) e.id: e.nom};
  final byEmployee = <String, CashierStat>{};
  for (final s in ref.watch(salesProvider)) {
    final id = s.employeeId;
    if (id == null) continue;
    final name = employees[id] ?? id;
    final existing = byEmployee[id];
    byEmployee[id] = CashierStat(
      employeeName: name,
      revenue: (existing?.revenue ?? 0) + s.total,
      tickets: (existing?.tickets ?? 0) + 1,
    );
  }
  final list = byEmployee.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return list;
});

/// Revenue bucketed by hour-of-day (0-23) across every recorded sale — the
/// "heures les plus rentables" ranking (not just today, the whole history).
final hourlyRevenueProvider = Provider<List<(int hour, double revenue)>>((ref) {
  final byHour = <int, double>{};
  for (final s in ref.watch(salesProvider)) {
    byHour[s.dateHeure.hour] = (byHour[s.dateHeure.hour] ?? 0) + s.total;
  }
  final list = byHour.entries.map((e) => (e.key, e.value)).toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return list;
});

/// Catalogue products that have never appeared in a single sale line.
final neverSoldProductsProvider = Provider<List<Product>>((ref) {
  final soldIds = <String>{};
  for (final s in ref.watch(salesProvider)) {
    for (final l in s.lignes) {
      soldIds.add(l.product.id);
    }
  }
  return ref
      .watch(productsProvider)
      .where((p) => !soldIds.contains(p.id))
      .toList();
});

class ProfitStat {
  final Product product;
  final double profit;
  final double revenue;
  const ProfitStat({
    required this.product,
    required this.profit,
    required this.revenue,
  });
}

/// Products ranked by total margin actually earned — different from "Top
/// produits" on the dashboard, which ranks by revenue: a high-revenue,
/// thin-margin product can rank far below a cheaper, high-margin one here.
final mostProfitableProductsProvider = Provider<List<ProfitStat>>((ref) {
  final byProduct = <String, ProfitStat>{};
  for (final s in ref.watch(salesProvider)) {
    for (final l in s.lignes) {
      final existing = byProduct[l.product.id];
      byProduct[l.product.id] = ProfitStat(
        product: l.product,
        profit: (existing?.profit ?? 0) + l.product.marge * l.quantite,
        revenue: (existing?.revenue ?? 0) + l.sousTotal,
      );
    }
  }
  final list = byProduct.values.toList()
    ..sort((a, b) => b.profit.compareTo(a.profit));
  return list;
});

class ClientStat {
  final Client client;
  final double total;
  final int tickets;
  const ClientStat({
    required this.client,
    required this.total,
    required this.tickets,
  });
}

/// Clients ranked by total purchase volume (crédit + comptant combined).
final topClientsProvider = Provider<List<ClientStat>>((ref) {
  final clients = {for (final c in ref.watch(clientsProvider)) c.id: c};
  final byClient = <String, ClientStat>{};
  for (final s in ref.watch(salesProvider)) {
    final id = s.clientId;
    if (id == null) continue;
    final client = clients[id];
    if (client == null) continue;
    final existing = byClient[id];
    byClient[id] = ClientStat(
      client: client,
      total: (existing?.total ?? 0) + s.total,
      tickets: (existing?.tickets ?? 0) + 1,
    );
  }
  final list = byClient.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
});

class SupplierUsageStat {
  final String nom;
  final double total;
  final int factures;
  const SupplierUsageStat({
    required this.nom,
    required this.total,
    required this.factures,
  });
}

/// Suppliers ranked by total invoiced amount — "les plus utilisés".
final topSuppliersProvider = Provider<List<SupplierUsageStat>>((ref) {
  final byName = <String, SupplierUsageStat>{};
  for (final i in ref.watch(purchaseInvoicesProvider)) {
    final nom = i.fournisseurNom ?? 'Fournisseur non précisé';
    final existing = byName[nom];
    byName[nom] = SupplierUsageStat(
      nom: nom,
      total: (existing?.total ?? 0) + i.montantTotal,
      factures: (existing?.factures ?? 0) + 1,
    );
  }
  final list = byName.values.toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
});

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

/// Last 6 months of net profit — "évolution du bénéfice".
final profitEvolutionProvider =
    Provider<({List<double> values, List<String> labels})>((ref) {
      final sales = ref.watch(salesProvider);
      final now = DateTime.now();
      final values = <double>[];
      final labels = <String>[];
      for (var i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final profit = sales
            .where(
              (s) =>
                  s.dateHeure.year == month.year &&
                  s.dateHeure.month == month.month,
            )
            .fold<double>(
              0,
              (sum, s) =>
                  sum +
                  s.lignes.fold<double>(
                    0,
                    (lsum, l) => lsum + l.product.marge * l.quantite,
                  ),
            );
        values.add(profit);
        labels.add(_monthLabels[month.month - 1]);
      }
      return (values: values, labels: labels);
    });

/// Last 6 months of expenses — "évolution des dépenses".
final expensesEvolutionProvider =
    Provider<({List<double> values, List<String> labels})>((ref) {
      final expenses = ref.watch(expensesProvider);
      final now = DateTime.now();
      final values = <double>[];
      final labels = <String>[];
      for (var i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final total = expenses
            .where(
              (e) => e.date.year == month.year && e.date.month == month.month,
            )
            .fold<double>(0, (sum, e) => sum + e.montant);
        values.add(total);
        labels.add(_monthLabels[month.month - 1]);
      }
      return (values: values, labels: labels);
    });

/// Current stock valued at cost (Σ stock × prix d'achat) — a snapshot, not
/// a real time series (the app doesn't keep historical stock levels, so a
/// fabricated "évolution du stock" chart would be dishonest).
final currentStockValueProvider = Provider<double>((ref) {
  return ref
      .watch(productsProvider)
      .fold<double>(0, (sum, p) => sum + p.stock * p.prixAchat);
});

class StockoutForecast {
  final Product product;
  final double dailyVelocity;
  final int daysLeft;
  const StockoutForecast({
    required this.product,
    required this.dailyVelocity,
    required this.daysLeft,
  });
}

const _stockoutVelocityWindowDays = 14;
const _stockoutForecastCapDays = 14;

/// For each product with recent sales, estimates days-until-stockout from
/// its average daily consumption over the last [_stockoutVelocityWindowDays]
/// days — capped to products running out within [_stockoutForecastCapDays],
/// soonest first.
final stockoutForecastProvider = Provider<List<StockoutForecast>>((ref) {
  final cutoff = DateTime.now().subtract(
    const Duration(days: _stockoutVelocityWindowDays),
  );
  final soldSince = <String, double>{};
  for (final s in ref.watch(salesProvider)) {
    if (s.dateHeure.isBefore(cutoff)) continue;
    for (final l in s.lignes) {
      soldSince[l.product.id] = (soldSince[l.product.id] ?? 0) + l.quantite;
    }
  }
  final forecasts = <StockoutForecast>[];
  for (final p in ref.watch(productsProvider)) {
    final soldQty = soldSince[p.id];
    if (soldQty == null || soldQty <= 0 || p.stock <= 0) continue;
    final velocity = soldQty / _stockoutVelocityWindowDays;
    final daysLeft = (p.stock / velocity).floor();
    if (daysLeft <= _stockoutForecastCapDays) {
      forecasts.add(
        StockoutForecast(
          product: p,
          dailyVelocity: velocity,
          daysLeft: daysLeft,
        ),
      );
    }
  }
  forecasts.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return forecasts;
});
