import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/employees/model/shift.dart';
import 'package:sou9ix/shared/features/employees/service/shifts_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

final shiftsRepositoryProvider = Provider<ShiftsRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return ShiftsRepository(FirebaseFirestore.instance, shopCode);
});

class ShiftsNotifier extends StateNotifier<List<Shift>> {
  ShiftsNotifier(this._repo) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final ShiftsRepository? _repo;
  StreamSubscription<List<Shift>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Opens a cash-register session for [employeeId] with a starting float
  /// of [fondInitial] — a no-op if they already have one open.
  Future<void> clockIn(
    String employeeId, {
    double fondInitial = 0,
    String fondSource = 'Report de caisse',
  }) async {
    if (state.any((s) => s.employeeId == employeeId && s.enCours)) return;
    final shift = Shift(
      id: 'sh${DateTime.now().microsecondsSinceEpoch}',
      employeeId: employeeId,
      clockIn: DateTime.now(),
      fondInitial: fondInitial,
      fondSource: fondSource,
    );
    state = [shift, ...state];
    await _repo?.upsert(shift);
  }

  /// Closes [shiftId]'s cash session with what was physically counted in
  /// the till — the reconciliation against expected cash is computed
  /// separately (see `cash_session_provider.dart`) since it needs sales/
  /// expense/payment data this notifier doesn't have.
  Future<void> closeCashSession(
    String shiftId, {
    required double montantCompte,
    String? ecartMotif,
    String? ecartCommentaire,
  }) async {
    Shift? closed;
    state = [
      for (final s in state)
        if (s.id == shiftId)
          (closed = s.copyWith(
            clockOut: DateTime.now(),
            montantCompte: montantCompte,
            ecartMotif: ecartMotif,
            ecartCommentaire: ecartCommentaire,
          ))
        else
          s,
    ];
    if (closed != null) await _repo?.upsert(closed);
  }
}

final shiftsProvider = StateNotifierProvider<ShiftsNotifier, List<Shift>>(
  (ref) => ShiftsNotifier(ref.watch(shiftsRepositoryProvider)),
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
