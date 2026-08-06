import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/auth/model/user.dart' show UserRole;
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/employee_module.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/employees`. This is what
/// makes the Caissier app's login screen (`EmployeeLoginScreen`) see the
/// exact same roster the Admin manages — no changes needed there, it
/// already just reads `activeEmployeesProvider` synchronously.
///
/// Security note: [Employee.pin]/[Employee.password] land in this
/// collection in plain text, same as they've always lived in plain memory.
/// Stage 1's Firestore rules are still open "test mode", so this is a real
/// exposure once shipped — flagged in the Stage 2 plan as a follow-up that
/// needs real auth, not fixed here.
class EmployeesRepository {
  EmployeesRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('employees');

  Stream<List<Employee>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Employee employee) =>
      _collection.doc(employee.id).set(employeeToFirestore(employee));

  Future<void> bootstrapIfEmpty(List<Employee> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final employee in seed) {
      batch.set(_collection.doc(employee.id), employeeToFirestore(employee));
    }
    await batch.commit();
  }

  static Employee _fromFirestore(String id, Map<String, dynamic> data) =>
      employeeFromFirestore(id, data);
}

/// Public so [AdminAuthService] can read/write the one Employee doc tied to
/// a Firebase Auth admin account without duplicating this codec.
Map<String, dynamic> employeeToFirestore(Employee employee) => {
  'nom': employee.nom,
  'telephone': employee.telephone,
  'poste': employee.poste,
  'actif': employee.actif,
  'modules': employee.modules.map((m) => m.name).toList(),
  'pin': employee.pin,
  'role': employee.role.name,
  'email': employee.email,
  'password': employee.password,
};

Employee employeeFromFirestore(String id, Map<String, dynamic> data) => Employee(
  id: id,
  nom: data['nom'] as String? ?? '',
  telephone: data['telephone'] as String? ?? '',
  poste: data['poste'] as String? ?? '',
  actif: data['actif'] as bool? ?? true,
  modules:
      (data['modules'] as List<dynamic>?)
          ?.map(
            (name) => EmployeeModule.values.firstWhere(
              (m) => m.name == name,
              orElse: () => EmployeeModule.venteCaisse,
            ),
          )
          .toSet() ??
      defaultCashierModules,
  pin: data['pin'] as String? ?? '0000',
  role: UserRole.values.firstWhere(
    (r) => r.name == data['role'],
    orElse: () => UserRole.caissier,
  ),
  email: data['email'] as String?,
  password: data['password'] as String?,
);
