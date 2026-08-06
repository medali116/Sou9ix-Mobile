import 'package:flutter/material.dart';

import 'package:sou9ix/shared/core/models/discount.dart';
import 'package:sou9ix/shared/features/pos/model/cart_item.dart';

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
}
