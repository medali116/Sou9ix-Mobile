import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shift.dart';

class ShiftsNotifier extends StateNotifier<List<Shift>> {
  ShiftsNotifier() : super(const []);

  void clockIn(String employeeId) {
    if (state.any((s) => s.employeeId == employeeId && s.enCours)) return;
    state = [
      Shift(
        id: 'sh${DateTime.now().microsecondsSinceEpoch}',
        employeeId: employeeId,
        clockIn: DateTime.now(),
      ),
      ...state,
    ];
  }

  void clockOut(String employeeId) {
    state = [
      for (final s in state)
        if (s.employeeId == employeeId && s.enCours)
          Shift(
            id: s.id,
            employeeId: s.employeeId,
            clockIn: s.clockIn,
            clockOut: DateTime.now(),
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
