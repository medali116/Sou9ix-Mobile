import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/caisse/model/caisse_adjustment.dart';

class CaisseAdjustmentsRepository {
  CaisseAdjustmentsRepository({
    required this.shopCode,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('caisseAdjustments');

  Stream<List<CaisseAdjustment>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => CaisseAdjustment.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> add(CaisseAdjustment adjustment) {
    return _collection.doc(adjustment.id).set(adjustment.toMap());
  }
}
