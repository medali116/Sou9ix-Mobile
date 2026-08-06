import 'package:flutter/material.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';

/// The 8 sections the Journal d'activité can be filtered to, and what the
/// dashboard's "Activités récentes" card counts.
enum ActivityCategory {
  tickets,
  produits,
  clients,
  fournisseurs,
  prix,
  stock,
  employes,
  depenses,
}

extension ActivityCategoryLabel on ActivityCategory {
  String get label => switch (this) {
    ActivityCategory.tickets => 'Tickets',
    ActivityCategory.produits => 'Produits',
    ActivityCategory.clients => 'Clients',
    ActivityCategory.fournisseurs => 'Fournisseurs',
    ActivityCategory.prix => 'Prix',
    ActivityCategory.stock => 'Stock',
    ActivityCategory.employes => 'Employés',
    ActivityCategory.depenses => 'Dépenses',
  };

  IconData get icon => switch (this) {
    ActivityCategory.tickets => Icons.receipt_long_rounded,
    ActivityCategory.produits => Icons.inventory_2_rounded,
    ActivityCategory.clients => Icons.people_rounded,
    ActivityCategory.fournisseurs => Icons.local_shipping_rounded,
    ActivityCategory.prix => Icons.sell_rounded,
    ActivityCategory.stock => Icons.warehouse_rounded,
    ActivityCategory.employes => Icons.badge_rounded,
    ActivityCategory.depenses => Icons.wallet_rounded,
  };
}

/// How sensitive/reversible an action is — drives the colored dot/badge in
/// the journal so an admin can tell what happened at a glance without
/// reading every line: green additions, blue edits, orange money movements,
/// red deletions.
enum ActivityImpact { ajout, modification, paiement, suppression }

extension ActivityImpactStyle on ActivityImpact {
  String get label => switch (this) {
    ActivityImpact.ajout => 'Ajout',
    ActivityImpact.modification => 'Modification',
    ActivityImpact.paiement => 'Paiement',
    ActivityImpact.suppression => 'Suppression',
  };

  Color get color => switch (this) {
    ActivityImpact.ajout => AppColors.success,
    ActivityImpact.modification => AppColors.info,
    ActivityImpact.paiement => AppColors.warning,
    ActivityImpact.suppression => AppColors.danger,
  };

  /// Whether this action type is sensitive enough to count toward the
  /// "Actions sensibles uniquement" filter and an employee's risk stats.
  bool get isSensitive =>
      this == ActivityImpact.suppression || this == ActivityImpact.modification;
}

/// One audit-trail entry — every sensitive operation in the app (price
/// change, stock correction, deletion, payment, new record...) is logged
/// here automatically, tagged with who did it, so an absent admin can
/// review exactly what happened while they were away instead of trusting
/// the team's word for it.
class ActivityLogEntry {
  final String id;
  final DateTime date;
  final String employeeName;
  final ActivityCategory category;
  final ActivityImpact impact;

  /// Short past-tense action label, e.g. "Ticket supprimé", "Prix modifié".
  final String action;

  /// What the action was about — a product/client/supplier name, a ticket
  /// reference, an employee name...
  final String? targetName;

  /// For a field-level change: which field, and its before/after value.
  final String? champ;
  final String? ancienneValeur;
  final String? nouvelleValeur;

  /// Signed numeric delta for a before/after change on a quantity/amount
  /// (e.g. stock -2.0, price +0.200) — null for non-numeric fields like a
  /// name or an address.
  final double? difference;

  /// Free-text reason, when one was captured (e.g. "Produit cassé",
  /// "Erreur de saisie").
  final String? motif;

  /// For a ticket/expense/payment amount, so the log reads at a glance
  /// without following the reference back to its source record.
  final double? montant;

  /// Platform the action was performed from (Android/iOS/Windows/...) —
  /// captured automatically at log time.
  final String? platform;

  const ActivityLogEntry({
    required this.id,
    required this.date,
    required this.employeeName,
    required this.category,
    required this.impact,
    required this.action,
    this.targetName,
    this.champ,
    this.ancienneValeur,
    this.nouvelleValeur,
    this.difference,
    this.motif,
    this.montant,
    this.platform,
  });

  bool get isFieldChange =>
      champ != null && ancienneValeur != null && nouvelleValeur != null;
}
