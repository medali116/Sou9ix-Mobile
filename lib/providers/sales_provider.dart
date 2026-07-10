import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/sale.dart';

class SalesNotifier extends StateNotifier<List<Sale>> {
  SalesNotifier() : super(_seed());

  static List<Sale> _seed() {
    final now = DateTime.now();
    return [
      Sale(
        id: 's1',
        dateHeure: now.subtract(const Duration(hours: 2)),
        lignes: const [],
        modePaiement: ModePaiement.especes,
      ),
    ];
  }

  Sale recordSale({
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    String? employeeId,
  }) {
    final sale = Sale(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      dateHeure: DateTime.now(),
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: clientId,
      employeeId: employeeId,
    );
    state = [sale, ...state];
    return sale;
  }

  Sale updateSale(Sale updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
    return updated;
  }

  void removeSale(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, List<Sale>>(
  (ref) => SalesNotifier(),
);

final todayRevenueProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  final now = DateTime.now();
  return sales
      .where(
        (s) =>
            s.dateHeure.year == now.year &&
            s.dateHeure.month == now.month &&
            s.dateHeure.day == now.day,
      )
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
