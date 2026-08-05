import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/returns/model/stock_return.dart';
import 'package:sou9ix/features/returns/service/stock_returns_repository.dart';

class StockReturnsNotifier extends StateNotifier<List<StockReturn>> {
  StockReturnsNotifier({
    required String? shopCode,
    StockReturnsRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? StockReturnsRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((returns) => state = returns);
    }
  }

  final StockReturnsRepository? _repo;
  StreamSubscription<List<StockReturn>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Optimistically shows the new loss right away, then confirms it against
  /// Firestore — rolled back (and the error rethrown so the caller can tell
  /// the user) if the write fails, instead of silently pretending it saved.
  Future<void> add(StockReturn stockReturn) async {
    final previous = state;
    state = [stockReturn, ...state];
    try {
      await _repo?.add(stockReturn);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final previous = state;
    state = state.where((r) => r.id != id).toList();
    try {
      await _repo?.remove(id);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final stockReturnsProvider =
    StateNotifierProvider<StockReturnsNotifier, List<StockReturn>>(
      (ref) =>
          StockReturnsNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );

final totalLossProvider = Provider<double>((ref) {
  return ref.watch(stockReturnsProvider).fold(0.0, (sum, r) => sum + r.perte);
});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final todayLossProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(stockReturnsProvider)
      .where((r) => _isSameDay(r.date, now))
      .fold(0.0, (sum, r) => sum + r.perte);
});

final thisMonthLossProvider = Provider<double>((ref) {
  final now = DateTime.now();
  return ref
      .watch(stockReturnsProvider)
      .where((r) => r.date.year == now.year && r.date.month == now.month)
      .fold(0.0, (sum, r) => sum + r.perte);
});

final lastMonthLossProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  return ref
      .watch(stockReturnsProvider)
      .where(
        (r) => r.date.year == lastMonth.year && r.date.month == lastMonth.month,
      )
      .fold(0.0, (sum, r) => sum + r.perte);
});

/// Today's loss total broken down by [RetourMotif], in enum order —
/// feeds the "Aujourd'hui : Péremption 4 DT · Casse 2 DT…" summary row.
final todayLossByMotifProvider = Provider<Map<RetourMotif, double>>((ref) {
  final now = DateTime.now();
  final byMotif = <RetourMotif, double>{};
  for (final r in ref.watch(stockReturnsProvider)) {
    if (!_isSameDay(r.date, now)) continue;
    byMotif[r.motif] = (byMotif[r.motif] ?? 0) + r.perte;
  }
  return byMotif;
});

/// All-time loss broken down by [RetourMotif] — feeds the répartition pie
/// chart.
final lossByMotifProvider = Provider<Map<RetourMotif, double>>((ref) {
  final byMotif = <RetourMotif, double>{};
  for (final r in ref.watch(stockReturnsProvider)) {
    byMotif[r.motif] = (byMotif[r.motif] ?? 0) + r.perte;
  }
  return byMotif;
});

class ProductLossStat {
  final String productId;
  final String productName;
  final double totalPerte;
  final int occurrences;

  const ProductLossStat({
    required this.productId,
    required this.productName,
    required this.totalPerte,
    required this.occurrences,
  });
}

/// Products ranked by total value lost, highest first — feeds "Produits
/// les plus perdus".
final mostLostProductsProvider = Provider<List<ProductLossStat>>((ref) {
  final byProduct = <String, ProductLossStat>{};
  for (final r in ref.watch(stockReturnsProvider)) {
    final existing = byProduct[r.productId];
    byProduct[r.productId] = ProductLossStat(
      productId: r.productId,
      productName: r.productName,
      totalPerte: (existing?.totalPerte ?? 0) + r.perte,
      occurrences: (existing?.occurrences ?? 0) + 1,
    );
  }
  final list = byProduct.values.toList()
    ..sort((a, b) => b.totalPerte.compareTo(a.totalPerte));
  return list;
});

/// Products lost 3 or more times in the last 7 days — surfaces a recurring
/// shrinkage problem (a shelf that keeps expiring, a till that keeps coming
/// up short) instead of letting it blend into a long list of one-offs.
final frequentLossAlertsProvider = Provider<List<ProductLossStat>>((ref) {
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final byProduct = <String, ProductLossStat>{};
  for (final r in ref.watch(stockReturnsProvider)) {
    if (r.date.isBefore(cutoff)) continue;
    final existing = byProduct[r.productId];
    byProduct[r.productId] = ProductLossStat(
      productId: r.productId,
      productName: r.productName,
      totalPerte: (existing?.totalPerte ?? 0) + r.perte,
      occurrences: (existing?.occurrences ?? 0) + 1,
    );
  }
  return byProduct.values.where((s) => s.occurrences >= 3).toList()
    ..sort((a, b) => b.occurrences.compareTo(a.occurrences));
});

// ---- List filters (search / motif / date range) ----

enum ReturnsDateFilter { toutes, aujourdhui, jours7, jours30, personnalise }

extension ReturnsDateFilterLabel on ReturnsDateFilter {
  String get label => switch (this) {
    ReturnsDateFilter.toutes => 'Tout',
    ReturnsDateFilter.aujourdhui => 'Aujourd\'hui',
    ReturnsDateFilter.jours7 => '7 jours',
    ReturnsDateFilter.jours30 => '30 jours',
    ReturnsDateFilter.personnalise => 'Personnalisé',
  };
}

final returnsSearchProvider = StateProvider<String>((ref) => '');
final returnsMotifFilterProvider = StateProvider<RetourMotif?>((ref) => null);
final returnsDateFilterProvider = StateProvider<ReturnsDateFilter>(
  (ref) => ReturnsDateFilter.toutes,
);
final returnsCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// [stockReturnsProvider] after search + motif + date filters, newest
/// first (the repository stream already yields newest-first, but this is
/// re-derived rather than assumed so filtering never depends on that).
final filteredStockReturnsProvider = Provider<List<StockReturn>>((ref) {
  final query = ref.watch(returnsSearchProvider).trim().toLowerCase();
  final motif = ref.watch(returnsMotifFilterProvider);
  final dateFilter = ref.watch(returnsDateFilterProvider);
  final customRange = ref.watch(returnsCustomRangeProvider);
  final now = DateTime.now();

  final filtered = ref.watch(stockReturnsProvider).where((r) {
    if (motif != null && r.motif != motif) return false;
    switch (dateFilter) {
      case ReturnsDateFilter.toutes:
        break;
      case ReturnsDateFilter.aujourdhui:
        if (!_isSameDay(r.date, now)) return false;
      case ReturnsDateFilter.jours7:
        if (r.date.isBefore(now.subtract(const Duration(days: 7)))) {
          return false;
        }
      case ReturnsDateFilter.jours30:
        if (r.date.isBefore(now.subtract(const Duration(days: 30)))) {
          return false;
        }
      case ReturnsDateFilter.personnalise:
        if (customRange == null) break;
        final start = DateTime(
          customRange.start.year,
          customRange.start.month,
          customRange.start.day,
        );
        final end = DateTime(
          customRange.end.year,
          customRange.end.month,
          customRange.end.day,
        ).add(const Duration(days: 1));
        if (r.date.isBefore(start) || !r.date.isBefore(end)) return false;
    }
    if (query.isNotEmpty && !r.productName.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  return filtered;
});
