import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/core/models/discount_firestore.dart';
import 'package:sou9ix/shared/features/pos/model/cart_item.dart';
import 'package:sou9ix/shared/features/products/service/products_repository.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/service/stock_movements_repository.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/sales`, plus the one
/// multi-collection write this whole migration was building toward:
/// [recordSaleBatch] persists a checkout's Sale doc, its per-product stock
/// decrements, and its stock-movement log entries as a single atomic
/// [WriteBatch] (all-or-nothing) — no `runTransaction` needed since every
/// write here is a blind `set`/`FieldValue.increment`, not a
/// read-then-write, so a batch gives the same safety under concurrent
/// writes from both apps with less overhead.
class SalesRepository {
  SalesRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  DocumentReference<Map<String, dynamic>> get _shopDoc =>
      _firestore.collection('shops').doc(_shopCode);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _shopDoc.collection('sales');

  Stream<List<Sale>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => saleFromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Sale sale) =>
      _collection.doc(sale.id).set(saleToFirestore(sale));

  Future<void> remove(String id) => _collection.doc(id).delete();

  Future<void> bootstrapIfEmpty(List<Sale> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final sale in seed) {
      batch.set(_collection.doc(sale.id), saleToFirestore(sale));
    }
    await batch.commit();
  }

  /// Persists one checkout in a single atomic write: the [sale] itself,
  /// a `stock: FieldValue.increment(-quantite)` on every product in
  /// [stockDeltas], every entry in [movements], and (for a credit sale) a
  /// `creditTotal` increment on the buying client.
  Future<void> recordSaleBatch({
    required Sale sale,
    required Map<String, double> stockDeltas,
    required List<StockMovement> movements,
    String? creditClientId,
    double? creditDelta,
  }) async {
    final batch = _firestore.batch();
    batch.set(_collection.doc(sale.id), saleToFirestore(sale));
    for (final entry in stockDeltas.entries) {
      batch.update(_shopDoc.collection('products').doc(entry.key), {
        'stock': FieldValue.increment(entry.value),
      });
    }
    for (final movement in movements) {
      batch.set(
        _shopDoc.collection('stock_movements').doc(movement.id),
        stockMovementToFirestore(movement),
      );
    }
    if (creditClientId != null && creditDelta != null) {
      batch.update(_shopDoc.collection('clients').doc(creditClientId), {
        'creditTotal': FieldValue.increment(creditDelta),
      });
    }
    await batch.commit();
  }
}

Map<String, dynamic> saleToFirestore(Sale sale) => {
  'dateHeure': Timestamp.fromDate(sale.dateHeure),
  'lignes': sale.lignes.map(cartItemToMap).toList(),
  'modePaiement': sale.modePaiement.name,
  'clientId': sale.clientId,
  'employeeId': sale.employeeId,
  'discount': discountToMap(sale.discount),
};

Sale saleFromFirestore(String id, Map<String, dynamic> data) => Sale(
  id: id,
  dateHeure: (data['dateHeure'] as Timestamp?)?.toDate() ?? DateTime.now(),
  lignes:
      (data['lignes'] as List<dynamic>?)
          ?.map((m) => cartItemFromMap(m as Map<String, dynamic>))
          .toList() ??
      const [],
  modePaiement: ModePaiement.values.firstWhere(
    (m) => m.name == data['modePaiement'],
    orElse: () => ModePaiement.especes,
  ),
  clientId: data['clientId'] as String?,
  employeeId: data['employeeId'] as String?,
  discount: discountFromMap(data['discount'] as Map<String, dynamic>?),
);

/// Public so [Trash]'s `SalesTrashNotifier` can reuse the exact same codec.
Map<String, dynamic> cartItemToMap(CartItem item) => {
  'product': productToFirestore(item.product),
  'productId': item.product.id,
  'quantite': item.quantite,
  'poidsUnitaire': item.poidsUnitaire,
  'discount': discountToMap(item.discount),
};

CartItem cartItemFromMap(Map<String, dynamic> m) => CartItem(
  product: productFromFirestore(
    m['productId'] as String? ?? '',
    m['product'] as Map<String, dynamic>? ?? const {},
  ),
  quantite: (m['quantite'] as num?)?.toDouble() ?? 0,
  poidsUnitaire: (m['poidsUnitaire'] as num?)?.toDouble(),
  discount: discountFromMap(m['discount'] as Map<String, dynamic>?),
);
