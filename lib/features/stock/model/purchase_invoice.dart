import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sou9ix/features/stock/model/purchase_invoice_line.dart';

enum PurchasePaymentMethod { especes, cheque, virement, carte }

extension PurchasePaymentMethodLabel on PurchasePaymentMethod {
  String get label {
    switch (this) {
      case PurchasePaymentMethod.especes:
        return 'Espèces';
      case PurchasePaymentMethod.cheque:
        return 'Chèque';
      case PurchasePaymentMethod.virement:
        return 'Virement';
      case PurchasePaymentMethod.carte:
        return 'Carte';
    }
  }

  IconData get icon {
    switch (this) {
      case PurchasePaymentMethod.especes:
        return Icons.payments_rounded;
      case PurchasePaymentMethod.cheque:
        return Icons.receipt_long_rounded;
      case PurchasePaymentMethod.virement:
        return Icons.account_balance_rounded;
      case PurchasePaymentMethod.carte:
        return Icons.credit_card_rounded;
    }
  }
}

/// One payment made toward a [PurchaseInvoice] — kept as a dated log
/// (instead of a single running total) so the invoice detail can show
/// *when* each installment was paid, not just how much is left.
class PurchaseInvoicePayment {
  final String id;
  final double montant;
  final DateTime date;
  final PurchasePaymentMethod? modePaiement;

  const PurchaseInvoicePayment({
    required this.id,
    required this.montant,
    required this.date,
    this.modePaiement,
  });

  /// Human-friendly receipt number derived from [id], e.g. "P-000012".
  String get reference {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length > 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
    return 'P-$tail';
  }
}

/// A supplier invoice — a single paper facture that can bundle several
/// products together (mirrors how a real "fournisseur" delivery note
/// works), with a photo of the paper invoice and partial-payment tracking:
/// the sum of [paiements] may be less than [montantTotal] when the shop
/// hasn't paid the supplier in full yet.
class PurchaseInvoice {
  final String id;
  final DateTime date;
  final String? fournisseurId;

  /// Supplier name snapshot taken when the invoice was recorded, so it
  /// still reads correctly even if the supplier is later renamed or deleted.
  final String? fournisseurNom;
  final Uint8List? photoBytes;
  final List<PurchaseInvoiceLine> lignes;
  final List<PurchaseInvoicePayment> paiements;

  const PurchaseInvoice({
    required this.id,
    required this.date,
    this.fournisseurId,
    this.fournisseurNom,
    this.photoBytes,
    required this.lignes,
    this.paiements = const [],
  });

  double get montantTotal => lignes.fold(0, (sum, l) => sum + l.montant);
  double get montantPaye => paiements.fold(0.0, (sum, p) => sum + p.montant);
  double get montantRestant =>
      (montantTotal - montantPaye).clamp(0, double.infinity);
  // Epsilon-compared to absorb floating-point drift from repeated partial payments.
  bool get soldee => montantRestant <= 0.001;

  /// Human-friendly invoice number derived from [id] (which is an opaque
  /// timestamp-based string), e.g. "FA-004821".
  String get reference {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length > 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
    return 'FA-$tail';
  }

  /// Date the invoice was fully settled (its last payment date), or null
  /// while it's still open.
  DateTime? get dateSolde {
    if (!soldee || paiements.isEmpty) return null;
    return paiements.map((p) => p.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Days between the invoice date and it being fully settled — null while
  /// still open. Used to compute a supplier's average "délai de paiement".
  int? get delaiPaiementJours {
    final solde = dateSolde;
    if (solde == null) return null;
    return solde.difference(date).inDays;
  }

  PurchaseInvoice copyWith({List<PurchaseInvoicePayment>? paiements}) =>
      PurchaseInvoice(
        id: id,
        date: date,
        fournisseurId: fournisseurId,
        fournisseurNom: fournisseurNom,
        photoBytes: photoBytes,
        lignes: lignes,
        paiements: paiements ?? this.paiements,
      );
}
