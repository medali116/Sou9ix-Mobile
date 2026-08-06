import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/activity_log` — append-only,
/// no seed data (the old hardcoded demo entries are dropped rather than
/// bootstrapped, since a real shop's audit trail should start genuinely
/// empty, not with fabricated history).
class ActivityLogRepository {
  ActivityLogRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('activity_log');

  Stream<List<ActivityLogEntry>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> log(ActivityLogEntry entry) =>
      _collection.doc(entry.id).set(_toFirestore(entry));

  static Map<String, dynamic> _toFirestore(ActivityLogEntry e) => {
    'date': Timestamp.fromDate(e.date),
    'employeeName': e.employeeName,
    'category': e.category.name,
    'impact': e.impact.name,
    'action': e.action,
    'targetName': e.targetName,
    'champ': e.champ,
    'ancienneValeur': e.ancienneValeur,
    'nouvelleValeur': e.nouvelleValeur,
    'difference': e.difference,
    'motif': e.motif,
    'montant': e.montant,
    'platform': e.platform,
  };

  static ActivityLogEntry _fromFirestore(String id, Map<String, dynamic> data) =>
      ActivityLogEntry(
        id: id,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        employeeName: data['employeeName'] as String? ?? '',
        category: ActivityCategory.values.firstWhere(
          (c) => c.name == data['category'],
          orElse: () => ActivityCategory.tickets,
        ),
        impact: ActivityImpact.values.firstWhere(
          (i) => i.name == data['impact'],
          orElse: () => ActivityImpact.ajout,
        ),
        action: data['action'] as String? ?? '',
        targetName: data['targetName'] as String?,
        champ: data['champ'] as String?,
        ancienneValeur: data['ancienneValeur'] as String?,
        nouvelleValeur: data['nouvelleValeur'] as String?,
        difference: (data['difference'] as num?)?.toDouble(),
        motif: data['motif'] as String?,
        montant: (data['montant'] as num?)?.toDouble(),
        platform: data['platform'] as String?,
      );
}
