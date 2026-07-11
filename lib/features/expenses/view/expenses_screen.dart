import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart'
    show PaymentMethod, PaymentMethodLabel;
import 'package:sou9ix/features/expenses/model/expense.dart';
import 'package:sou9ix/features/expenses/service/expense_export_service.dart';
import 'package:sou9ix/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/photo_picker_field.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

enum _Period { tous, aujourdhui, semaine, mois }

extension on _Period {
  String get label => switch (this) {
    _Period.tous => 'Toutes les dates',
    _Period.aujourdhui => 'Aujourd\'hui',
    _Period.semaine => 'Cette semaine',
    _Period.mois => 'Ce mois',
  };

  IconData get icon => switch (this) {
    _Period.tous => Icons.all_inclusive_rounded,
    _Period.aujourdhui => Icons.today_rounded,
    _Period.semaine => Icons.view_week_rounded,
    _Period.mois => Icons.calendar_month_rounded,
  };
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _query = '';
  _Period _period = _Period.tous;
  ExpenseCategory? _categoryFilter;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _filterTile({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColors.success : AppColors.textFaint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? AppColors.success.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              leading: Icon(icon, color: color),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? AppColors.success : AppColors.textPrimary,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPeriodSheet() async {
    final result = await showModalBottomSheet<_Period>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtrer par date',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final p in _Period.values)
              _filterTile(
                selected: _period == p,
                icon: p.icon,
                label: p.label,
                onTap: () => Navigator.pop(context, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _period = result);
  }

  Future<void> _openCategorySheet() async {
    const allSentinel = '__all__';
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtrer par catégorie',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterTile(
                      selected: _categoryFilter == null,
                      icon: Icons.apps_rounded,
                      label: 'Toutes les catégories',
                      onTap: () => Navigator.pop(context, allSentinel),
                    ),
                    for (final c in ExpenseCategory.values)
                      _filterTile(
                        selected: _categoryFilter == c,
                        icon: c.icon,
                        label: c.label,
                        onTap: () => Navigator.pop(context, c.name),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _categoryFilter = result == allSentinel
            ? null
            : ExpenseCategory.values.firstWhere((c) => c.name == result);
      });
    }
  }

