/// One work session for an employee: clocked in at [clockIn], and, once
/// they clock out, [clockOut]. A null [clockOut] means still on shift.
class Shift {
  final String id;
  final String employeeId;
  final DateTime clockIn;
  final DateTime? clockOut;

  const Shift({
    required this.id,
    required this.employeeId,
    required this.clockIn,
    this.clockOut,
  });

  bool get enCours => clockOut == null;
  Duration get duree => (clockOut ?? DateTime.now()).difference(clockIn);
}
