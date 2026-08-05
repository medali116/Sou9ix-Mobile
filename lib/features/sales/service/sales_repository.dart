import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/sales/model/sale.dart';

class SalesRepository {
  SalesRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('sales');

  Stream<List<Sale>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> upsert(Sale sale) {
    return _collection.doc(sale.id).set(sale.toMap());
  }

  Future<void> remove(String id) {
    return _collection.doc(id).delete();
  }
}
