import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';

class SuppliersNotifier extends StateNotifier<List<Supplier>> {
  SuppliersNotifier(this._ref) : super(_seed());

  final Ref _ref;

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
      state = [
        for (final s in state)
          if (s.id == supplier.id) supplier else s,
      ];
    } else {
      state = [...state, supplier];
      logActivity(
        _ref,
        category: ActivityCategory.fournisseurs,
        impact: ActivityImpact.ajout,
        action: 'Nouveau fournisseur',
        targetName: supplier.nom,
      );
    }
  }

  /// Soft delete — the supplier lands in the trash (restore/purge from
  /// there) instead of vanishing for good, matching products/clients/sales.
  void remove(String id, {required String motif}) {
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
  }
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, List<Supplier>>(
      (ref) => SuppliersNotifier(ref),
    );
