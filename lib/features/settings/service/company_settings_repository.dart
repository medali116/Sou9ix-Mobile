import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/settings/model/company_settings.dart';

/// A shop's settings live directly on its `shops/{shopCode}` doc — that doc
/// *is* the shop, so there's no separate `settings` collection like Phase 0
/// briefly had.
class CompanySettingsRepository {
  CompanySettingsRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('shops').doc(shopCode);

  /// Emits the default [CompanySettings] until the doc exists (e.g. before
  /// "Créer mon espace" has run for the first time), then the real values.
  Stream<CompanySettings> watch() {
    return _doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return const CompanySettings();
      return CompanySettings.fromMap(data);
    });
  }

  /// One-shot read, used at login time to resolve the shop's display name
  /// before the reactive [watch] stream (scoped via `currentShopCodeProvider`)
  /// has had a chance to catch up to the just-resolved shop code.
  Future<CompanySettings> fetchOnce() async {
    final snapshot = await _doc.get();
    final data = snapshot.data();
    if (data == null) return const CompanySettings();
    return CompanySettings.fromMap(data);
  }

  Future<void> save(CompanySettings settings) {
    return _doc.set(settings.toMap());
  }
}
