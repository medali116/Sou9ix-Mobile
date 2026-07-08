import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/category.dart';
import '../models/product.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier() : super(buildMockProducts());

  void decrementStock(String productId, double quantite) {
    state = [
      for (final p in state)
        if (p.id == productId) p.copyWith(stock: p.stock - quantite) else p,
    ];
  }

  /// Adds freshly received quantity to a product's stock, e.g. after a
  /// supplier delivery — optionally updating the purchase price if it
  /// changed since the last restock.
  void restock(String productId, double quantiteRecue, {double? nouveauPrixAchat}) {
    state = [
      for (final p in state)
        if (p.id == productId)
          p.copyWith(
            stock: p.stock + quantiteRecue,
            prixAchat: nouveauPrixAchat ?? p.prixAchat,
          )
        else
          p,
    ];
  }

  /// Applies an arbitrary signed adjustment to a product's stock — used to
  /// reconcile stock when a past sale is edited or deleted (unlike
  /// [decrementStock]/[restock], which only move in one direction).
  void adjustStock(String productId, double delta) {
    state = [
      for (final p in state)
        if (p.id == productId) p.copyWith(stock: p.stock + delta) else p,
    ];
  }

  void upsert(Product product) {
    final exists = state.any((p) => p.id == product.id);
    if (exists) {
      state = [for (final p in state) if (p.id == product.id) product else p];
    } else {
      state = [...state, product];
    }
  }

  void remove(String productId) {
    state = state.where((p) => p.id != productId).toList();
  }
}

final productsProvider =
    StateNotifierProvider<ProductsNotifier, List<Product>>(
  (ref) => ProductsNotifier(),
);

final categoriesProvider = Provider<List<ProductCategory>>((ref) => mockCategories);

final lowStockProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider);
  return products.where((p) => p.stockFaible).toList();
});
