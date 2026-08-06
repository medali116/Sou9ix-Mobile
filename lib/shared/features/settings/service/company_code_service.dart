import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Excludes visually-confusable characters (0/O, 1/I/L) so a code read
/// aloud or copied by hand doesn't get mistyped.
const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const _codePrefix = 'S9X-';
const _codeSuffixLength = 5;

String _randomSuffix() {
  final rand = Random.secure();
  return List.generate(
    _codeSuffixLength,
    (_) => _codeAlphabet[rand.nextInt(_codeAlphabet.length)],
  ).join();
}

/// Every shop (one per Admin) is registered under `shops/{code}` in
/// Firestore — the one piece of state this app shares across the Admin and
/// Caissier installs, since each app otherwise only holds its own local,
/// in-memory data. The code itself never changes once generated.
class CompanyCodeService {
  CompanyCodeService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Generates a fresh, unused shop code (`S9X-XXXXX`) and registers it,
  /// retrying on the extremely unlikely collision.
  Future<String> createShopCode({required String adminName}) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = '$_codePrefix${_randomSuffix()}';
      final doc = _firestore.collection('shops').doc(code);
      final snapshot = await doc.get();
      if (snapshot.exists) continue;
      await doc.set({
        'adminName': adminName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return code;
    }
    throw Exception(
      'Impossible de générer un code de magasin unique — réessayez.',
    );
  }

  /// Whether [code] matches a registered shop.
  Future<bool> shopCodeExists(String code) async {
    final normalized = code.trim().toUpperCase();
    final doc = await _firestore.collection('shops').doc(normalized).get();
    return doc.exists;
  }
}

final companyCodeServiceProvider = Provider<CompanyCodeService>(
  (ref) => CompanyCodeService(FirebaseFirestore.instance),
);
