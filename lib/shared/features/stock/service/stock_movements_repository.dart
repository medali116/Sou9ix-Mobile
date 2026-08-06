import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/stock_movements` — append-
/// only (no update/delete), no seed data.
class StockMovementsRepository {
  StockMovementsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('stock_movements');

  Stream<List<StockMovement>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> record(StockMovement movement) =>
      _collection.doc(movement.id).set(stockMovementToFirestore(movement));

  static StockMovement _fromFirestore(String id, Map<String, dynamic> data) =>
      stockMovementFromFirestore(id, data);
}

/// Public so domains that write stock movements as part of a larger batch
/// (e.g. [SalesRepository.recordSaleBatch]) can reuse the exact same codec.
Map<String, dynamic> stockMovementToFirestore(StockMovement movement) => {
  'date': Timestamp.fromDate(movement.date),
  'productId': movement.productId,
  'productName': movement.productName,
  'type': movement.type.name,
  'quantite': movement.quantite,
  'stockApres': movement.stockApres,
  'reference': movement.reference,
  'motif': movement.motif,
  'employeeName': movement.employeeName,
};

StockMovement stockMovementFromFirestore(String id, Map<String, dynamic> data) =>
    StockMovement(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? '',
      type: StockMovementType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => StockMovementType.ajustement,
      ),
      quantite: (data['quantite'] as num?)?.toDouble() ?? 0,
      stockApres: (data['stockApres'] as num?)?.toDouble() ?? 0,
      reference: data['reference'] as String?,
      motif: data['motif'] as String?,
      employeeName: data['employeeName'] as String? ?? '',
    );
