import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many cart lines an employee has removed before checkout during
/// their current shift — routine (a customer changes their mind before
/// paying), so it's a lightweight per-employee tally rather than a full
/// `ActivityLogEntry`, keeping the real audit log free of that noise
/// while still giving the session-detail screen a count. Reset to 0 when
/// that employee opens a new shift.
class CartRemovalNotifier extends StateNotifier<Map<String, int>> {
  CartRemovalNotifier() : super(const {});

  void increment(String employeeId) =>
      state = {...state, employeeId: (state[employeeId] ?? 0) + 1};

  void reset(String employeeId) => state = {...state, employeeId: 0};
}

final cartRemovalProvider =
    StateNotifierProvider<CartRemovalNotifier, Map<String, int>>(
      (ref) => CartRemovalNotifier(),
    );
