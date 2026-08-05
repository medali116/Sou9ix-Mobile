import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/products/model/product.dart';

class ProductsRepository {
  ProductsRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('products');

  Stream<List<Product>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Product.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> upsert(Product product) {
    return _collection.doc(product.id).set(product.toMap());
  }

  Future<void> remove(String productId) {
    return _collection.doc(productId).delete();
  }
}
