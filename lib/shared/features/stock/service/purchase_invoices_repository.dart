import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/core/models/discount_firestore.dart';
import 'package:sou9ix/shared/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/shared/features/stock/model/purchase_invoice_line.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/purchase_invoices`.
/// [PurchaseInvoice.photoBytes] stays local-only — photo sync needs
/// Firebase Storage, out of scope for this stage (same note as
/// [ProductsRepository]/[SuppliersRepository]).
class PurchaseInvoicesRepository {
  PurchaseInvoicesRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('purchase_invoices');

  Stream<List<PurchaseInvoice>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(PurchaseInvoice invoice) =>
      _collection.doc(invoice.id).set(_toFirestore(invoice));

  Future<void> bootstrapIfEmpty(List<PurchaseInvoice> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final invoice in seed) {
      batch.set(_collection.doc(invoice.id), _toFirestore(invoice));
    }
    await batch.commit();
  }

  static Map<String, dynamic> _toFirestore(PurchaseInvoice invoice) => {
    'date': Timestamp.fromDate(invoice.date),
    'dateReception': invoice.dateReception == null
        ? null
        : Timestamp.fromDate(invoice.dateReception!),
    'numeroFournisseur': invoice.numeroFournisseur,
    'fournisseurId': invoice.fournisseurId,
    'fournisseurNom': invoice.fournisseurNom,
    'lignes': invoice.lignes.map(_lineToMap).toList(),
    'paiements': invoice.paiements.map(_paymentToMap).toList(),
    'tvaRate': invoice.tvaRate,
    'discount': discountToMap(invoice.discount),
    'notes': invoice.notes,
  };

  static Map<String, dynamic> _lineToMap(PurchaseInvoiceLine line) => {
    'productId': line.productId,
    'productName': line.productName,
    'quantite': line.quantite,
    'venduAuPoids': line.venduAuPoids,
    'prixAchatUnitaire': line.prixAchatUnitaire,
  };

  static Map<String, dynamic> _paymentToMap(PurchaseInvoicePayment p) => {
    'id': p.id,
    'montant': p.montant,
    'date': Timestamp.fromDate(p.date),
    'modePaiement': p.modePaiement?.name,
  };

  static PurchaseInvoice _fromFirestore(String id, Map<String, dynamic> data) =>
      PurchaseInvoice(
        id: id,
        date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        dateReception: (data['dateReception'] as Timestamp?)?.toDate(),
        numeroFournisseur: data['numeroFournisseur'] as String?,
        fournisseurId: data['fournisseurId'] as String?,
        fournisseurNom: data['fournisseurNom'] as String?,
        lignes:
            (data['lignes'] as List<dynamic>?)
                ?.map((m) => _lineFromMap(m as Map<String, dynamic>))
                .toList() ??
            const [],
        paiements:
            (data['paiements'] as List<dynamic>?)
                ?.map((m) => _paymentFromMap(m as Map<String, dynamic>))
                .toList() ??
            const [],
        tvaRate: (data['tvaRate'] as num?)?.toDouble() ?? 0,
        discount: discountFromMap(data['discount'] as Map<String, dynamic>?),
        notes: data['notes'] as String?,
      );

  static PurchaseInvoiceLine _lineFromMap(Map<String, dynamic> m) =>
      PurchaseInvoiceLine(
        productId: m['productId'] as String?,
        productName: m['productName'] as String? ?? '',
        quantite: (m['quantite'] as num?)?.toDouble() ?? 0,
        venduAuPoids: m['venduAuPoids'] as bool? ?? false,
        prixAchatUnitaire: (m['prixAchatUnitaire'] as num?)?.toDouble() ?? 0,
      );

  static PurchaseInvoicePayment _paymentFromMap(Map<String, dynamic> m) =>
      PurchaseInvoicePayment(
        id: m['id'] as String? ?? '',
        montant: (m['montant'] as num?)?.toDouble() ?? 0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        modePaiement: m['modePaiement'] == null
            ? null
            : PurchasePaymentMethod.values.firstWhere(
                (p) => p.name == m['modePaiement'],
                orElse: () => PurchasePaymentMethod.especes,
              ),
      );
}
