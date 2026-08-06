import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/clients/model/client.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/clients`. [Client.transactions]
/// stays embedded (not a subcollection) — each entry is a handful of
/// scalar fields, so even a client with hundreds of karné transactions is
/// nowhere near Firestore's 1MB document limit, and embedding keeps reads
/// simple (one document = one client with full history, no composed
/// per-client subcollection stream to maintain).
class ClientsRepository {
  ClientsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(_shopCode).collection('clients');

  Stream<List<Client>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Client client) =>
      _collection.doc(client.id).set(clientToFirestore(client));

  Future<void> remove(String id) => _collection.doc(id).delete();

  Future<void> bootstrapIfEmpty(List<Client> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final client in seed) {
      batch.set(_collection.doc(client.id), clientToFirestore(client));
    }
    await batch.commit();
  }

  static Client _fromFirestore(String id, Map<String, dynamic> data) =>
      clientFromFirestore(id, data);
}

/// Public so [Trash]-style domains that embed a full [Client] snapshot can
/// reuse the exact same codec instead of duplicating it.
Map<String, dynamic> clientToFirestore(Client client) => {
  'nom': client.nom,
  'telephone': client.telephone,
  'creditTotal': client.creditTotal,
  'dernierAchat': Timestamp.fromDate(client.dernierAchat),
  'adresse': client.adresse,
  'notes': client.notes,
  'limiteCredit': client.limiteCredit,
  'transactions': client.transactions.map(_transactionToMap).toList(),
};

Map<String, dynamic> _transactionToMap(ClientTransaction t) => {
  'id': t.id,
  'type': t.type.name,
  'montant': t.montant,
  'date': Timestamp.fromDate(t.date),
  'modePaiement': t.modePaiement?.name,
  'notes': t.notes,
  'allocations': t.allocations
      .map((a) => {'saleId': a.saleId, 'montant': a.montant})
      .toList(),
};

Client clientFromFirestore(String id, Map<String, dynamic> data) => Client(
  id: id,
  nom: data['nom'] as String? ?? '',
  telephone: data['telephone'] as String? ?? '',
  creditTotal: (data['creditTotal'] as num?)?.toDouble() ?? 0,
  dernierAchat: (data['dernierAchat'] as Timestamp?)?.toDate() ?? DateTime.now(),
  adresse: data['adresse'] as String?,
  notes: data['notes'] as String?,
  limiteCredit: (data['limiteCredit'] as num?)?.toDouble(),
  transactions:
      (data['transactions'] as List<dynamic>?)
          ?.map((m) => _transactionFromMap(m as Map<String, dynamic>))
          .toList() ??
      const [],
);

ClientTransaction _transactionFromMap(Map<String, dynamic> m) =>
    ClientTransaction(
      id: m['id'] as String? ?? '',
      type: ClientTransactionType.values.firstWhere(
        (t) => t.name == m['type'],
        orElse: () => ClientTransactionType.ajustement,
      ),
      montant: (m['montant'] as num?)?.toDouble() ?? 0,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modePaiement: m['modePaiement'] == null
          ? null
          : PaymentMethod.values.firstWhere(
              (p) => p.name == m['modePaiement'],
              orElse: () => PaymentMethod.especes,
            ),
      notes: m['notes'] as String?,
      allocations:
          (m['allocations'] as List<dynamic>?)
              ?.map(
                (a) => PaymentAllocation(
                  saleId: (a as Map<String, dynamic>)['saleId'] as String,
                  montant: (a['montant'] as num).toDouble(),
                ),
              )
              .toList() ??
          const [],
    );
