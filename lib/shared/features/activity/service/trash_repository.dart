import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic Firestore-backed CRUD for one of the four
/// `shops/{shopCode}/trash_*` collections — [T] is the soft-deleted domain model
/// itself (a full snapshot, not a reference), converted via the same
/// [toFirestore]/[fromFirestore] codec each domain's own repository
/// already exposes, so a trashed record round-trips identically to a live
/// one.
class TrashRepository<T> {
  TrashRepository(
    this._firestore,
    this._shopCode,
    this._collectionName, {
    required Map<String, dynamic> Function(T) toFirestore,
    required T Function(String, Map<String, dynamic>) fromFirestore,
  }) : _toFirestore = toFirestore,
       _fromFirestore = fromFirestore;

  final FirebaseFirestore _firestore;
  final String _shopCode;
  final String _collectionName;
  final Map<String, dynamic> Function(T) _toFirestore;
  final T Function(String, Map<String, dynamic>) _fromFirestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection(_collectionName);

  Stream<List<T>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> add(String id, T item) =>
      _collection.doc(id).set(_toFirestore(item));

  Future<void> removeById(String id) => _collection.doc(id).delete();
}
