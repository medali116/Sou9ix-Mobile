import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/shared/features/expenses/model/expense.dart';
import 'package:sou9ix/shared/features/expenses/service/expenses_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';

List<Expense> _buildMockExpenses() {
  final now = DateTime.now();
  return [
    Expense(
      id: 'e1',
      label: 'Loyer du local',
      montant: 850,
      categorie: ExpenseCategory.loyer,
      date: DateTime(now.year, now.month, 1),
      recurrente: true,
      paye: true,
      ajouteePar: 'Yassine Karoui',
    ),
    Expense(
      id: 'e2',
      label: 'Facture STEG',
      montant: 120.5,
      categorie: ExpenseCategory.steg,
      date: now.subtract(const Duration(days: 4)),
      recurrente: true,
      paye: false,
      ajouteePar: 'Rania Mejri',
    ),
    Expense(
      id: 'e3',
      label: 'Salaire — Rania Mejri',
      montant: 900,
      categorie: ExpenseCategory.salaires,
      date: now.subtract(const Duration(days: 6)),
      recurrente: true,
      paye: true,
      ajouteePar: 'Yassine Karoui',
    ),
    Expense(
      id: 'e4',
      label: 'Sacs & emballages',
      montant: 65,
      categorie: ExpenseCategory.fournitures,
      date: now.subtract(const Duration(days: 10)),
      paye: true,
      ajouteePar: 'Rania Mejri',
    ),
    Expense(
      id: 'e5',
      label: 'Produits de nettoyage',
      montant: 15,
      categorie: ExpenseCategory.nettoyage,
      date: now,
      paye: true,
      ajouteePar: 'Yassine Karoui',
    ),
  ];
}

final expensesRepositoryProvider = Provider<ExpensesRepository?>((ref) {
  final shopCode = ref.watch(shopCodeProvider);
  if (shopCode == null) return null;
  return ExpensesRepository(FirebaseFirestore.instance, shopCode);
});

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  ExpensesNotifier(this._ref, this._repo) : super(_buildMockExpenses()) {
    unawaited(_init());
  }

  final Ref _ref;
  final ExpensesRepository? _repo;
  StreamSubscription<List<Expense>>? _sub;

  Future<void> _init() async {
    final repo = _repo;
    if (repo == null) return;
    await repo.bootstrapIfEmpty(state);
    _sub = repo.watchAll().listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void add(Expense expense) {
    state = [expense, ...state];
    logActivity(
      _ref,
      category: ActivityCategory.depenses,
      impact: ActivityImpact.ajout,
      action: 'Dépense ajoutée',
      targetName: expense.label,
      montant: expense.montant,
    );
    unawaited(_repo?.upsert(expense));
  }

  void update(Expense expense) {
    state = [
      for (final e in state)
        if (e.id == expense.id) expense else e,
    ];
    unawaited(_repo?.upsert(expense));
  }

  void duplicate(Expense expense) {
    final copy = expense.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: '${expense.label} (copie)',
      date: DateTime.now(),
    );
    state = [copy, ...state];
    unawaited(_repo?.upsert(copy));
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    unawaited(_repo?.remove(id));
  }
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<Expense>>(
  (ref) => ExpensesNotifier(ref, ref.watch(expensesRepositoryProvider)),
);

List<Expense> _forMonth(List<Expense> expenses, int year, int month) => expenses
    .where((e) => e.date.year == year && e.date.month == month)
    .toList();

final expensesThisMonthTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final list = _forMonth(ref.watch(expensesProvider), now.year, now.month);
  return list.fold(0.0, (total, e) => total + e.montant);
});

final expensesLastMonthTotalProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  final list = _forMonth(
    ref.watch(expensesProvider),
    lastMonth.year,
    lastMonth.month,
  );
  return list.fold(0.0, (total, e) => total + e.montant);
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
  return list.fold(0.0, (total, e) => total + e.montant) / list.length;
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
