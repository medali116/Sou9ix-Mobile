import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/service/suppliers_repository.dart';

class SuppliersNotifier extends StateNotifier<List<Supplier>> {
  /// [shopCode] is null when nobody's logged in yet — there's no shop to
  /// subscribe to, so the list just stays empty until a session with a shop
  /// code exists.
  SuppliersNotifier(this._ref, {required String? shopCode, SuppliersRepository? repository})
    : _repo = shopCode == null ? null : (repository ?? SuppliersRepository(shopCode: shopCode)),
      super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((suppliers) => state = suppliers);
    }
  }

  final Ref _ref;
  final SuppliersRepository? _repo;
  StreamSubscription<List<Supplier>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void upsert(Supplier supplier) {
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
    _repo?.upsert(supplier);
  }

  /// Soft delete — the supplier lands in the trash (restore/purge from
  /// there) instead of vanishing for good, matching products/clients/sales.
  void remove(String id, {required String motif}) {
    final matches = state.where((s) => s.id == id);
    final supplier = matches.isEmpty ? null : matches.first;
    if (supplier == null) return;
    _repo?.remove(id);
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
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, List<Supplier>>(
      (ref) => SuppliersNotifier(ref, shopCode: ref.watch(currentShopCodeProvider)),
    );
