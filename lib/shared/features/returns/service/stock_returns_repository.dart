import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/returns/model/stock_return.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/stock_returns` — append-
/// only, no seed data.
class StockReturnsRepository {
  StockReturnsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('stock_returns');

  Stream<List<StockReturn>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> add(StockReturn stockReturn) =>
      _collection.doc(stockReturn.id).set(_toFirestore(stockReturn));

  static Map<String, dynamic> _toFirestore(StockReturn r) => {
    'date': Timestamp.fromDate(r.date),
    'productId': r.productId,
    'productName': r.productName,
    'quantite': r.quantite,
    'venduAuPoids': r.venduAuPoids,
    'prixAchatUnitaire': r.prixAchatUnitaire,
    'motif': r.motif.name,
    'note': r.note,
  };

  static StockReturn _fromFirestore(String id, Map<String, dynamic> data) =>
      StockReturn(
        id: id,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        productId: data['productId'] as String? ?? '',
        productName: data['productName'] as String? ?? '',
        quantite: (data['quantite'] as num?)?.toDouble() ?? 0,
        venduAuPoids: data['venduAuPoids'] as bool? ?? false,
        prixAchatUnitaire: (data['prixAchatUnitaire'] as num?)?.toDouble() ?? 0,
        motif: RetourMotif.values.firstWhere(
          (m) => m.name == data['motif'],
          orElse: () => RetourMotif.autre,
        ),
        note: data['note'] as String?,
      );
}
