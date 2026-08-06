import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/returns/model/stock_return.dart';
import 'package:sou9ix/shared/features/returns/service/stock_returns_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

final stockReturnsRepositoryProvider = Provider<StockReturnsRepository?>((
  ref,
) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return StockReturnsRepository(FirebaseFirestore.instance, shopCode);
});

class StockReturnsNotifier extends StateNotifier<List<StockReturn>> {
  StockReturnsNotifier(this._repo) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final StockReturnsRepository? _repo;
  StreamSubscription<List<StockReturn>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void add(StockReturn stockReturn) {
    state = [stockReturn, ...state];
    unawaited(_repo?.add(stockReturn));
  }
}

final stockReturnsProvider =
    StateNotifierProvider<StockReturnsNotifier, List<StockReturn>>(
      (ref) => StockReturnsNotifier(ref.watch(stockReturnsRepositoryProvider)),
    );

final totalLossProvider = Provider<double>((ref) {
  return ref
      .watch(stockReturnsProvider)
      .fold(0.0, (total, r) => total + r.perte);
});
