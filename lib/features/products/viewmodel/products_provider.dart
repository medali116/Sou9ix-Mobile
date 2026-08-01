import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/features/products/model/category.dart';
import 'package:sou9ix/features/products/model/product.dart';

final List<ProductCategory> mockCategories = [
  const ProductCategory(
    id: 'fruits_secs',
    name: 'Fruits secs',
    icon: Icons.eco_rounded,
  ),
  const ProductCategory(
    id: 'epices',
    name: 'Épices',
    icon: Icons.local_fire_department_rounded,
  ),
  const ProductCategory(
    id: 'cafe',
    name: 'Torréfaction',
    icon: Icons.coffee_rounded,
  ),
  const ProductCategory(
    id: 'epicerie',
    name: 'Épicerie',
    icon: Icons.kitchen_rounded,
  ),
  const ProductCategory(
    id: 'boissons',
    name: 'Boissons',
    icon: Icons.local_drink_rounded,
  ),
];

List<Product> _buildMockProducts() => [
  Product(
    id: 'p1',
    name: 'Cacahuètes grillées',
    emoji: '🥜',
    prixVente: 8.000,
    prixAchat: 5.200,
    codeBarres: '6191234500017',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 12.5,
    seuilAlerte: 3,
  ),
  Product(
    id: 'p2',
    name: 'Amandes décortiquées',
    emoji: '🌰',
    prixVente: 22.000,
    prixAchat: 16.500,
    codeBarres: '6191234500024',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 2.0,
    seuilAlerte: 3,
  ),
  Product(
    id: 'p3',
    name: 'Pistaches grillées',
    emoji: '🥨',
    prixVente: 34.000,
    prixAchat: 27.000,
    codeBarres: '6191234500031',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 8.0,
    seuilAlerte: 2,
  ),
  Product(
    id: 'p4',
    name: 'Noix de cajou',
    emoji: '🌰',
    prixVente: 29.500,
    prixAchat: 22.000,
    codeBarres: '6191234500048',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 5.4,
    seuilAlerte: 2,
  ),
  Product(
    id: 'p5',
    name: 'Graines de tournesol',
    emoji: '🌻',
    prixVente: 6.000,
    prixAchat: 3.800,
    codeBarres: '6191234500055',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 1.2,
    seuilAlerte: 2,
  ),
  Product(
    id: 'p6',
    name: 'Café torréfié Arabica',
    emoji: '☕',
    prixVente: 18.000,
    prixAchat: 12.500,
    codeBarres: '6191234500062',
    venduAuPoids: true,
    categorieId: 'cafe',
    stock: 9.0,
    seuilAlerte: 2,
  ),
  Product(
    id: 'p7',
    name: 'Café moulu Robusta',
    emoji: '☕',
    prixVente: 14.500,
    prixAchat: 9.800,
    codeBarres: '6191234500079',
    venduAuPoids: true,
    categorieId: 'cafe',
    stock: 0.8,
    seuilAlerte: 2,
  ),
  Product(
    id: 'p8',
    name: 'Ras el-hanout',
    emoji: '🌶️',
    prixVente: 25.000,
    prixAchat: 17.000,
    codeBarres: '6191234500086',
    venduAuPoids: true,
    categorieId: 'epices',
    stock: 3.5,
    seuilAlerte: 1,
  ),
  Product(
    id: 'p9',
    name: 'Curcuma moulu',
    emoji: '🟡',
    prixVente: 16.000,
    prixAchat: 10.500,
    codeBarres: '6191234500093',
    venduAuPoids: true,
    categorieId: 'epices',
    stock: 4.2,
    seuilAlerte: 1,
  ),
  Product(
    id: 'p10',
    name: 'Huile d\'olive 1L',
    emoji: '🫒',
    prixVente: 19.900,
    prixAchat: 15.200,
    codeBarres: '6191234500109',
    venduAuPoids: false,
    categorieId: 'epicerie',
    stock: 24,
    seuilAlerte: 6,
  ),
  Product(
    id: 'p11',
    name: 'Pâtes 500g',
    emoji: '🍝',
    prixVente: 2.200,
    prixAchat: 1.500,
    codeBarres: '6191234500116',
    venduAuPoids: false,
    categorieId: 'epicerie',
    stock: 60,
    seuilAlerte: 10,
  ),
  Product(
    id: 'p12',
    name: 'Eau minérale 1.5L',
    emoji: '💧',
    prixVente: 1.100,
    prixAchat: 0.650,
    codeBarres: '6191234500123',
    venduAuPoids: false,
    categorieId: 'boissons',
    stock: 4,
    seuilAlerte: 12,
  ),
  Product(
    id: 'p13',
    name: 'Jus d\'orange 1L',
    emoji: '🧃',
    prixVente: 3.800,
    prixAchat: 2.600,
    codeBarres: '6191234500130',
    venduAuPoids: false,
    categorieId: 'boissons',
    stock: 18,
    seuilAlerte: 5,
  ),
  Product(
    id: 'p14',
    name: 'Dattes Deglet Nour',
    emoji: '🍈',
    prixVente: 12.000,
    prixAchat: 8.400,
    codeBarres: '6191234500147',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 15.0,
    seuilAlerte: 3,
  ),
  Product(
    id: 'p15',
    name: 'Figues séchées',
    emoji: '🫐',
    prixVente: 17.500,
    prixAchat: 12.000,
    codeBarres: '6191234500154',
    venduAuPoids: true,
    categorieId: 'fruits_secs',
    stock: 6.6,
    seuilAlerte: 2,
  ),
];

class ProductsNotifier extends StateNotifier<List<Product>> {
  ProductsNotifier(this._ref) : super(_buildMockProducts());

  final Ref _ref;

  void decrementStock(String productId, double quantite) {
    state = [
      for (final p in state)
        if (p.id == productId) p.copyWith(stock: p.stock - quantite) else p,
    ];
  }

  /// Adds freshly received quantity to a product's stock, e.g. after a
  /// supplier delivery — optionally updating the purchase price if it
  /// changed since the last restock.
  void restock(
    String productId,
    double quantiteRecue, {
    double? nouveauPrixAchat,
  }) {
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

  /// Edits go through here whether they come from the product form (price)
  /// or the stock screen's "Ajuster" sheet (stock) — comparing against the
  /// previous value here, once, means every edit path gets logged the same
  /// way without each screen having to remember to do it.
  void upsert(Product product, {String? motifStock, String? motifPrix}) {
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
      state = [
        for (final p in state)
          if (p.id == product.id) product else p,
      ];
    } else {
      state = [...state, product];
    }
  }

  void remove(String productId, {required String motif}) {
    final matches = state.where((p) => p.id == productId);
    final product = matches.isEmpty ? null : matches.first;
    state = state.where((p) => p.id != productId).toList();
    if (product != null) {
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
}

final productsProvider = StateNotifierProvider<ProductsNotifier, List<Product>>(
  (ref) => ProductsNotifier(ref),
);

class CategoriesNotifier extends StateNotifier<List<ProductCategory>> {
  CategoriesNotifier() : super(mockCategories);

  /// Adds a category created on the fly from the product form — a no-op
  /// if one with the same id already exists.
  void add(ProductCategory category) {
    if (state.any((c) => c.id == category.id)) return;
    state = [...state, category];
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<ProductCategory>>(
      (ref) => CategoriesNotifier(),
    );

final lowStockProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider);
  return products.where((p) => p.stockFaible).toList();
});
