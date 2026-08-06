import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/caisse/model/caisse_adjustment.dart';
import 'package:sou9ix/shared/features/caisse/service/caisse_adjustments_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

final caisseAdjustmentsRepositoryProvider =
    Provider<CaisseAdjustmentsRepository?>((ref) {
      final shopCode = ref.watch(shopCodeProvider);
      if (shopCode == null) return null;
      return CaisseAdjustmentsRepository(FirebaseFirestore.instance, shopCode);
    });

class CaisseAdjustmentsNotifier extends StateNotifier<List<CaisseAdjustment>> {
  CaisseAdjustmentsNotifier(this._ref, this._repo) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final Ref _ref;
  final CaisseAdjustmentsRepository? _repo;
  StreamSubscription<List<CaisseAdjustment>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add({
    required double montant,
    required String targetEmployeeId,
    required String motif,
    String? note,
  }) async {
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
    await _repo?.add(adjustment);
  }
}

final caisseAdjustmentsProvider =
    StateNotifierProvider<CaisseAdjustmentsNotifier, List<CaisseAdjustment>>(
      (ref) => CaisseAdjustmentsNotifier(
        ref,
        ref.watch(caisseAdjustmentsRepositoryProvider),
      ),
    );
