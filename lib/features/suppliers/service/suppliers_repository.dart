import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/suppliers/model/supplier.dart';

class SuppliersRepository {
  SuppliersRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('suppliers');

  Stream<List<Supplier>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Supplier.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> upsert(Supplier supplier) {
    return _collection.doc(supplier.id).set(supplier.toMap());
  }

  Future<void> remove(String supplierId) {
    return _collection.doc(supplierId).delete();
  }
}
