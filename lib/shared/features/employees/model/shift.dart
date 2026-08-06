/// One work session for an employee, doubling as their cash-register
/// session: clocked in at [clockIn] with a starting float ([fondInitial]),
/// and, once they clock out, [clockOut] plus what they physically counted
/// in the till ([montantCompte]) — the difference against what the app
/// expects (sales/payments/expenses recorded during the session) is the
/// [ecart], with [ecartMotif]/[ecartCommentaire] required once it isn't
/// zero. A null [clockOut] means still on shift.
class Shift {
  final String id;
  final String employeeId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final double fondInitial;

  /// Where the starting float came from — e.g. "Report de caisse",
  /// "Remise par l'admin" or "Passation de Yassine" — so an admin
  /// reviewing a session never has to wonder who put the money in.
  final String fondSource;
  final double? montantCompte;
  final String? ecartMotif;
  final String? ecartCommentaire;

  const Shift({
    required this.id,
    required this.employeeId,
    required this.clockIn,
    this.clockOut,
    this.fondInitial = 0,
    this.fondSource = 'Report de caisse',
    this.montantCompte,
    this.ecartMotif,
    this.ecartCommentaire,
  });

  bool get enCours => clockOut == null;
  Duration get duree => (clockOut ?? DateTime.now()).difference(clockIn);

  Shift copyWith({
    DateTime? clockOut,
    double? montantCompte,
    String? ecartMotif,
    String? ecartCommentaire,
  }) => Shift(
    id: id,
    employeeId: employeeId,
    clockIn: clockIn,
    clockOut: clockOut ?? this.clockOut,
    fondInitial: fondInitial,
    montantCompte: montantCompte ?? this.montantCompte,
    ecartMotif: ecartMotif ?? this.ecartMotif,
    ecartCommentaire: ecartCommentaire ?? this.ecartCommentaire,
  );
}
