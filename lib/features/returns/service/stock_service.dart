import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/returns/model/stock_return.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/returns/viewmodel/stock_returns_provider.dart';
import 'package:sou9ix/features/stock/model/stock_movement.dart';
import 'package:sou9ix/features/stock/viewmodel/stock_movements_provider.dart';

/// Encapsulates recording a stock write-off (expired, damaged, stolen,
/// returned to a supplier…): decrementing the live stock and logging the
/// loss in the same step, so the two can never drift apart. Both writes are
/// awaited and their errors propagated — a caller that doesn't await this
/// (or ignores a thrown error) risks the stock/loss ledgers going out of
/// sync, so every UI entry point must await and surface failures.
class StockService {
  StockService(this._ref);

  final Ref _ref;

  Future<void> recordReturn({
    required Product product,
    required double quantite,
    required RetourMotif motif,
    String? note,
    Uint8List? photoBytes,
  }) async {
    await _ref
        .read(productsProvider.notifier)
        .decrementStock(product.id, quantite);
    await _ref
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
            prixVenteUnitaire: product.prixVente,
            motif: motif,
            note: note,
            employeeName: _ref.read(authProvider)?.nom ?? 'Inconnu',
            photoBytes: photoBytes,
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

  /// Undoes a logged loss: puts the quantity back into stock (so deleting a
  /// mistaken entry doesn't leave the catalogue permanently short) and
  /// removes the ledger row. Silently skips the stock restore if the
  /// product itself was since deleted from the catalogue — the loss row
  /// still gets removed either way.
  Future<void> deleteReturn(StockReturn stockReturn) async {
    final stillExists = _ref
        .read(productsProvider)
        .any((p) => p.id == stockReturn.productId);
    if (stillExists) {
      await _ref
          .read(productsProvider.notifier)
          .restock(stockReturn.productId, stockReturn.quantite);
    }
    await _ref.read(stockReturnsProvider.notifier).remove(stockReturn.id);
    logActivity(
      _ref,
      category: ActivityCategory.stock,
      impact: ActivityImpact.suppression,
      action: 'Perte supprimée',
      targetName: stockReturn.productName,
      motif: stillExists
          ? 'Stock restauré (+${stockReturn.quantite.toStringAsFixed(stockReturn.venduAuPoids ? 3 : 0)} ${stockReturn.unite})'
          : null,
      montant: stockReturn.perte,
    );
  }
}

final stockServiceProvider = Provider<StockService>((ref) => StockService(ref));
