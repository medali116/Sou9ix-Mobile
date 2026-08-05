import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';

class ActivityLogRepository {
  ActivityLogRepository({required this.shopCode, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final String shopCode;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopCode).collection('activityLog');

  Stream<List<ActivityLogEntry>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ActivityLogEntry.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> log(ActivityLogEntry entry) {
    return _collection.doc(entry.id).set(entry.toMap());
  }
}
