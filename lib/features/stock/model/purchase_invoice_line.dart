/// One product line within a [PurchaseInvoice]. `productName` is a
/// snapshot taken at the time the invoice was recorded, so the invoice
/// still reads correctly even if the product is later renamed or deleted.
class PurchaseInvoiceLine {
  final String? productId;
  final String productName;
  final double quantite;
  final bool venduAuPoids;
  final double prixAchatUnitaire;

  const PurchaseInvoiceLine({
    this.productId,
    required this.productName,
    required this.quantite,
    required this.venduAuPoids,
    required this.prixAchatUnitaire,
  });

  double get montant => quantite * prixAchatUnitaire;
  String get unite => venduAuPoids ? 'kg' : 'pcs';
}
