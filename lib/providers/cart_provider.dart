import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(const []);

  void addPiece(Product product) {
    final index = state.indexWhere((i) => i.product.id == product.id);
    if (index == -1) {
      state = [...state, CartItem(product: product, quantite: 1)];
    } else {
      final item = state[index];
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == index)
            item.copyWith(quantite: item.quantite + 1)
          else
            state[i],
      ];
    }
  }

  void addWeighted(Product product, double poidsKg) {
    final index = state.indexWhere((i) => i.product.id == product.id);
    if (index == -1) {
      state = [...state, CartItem(product: product, quantite: poidsKg)];
    } else {
      final item = state[index];
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == index)
            item.copyWith(quantite: item.quantite + poidsKg)
          else
            state[i],
      ];
    }
  }

  void updateQuantite(String productId, double quantite) {
    if (quantite <= 0) {
      removeItem(productId);
      return;
    }
    state = [
      for (final i in state)
        if (i.product.id == productId) i.copyWith(quantite: quantite) else i,
    ];
  }

  void removeItem(String productId) {
    state = state.where((i) => i.product.id != productId).toList();
  }

  void clear() => state = const [];

  double get total => state.fold(0, (sum, i) => sum + i.sousTotal);
  int get itemCount => state.length;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(),
);

final cartTotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, i) => sum + i.sousTotal);
});
