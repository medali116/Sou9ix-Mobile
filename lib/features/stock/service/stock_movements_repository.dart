import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/stock/model/stock_movement.dart';

class StockMovementsRepository {
  StockMovementsRepository({
    required this.shopCode,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('stockMovements');

  Stream<List<StockMovement>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StockMovement.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> record(StockMovement movement) {
    return _collection.doc(movement.id).set(movement.toMap());
  }
}
