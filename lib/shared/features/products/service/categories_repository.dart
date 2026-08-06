import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:sou9ix/shared/features/products/model/category.dart';

/// [ProductCategory.icon] is an [IconData], which doesn't serialize to
/// Firestore directly — every category (seeded or user-created) picks from
/// this small fixed palette instead, stored as a string key.
/// [ProductFormScreen._createNewCategory] always uses `Icons.category_rounded`
/// for on-the-fly categories, so `'category'` covers every user-created one;
/// the rest are the seeded categories' icons.
const categoryIconPalette = <String, IconData>{
  'eco': Icons.eco_rounded,
  'fire': Icons.local_fire_department_rounded,
  'coffee': Icons.coffee_rounded,
  'kitchen': Icons.kitchen_rounded,
  'drink': Icons.local_drink_rounded,
  'category': Icons.category_rounded,
};

IconData iconForKey(String? key) =>
    categoryIconPalette[key] ?? Icons.category_rounded;

String keyForIcon(IconData icon) => categoryIconPalette.entries
    .firstWhere(
      (e) => e.value == icon,
      orElse: () => const MapEntry('category', Icons.category_rounded),
    )
    .key;

class CategoriesRepository {
  CategoriesRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore
      .collection('shops')
      .doc(_shopCode)
      .collection('categories');

  Stream<List<ProductCategory>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> add(ProductCategory category) =>
      _collection.doc(category.id).set(_toFirestore(category));

  Future<void> bootstrapIfEmpty(List<ProductCategory> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final category in seed) {
      batch.set(_collection.doc(category.id), _toFirestore(category));
    }
    await batch.commit();
  }

  static Map<String, dynamic> _toFirestore(ProductCategory category) => {
    'name': category.name,
    'iconKey': keyForIcon(category.icon),
  };

  static ProductCategory _fromFirestore(String id, Map<String, dynamic> data) =>
      ProductCategory(
        id: id,
        name: data['name'] as String? ?? '',
        icon: iconForKey(data['iconKey'] as String?),
      );
}
