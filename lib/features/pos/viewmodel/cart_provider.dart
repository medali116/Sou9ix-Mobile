import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/pos/model/cart_item.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_removal_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref _ref;
  CartNotifier(this._ref) : super(const []);

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
      state = [
        ...state,
        CartItem(product: product, quantite: poidsKg, poidsUnitaire: poidsKg),
      ];
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

  /// Adds one more [CartItem.poidsUnitaire] to a weighed line — the +/-
  /// stepper's "+", e.g. 2kg entered once becomes 4kg.
  void incrementWeightUnit(String productId) {
    final index = state.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;
    final item = state[index];
    final unit = item.poidsUnitaire;
    if (unit == null || unit <= 0) return;
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index)
          item.copyWith(quantite: item.quantite + unit)
        else
          state[i],
    ];
  }

  /// Removes one [CartItem.poidsUnitaire] from a weighed line — the +/-
  /// stepper's "-". Drops the line entirely once it would go to zero or
  /// below, mirroring [updateQuantite]'s behavior.
  void decrementWeightUnit(String productId) {
    final index = state.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;
    final item = state[index];
    final unit = item.poidsUnitaire;
    if (unit == null || unit <= 0) return;
    final newQuantite = item.quantite - unit;
    if (newQuantite <= 0) {
      removeItem(productId);
      return;
    }
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) item.copyWith(quantite: newQuantite) else state[i],
    ];
  }

  void updateQuantite(String productId, double quantite) {
    if (quantite <= 0) {
      removeItem(productId);
      return;
    }
    state = [
      for (final i in state)
        if (i.product.id == productId)
          // A manual re-entry (weight sheet or typed value) redefines the
          // "unit" the stepper steps by from here on.
          i.copyWith(
            quantite: quantite,
            poidsUnitaire: i.product.venduAuPoids ? quantite : null,
          )
        else
          i,
    ];
  }

  void removeItem(String productId) {
    state = state.where((i) => i.product.id != productId).toList();
    final employeeId = _ref.read(activeEmployeeProvider);
    if (employeeId != null) {
      _ref.read(cartRemovalProvider.notifier).increment(employeeId);
    }
  }

  void setDiscount(String productId, Discount discount) {
    state = [
      for (final i in state)
        if (i.product.id == productId) i.copyWith(discount: discount) else i,
    ];
  }

  void clear() => state = const [];

  double get total => state.fold(0, (sum, i) => sum + i.sousTotal);
  int get itemCount => state.length;
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (ref) => CartNotifier(ref),
);

/// Extra discount the cashier grants on the whole ticket, on top of any
/// per-line discounts — reset once the sale is confirmed or the cart is
/// cleared.
final cartDiscountProvider = StateProvider<Discount>(
  (ref) => const Discount.none(),
);

final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold(0, (sum, i) => sum + i.sousTotal);
});

final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  return discount.applyTo(subtotal);
});
