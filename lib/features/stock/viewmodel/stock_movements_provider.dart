import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/stock/model/stock_movement.dart';

class StockMovementsNotifier extends StateNotifier<List<StockMovement>> {
  StockMovementsNotifier() : super(const []);

  void record(StockMovement movement) => state = [movement, ...state];
}

final stockMovementsProvider =
    StateNotifierProvider<StockMovementsNotifier, List<StockMovement>>(
      (ref) => StockMovementsNotifier(),
    );

/// Single entry point every stock-mutating flow records through (sale
/// checkout/deletion, invoice receipt, manual adjustment) — mirrors
/// [logActivity]'s role for the general audit log, but keeps a numeric,
/// per-product trail a product's real quantity history can be
/// reconstructed from.
void recordStockMovement(
  Ref ref, {
  required String productId,
  required String productName,
  required StockMovementType type,
  required double quantite,
  required double stockApres,
  String? reference,
  String? motif,
}) {
  ref
      .read(stockMovementsProvider.notifier)
      .record(
        StockMovement(
          id: '${DateTime.now().microsecondsSinceEpoch}$productId',
          date: DateTime.now(),
          productId: productId,
          productName: productName,
          type: type,
          quantite: quantite,
          stockApres: stockApres,
          reference: reference,
          motif: motif,
          employeeName: ref.read(authProvider)?.nom ?? 'Inconnu',
        ),
      );
}

/// A single product's movements, newest first.
final productMovementsProvider = Provider.family<List<StockMovement>, String>(
  (ref, productId) => ref
      .watch(stockMovementsProvider)
      .where((m) => m.productId == productId)
      .toList(),
);
