import 'package:flutter/material.dart';

import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/pos/model/cart_item.dart';

enum ModePaiement { especes, carte, credit }

extension ModePaiementLabel on ModePaiement {
  String get label {
    switch (this) {
      case ModePaiement.especes:
        return 'Espèces';
      case ModePaiement.carte:
        return 'Carte';
      case ModePaiement.credit:
        return 'Crédit';
    }
  }

  IconData get icon {
    switch (this) {
      case ModePaiement.especes:
        return Icons.payments_rounded;
      case ModePaiement.carte:
        return Icons.credit_card_rounded;
      case ModePaiement.credit:
        return Icons.menu_book_rounded;
    }
  }
}

class Sale {
  final String id;
  final DateTime dateHeure;
  final List<CartItem> lignes;
  final ModePaiement modePaiement;
  final String? clientId;
  final String? employeeId;

  /// Extra discount applied on top of the (already per-line-discounted)
  /// ticket subtotal, e.g. a cashier-granted rebate on the whole sale.
  final Discount discount;

  const Sale({
    required this.id,
    required this.dateHeure,
    required this.lignes,
    required this.modePaiement,
    this.clientId,
    this.employeeId,
    this.discount = const Discount.none(),
  });

  double get sousTotal => lignes.fold(0, (sum, l) => sum + l.sousTotal);
  double get total => discount.applyTo(sousTotal);
  int get nombreArticles => lignes.length;

  Map<String, dynamic> toMap() => {
    'dateHeure': dateHeure.toIso8601String(),
    'lignes': lignes.map((l) => l.toMap()).toList(),
    'modePaiement': modePaiement.name,
    'clientId': clientId,
    'employeeId': employeeId,
    'remise': discount.toMap(),
  };

  factory Sale.fromMap(String id, Map<String, dynamic> map) => Sale(
    id: id,
    dateHeure: DateTime.parse(map['dateHeure'] as String),
    lignes: (map['lignes'] as List<dynamic>? ?? [])
        .map((l) => CartItem.fromMap(l as Map<String, dynamic>))
        .toList(),
    modePaiement: ModePaiement.values.firstWhere(
      (m) => m.name == map['modePaiement'],
      orElse: () => ModePaiement.especes,
    ),
    clientId: map['clientId'] as String?,
    employeeId: map['employeeId'] as String?,
    discount: Discount.fromMap(
      (map['remise'] ?? map['discount']) as Map<String, dynamic>?,
    ),
  );
}
