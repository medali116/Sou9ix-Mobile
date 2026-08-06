import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/service/stock_movements_repository.dart';

final stockMovementsRepositoryProvider = Provider<StockMovementsRepository?>((
  ref,
) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return StockMovementsRepository(FirebaseFirestore.instance, shopCode);
});

class StockMovementsNotifier extends StateNotifier<List<StockMovement>> {
  StockMovementsNotifier(this._repo) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final StockMovementsRepository? _repo;
  StreamSubscription<List<StockMovement>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void record(StockMovement movement) {
    recordLocal(movement);
    unawaited(_repo?.record(movement));
  }

  /// Same optimistic local mutation as [record], without the persist call
  /// — used by [SaleService.checkout], which writes every line's movement
  /// as part of one combined [SalesRepository.recordSaleBatch] write.
  void recordLocal(StockMovement movement) => state = [movement, ...state];
}

final stockMovementsProvider =
    StateNotifierProvider<StockMovementsNotifier, List<StockMovement>>(
      (ref) =>
          StockMovementsNotifier(ref.watch(stockMovementsRepositoryProvider)),
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
        buildStockMovement(
          ref,
          productId: productId,
          productName: productName,
          type: type,
          quantite: quantite,
          stockApres: stockApres,
          reference: reference,
          motif: motif,
        ),
      );
}

/// Builds a [StockMovement] without recording it — used by
/// [SaleService.checkout] to fold the movement into a batch write instead
/// of persisting it on its own via [recordStockMovement].
StockMovement buildStockMovement(
  Ref ref, {
  required String productId,
  required String productName,
  required StockMovementType type,
  required double quantite,
  required double stockApres,
  String? reference,
  String? motif,
}) => StockMovement(
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
);

/// A single product's movements, newest first.
final productMovementsProvider = Provider.family<List<StockMovement>, String>(
  (ref, productId) => ref
      .watch(stockMovementsProvider)
      .where((m) => m.productId == productId)
      .toList(),
);
