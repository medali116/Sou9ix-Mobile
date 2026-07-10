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
