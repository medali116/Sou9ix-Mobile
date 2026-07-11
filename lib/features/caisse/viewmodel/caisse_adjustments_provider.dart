import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/caisse/model/caisse_adjustment.dart';

class CaisseAdjustmentsNotifier extends StateNotifier<List<CaisseAdjustment>> {
  CaisseAdjustmentsNotifier(this._ref) : super(const []);

  final Ref _ref;

  void add({
    required double montant,
    required String targetEmployeeId,
    required String motif,
    String? note,
  }) {
    state = [
      CaisseAdjustment(
        id: 'cadj${DateTime.now().microsecondsSinceEpoch}',
        date: DateTime.now(),
        montant: montant,
        targetEmployeeId: targetEmployeeId,
        motif: motif,
        note: note,
        recordedByName: _ref.read(authProvider)?.nom ?? 'Inconnu',
      ),
      ...state,
    ];
  }
}

final caisseAdjustmentsProvider =
    StateNotifierProvider<CaisseAdjustmentsNotifier, List<CaisseAdjustment>>(
      (ref) => CaisseAdjustmentsNotifier(ref),
    );
