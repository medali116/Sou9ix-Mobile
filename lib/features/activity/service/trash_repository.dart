import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic Firestore-backed trash bin — [ProductsTrashNotifier] etc. each
/// instantiate one of these with their own (de)serializer rather than
/// duplicating the same collection/stream/add/remove plumbing four times.
class TrashRepository<T> {
  TrashRepository({
    required this.shopCode,
    required String collectionName,
    required this.toMap,
    required this.fromMap,
    FirebaseFirestore? firestore,
  }) : _collectionName = collectionName,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final String _collectionName;
  final Map<String, dynamic> Function(T item) toMap;
  final T Function(String id, Map<String, dynamic> map) fromMap;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection(_collectionName);

  Stream<List<T>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => fromMap(doc.id, doc.data())).toList(),
    );
  }

  Future<void> add(String id, T item) {
    return _collection.doc(id).set(toMap(item));
  }

  Future<void> removeById(String id) {
    return _collection.doc(id).delete();
  }
}
