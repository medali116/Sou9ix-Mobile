import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/employees/model/shift.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/shifts` — no seed data (a
/// shift only ever exists because someone clocked in), so no bootstrap
/// step, unlike the domains with demo data.
class ShiftsRepository {
  ShiftsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(_shopCode).collection('shifts');

  Stream<List<Shift>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Shift shift) =>
      _collection.doc(shift.id).set(_toFirestore(shift));

  static Map<String, dynamic> _toFirestore(Shift shift) => {
    'employeeId': shift.employeeId,
    'clockIn': Timestamp.fromDate(shift.clockIn),
    'clockOut': shift.clockOut == null
        ? null
        : Timestamp.fromDate(shift.clockOut!),
    'fondInitial': shift.fondInitial,
    'fondSource': shift.fondSource,
    'montantCompte': shift.montantCompte,
    'ecartMotif': shift.ecartMotif,
    'ecartCommentaire': shift.ecartCommentaire,
  };

  static Shift _fromFirestore(String id, Map<String, dynamic> data) => Shift(
    id: id,
    employeeId: data['employeeId'] as String? ?? '',
    clockIn: (data['clockIn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    clockOut: (data['clockOut'] as Timestamp?)?.toDate(),
    fondInitial: (data['fondInitial'] as num?)?.toDouble() ?? 0,
    fondSource: data['fondSource'] as String? ?? 'Report de caisse',
    montantCompte: (data['montantCompte'] as num?)?.toDouble(),
    ecartMotif: data['ecartMotif'] as String?,
    ecartCommentaire: data['ecartCommentaire'] as String?,
  );
}
