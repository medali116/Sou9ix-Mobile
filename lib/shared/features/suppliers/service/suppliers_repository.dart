import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/suppliers/model/supplier.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/suppliers` — the template
/// every other domain's repository follows. Deliberately does not persist
/// [Supplier.photoBytes]: photo sync needs Firebase Storage, out of scope
/// for this stage, so a picked photo is local-only for the rest of this
/// session and disappears once the next Firestore snapshot echoes back.
class SuppliersRepository {
  SuppliersRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('suppliers');

  Stream<List<Supplier>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Supplier supplier) =>
      _collection.doc(supplier.id).set(supplierToFirestore(supplier));

  Future<void> remove(String id) => _collection.doc(id).delete();

  /// Writes [seed] once, only if this shop's suppliers collection is
  /// completely empty — keeps the existing "new shop opens with friendly
  /// demo data" onboarding experience without re-seeding on every launch.
  Future<void> bootstrapIfEmpty(List<Supplier> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final supplier in seed) {
      batch.set(_collection.doc(supplier.id), supplierToFirestore(supplier));
    }
    await batch.commit();
  }

  static Supplier _fromFirestore(String id, Map<String, dynamic> data) =>
      supplierFromFirestore(id, data);
}

/// Public so [Trash]-style domains that embed a full [Supplier] snapshot
/// can reuse the exact same codec instead of duplicating it.
Map<String, dynamic> supplierToFirestore(Supplier supplier) => {
  'nom': supplier.nom,
  'telephone': supplier.telephone,
  'adresse': supplier.adresse,
};

Supplier supplierFromFirestore(String id, Map<String, dynamic> data) =>
    Supplier(
      id: id,
      nom: data['nom'] as String? ?? '',
      telephone: data['telephone'] as String? ?? '',
      adresse: data['adresse'] as String? ?? '',
    );
