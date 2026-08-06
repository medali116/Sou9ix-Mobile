import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';
import 'package:sou9ix/shared/features/suppliers/model/supplier.dart';
import 'package:sou9ix/shared/features/suppliers/service/suppliers_repository.dart';

/// Null while this device doesn't know its shop code yet (e.g. the Admin
/// app's brief pre-signup window) — [SuppliersNotifier] simply stays empty
/// until a repository becomes available.
final suppliersRepositoryProvider = Provider<SuppliersRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return SuppliersRepository(FirebaseFirestore.instance, shopCode);
});

class SuppliersNotifier extends StateNotifier<List<Supplier>> {
  SuppliersNotifier(this._ref, this._repo) : super(const []) {
    unawaited(_init());
  }

  final Ref _ref;
  final SuppliersRepository? _repo;
  StreamSubscription<List<Supplier>>? _sub;

  static List<Supplier> _seed() => const [
    Supplier(
      id: 'f1',
      nom: 'Grossiste Fruits Secs Sfax',
      telephone: '+216 74 111 222',
      adresse: 'Zone industrielle, Sfax',
    ),
    Supplier(
      id: 'f2',
      nom: 'Torréfaction Ben Ali',
      telephone: '+216 71 333 444',
      adresse: 'Rue de la Torréfaction, Tunis',
    ),
  ];

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.bootstrapIfEmpty(_seed());
    _sub = repo.watchAll().listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> upsert(Supplier supplier) async {
    final exists = state.any((s) => s.id == supplier.id);
    if (exists) {
      final old = state.firstWhere((s) => s.id == supplier.id);
      if (old.nom != supplier.nom) {
        logActivity(
          _ref,
          category: ActivityCategory.fournisseurs,
          impact: ActivityImpact.modification,
          action: 'Fournisseur modifié',
          targetName: supplier.nom,
          champ: 'Nom',
          ancienneValeur: old.nom,
          nouvelleValeur: supplier.nom,
        );
      }
      if (old.telephone != supplier.telephone) {
        logActivity(
          _ref,
          category: ActivityCategory.fournisseurs,
          impact: ActivityImpact.modification,
          action: 'Fournisseur modifié',
          targetName: supplier.nom,
          champ: 'Téléphone',
          ancienneValeur: old.telephone,
          nouvelleValeur: supplier.telephone,
        );
      }
      if (old.adresse != supplier.adresse) {
        logActivity(
          _ref,
          category: ActivityCategory.fournisseurs,
          impact: ActivityImpact.modification,
          action: 'Fournisseur modifié',
          targetName: supplier.nom,
          champ: 'Adresse',
          ancienneValeur: old.adresse,
          nouvelleValeur: supplier.adresse,
        );
      }
    } else {
      logActivity(
        _ref,
        category: ActivityCategory.fournisseurs,
        impact: ActivityImpact.ajout,
        action: 'Nouveau fournisseur',
        targetName: supplier.nom,
      );
    }
    state = exists
        ? [for (final s in state) if (s.id == supplier.id) supplier else s]
        : [...state, supplier];
    await _repo?.upsert(supplier);
  }

  /// Soft delete — the supplier lands in the trash (restore/purge from
  /// there) instead of vanishing for good, matching products/clients/sales.
  Future<void> remove(String id, {required String motif}) async {
    final matches = state.where((s) => s.id == id);
    final supplier = matches.isEmpty ? null : matches.first;
    state = state.where((s) => s.id != id).toList();
    if (supplier != null) {
      _ref.read(suppliersTrashProvider.notifier).add(supplier);
      logActivity(
        _ref,
        category: ActivityCategory.fournisseurs,
        impact: ActivityImpact.suppression,
        action: 'Fournisseur supprimé',
        targetName: supplier.nom,
        motif: motif,
      );
    }
    await _repo?.remove(id);
  }
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, List<Supplier>>(
      (ref) => SuppliersNotifier(ref, ref.watch(suppliersRepositoryProvider)),
    );
