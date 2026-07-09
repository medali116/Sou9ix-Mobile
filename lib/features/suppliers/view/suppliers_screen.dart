import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

enum _Filter { tous, avecDettes, soldes }

extension on _Filter {
  String get label => switch (this) {
    _Filter.tous => 'Tous',
    _Filter.avecDettes => 'Avec dettes',
    _Filter.soldes => 'Soldés',
  };
}

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _query = '';
  _Filter _filter = _Filter.tous;

  @override
  Widget build(BuildContext context) {
    final allSuppliers = ref.watch(suppliersProvider);
    final allInvoices = ref.watch(purchaseInvoicesProvider);

    double debtFor(String supplierId) => allInvoices
        .where((i) => i.fournisseurId == supplierId)
        .fold(0.0, (sum, i) => sum + i.montantRestant);

    var suppliers = allSuppliers;
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      suppliers = suppliers
          .where(
            (s) =>
                s.nom.toLowerCase().contains(q) ||
                s.telephone.toLowerCase().contains(q),
          )
          .toList();
    }
    switch (_filter) {
      case _Filter.tous:
        break;
      case _Filter.avecDettes:
        suppliers = suppliers.where((s) => debtFor(s.id) > 0).toList();
      case _Filter.soldes:
        suppliers = suppliers.where((s) => debtFor(s.id) <= 0).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un fournisseur...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: suppliers.isEmpty
                ? const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Aucun fournisseur',
                    message: 'Aucun résultat pour ces filtres.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = suppliers[index];
                      return _SupplierTile(supplier: s, dette: debtFor(s.id))
                          .animate()
                          .fadeIn(duration: 220.ms, delay: (18 * index).ms);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/suppliers/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Fournisseur'),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final double dette;
  const _SupplierTile({required this.supplier, required this.dette});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => context.push('/suppliers/detail', extra: supplier),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Hero(
              tag: 'supplier-${supplier.id}',
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                foregroundColor: AppColors.tealDark,
                backgroundImage: supplier.photoBytes != null
                    ? MemoryImage(supplier.photoBytes!)
                    : null,
                child: supplier.photoBytes != null
                    ? null
                    : Text(
                        supplier.nom.substring(0, 1),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.nom,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    supplier.telephone.isEmpty
                        ? supplier.adresse
                        : supplier.telephone,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (dette > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  AppFormat.dtShort(dette),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textFaint,
              ),
          ],
        ),
      ),
    );
  }
}
