import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/products/model/category.dart';

class CategoriesRepository {
  CategoriesRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('categories');

  Stream<List<ProductCategory>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ProductCategory.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> add(ProductCategory category) {
    return _collection.doc(category.id).set(category.toMap());
  }
}
