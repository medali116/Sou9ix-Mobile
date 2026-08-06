enum RetourMotif { peremption, casse, vol, autre }

extension RetourMotifLabel on RetourMotif {
  String get label {
    switch (this) {
      case RetourMotif.peremption:
        return 'Péremption';
      case RetourMotif.casse:
        return 'Casse';
      case RetourMotif.vol:
        return 'Vol';
      case RetourMotif.autre:
        return 'Autre';
    }
  }
}

/// A product write-off: stock that left inventory without being sold
/// (expired, damaged, stolen…). [productName] and [prixAchatUnitaire] are
/// snapshots taken at the time of the return, so the loss value and label
/// stay meaningful even if the product is later renamed, repriced, or
/// deleted from the catalogue.
class StockReturn {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final double quantite;
  final bool venduAuPoids;
  final double prixAchatUnitaire;
  final RetourMotif motif;
  final String? note;

  const StockReturn({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.quantite,
    required this.venduAuPoids,
    required this.prixAchatUnitaire,
    required this.motif,
    this.note,
  });

  double get perte => quantite * prixAchatUnitaire;
  String get unite => venduAuPoids ? 'kg' : 'pcs';
}
