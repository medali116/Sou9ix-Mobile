import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/expenses/model/expense.dart';

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

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  ExpensesNotifier() : super(_buildMockExpenses());

  void add(Expense expense) => state = [expense, ...state];

  void update(Expense expense) {
    state = [
      for (final e in state)
        if (e.id == expense.id) expense else e,
    ];
  }

  void duplicate(Expense expense) {
    final copy = expense.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: '${expense.label} (copie)',
      date: DateTime.now(),
    );
    state = [copy, ...state];
  }

  void remove(String id) => state = state.where((e) => e.id != id).toList();
}

final expensesProvider = StateNotifierProvider<ExpensesNotifier, List<Expense>>(
  (ref) => ExpensesNotifier(),
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
