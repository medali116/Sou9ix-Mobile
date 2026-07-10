import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/features/alerts/viewmodel/settings_provider.dart';

/// Products whose expiry date falls within the configured warning window
/// (but hasn't passed yet — already-expired products are [expiredProductsProvider]).
final expiringSoonProvider = Provider<List<Product>>((ref) {
  final days = ref.watch(expiryWarningDaysProvider);
  final now = DateTime.now();
  final cutoff = now.add(Duration(days: days));
  return ref.watch(productsProvider).where((p) {
    final d = p.datePeremption;
    return d != null && d.isAfter(now) && d.isBefore(cutoff);
  }).toList();
});

final expiredProductsProvider = Provider<List<Product>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(productsProvider)
      .where((p) => p.datePeremption != null && p.datePeremption!.isBefore(now))
      .toList();
});

/// Clients whose karné balance has reached or passed their credit limit.
final clientsOverLimitProvider = Provider<List<Client>>((ref) {
  return ref
      .watch(clientsProvider)
      .where((c) => c.limiteCredit != null && c.creditTotal >= c.limiteCredit!)
      .toList();
});

/// Supplier invoices still open 45+ days after they were recorded.
const oldUnpaidInvoiceThresholdDays = 45;

final oldUnpaidInvoicesProvider = Provider<List<PurchaseInvoice>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(unsettledInvoicesProvider)
      .where(
        (i) => now.difference(i.date).inDays >= oldUnpaidInvoiceThresholdDays,
      )
      .toList();
});

/// Products currently priced to sell at (or below) their own cost — a
/// configuration mistake, not a one-off sale, so it's worth flagging every
/// time the catalogue is checked rather than only at sale time.
final lossProductsProvider = Provider<List<Product>>((ref) {
  return ref
      .watch(productsProvider)
      .where((p) => p.prixVente <= p.prixAchat)
      .toList();
});

/// Products that haven't sold at all in the configured window — dead stock
/// tying up shelf space and cash.
const staleProductThresholdDays = 30;

final staleProductsProvider = Provider<List<Product>>((ref) {
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: staleProductThresholdDays));
  final lastSaleByProduct = <String, DateTime>{};
  for (final s in ref.watch(salesProvider)) {
    for (final l in s.lignes) {
      final current = lastSaleByProduct[l.product.id];
      if (current == null || s.dateHeure.isAfter(current)) {
        lastSaleByProduct[l.product.id] = s.dateHeure;
      }
    }
  }
  return ref.watch(productsProvider).where((p) {
    final lastSale = lastSaleByProduct[p.id];
    return lastSale == null || lastSale.isBefore(cutoff);
  }).toList();
});

/// Prices touched today — lets an admin sanity-check same-day repricing at
/// a glance instead of digging through the full journal.
final todayPriceChangesProvider = Provider<List<ActivityLogEntry>>((ref) {
  final now = DateTime.now();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  return ref
      .watch(activityLogProvider)
      .where((e) => e.category == ActivityCategory.prix && sameDay(e.date, now))
      .toList();
});

/// Unusually many tickets cancelled recently — worth a look even before
/// checking who did it.
const frequentDeletionThreshold = 3;
const frequentDeletionWindowDays = 7;

final recentTicketDeletionsProvider = Provider<List<ActivityLogEntry>>((ref) {
  final cutoff = DateTime.now().subtract(
    const Duration(days: frequentDeletionWindowDays),
  );
  return ref
      .watch(activityLogProvider)
      .where(
        (e) =>
            e.category == ActivityCategory.tickets &&
            e.impact == ActivityImpact.suppression &&
            e.date.isAfter(cutoff),
      )
      .toList();
});

final hasFrequentTicketDeletionsProvider = Provider<bool>((ref) {
  return ref.watch(recentTicketDeletionsProvider).length >=
      frequentDeletionThreshold;
});

/// Aggregate count surfaced on the notification bell badge and the
/// dashboard's "Alertes" card — sum of every alert category shown on the
/// Alertes screen. [oldUnpaidInvoicesProvider] is a subset of
/// [unsettledInvoicesProvider] (an urgency flag on invoices already
/// counted there), so it isn't added again here.
final totalAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(lowStockProvider).length +
      ref.watch(expiringSoonProvider).length +
      ref.watch(expiredProductsProvider).length +
      ref.watch(unsettledInvoicesProvider).length +
      ref.watch(clientsOverLimitProvider).length +
      ref.watch(lossProductsProvider).length +
      ref.watch(staleProductsProvider).length +
      ref.watch(todayPriceChangesProvider).length +
      (ref.watch(hasFrequentTicketDeletionsProvider) ? 1 : 0);
});
