import 'package:flutter/material.dart';

/// Which parts of the app an employee can work in — configured on the
/// employee's own page (Employés → fiche → Permissions).
///
/// Deliberately module-level, not per-action: an employee trusted with a
/// module should be able to work freely inside it (create a ticket, edit a
/// client, adjust stock) without a second gate on every button — the
/// accountability comes from the activity journal recording what they did,
/// not from blocking them beforehand. See [ActivityLogEntry].
///
/// Note: the app currently only has two *login* roles (Admin/Caissier —
/// see [UserRole]); a staff roster entry ([Employee]) isn't yet tied to an
/// individual login session, so this list is the source of truth an admin
/// configures, but it isn't enforced screen-by-screen yet. Wiring real
/// enforcement needs each cashier to sign in as a specific [Employee] first.
enum EmployeeModule {
  venteCaisse,
  clientsCredits,
  stockProduits,
  fournisseurs,
  rapportsFinanciers,
  administration,
}

extension EmployeeModuleLabel on EmployeeModule {
  String get label => switch (this) {
    EmployeeModule.venteCaisse => 'Vente & caisse',
    EmployeeModule.clientsCredits => 'Clients & crédits',
    EmployeeModule.stockProduits => 'Stock & produits',
    EmployeeModule.fournisseurs => 'Fournisseurs',
    EmployeeModule.rapportsFinanciers => 'Rapports financiers',
    EmployeeModule.administration => 'Administration',
  };

  /// Shown under the label — replaces the old per-action checklist as the
  /// way an admin sees what a module actually covers.
  String get description => switch (this) {
    EmployeeModule.venteCaisse => 'Créer, modifier et annuler des tickets',
    EmployeeModule.clientsCredits => 'Fiches clients et paiements/crédits',
    EmployeeModule.stockProduits => 'Catalogue, quantités et produits',
    EmployeeModule.fournisseurs => 'Fournisseurs et commandes',
    EmployeeModule.rapportsFinanciers => 'Statistiques, marges, bénéfices',
    EmployeeModule.administration => 'Employés et paramètres du magasin',
  };

  IconData get icon => switch (this) {
    EmployeeModule.venteCaisse => Icons.point_of_sale_rounded,
    EmployeeModule.clientsCredits => Icons.people_alt_rounded,
    EmployeeModule.stockProduits => Icons.inventory_2_rounded,
    EmployeeModule.fournisseurs => Icons.local_shipping_rounded,
    EmployeeModule.rapportsFinanciers => Icons.bar_chart_rounded,
    EmployeeModule.administration => Icons.admin_panel_settings_rounded,
  };

  /// Higher-trust areas worth flagging visually — granting these to a
  /// cashier is a more consequential decision than day-to-day sales access.
  bool get sensitive => switch (this) {
    EmployeeModule.fournisseurs ||
    EmployeeModule.rapportsFinanciers ||
    EmployeeModule.administration => true,
    _ => false,
  };
}

/// Sensible defaults for a rank-and-file cashier: day-to-day sales and
/// client work is allowed, everything store-wide or owner-level is not.
const Set<EmployeeModule> defaultCashierModules = {
  EmployeeModule.venteCaisse,
  EmployeeModule.clientsCredits,
};
