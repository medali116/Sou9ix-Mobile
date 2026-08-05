import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/expenses/model/expense.dart';
import 'package:sou9ix/features/expenses/service/expenses_repository.dart';

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  ExpensesNotifier(
    this._ref, {
    required String? shopCode,
    ExpensesRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? ExpensesRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((expenses) => state = expenses);
    }
  }

  final Ref _ref;
  final ExpensesRepository? _repo;
  StreamSubscription<List<Expense>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void add(Expense expense) {
    state = [expense, ...state];
    _repo?.upsert(expense);
    logActivity(
      _ref,
      category: ActivityCategory.depenses,
      impact: ActivityImpact.ajout,
      action: 'Dépense ajoutée',
      targetName: expense.label,
      montant: expense.montant,
    );
  }

  void update(Expense expense) {
    state = [
      for (final e in state)
        if (e.id == expense.id) expense else e,
    ];
    _repo?.upsert(expense);
  }

  void duplicate(Expense expense) {
    final copy = expense.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: '${expense.label} (copie)',
      date: DateTime.now(),
    );
    state = [copy, ...state];
    _repo?.upsert(copy);
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _repo?.remove(id);
  }
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<Expense>>(
  (ref) => ExpensesNotifier(ref, shopCode: ref.watch(currentShopCodeProvider)),
);

List<Expense> _forMonth(List<Expense> expenses, int year, int month) => expenses
    .where((e) => e.date.year == year && e.date.month == month)
    .toList();

final expensesThisMonthTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final list = _forMonth(ref.watch(expensesProvider), now.year, now.month);
  return list.fold(0.0, (sum, e) => sum + e.montant);
});

final expensesLastMonthTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  final list = _forMonth(
    ref.watch(expensesProvider),
    lastMonth.year,
    lastMonth.month,
  );
  return list.fold(0.0, (sum, e) => sum + e.montant);
});

/// Percentage change of this month's total vs. last month's — null when
/// there's no prior-month spending to compare against (avoids a meaningless
/// "+∞%").
final expensesMoMChangeProvider = Provider<double?>((ref) {
  final thisMonth = ref.watch(expensesThisMonthTotalProvider);
  final lastMonth = ref.watch(expensesLastMonthTotalProvider);
  if (lastMonth <= 0) return null;
  return ((thisMonth - lastMonth) / lastMonth) * 100;
});

final expensesAverageProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final list = _forMonth(ref.watch(expensesProvider), now.year, now.month);
  if (list.isEmpty) return 0;
  return list.fold(0.0, (sum, e) => sum + e.montant) / list.length;
});

/// The category with the highest spend this month, along with its total —
/// null when there's nothing recorded yet.
final expensesTopCategoryProvider = Provider<(ExpenseCategory, double)?>((ref) {
  final now = DateTime.now();
  final list = _forMonth(ref.watch(expensesProvider), now.year, now.month);
  if (list.isEmpty) return null;
  final totals = <ExpenseCategory, double>{};
  for (final e in list) {
    totals[e.categorie] = (totals[e.categorie] ?? 0) + e.montant;
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return (sorted.first.key, sorted.first.value);
});

/// This month's spend per category, sorted descending — feeds the pie chart
/// and its legend.
final expensesCategoryBreakdownProvider =
    Provider<List<(ExpenseCategory, double)>>((ref) {
      final now = DateTime.now();
      final list = _forMonth(ref.watch(expensesProvider), now.year, now.month);
      final totals = <ExpenseCategory, double>{};
      for (final e in list) {
        totals[e.categorie] = (totals[e.categorie] ?? 0) + e.montant;
      }
      final entries = totals.entries.map((e) => (e.key, e.value)).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      return entries;
    });
