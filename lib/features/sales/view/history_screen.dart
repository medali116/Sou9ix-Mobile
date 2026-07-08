import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/sales/service/sale_service.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _employeeFilter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    var sales = ref.watch(salesProvider).where((s) => s.lignes.isNotEmpty).toList();
    if (_employeeFilter != null) {
      sales = sales.where((s) => s.employeeId == _employeeFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      sales = sales.where((s) {
        final ticketId = s.id.substring(s.id.length - 6).toLowerCase();
        return ticketId.contains(q) || s.lignes.any((l) => l.product.name.toLowerCase().contains(q));
      }).toList();
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
                    Text('Aujourd\'hui', style: Theme.of(context).textTheme.bodyMedium),
                    Text(AppFormat.dt(todayTotal), style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Tickets', style: Theme.of(context).textTheme.bodyMedium),
                    Text('${sales.length}', style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un ticket ou un produit…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
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
                        onSelected: (_) => setState(() => _employeeFilter = e.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: sales.isEmpty
                ? EmptyState(
                    icon: _query.isEmpty ? Icons.receipt_long_outlined : Icons.search_off_rounded,
                    title: _query.isEmpty ? 'Aucune vente' : 'Aucun résultat',
                    message: _query.isEmpty
                        ? 'Les ventes réalisées à la caisse\napparaîtront ici.'
                        : 'Aucun ticket ou produit ne correspond\nà cette recherche.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return _SaleTile(sale: sale)
                          .animate()
                          .fadeIn(duration: 220.ms, delay: (18 * index).ms);
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
            if (sale.lignes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const Text('Retourner un produit'),
                onTap: () => Navigator.pop(context, 'return'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Annuler la vente', style: TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'edit') {
      context.push('/history/edit', extra: sale);
    } else if (action == 'return') {
      _startReturn(context, ref);
    } else if (action == 'cancel') {
      _confirmCancel(context, ref);
    }
  }

  Future<void> _startReturn(BuildContext context, WidgetRef ref) async {
    if (sale.lignes.length == 1) {
      context.push('/returns/new', extra: sale.lignes.first.product);
      return;
    }
    final product = await showModalBottomSheet<Product>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Quel produit retourner ?', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            for (final l in sale.lignes)
              ListTile(
                title: Text(l.product.name),
                subtitle: Text(l.product.venduAuPoids ? AppFormat.kg(l.quantite) : '${l.quantite.toInt()} pcs'),
                onTap: () => Navigator.pop(context, l.product),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (product != null && context.mounted) {
      context.push('/returns/new', extra: product);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler cette vente ?'),
        content: const Text(
          'Le stock des articles vendus sera restitué et le crédit client (si applicable) annulé. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Retour')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la vente', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    ref.read(saleServiceProvider).deleteSale(sale);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? employeeName;
    if (sale.employeeId != null) {
      final matches = ref.watch(employeesProvider).where((e) => e.id == sale.employeeId);
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
                    Text('Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${DateFormat('HH:mm').format(sale.dateHeure)} · ${sale.nombreArticles} article${sale.nombreArticles > 1 ? 's' : ''} · ${sale.modePaiement.label}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (employeeName != null)
                      Text(
                        employeeName,
                        style: const TextStyle(fontSize: 11, color: AppColors.textFaint, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              Text(AppFormat.dt(sale.total), style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: () => _openMenu(context, ref),
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textFaint, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
