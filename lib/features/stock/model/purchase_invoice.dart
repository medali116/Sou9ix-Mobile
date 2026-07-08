import 'dart:typed_data';

import 'package:sou9ix/features/stock/model/purchase_invoice_line.dart';

/// A supplier invoice — a single paper facture that can bundle several
/// products together (mirrors how a real "fournisseur" delivery note
/// works), with a photo of the paper invoice and partial-payment tracking:
/// [montantPaye] may be less than [montantTotal] when the shop hasn't paid
/// the supplier in full yet.
class PurchaseInvoice {
  final String id;
  final DateTime date;
  final String? fournisseurId;
  /// Supplier name snapshot taken when the invoice was recorded, so it
  /// still reads correctly even if the supplier is later renamed or deleted.
  final String? fournisseurNom;
  final Uint8List? photoBytes;
  final List<PurchaseInvoiceLine> lignes;
  final double montantPaye;

  const PurchaseInvoice({
    required this.id,
    required this.date,
    this.fournisseurId,
    this.fournisseurNom,
    this.photoBytes,
    required this.lignes,
    required this.montantPaye,
  });

  double get montantTotal => lignes.fold(0, (sum, l) => sum + l.montant);
  double get montantRestant => (montantTotal - montantPaye).clamp(0, double.infinity);
  // Epsilon-compared to absorb floating-point drift from repeated partial payments.
  bool get soldee => montantRestant <= 0.001;

  PurchaseInvoice copyWith({double? montantPaye}) => PurchaseInvoice(
        id: id,
        date: date,
        fournisseurId: fournisseurId,
        fournisseurNom: fournisseurNom,
        photoBytes: photoBytes,
        lignes: lignes,
        montantPaye: montantPaye ?? this.montantPaye,
      );
}
