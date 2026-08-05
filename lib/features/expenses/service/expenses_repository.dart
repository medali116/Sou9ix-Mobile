import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/expenses/model/expense.dart';

class ExpensesRepository {
  ExpensesRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('expenses');

  Stream<List<Expense>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Expense.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> upsert(Expense expense) {
    return _collection.doc(expense.id).set(expense.toMap());
  }

  Future<void> remove(String id) {
    return _collection.doc(id).delete();
  }
}
