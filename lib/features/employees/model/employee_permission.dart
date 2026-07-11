/// Fine-grained actions an admin can grant or withhold per staff member —
/// configured on the employee's own page (Employés → fiche → Permissions).
///
/// Note: the app currently only has two *login* roles (Admin/Caissier —
/// see [UserRole]); a staff roster entry ([Employee]) isn't yet tied to an
/// individual login session, so this list is the source of truth an admin
/// configures, but it isn't enforced screen-by-screen yet. Wiring real
/// enforcement needs each cashier to sign in as a specific [Employee]
/// first.
enum EmployeePermission {
  creerTicket,
  annulerTicket,
  modifierQuantite,
  modifierPrixVente,
  encaisserClient,
  supprimerProduit,
  modifierMagasin,
  supprimerClient,
  supprimerFournisseur,
}

extension EmployeePermissionLabel on EmployeePermission {
  String get label => switch (this) {
    EmployeePermission.creerTicket => 'Créer un ticket',
    EmployeePermission.annulerTicket => 'Annuler un ticket',
    EmployeePermission.modifierQuantite => 'Modifier la quantité',
    EmployeePermission.modifierPrixVente => 'Modifier le prix de vente',
    EmployeePermission.encaisserClient => 'Enregistrer des paiements clients',
    EmployeePermission.supprimerProduit => 'Supprimer un produit',
    EmployeePermission.modifierMagasin =>
      'Modifier les informations du magasin',
    EmployeePermission.supprimerClient => 'Supprimer un client',
    EmployeePermission.supprimerFournisseur => 'Supprimer un fournisseur',
  };

  /// Which section of the permissions sheet this belongs under.
  PermissionCategory get category => switch (this) {
    EmployeePermission.creerTicket ||
    EmployeePermission.annulerTicket ||
    EmployeePermission.modifierQuantite ||
    EmployeePermission.modifierPrixVente => PermissionCategory.vente,
    EmployeePermission.encaisserClient ||
    EmployeePermission.supprimerClient => PermissionCategory.clients,
    EmployeePermission.supprimerFournisseur => PermissionCategory.fournisseurs,
    EmployeePermission.supprimerProduit => PermissionCategory.catalogue,
    EmployeePermission.modifierMagasin => PermissionCategory.magasin,
  };

  /// Destructive or store-wide actions — worth flagging visually since
  /// granting them to a cashier is a more consequential decision than the
  /// day-to-day sales permissions.
  bool get risky => switch (this) {
    EmployeePermission.annulerTicket ||
    EmployeePermission.supprimerProduit ||
    EmployeePermission.supprimerClient ||
    EmployeePermission.supprimerFournisseur ||
    EmployeePermission.modifierMagasin => true,
    _ => false,
  };
}

enum PermissionCategory { vente, clients, fournisseurs, catalogue, magasin }

extension PermissionCategoryLabel on PermissionCategory {
  String get label => switch (this) {
    PermissionCategory.vente => 'Vente',
    PermissionCategory.clients => 'Clients',
    PermissionCategory.fournisseurs => 'Fournisseurs',
    PermissionCategory.catalogue => 'Catalogue',
    PermissionCategory.magasin => 'Magasin',
  };
}

/// Sensible defaults for a rank-and-file cashier: day-to-day sales work is
/// allowed, anything destructive or store-wide is not.
const Set<EmployeePermission> defaultCashierPermissions = {
  EmployeePermission.creerTicket,
  EmployeePermission.annulerTicket,
  EmployeePermission.modifierQuantite,
  EmployeePermission.modifierPrixVente,
  EmployeePermission.encaisserClient,
};
