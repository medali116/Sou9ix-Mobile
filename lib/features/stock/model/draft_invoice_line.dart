import 'dart:typed_data';

import 'package:sou9ix/features/products/model/product.dart';

/// One product line being staged into a supplier invoice, before the whole
/// invoice is submitted. Nothing is written to any provider until then —
/// [newProductDraft] is a fully-formed [Product] that simply hasn't been
/// upserted yet.
class DraftInvoiceLine {
  final Product? existingProduct;
  final Product? newProductDraft;
  final double quantite;
  final double prixAchatUnitaire;

  const DraftInvoiceLine({
    this.existingProduct,
    this.newProductDraft,
    required this.quantite,
    required this.prixAchatUnitaire,
  });

  String get productName => (existingProduct ?? newProductDraft)!.name;
  bool get venduAuPoids => (existingProduct ?? newProductDraft)!.venduAuPoids;
  String get emoji => (existingProduct ?? newProductDraft)!.emoji;
  Uint8List? get photoBytes => (existingProduct ?? newProductDraft)!.photoBytes;
  double get montant => quantite * prixAchatUnitaire;
}
