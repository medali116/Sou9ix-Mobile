import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/caisse/model/caisse_adjustment.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/caisse_adjustments` — no
/// seed data, no bootstrap step.
class CaisseAdjustmentsRepository {
  CaisseAdjustmentsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('caisse_adjustments');

  Stream<List<CaisseAdjustment>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> add(CaisseAdjustment adjustment) =>
      _collection.doc(adjustment.id).set(_toFirestore(adjustment));

  static Map<String, dynamic> _toFirestore(CaisseAdjustment adjustment) => {
    'date': Timestamp.fromDate(adjustment.date),
    'montant': adjustment.montant,
    'targetEmployeeId': adjustment.targetEmployeeId,
    'motif': adjustment.motif,
    'note': adjustment.note,
    'recordedByName': adjustment.recordedByName,
  };

  static CaisseAdjustment _fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) => CaisseAdjustment(
    id: id,
    date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    montant: (data['montant'] as num?)?.toDouble() ?? 0,
    targetEmployeeId: data['targetEmployeeId'] as String? ?? '',
    motif: data['motif'] as String? ?? '',
    note: data['note'] as String?,
    recordedByName: data['recordedByName'] as String? ?? '',
  );
}
