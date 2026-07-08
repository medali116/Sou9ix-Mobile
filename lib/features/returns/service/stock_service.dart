import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/returns/model/stock_return.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/returns/viewmodel/stock_returns_provider.dart';

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
    _ref.read(stockReturnsProvider.notifier).add(StockReturn(
          id: 'ret${DateTime.now().microsecondsSinceEpoch}',
          date: DateTime.now(),
          productId: product.id,
          productName: product.name,
          quantite: quantite,
          venduAuPoids: product.venduAuPoids,
          prixAchatUnitaire: product.prixAchat,
          motif: motif,
          note: note,
        ));
  }
}

final stockServiceProvider = Provider<StockService>((ref) => StockService(ref));
