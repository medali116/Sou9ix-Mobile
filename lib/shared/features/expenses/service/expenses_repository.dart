import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/clients/model/client.dart' show PaymentMethod;
import 'package:sou9ix/shared/features/expenses/model/expense.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/expenses`.
/// [Expense.photoBytes] stays local-only — photo sync needs Firebase
/// Storage, out of scope for this stage (same note as other domains).
class ExpensesRepository {
  ExpensesRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(_shopCode).collection('expenses');

  Stream<List<Expense>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Expense expense) =>
      _collection.doc(expense.id).set(_toFirestore(expense));

  Future<void> remove(String id) => _collection.doc(id).delete();

  Future<void> bootstrapIfEmpty(List<Expense> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final expense in seed) {
      batch.set(_collection.doc(expense.id), _toFirestore(expense));
    }
    await batch.commit();
  }

  static Map<String, dynamic> _toFirestore(Expense expense) => {
    'label': expense.label,
    'montant': expense.montant,
    'categorie': expense.categorie.name,
    'date': Timestamp.fromDate(expense.date),
    'description': expense.description,
    'paye': expense.paye,
    'recurrente': expense.recurrente,
    'ajouteePar': expense.ajouteePar,
    'modePaiement': expense.modePaiement.name,
  };

  static Expense _fromFirestore(String id, Map<String, dynamic> data) =>
      Expense(
        id: id,
        label: data['label'] as String? ?? '',
        montant: (data['montant'] as num?)?.toDouble() ?? 0,
        categorie: ExpenseCategory.values.firstWhere(
          (c) => c.name == data['categorie'],
          orElse: () => ExpenseCategory.autre,
        ),
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        description: data['description'] as String?,
        paye: data['paye'] as bool? ?? true,
        recurrente: data['recurrente'] as bool? ?? false,
        ajouteePar: data['ajouteePar'] as String?,
        modePaiement: PaymentMethod.values.firstWhere(
          (p) => p.name == data['modePaiement'],
          orElse: () => PaymentMethod.especes,
        ),
      );
}
