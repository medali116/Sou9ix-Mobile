import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/products/model/category.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/products/service/categories_repository.dart';
import 'package:sou9ix/features/products/service/products_repository.dart';

class ProductsNotifier extends StateNotifier<List<Product>> {
  /// [shopCode] is null when nobody's logged in yet — there's no shop to
  /// subscribe to, so the catalog just stays empty until a session with a
  /// shop code exists.
  ProductsNotifier(
    this._ref, {
    required String? shopCode,
    ProductsRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? ProductsRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((products) => state = products);
    }
  }

  final Ref _ref;
  final ProductsRepository? _repo;
  StreamSubscription<List<Product>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> decrementStock(String productId, double quantite) async {
    final matches = state.where((p) => p.id == productId);
    if (matches.isEmpty) return;
    await _repo?.upsert(
      matches.first.copyWith(stock: matches.first.stock - quantite),
    );
  }

  /// Adds freshly received quantity to a product's stock, e.g. after a
  /// supplier delivery — optionally updating the purchase price if it
  /// changed since the last restock.
  Future<void> restock(
    String productId,
    double quantiteRecue, {
    double? nouveauPrixAchat,
  }) async {
    final matches = state.where((p) => p.id == productId);
    if (matches.isEmpty) return;
    final p = matches.first;
    await _repo?.upsert(
      p.copyWith(
        stock: p.stock + quantiteRecue,
        prixAchat: nouveauPrixAchat ?? p.prixAchat,
      ),
    );
  }

  /// Applies an arbitrary signed adjustment to a product's stock — used to
  /// reconcile stock when a past sale is edited or deleted (unlike
  /// [decrementStock]/[restock], which only move in one direction).
  void adjustStock(String productId, double delta) {
    final matches = state.where((p) => p.id == productId);
    if (matches.isEmpty) return;
    final p = matches.first;
    _repo?.upsert(p.copyWith(stock: p.stock + delta));
  }

  /// Edits go through here whether they come from the product form (price)
  /// or the stock screen's "Ajuster" sheet (stock) — comparing against the
  /// previous value here, once, means every edit path gets logged the same
  /// way without each screen having to remember to do it.
  Future<void> upsert(
    Product product, {
    String? motifStock,
    String? motifPrix,
  }) async {
    final exists = state.any((p) => p.id == product.id);
    if (exists) {
      final old = state.firstWhere((p) => p.id == product.id);
      if (old.name != product.name) {
        logActivity(
          _ref,
          category: ActivityCategory.produits,
          impact: ActivityImpact.modification,
          action: 'Produit modifié',
          targetName: product.name,
          champ: 'Nom',
          ancienneValeur: old.name,
          nouvelleValeur: product.name,
        );
      }
      if (old.prixVente != product.prixVente) {
        logActivity(
          _ref,
          category: ActivityCategory.prix,
          impact: ActivityImpact.modification,
          action: 'Prix modifié',
          targetName: product.name,
          champ: 'Prix de vente',
          ancienneValeur: AppFormat.dt(old.prixVente),
          nouvelleValeur: AppFormat.dt(product.prixVente),
          difference: product.prixVente - old.prixVente,
          motif: motifPrix,
        );
      }
      if (old.prixAchat != product.prixAchat) {
        logActivity(
          _ref,
          category: ActivityCategory.prix,
          impact: ActivityImpact.modification,
          action: 'Prix modifié',
          targetName: product.name,
          champ: 'Prix d\'achat',
          ancienneValeur: AppFormat.dt(old.prixAchat),
          nouvelleValeur: AppFormat.dt(product.prixAchat),
          difference: product.prixAchat - old.prixAchat,
          motif: motifPrix,
        );
      }
      if (old.stock != product.stock) {
        logActivity(
          _ref,
          category: ActivityCategory.stock,
          impact: ActivityImpact.modification,
          action: 'Stock ajusté',
          targetName: product.name,
          champ: 'Stock',
          ancienneValeur:
              '${old.stock.toStringAsFixed(old.venduAuPoids ? 3 : 0)} ${old.unite}',
          nouvelleValeur:
              '${product.stock.toStringAsFixed(product.venduAuPoids ? 3 : 0)} ${product.unite}',
          difference: product.stock - old.stock,
          motif: motifStock,
        );
      }
    }
    await _repo?.upsert(product);
  }

  Future<void> remove(String productId, {required String motif}) async {
    final matches = state.where((p) => p.id == productId);
    final product = matches.isEmpty ? null : matches.first;
    if (product == null) return;
    await _repo?.remove(productId);
    _ref.read(productsTrashProvider.notifier).add(product);
    logActivity(
      _ref,
      category: ActivityCategory.produits,
      impact: ActivityImpact.suppression,
      action: 'Produit supprimé',
      targetName: product.name,
      motif: motif,
    );
  }
}

final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
  (ref) => ProductsNotifier(ref, shopCode: ref.watch(currentShopCodeProvider)),
);

class CategoriesNotifier extends StateNotifier<List<ProductCategory>> {
  CategoriesNotifier({
    required String? shopCode,
    CategoriesRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? CategoriesRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen(
        (categories) => state = categories,
      );
    }
  }

  final CategoriesRepository? _repo;
  StreamSubscription<List<ProductCategory>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Adds a category created on the fly from the product form — a no-op
  /// if one with the same id already exists.
  Future<void> add(ProductCategory category) async {
    if (state.any((c) => c.id == category.id)) return;
    await _repo?.add(category);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<ProductCategory>>(
      (ref) => CategoriesNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );

final lowStockProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider);
  return products.where((p) => p.stockFaible).toList();
});
