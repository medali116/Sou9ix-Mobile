import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/employees/model/shift.dart';

class ShiftsNotifier extends StateNotifier<List<Shift>> {
  ShiftsNotifier() : super(const []);

  /// Opens a cash-register session for [employeeId] with a starting float
  /// of [fondInitial] — a no-op if they already have one open.
  void clockIn(
    String employeeId, {
    double fondInitial = 0,
    String fondSource = 'Report de caisse',
  }) {
    if (state.any((s) => s.employeeId == employeeId && s.enCours)) return;
    state = [
      Shift(
        id: 'sh${DateTime.now().microsecondsSinceEpoch}',
        employeeId: employeeId,
        clockIn: DateTime.now(),
        fondInitial: fondInitial,
        fondSource: fondSource,
      ),
      ...state,
    ];
  }

  /// Closes [shiftId]'s cash session with what was physically counted in
  /// the till — the reconciliation against expected cash is computed
  /// separately (see `cash_session_provider.dart`) since it needs sales/
  /// expense/payment data this notifier doesn't have.
  void closeCashSession(
    String shiftId, {
    required double montantCompte,
    String? ecartMotif,
    String? ecartCommentaire,
  }) {
    state = [
      for (final s in state)
        if (s.id == shiftId)
          s.copyWith(
            clockOut: DateTime.now(),
            montantCompte: montantCompte,
            ecartMotif: ecartMotif,
            ecartCommentaire: ecartCommentaire,
          )
        else
          s,
    ];
  }
}

final shiftsProvider = StateNotifierProvider<ShiftsNotifier, List<Shift>>(
  (ref) => ShiftsNotifier(),
);

final openShiftsProvider = Provider<List<Shift>>((ref) {
  return ref.watch(shiftsProvider).where((s) => s.enCours).toList();
});

final shiftsForEmployeeProvider = Provider.family<List<Shift>, String>((
  ref,
  employeeId,
) {
  return ref
      .watch(shiftsProvider)
      .where((s) => s.employeeId == employeeId)
      .toList();
});

/// Who sales get attributed to right now — set on clock-in, cleared on
/// clock-out. Mirrors the existing `pendingClientProvider` pattern.
final activeEmployeeProvider = StateProvider<String?>((ref) => null);

/// Set when the current employee taps "Plus tard" on "Ouverture de
/// caisse" — lets them browse the rest of the app without a shift open.
/// Reset on logout/employee switch so the next person is asked again;
/// the actual anti-fraud check still happens at sale time, not here.
final caisseOpeningDeferredProvider = StateProvider<bool>((ref) => false);