  Future<void> _openExportSheet(List<Expense> expenses) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exporter',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
              ),
              title: const Text('Exporter en PDF'),
              subtitle: Text(
                '${expenses.length} dépense${expenses.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                expenseExportService.exportPdf(expenses);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: AppColors.success,
              ),
              title: const Text('Exporter en Excel (CSV)'),
              subtitle: Text(
                '${expenses.length} dépense${expenses.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                expenseExportService.exportCsv(expenses);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openExpenseFormSheet(WidgetRef ref, {Expense? existing}) async {
    final labelCtrl = TextEditingController(text: existing?.label);
    final montantCtrl = TextEditingController(
      text: existing != null ? existing.montant.toStringAsFixed(3) : '',
    );
    final descCtrl = TextEditingController(text: existing?.description);
    final formKey = GlobalKey<FormState>();
    var categorie = existing?.categorie ?? ExpenseCategory.autre;
    var date = existing?.date ?? DateTime.now();
    var photoBytes = existing?.photoBytes;
    var paye = existing?.paye ?? true;
    var recurrente = existing?.recurrente ?? false;
    var modePaiement = existing?.modePaiement ?? PaymentMethod.especes;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.92,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SheetHandle(),
                    const SizedBox(height: 14),
                    Text(
                      existing == null
                          ? 'Nouvelle dépense'
                          : 'Modifier la dépense',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Nom',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: labelCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Facture STEG',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Montant',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: montantCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.000',
                        suffixText: 'DT',
                      ),
                      validator: (v) {
                        final value = double.tryParse(
                          (v ?? '').replaceAll(',', '.'),
                        );
                        return (value == null || value <= 0)
                            ? 'Montant invalide'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Catégorie',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ExpenseCategory.values.map((c) {
                        final selected = c == categorie;
                        return ChoiceChip(
                          label: Text(c.label),
                          avatar: Icon(
                            c.icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          selected: selected,
                          onSelected: (_) => setSheetState(() => categorie = c),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Date',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(DateFormat('dd/MM/yyyy').format(date)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Photo de la facture',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    PhotoPickerField(
                      photoBytes: photoBytes,
                      onChanged: (bytes) =>
                          setSheetState(() => photoBytes = bytes),
                      placeholderLabel: 'Ajouter une photo de la facture',
                      placeholderIcon: Icons.receipt_long_outlined,
                      height: 120,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Réparation climatiseur',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Payée'),
                            avatar: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: paye
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            selected: paye,
                            selectedColor: AppColors.success,
                            onSelected: (_) => setSheetState(() => paye = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Non payée'),
                            avatar: Icon(
                              Icons.hourglass_empty_rounded,
                              size: 16,
                              color: !paye
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            selected: !paye,
                            selectedColor: AppColors.warning,
                            onSelected: (_) =>
                                setSheetState(() => paye = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mode de paiement',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    Text(
                      'Espèces = sortie de la caisse, prise en compte dans la clôture de caisse',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PaymentMethod.values.map((m) {
                        final selected = m == modePaiement;
                        return ChoiceChip(
                          label: Text(m.label),
                          avatar: Icon(
                            m.icon,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          selected: selected,
                          onSelected: (_) =>
                              setSheetState(() => modePaiement = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Dépense récurrente'),
                        subtitle: const Text(
                          'Se répète chaque mois (ex. loyer, STEG)',
                        ),
                        value: recurrente,
                        activeThumbColor: AppColors.teal,
                        onChanged: (v) => setSheetState(() => recurrente = v),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final user = ref.read(authProvider);
                          final expense = Expense(
                            id:
                                existing?.id ??
                                DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                            label: labelCtrl.text.trim(),
                            montant: double.parse(
                              montantCtrl.text.replaceAll(',', '.'),
                            ),
                            categorie: categorie,
                            date: date,
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            photoBytes: photoBytes,
                            paye: paye,
                            recurrente: recurrente,
                            ajouteePar: existing?.ajouteePar ?? user?.nom,
                            modePaiement: modePaiement,
                          );
                          if (existing == null) {
                            ref.read(expensesProvider.notifier).add(expense);
                          } else {
                            ref.read(expensesProvider.notifier).update(expense);
                          }
                          Navigator.pop(sheetContext, true);
                        },
                        child: Text(
                          existing == null
                              ? 'Ajouter la dépense'
                              : 'Enregistrer les modifications',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              existing == null ? 'Dépense ajoutée' : 'Dépense modifiée',
            ),
          ),
        );
    }
  }

  Future<void> _confirmDelete(WidgetRef ref, Expense e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette dépense ?'),
        content: Text('« ${e.label} » sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(expensesProvider.notifier).remove(e.id);
  }

  Future<void> _openDetailSheet(WidgetRef ref, Expense e) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.label,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  PressScale(
                    onTap: () async {
                      final action = await showModalBottomSheet<String>(
                        context: sheetContext,
                        backgroundColor: Colors.transparent,
                        builder: (_) => Container(
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppRadius.xl),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SheetHandle(),
                              ListTile(
                                leading: const Icon(Icons.edit_outlined),
                                title: const Text('Modifier'),
                                onTap: () =>
                                    Navigator.pop(sheetContext, 'edit'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.copy_rounded),
                                title: const Text('Dupliquer'),
                                onTap: () =>
                                    Navigator.pop(sheetContext, 'duplicate'),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                ),
                                title: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: AppColors.danger),
                                ),
                                onTap: () =>
                                    Navigator.pop(sheetContext, 'delete'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );
                      if (!sheetContext.mounted) return;
                      if (action == 'edit') {
                        Navigator.pop(sheetContext);
                        _openExpenseFormSheet(ref, existing: e);
                      } else if (action == 'duplicate') {
                        ref.read(expensesProvider.notifier).duplicate(e);
                        Navigator.pop(sheetContext);
                      } else if (action == 'delete') {
                        Navigator.pop(sheetContext);
                        _confirmDelete(ref, e);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Icon(Icons.more_vert_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow('Montant', AppFormat.dt(e.montant), bold: true),
              _detailRow('Catégorie', e.categorie.label),
              _detailRow('Date', DateFormat('dd/MM/yyyy').format(e.date)),
              if (e.description != null && e.description!.isNotEmpty)
                _detailRow('Description', e.description!),
              if (e.ajouteePar != null)
                _detailRow('Ajoutée par', e.ajouteePar!),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBadge(paye: e.paye),
                  if (e.recurrente) const _RecurrentBadge(),
                ],
              ),
              if (e.photoBytes != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Photo de la facture',
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.memory(
                    e.photoBytes!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expensesProvider);
    final monthTotal = ref.watch(expensesThisMonthTotalProvider);
    final momChange = ref.watch(expensesMoMChangeProvider);
    final average = ref.watch(expensesAverageProvider);
    final topCategory = ref.watch(expensesTopCategoryProvider);
    final breakdown = ref.watch(expensesCategoryBreakdownProvider);

    var expenses = List.of(allExpenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    final now = DateTime.now();
    switch (_period) {
      case _Period.tous:
        break;
      case _Period.aujourdhui:
        expenses = expenses.where((e) => _sameDay(e.date, now)).toList();
        break;
      case _Period.semaine:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        expenses = expenses
            .where((e) => !e.date.isBefore(startOfWeek))
            .toList();
        break;
      case _Period.mois:
        expenses = expenses
            .where((e) => e.date.year == now.year && e.date.month == now.month)
            .toList();
        break;
    }

    if (_categoryFilter != null) {
      expenses = expenses.where((e) => e.categorie == _categoryFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      expenses = expenses
          .where((e) => e.label.toLowerCase().contains(q))
          .toList();
    }

    const chartColors = [
      AppColors.teal,
      AppColors.gold,
      AppColors.info,
      AppColors.danger,
      AppColors.tealDark,
      AppColors.goldDark,
      AppColors.success,
      AppColors.textSecondary,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses & charges'),
        actions: [
          IconButton(
            onPressed: () => _openExportSheet(expenses),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exporter',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL CE MOIS',
                        style: TextStyle(
                          color: AppColors.tealLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            AppFormat.dt(monthTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (momChange != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (momChange >= 0
                                            ? AppColors.danger
                                            : AppColors.success)
                                        .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    momChange >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    size: 13,
                                    color: momChange >= 0
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${momChange >= 0 ? '+' : ''}${momChange.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: momChange >= 0
                                          ? AppColors.danger
                                          : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        momChange == null
                            ? '${allExpenses.length} dépense${allExpenses.length > 1 ? 's' : ''} enregistrée${allExpenses.length > 1 ? 's' : ''}'
                            : '${momChange >= 0 ? '+' : ''}${momChange.toStringAsFixed(0)}% par rapport au mois dernier',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wallet_outlined,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.functions_rounded,
                  label: 'Moyenne / dépense',
                  value: AppFormat.dtShort(average),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: topCategory != null
                      ? topCategory.$1.icon
                      : Icons.category_outlined,
                  label: 'Catégorie principale',
                  value: topCategory != null ? topCategory.$1.label : '—',
                ),
              ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 26,
                        sections: [
                          for (var i = 0; i < breakdown.length; i++)
                            PieChartSectionData(
                              value: breakdown[i].$2,
                              color: chartColors[i % chartColors.length],
                              title: '',
                              radius: 16,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < breakdown.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: chartColors[i % chartColors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    breakdown[i].$1.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${(breakdown[i].$2 / monthTotal * 100).round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Rechercher une dépense…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterPill(
                    leading: Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _period == _Period.tous
                          ? AppColors.textSecondary
                          : AppColors.teal,
                    ),
                    label: _period.label,
                    active: _period != _Period.tous,
                    onTap: _openPeriodSheet,
                  ),
                ),
                _FilterPill(
                  leading: Icon(
                    Icons.label_outline_rounded,
                    size: 14,
                    color: _categoryFilter == null
                        ? AppColors.textSecondary
                        : AppColors.teal,
                  ),
                  label: _categoryFilter?.label ?? 'Toutes les catégories',
                  active: _categoryFilter != null,
                  onTap: _openCategorySheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.wallet_outlined,
                title: 'Aucune dépense',
                message: 'Aucun résultat pour ces filtres.',
              ),
            )
          else
            ...expenses.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Slidable(
                  key: ValueKey(e.id),
                  endActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (_) => _confirmDelete(ref, e),
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_outline_rounded,
                        label: 'Supprimer',
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ],
                  ),
                  child: PressScale(
                    onTap: () => _openDetailSheet(ref, e),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Icon(
                                  e.categorie.icon,
                                  color: AppColors.teal,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.categorie.label} · ${DateFormat('dd/MM/yyyy').format(e.date)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppFormat.dt(e.montant),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatusBadge(paye: e.paye),
                              if (e.recurrente) const _RecurrentBadge(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 220.ms, delay: (18 * index).ms);
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExpenseFormSheet(ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle dépense'),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.teal, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.leading,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? AppColors.teal : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.teal : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? AppColors.teal : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool paye;
  const _StatusBadge({required this.paye});

  @override
  Widget build(BuildContext context) {
    final color = paye ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            paye ? 'Payée' : 'En attente',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurrentBadge extends StatelessWidget {
  const _RecurrentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 11, color: AppColors.info),
          SizedBox(width: 4),
          Text(
            'Récurrente',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}
