import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/employees/model/employee.dart';

/// A single shop's roster — lives at `shops/{shopCode}/employees`. For
/// looking an employee up *before* the shop is known (login), see
/// `EmployeeDirectory` instead, which searches every shop at once.
class EmployeesRepository {
  EmployeesRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(shopCode)
      .collection('employees');

  Stream<List<Employee>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Employee.fromMap(doc.id, doc.data(), shopCode: shopCode))
          .toList(),
    );
  }

  /// One-shot read, used at login time — a device already bound to this
  /// shop (see `ShopCodeStorage`) looks the caissier up here directly rather
  /// than through the cross-shop `EmployeeDirectory`.
  Future<List<Employee>> fetchOnce() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => Employee.fromMap(doc.id, doc.data(), shopCode: shopCode))
        .toList();
  }

  Future<void> upsert(Employee employee) {
    return _collection.doc(employee.id).set(employee.toMap());
  }
}
