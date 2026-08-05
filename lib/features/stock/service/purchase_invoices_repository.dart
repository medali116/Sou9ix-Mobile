import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/stock/model/purchase_invoice.dart';

class PurchaseInvoicesRepository {
  PurchaseInvoicesRepository({
    required this.shopCode,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('purchaseInvoices');

  Stream<List<PurchaseInvoice>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => PurchaseInvoice.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> upsert(PurchaseInvoice invoice) {
    return _collection.doc(invoice.id).set(invoice.toMap());
  }
}
