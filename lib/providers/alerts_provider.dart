import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import 'products_provider.dart';
import 'purchase_invoices_provider.dart';
import 'settings_provider.dart';

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

/// Aggregate count surfaced on the notification bell badge and the
/// dashboard's "Alertes" card — sum of every alert category shown on the
/// Alertes screen.
final totalAlertsCountProvider = Provider<int>((ref) {
  return ref.watch(lowStockProvider).length +
      ref.watch(expiringSoonProvider).length +
      ref.watch(expiredProductsProvider).length +
      ref.watch(unsettledInvoicesProvider).length;
});
