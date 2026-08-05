import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/employees/model/shift.dart';

class ShiftsRepository {
  ShiftsRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('shifts');

  Stream<List<Shift>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Shift.fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> upsert(Shift shift) {
    return _collection.doc(shift.id).set(shift.toMap());
  }
}
