import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/returns/model/stock_return.dart';

class StockReturnsRepository {
  StockReturnsRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('stockReturns');

  Stream<List<StockReturn>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StockReturn.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> add(StockReturn stockReturn) {
    return _collection.doc(stockReturn.id).set(stockReturn.toMap());
  }

  Future<void> remove(String id) {
    return _collection.doc(id).delete();
  }
}
