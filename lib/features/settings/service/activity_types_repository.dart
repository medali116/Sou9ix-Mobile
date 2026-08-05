import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/features/settings/model/activity_type.dart';

class ActivityTypesRepository {
  ActivityTypesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('activityTypes');

  Stream<List<ActivityType>> watchAll() {
    return _collection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ActivityType.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> add(ActivityType type) {
    return _collection.doc(type.id).set(type.toMap());
  }
}
