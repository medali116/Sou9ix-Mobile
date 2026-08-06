import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/core/models/discount.dart';
import 'package:sou9ix/shared/features/pos/model/cart_item.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/service/sales_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

// Mirrors the catalogue's real products/model/product.dart seed values
// (same ids/names/prices) purely so the dashboard's "Top produits" and
// revenue chart have believable data to aggregate — every mock provider in
// this app seeds independently rather than cross-referencing another
// provider's state.
const _cacahuetes = Product(
  id: 'p1',
  name: 'Cacahuètes grillées',
  emoji: '🥜',
  prixVente: 8.000,
  prixAchat: 5.200,
  venduAuPoids: true,
  categorieId: 'fruits_secs',
  stock: 12.5,
  seuilAlerte: 3,
);
const _amandes = Product(
  id: 'p2',
  name: 'Amandes décortiquées',
  emoji: '🌰',
  prixVente: 22.000,
  prixAchat: 16.500,
  venduAuPoids: true,
  categorieId: 'fruits_secs',
  stock: 2.0,
  seuilAlerte: 3,
);
const _pistaches = Product(
  id: 'p3',
  name: 'Pistaches grillées',
  emoji: '🥨',
  prixVente: 34.000,
  prixAchat: 27.000,
  venduAuPoids: true,
  categorieId: 'fruits_secs',
  stock: 8.0,
  seuilAlerte: 2,
);
const _cajou = Product(
  id: 'p4',
  name: 'Noix de cajou',
  emoji: '🌰',
  prixVente: 29.500,
  prixAchat: 22.000,
  venduAuPoids: true,
  categorieId: 'fruits_secs',
  stock: 5.4,
  seuilAlerte: 2,
);
const _arabica = Product(
  id: 'p6',
  name: 'Café torréfié Arabica',
  emoji: '☕',
  prixVente: 18.000,
  prixAchat: 12.500,
  venduAuPoids: true,
  categorieId: 'cafe',
  stock: 9.0,
  seuilAlerte: 2,
);
const _robusta = Product(
  id: 'p7',
  name: 'Café moulu Robusta',
  emoji: '☕',
  prixVente: 14.500,
  prixAchat: 9.800,
  venduAuPoids: true,
  categorieId: 'cafe',
  stock: 0.8,
  seuilAlerte: 2,
);

final salesRepositoryProvider = Provider<SalesRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return SalesRepository(FirebaseFirestore.instance, shopCode);
});

class SalesNotifier extends StateNotifier<List<Sale>> {
  SalesNotifier(this._repo) : super(_seed()) {
    unawaited(_init());
  }

  final SalesRepository? _repo;
  StreamSubscription<List<Sale>>? _sub;

  static Sale _sale({
    required int id,
    required int daysAgo,
    required int hour,
    required int minute,
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
  }) {
    final now = DateTime.now();
    final day = now.subtract(Duration(days: daysAgo));
    return Sale(
      // Padded so every seed id is at least as long as the real
      // 's${microsecondsSinceEpoch}' ids `recordSale` generates — several
      // screens derive a short "Ticket #" by taking the id's last 6 chars.
      id: 's${id.toString().padLeft(6, '0')}',
      dateHeure: DateTime(day.year, day.month, day.day, hour, minute),
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: clientId,
      // Alternates between the two seeded staff (e1 Yassine / e2 Rania) so
      // "Top caissiers" style analytics have something real to aggregate.
      employeeId: id.isOdd ? 'e1' : 'e2',
    );
  }

