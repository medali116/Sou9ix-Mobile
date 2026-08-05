import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';

enum RetourMotif { peremption, casse, vol, retourFournisseur, autre }

extension RetourMotifLabel on RetourMotif {
  String get label {
    switch (this) {
      case RetourMotif.peremption:
        return 'Péremption';
      case RetourMotif.casse:
        return 'Casse';
      case RetourMotif.vol:
        return 'Vol';
      case RetourMotif.retourFournisseur:
        return 'Retour fournisseur';
      case RetourMotif.autre:
        return 'Autre';
    }
  }

  Color get color {
    switch (this) {
      case RetourMotif.peremption:
        return AppColors.warning;
      case RetourMotif.casse:
        return AppColors.purple;
      case RetourMotif.vol:
        return AppColors.danger;
      case RetourMotif.retourFournisseur:
        return AppColors.info;
      case RetourMotif.autre:
        return AppColors.textSecondary;
    }
  }

  IconData get icon {
    switch (this) {
      case RetourMotif.peremption:
        return Icons.event_busy_rounded;
      case RetourMotif.casse:
        return Icons.broken_image_outlined;
      case RetourMotif.vol:
        return Icons.report_gmailerrorred_rounded;
      case RetourMotif.retourFournisseur:
        return Icons.local_shipping_outlined;
      case RetourMotif.autre:
        return Icons.help_outline_rounded;
    }
  }
}

/// A product write-off: stock that left inventory without being sold
/// (expired, damaged, stolen, returned to a supplier…). [productName],
/// [prixAchatUnitaire] and [prixVenteUnitaire] are snapshots taken at the
/// time of the return, so the loss value and label stay meaningful even if
/// the product is later renamed, repriced, or deleted from the catalogue.
class StockReturn {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final double quantite;
  final bool venduAuPoids;
  final double prixAchatUnitaire;

  /// Snapshot of the sale price at the time of the loss — lets the
  /// analytics distinguish what the loss cost (achat) from what it would
  /// have been worth sold (vente). Defaults to 0 for returns recorded
  /// before this field existed.
  final double prixVenteUnitaire;
  final RetourMotif motif;
  final String? note;

  /// Who logged this loss — captured from the active session at creation
  /// time (not looked up later) so it stays accurate even if the employee
  /// is later renamed or removed from the roster.
  final String employeeName;
  final Uint8List? photoBytes;

  const StockReturn({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.quantite,
    required this.venduAuPoids,
    required this.prixAchatUnitaire,
    this.prixVenteUnitaire = 0,
    required this.motif,
    this.note,
    required this.employeeName,
    this.photoBytes,
  });

  double get perte => quantite * prixAchatUnitaire;
  double get valeurVentePerdue => quantite * prixVenteUnitaire;
  String get unite => venduAuPoids ? 'kg' : 'pcs';

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'productId': productId,
    'nomProduit': productName,
    'quantite': quantite,
    'venduAuPoids': venduAuPoids,
    'prixAchatUnitaire': prixAchatUnitaire,
    'prixVenteUnitaire': prixVenteUnitaire,
    'motif': motif.name,
    'note': note,
    'nomEmploye': employeeName,
    'photo': photoBytes == null ? null : base64Encode(photoBytes!),
  };

  factory StockReturn.fromMap(String id, Map<String, dynamic> map) =>
      StockReturn(
        id: id,
        date: DateTime.parse(map['date'] as String),
        productId: map['productId'] as String,
        productName: (map['nomProduit'] ?? map['productName']) as String,
        quantite: (map['quantite'] as num).toDouble(),
        venduAuPoids: map['venduAuPoids'] as bool,
        prixAchatUnitaire: (map['prixAchatUnitaire'] as num).toDouble(),
        prixVenteUnitaire: (map['prixVenteUnitaire'] as num?)?.toDouble() ?? 0,
        motif: RetourMotif.values.firstWhere(
          (m) => m.name == map['motif'],
          orElse: () => RetourMotif.autre,
        ),
        note: map['note'] as String?,
        employeeName: (map['nomEmploye'] as String?) ?? 'Inconnu',
        photoBytes: map['photo'] == null
            ? null
            : base64Decode(map['photo'] as String),
      );
}
