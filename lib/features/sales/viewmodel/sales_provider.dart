import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/pos/model/cart_item.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/service/sales_repository.dart';

class SalesNotifier extends StateNotifier<List<Sale>> {
  SalesNotifier({required String? shopCode, SalesRepository? repository})
    : _repo = shopCode == null ? null : (repository ?? SalesRepository(shopCode: shopCode)),
      super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((sales) => state = sales);
    }
  }

  final SalesRepository? _repo;
  StreamSubscription<List<Sale>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Sale recordSale({
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    String? employeeId,
    Discount discount = const Discount.none(),
  }) {
    final sale = Sale(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      dateHeure: DateTime.now(),
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: clientId,
      employeeId: employeeId,
      discount: discount,
    );
    state = [sale, ...state];
    _repo?.upsert(sale);
    return sale;
  }

  Sale updateSale(Sale updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
    _repo?.upsert(updated);
    return updated;
  }

  void removeSale(String id) {
    state = state.where((s) => s.id != id).toList();
    _repo?.remove(id);
  }

  /// Brings a sale back from the Corbeille, preserving its original id
  /// (unlike [recordSale], which always mints a new one).
  void restore(Sale sale) {
    state = [sale, ...state];
    _repo?.upsert(sale);
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, List<Sale>>(
  (ref) => SalesNotifier(shopCode: ref.watch(currentShopCodeProvider)),
);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final todayRevenueProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  final now = DateTime.now();
  return sales
      .where((s) => _isSameDay(s.dateHeure, now))
      .fold(0.0, (sum, s) => sum + s.total);
});

final employeeSalesProvider = Provider.family<List<Sale>, String>((
  ref,
  employeeId,
) {
  return ref
      .watch(salesProvider)
      .where((s) => s.employeeId == employeeId)
      .toList();
});
