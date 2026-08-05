import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/employees/model/employee.dart';

/// The one place in the app that legitimately looks across shop boundaries.
/// Every other read is scoped to a single `shops/{shopCode}/...` subtree —
/// but at login time (or at signup, checking e-mail/phone uniqueness) the
/// app doesn't know which shop yet, so it has to search all of them via a
/// Firestore `collectionGroup` query. No composite index is needed since
/// matching happens client-side rather than through `.where()`.
class EmployeeDirectory {
  EmployeeDirectory({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Employee>> findAll() async {
    final snapshot = await _firestore.collectionGroup('employees').get();
    return snapshot.docs
        .map((doc) {
          // A collectionGroup query matches *any* collection named
          // "employees" at any depth — including a stray top-level one left
          // over from before shops existed. Those have no parent shop
          // document (parent.parent is null for a root collection), so
          // they're skipped rather than crashing on a null shop code.
          final shopDoc = doc.reference.parent.parent;
          if (shopDoc == null) return null;
          return Employee.fromMap(doc.id, doc.data(), shopCode: shopDoc.id);
        })
        .whereType<Employee>()
        .toList();
  }
}
