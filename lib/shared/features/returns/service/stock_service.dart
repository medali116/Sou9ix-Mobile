import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/returns/model/stock_return.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/returns/viewmodel/stock_returns_provider.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/stock_movements_provider.dart';

/// Encapsulates recording a stock write-off (expired, damaged, stolen…):
/// decrementing the live stock and logging the loss in the same step, so
/// the two can never drift apart.
class StockService {
  StockService(this._ref);

  final Ref _ref;

  void recordReturn({
    required Product product,
    required double quantite,
    required RetourMotif motif,
    String? note,
  }) {
    _ref.read(productsProvider.notifier).decrementStock(product.id, quantite);
    _ref
        .read(stockReturnsProvider.notifier)
        .add(
          StockReturn(
            id: 'ret${DateTime.now().microsecondsSinceEpoch}',
            date: DateTime.now(),
            productId: product.id,
            productName: product.name,
            quantite: quantite,
            venduAuPoids: product.venduAuPoids,
            prixAchatUnitaire: product.prixAchat,
            motif: motif,
            note: note,
          ),
        );

    final stockApres = _ref
        .read(productsProvider)
        .firstWhere((p) => p.id == product.id)
        .stock;
    recordStockMovement(
      _ref,
      productId: product.id,
      productName: product.name,
      type: StockMovementType.ajustement,
      quantite: -quantite,
      stockApres: stockApres,
      reference: 'Perte',
      motif: note != null ? '${motif.label} · $note' : motif.label,
    );
    logActivity(
      _ref,
      category: ActivityCategory.stock,
      impact: ActivityImpact.suppression,
      action: 'Perte enregistrée',
      targetName: product.name,
      motif: note != null ? '${motif.label} · $note' : motif.label,
      montant: quantite * product.prixAchat,
    );
  }
}

final stockServiceProvider = Provider<StockService>((ref) => StockService(ref));
