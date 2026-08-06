import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';

/// Current stock valued at cost (Σ stock × prix d'achat) — a snapshot, not
/// a real time series (the app doesn't keep historical stock levels, so a
/// fabricated "évolution du stock" chart would be dishonest).
final currentStockValueProvider = Provider<double>((ref) {
  return ref
      .watch(productsProvider)
      .fold<double>(0, (sum, p) => sum + p.stock * p.prixAchat);
});
