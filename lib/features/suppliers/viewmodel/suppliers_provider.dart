import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/suppliers/model/supplier.dart';

class SuppliersNotifier extends StateNotifier<List<Supplier>> {
  SuppliersNotifier() : super(_seed());

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
      state = [
        for (final s in state)
          if (s.id == supplier.id) supplier else s,
      ];
    } else {
      state = [...state, supplier];
    }
  }

  void remove(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final suppliersProvider =
    StateNotifierProvider<SuppliersNotifier, List<Supplier>>(
      (ref) => SuppliersNotifier(),
    );