  static List<Sale> _seed() => [
    // J-6
    _sale(
      id: 1,
      daysAgo: 6,
      hour: 9,
      minute: 15,
      modePaiement: ModePaiement.especes,
      lignes: const [
        CartItem(product: _cacahuetes, quantite: 3),
        CartItem(product: _arabica, quantite: 2),
      ],
    ),
    _sale(
      id: 2,
      daysAgo: 6,
      hour: 12,
      minute: 40,
      modePaiement: ModePaiement.carte,
      lignes: const [CartItem(product: _amandes, quantite: 4)],
    ),
    _sale(
      id: 3,
      daysAgo: 6,
      hour: 17,
      minute: 5,
      modePaiement: ModePaiement.especes,
      lignes: const [
        CartItem(product: _pistaches, quantite: 2),
        CartItem(product: _robusta, quantite: 3),
      ],
    ),
    // J-5
    _sale(
      id: 4,
      daysAgo: 5,
      hour: 10,
      minute: 20,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _cacahuetes, quantite: 5)],
    ),
    _sale(
      id: 5,
      daysAgo: 5,
      hour: 16,
      minute: 50,
      modePaiement: ModePaiement.carte,
      lignes: const [
        CartItem(product: _arabica, quantite: 4),
        CartItem(product: _cajou, quantite: 1.5),
      ],
    ),
    // J-4
    _sale(
      id: 6,
      daysAgo: 4,
      hour: 9,
      minute: 30,
      modePaiement: ModePaiement.especes,
      lignes: const [
        CartItem(product: _amandes, quantite: 3),
        CartItem(product: _pistaches, quantite: 1.5),
      ],
    ),
    _sale(
      id: 7,
      daysAgo: 4,
      hour: 13,
      minute: 10,
      modePaiement: ModePaiement.credit,
      clientId: 'c1',
      lignes: const [
        CartItem(product: _arabica, quantite: 2.5),
        CartItem(product: _cacahuetes, quantite: 2),
      ],
    ),
    _sale(
      id: 8,
      daysAgo: 4,
      hour: 18,
      minute: 25,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _robusta, quantite: 4)],
    ),
    // J-3
    _sale(
      id: 9,
      daysAgo: 3,
      hour: 9,
      minute: 5,
      modePaiement: ModePaiement.carte,
      lignes: const [
        CartItem(product: _pistaches, quantite: 3),
        CartItem(product: _cajou, quantite: 2),
      ],
    ),
    _sale(
      id: 10,
      daysAgo: 3,
      hour: 14,
      minute: 45,
      modePaiement: ModePaiement.credit,
      clientId: 'c4',
      lignes: const [
        CartItem(product: _arabica, quantite: 6),
        CartItem(product: _robusta, quantite: 3),
      ],
    ),
    _sale(
      id: 11,
      daysAgo: 3,
      hour: 19,
      minute: 0,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _cacahuetes, quantite: 4)],
    ),
    // J-2
    _sale(
      id: 12,
      daysAgo: 2,
      hour: 10,
      minute: 15,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _amandes, quantite: 2.5)],
    ),
    _sale(
      id: 13,
      daysAgo: 2,
      hour: 15,
      minute: 30,
      modePaiement: ModePaiement.carte,
      lignes: const [
        CartItem(product: _arabica, quantite: 5),
        CartItem(product: _pistaches, quantite: 1),
      ],
    ),
    _sale(
      id: 14,
      daysAgo: 2,
      hour: 18,
      minute: 40,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _cacahuetes, quantite: 6)],
    ),
    // J-1
    _sale(
      id: 15,
      daysAgo: 1,
      hour: 9,
      minute: 50,
      modePaiement: ModePaiement.especes,
      lignes: const [
        CartItem(product: _pistaches, quantite: 4),
        CartItem(product: _robusta, quantite: 3),
      ],
    ),
    _sale(
      id: 16,
      daysAgo: 1,
      hour: 13,
      minute: 20,
      modePaiement: ModePaiement.credit,
      clientId: 'c3',
      lignes: const [
        CartItem(product: _arabica, quantite: 4),
        CartItem(product: _cajou, quantite: 3),
      ],
    ),
    _sale(
      id: 17,
      daysAgo: 1,
      hour: 20,
      minute: 5,
      modePaiement: ModePaiement.carte,
      lignes: const [CartItem(product: _amandes, quantite: 5)],
    ),
    // Aujourd'hui
    _sale(
      id: 18,
      daysAgo: 0,
      hour: 8,
      minute: 45,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _cacahuetes, quantite: 2)],
    ),
    _sale(
      id: 19,
      daysAgo: 0,
      hour: 10,
      minute: 10,
      modePaiement: ModePaiement.carte,
      lignes: const [CartItem(product: _pistaches, quantite: 1)],
    ),
    _sale(
      id: 20,
      daysAgo: 0,
      hour: 12,
      minute: 30,
      modePaiement: ModePaiement.especes,
      lignes: const [
        CartItem(product: _arabica, quantite: 3),
        CartItem(product: _cacahuetes, quantite: 2),
      ],
    ),
    _sale(
      id: 21,
      daysAgo: 0,
      hour: 15,
      minute: 55,
      modePaiement: ModePaiement.credit,
      clientId: 'c1',
      lignes: const [
        CartItem(product: _amandes, quantite: 3.5),
        CartItem(product: _robusta, quantite: 2),
      ],
    ),
    _sale(
      id: 22,
      daysAgo: 0,
      hour: 16,
      minute: 42,
      modePaiement: ModePaiement.especes,
      lignes: const [CartItem(product: _cajou, quantite: 1)],
    ),
  ];

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.bootstrapIfEmpty(state);
    _sub = repo.watchAll().listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Builds and records a new sale, persisting it on its own (used by
  /// callers that don't need the combined stock/credit batch — see
  /// [SaleService.checkout] for the full checkout write).
  Sale recordSale({
    required List<CartItem> lignes,
    required ModePaiement modePaiement,
    String? clientId,
    String? employeeId,
    Discount discount = const Discount.none(),
  }) {
    final sale = Sale(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      dateHeure: DateTime.now(),
      lignes: lignes,
      modePaiement: modePaiement,
      clientId: clientId,
      employeeId: employeeId,
      discount: discount,
    );
    state = [sale, ...state];
    unawaited(_repo?.upsert(sale));
    return sale;
  }

  /// Adds an already-built [Sale] (its id pre-allocated by the caller) to
  /// local state only — used by [SaleService.checkout], which persists it
  /// itself as part of a combined batch write instead of via [upsert].
  void addLocal(Sale sale) => state = [sale, ...state];

  Sale updateSale(Sale updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
    unawaited(_repo?.upsert(updated));
    return updated;
  }

  void removeSale(String id) {
    state = state.where((s) => s.id != id).toList();
    unawaited(_repo?.remove(id));
  }

  /// Brings a sale back from the Corbeille, preserving its original id
  /// (unlike [recordSale], which always mints a new one).
  void restore(Sale sale) {
    state = [sale, ...state];
    unawaited(_repo?.upsert(sale));
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, List<Sale>>(
  (ref) => SalesNotifier(ref.watch(salesRepositoryProvider)),
);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final todayRevenueProvider = Provider<double>((ref) {
  final sales = ref.watch(salesProvider);
  final now = DateTime.now();
  return sales
      .where((s) => _isSameDay(s.dateHeure, now))
      .fold(0.0, (total, s) => total + s.total);
});

final employeeSalesProvider = Provider.family<List<Sale>, String>((
  ref,
  employeeId,
) {
  return ref
      .watch(salesProvider)
      .where((s) => s.employeeId == employeeId)
      .toList();
});
