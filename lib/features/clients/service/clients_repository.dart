import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/clients/model/client.dart';

class ClientsRepository {
  ClientsRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('clients');

  Stream<List<Client>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Client.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> upsert(Client client) {
    return _collection.doc(client.id).set(client.toMap());
  }

  Future<void> remove(String id) {
    return _collection.doc(id).delete();
  }
}
