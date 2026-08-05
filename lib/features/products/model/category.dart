import 'package:flutter/material.dart';

/// Icon shown per category id — kept as a fixed, const lookup rather than
/// persisting `IconData` itself in Firestore: reconstructing an `IconData`
/// from a stored code point defeats Flutter's icon tree-shaking in release
/// builds (it can only keep glyphs it sees referenced as `const IconData`
/// literals), which would show missing/garbled icons. Any category id not
/// listed here (e.g. one created on the fly from the product form) falls
/// back to [_defaultCategoryIcon].
const _defaultCategoryIcon = Icons.category_rounded;

const Map<String, IconData> _knownCategoryIcons = {
  'fruits_secs': Icons.eco_rounded,
  'epices': Icons.local_fire_department_rounded,
  'cafe': Icons.coffee_rounded,
  'epicerie': Icons.kitchen_rounded,
  'boissons': Icons.local_drink_rounded,
};

IconData iconForCategory(String id) =>
    _knownCategoryIcons[id] ?? _defaultCategoryIcon;

class ProductCategory {
  final String id;
  final String name;
  final IconData icon;

  const ProductCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {'nom': name};

  factory ProductCategory.fromMap(String id, Map<String, dynamic> map) =>
      ProductCategory(
        id: id,
        name: (map['nom'] ?? map['name']) as String,
        icon: iconForCategory(id),
      );
}
