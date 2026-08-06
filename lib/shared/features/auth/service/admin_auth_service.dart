import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/auth/model/user.dart' show UserRole;
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/employee_module.dart';
import 'package:sou9ix/shared/features/employees/service/employees_repository.dart';
import 'package:sou9ix/shared/features/settings/service/company_code_service.dart';

/// What a successful sign-up/sign-in resolves to: the roster entry to open
/// a session for, and which shop it belongs to (needed by callers that
/// haven't cached a shop code locally yet — see [AdminLoginScreen], which
/// is exactly the "logging in on a device that's never seen this shop
/// before" case Stage 2's local-only `ShopCodeStorage` couldn't handle on
/// its own).
class AdminAuthResult {
  final Employee employee;
  final String shopCode;
  const AdminAuthResult({required this.employee, required this.shopCode});
}

/// Real Firebase Authentication for the Admin app — replaces Stage 1/2's
/// plaintext [Employee.password] comparison. A top-level `admins/{uid}`
/// document (outside any shop's subtree, since it's the one thing that
/// must be look-up-able *before* a shop code is known) maps a Firebase
/// Auth account to the shop it owns; the actual roster entry still lives
/// at `shops/{shopCode}/employees/{uid}` — same collection every other
/// employee lives in, just with the Firebase Auth uid as its id instead of
/// a locally-minted one.
class AdminAuthService {
  AdminAuthService(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Order matters here: the Firebase Auth account is created *first* — if
  /// that's the step that fails (wrong provider config, weak password,
  /// email taken...), nothing else has happened yet. Only once it succeeds
  /// do we generate and register a shop code, so a failed sign-up never
  /// leaves an orphaned `shops/{code}` document with no admin attached.
  Future<AdminAuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String pin,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final shopCode = await CompanyCodeService(
      _firestore,
    ).createShopCode(adminName: name);

    await _firestore.collection('admins').doc(uid).set({
      'shopCode': shopCode,
      'name': name,
      'email': email,
    });

    final employee = Employee(
      id: uid,
      nom: name,
      telephone: '',
      poste: 'Gérant',
      modules: EmployeeModule.values.toSet(),
      pin: pin,
      role: UserRole.admin,
      email: email,
    );
    await EmployeesRepository(_firestore, shopCode).upsert(employee);

    return AdminAuthResult(employee: employee, shopCode: shopCode);
  }

  Future<AdminAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final adminDoc = await _firestore.collection('admins').doc(uid).get();
    final shopCode = adminDoc.data()?['shopCode'] as String?;
    if (shopCode == null) {
      throw StateError('Aucun magasin associé à ce compte administrateur.');
    }

    final employeeDoc = await _firestore
        .collection('shops')
        .doc(shopCode)
        .collection('employees')
        .doc(uid)
        .get();
    final employeeData = employeeDoc.data();
    if (employeeData == null) {
      throw StateError('Compte administrateur introuvable pour ce magasin.');
    }

    return AdminAuthResult(
      employee: employeeFromFirestore(uid, employeeData),
      shopCode: shopCode,
    );
  }
}

final adminAuthServiceProvider = Provider<AdminAuthService>(
  (ref) => AdminAuthService(FirebaseAuth.instance, FirebaseFirestore.instance),
);

/// Friendly French messages for the [FirebaseAuthException] codes this
/// screen's flows can actually hit — falls back to the SDK's own message
/// for anything unexpected rather than hiding it behind a generic string.
String firebaseAuthErrorMessage(FirebaseAuthException e) => switch (e.code) {
  'email-already-in-use' => 'Un compte existe déjà avec cette adresse e-mail.',
  'weak-password' => 'Mot de passe trop faible — utilisez au moins 6 caractères.',
  'invalid-email' => 'Adresse e-mail invalide.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Adresse e-mail ou mot de passe incorrect.',
  'user-disabled' => 'Ce compte a été désactivé.',
  'too-many-requests' => 'Trop de tentatives — réessayez dans quelques instants.',
  'network-request-failed' =>
    'Impossible de contacter le serveur — vérifiez votre connexion internet.',
  'operation-not-allowed' =>
    'La connexion par e-mail/mot de passe n\'est pas activée sur ce projet Firebase (Authentication → Sign-in method).',
  // Fallback keeps the raw code visible — several plugin versions return a
  // generic e.message ("Error"/null) for codes this list doesn't special-
  // case, and a bare "Error" in the UI is undiagnosable without it.
  _ => 'Erreur (${e.code}) : ${e.message ?? 'réessayez.'}',
};
