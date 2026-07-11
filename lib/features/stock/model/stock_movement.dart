import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';

/// Why a product's stock changed — every entry point that actually
/// mutates [Product.stock] (sale checkout, invoice receipt, manual
/// correction) records one of these so a product's full movement history
/// can be reconstructed instead of only showing its past sales.
enum StockMovementType { achat, vente, ajustement }

extension StockMovementTypeStyle on StockMovementType {
  String get label => switch (this) {
    StockMovementType.achat => 'Achat fournisseur',
    StockMovementType.vente => 'Vente',
    StockMovementType.ajustement => 'Ajustement manuel',
  };

  IconData get icon => switch (this) {
    StockMovementType.achat => Icons.local_shipping_rounded,
    StockMovementType.vente => Icons.point_of_sale_rounded,
    StockMovementType.ajustement => Icons.tune_rounded,
  };

  Color get color => switch (this) {
    StockMovementType.achat => AppColors.success,
    StockMovementType.vente => AppColors.danger,
    StockMovementType.ajustement => AppColors.info,
  };
}

/// One stock change for one product — [quantite] is signed (positive for
/// stock coming in, negative for stock going out) so the sign alone tells
/// the direction without needing to branch on [type].
class StockMovement {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final StockMovementType type;
  final double quantite;
  final double stockApres;

  /// What this movement is tied to, e.g. "Ticket #A1B2C3" or "Facture
  /// #FA-002" — lets the admin jump from a stock change to its source.
  final String? reference;
  final String? motif;
  final String employeeName;

  const StockMovement({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantite,
    required this.stockApres,
    this.reference,
    this.motif,
    required this.employeeName,
  });

  double get stockAvant => stockApres - quantite;
}
