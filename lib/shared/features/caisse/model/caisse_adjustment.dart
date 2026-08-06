/// Controlled reasons for pulling cash out of the till — kept separate
/// from [AjoutMotif] since "why money leaves" and "why money arrives"
/// aren't the same list, and a free-text field alone wouldn't let the
/// admin later run real statistics on where cash actually goes.
enum RetraitMotif {
  versementCoffre,
  depense,
  remiseAdmin,
  transfertAutreCaisse,
  autre,
}

extension RetraitMotifLabel on RetraitMotif {
  String get label => switch (this) {
    RetraitMotif.versementCoffre => 'Versement au coffre',
    RetraitMotif.depense => 'Dépense',
    RetraitMotif.remiseAdmin => 'Remise à l\'admin',
    RetraitMotif.transfertAutreCaisse => 'Transfert vers une autre caisse',
    RetraitMotif.autre => 'Autre',
  };
}

enum AjoutMotif {
  monnaie,
  apportFonds,
  transfertAutreCaisse,
  correctionAutorisee,
  autre,
}

extension AjoutMotifLabel on AjoutMotif {
  String get label => switch (this) {
    AjoutMotif.monnaie => 'Monnaie',
    AjoutMotif.apportFonds => 'Apport de fonds',
    AjoutMotif.transfertAutreCaisse => 'Transfert d\'une autre caisse',
    AjoutMotif.correctionAutorisee => 'Correction autorisée',
    AjoutMotif.autre => 'Autre',
  };
}

/// A manual cash movement that isn't a sale, a client payment or an
/// expense — e.g. an admin pulling cash out of a specific cashier's till
/// to deposit at the bank ([montant] negative) or topping it up with
/// extra change ([montant] positive). Every dinar in or out of the
/// register is tied to [targetEmployeeId]'s session, so it can never be
/// absorbed into the wrong cashier's reconciliation just because two
/// sessions happened to be open at the same time.
class CaisseAdjustment {
  final String id;
  final DateTime date;
  final double montant;
  final String targetEmployeeId;
  final String motif;
  final String? note;

  /// Who actually performed the action (often the admin, sometimes the
  /// cashier themselves) — distinct from [targetEmployeeId], whose till
  /// the money moved in or out of.
  final String recordedByName;

  const CaisseAdjustment({
    required this.id,
    required this.date,
    required this.montant,
    required this.targetEmployeeId,
    required this.motif,
    this.note,
    required this.recordedByName,
  });
}
