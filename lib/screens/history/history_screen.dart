import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../models/sale.dart';
import '../../providers/clients_provider.dart';
import '../../providers/employees_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/sales_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/sheet_handle.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _employeeFilter;

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    var sales = ref
        .watch(salesProvider)
        .where((s) => s.lignes.isNotEmpty)
        .toList();
    if (_employeeFilter != null) {
      sales = sales.where((s) => s.employeeId == _employeeFilter).toList();
    }
    final todayTotal = sales.fold<double>(0, (sum, s) => sum + s.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des ventes')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aujourd\'hui',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      AppFormat.dt(todayTotal),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Tickets',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${sales.length}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          if (employees.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Tous'),
                      selected: _employeeFilter == null,
                      onSelected: (_) => setState(() => _employeeFilter = null),
                    ),
                  ),
                  for (final e in employees)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.nom),
                        selected: _employeeFilter == e.id,
                        onSelected: (_) =>
                            setState(() => _employeeFilter = e.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: sales.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune vente',
                    message:
                        'Les ventes réalisées à la caisse\napparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return _SaleTile(sale: sale).animate().fadeIn(
                        duration: 220.ms,
                        delay: (18 * index).ms,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends ConsumerWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  IconData get _icon {
    switch (sale.modePaiement) {
      case ModePaiement.especes:
        return Icons.payments_rounded;
      case ModePaiement.carte:
        return Icons.credit_card_rounded;
      case ModePaiement.credit:
        return Icons.menu_book_rounded;
    }
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
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
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'edit'),
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
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'edit') {
      context.push('/history/edit', extra: sale);
    } else if (action == 'delete') {
      _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette vente ?'),
        content: const Text(
          'Le stock des articles vendus sera restitué et le crédit client (si applicable) annulé. Cette action est irréversible.',
        ),
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
    if (confirmed != true) return;

    for (final l in sale.lignes) {
      ref.read(productsProvider.notifier).adjustStock(l.product.id, l.quantite);
    }
    if (sale.modePaiement == ModePaiement.credit && sale.clientId != null) {
      ref.read(clientsProvider.notifier).addCredit(sale.clientId!, -sale.total);
    }
    ref.read(salesProvider.notifier).removeSale(sale.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? employeeName;
    if (sale.employeeId != null) {
      final matches = ref
          .watch(employeesProvider)
          .where((e) => e.id == sale.employeeId);
      employeeName = matches.isEmpty ? 'Employé supprimé' : matches.first.nom;
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/receipt', extra: sale),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_icon, color: AppColors.teal, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(sale.dateHeure)} · ${sale.nombreArticles} article${sale.nombreArticles > 1 ? 's' : ''} · ${sale.modePaiement.label}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (employeeName != null)
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                AppFormat.dt(sale.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => _openMenu(context, ref),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textFaint,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
