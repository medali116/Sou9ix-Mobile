import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/caisse/model/caisse_adjustment.dart';
import 'package:sou9ix/features/caisse/service/caisse_adjustments_repository.dart';

class CaisseAdjustmentsNotifier extends StateNotifier<List<CaisseAdjustment>> {
  CaisseAdjustmentsNotifier(
    this._ref, {
    required String? shopCode,
    CaisseAdjustmentsRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? CaisseAdjustmentsRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((adjustments) => state = adjustments);
    }
  }

  final Ref _ref;
  final CaisseAdjustmentsRepository? _repo;
  StreamSubscription<List<CaisseAdjustment>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void add({
    required double montant,
    required String targetEmployeeId,
    required String motif,
    String? note,
  }) {
    final adjustment = CaisseAdjustment(
      id: 'cadj${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      montant: montant,
      targetEmployeeId: targetEmployeeId,
      motif: motif,
      note: note,
      recordedByName: _ref.read(authProvider)?.nom ?? 'Inconnu',
    );
    state = [adjustment, ...state];
    _repo?.add(adjustment);
  }
}

final caisseAdjustmentsProvider =
    StateNotifierProvider<CaisseAdjustmentsNotifier, List<CaisseAdjustment>>(
      (ref) => CaisseAdjustmentsNotifier(
        ref,
        shopCode: ref.watch(currentShopCodeProvider),
      ),
    );
