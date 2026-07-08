import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stock_return.dart';

class StockReturnsNotifier extends StateNotifier<List<StockReturn>> {
  StockReturnsNotifier() : super(const []);

  void add(StockReturn stockReturn) => state = [stockReturn, ...state];
}

final stockReturnsProvider = StateNotifierProvider<StockReturnsNotifier, List<StockReturn>>(
  (ref) => StockReturnsNotifier(),
);

final totalLossProvider = Provider<double>((ref) {
  return ref.watch(stockReturnsProvider).fold(0.0, (sum, r) => sum + r.perte);
});
