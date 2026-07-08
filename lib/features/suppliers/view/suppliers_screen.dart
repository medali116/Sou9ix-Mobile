import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      body: suppliers.isEmpty
          ? const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Aucun fournisseur',
              message: 'Ajoutez vos fournisseurs pour suivre\nleurs coordonnées et vos achats.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: suppliers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final s = suppliers[index];
                return _SupplierTile(supplier: s).animate().fadeIn(duration: 220.ms, delay: (18 * index).ms);
              },
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
  const _SupplierTile({required this.supplier});

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
                backgroundImage: supplier.photoBytes != null ? MemoryImage(supplier.photoBytes!) : null,
                child: supplier.photoBytes != null
                    ? null
                    : Text(supplier.nom.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supplier.nom, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    supplier.telephone.isEmpty ? supplier.adresse : supplier.telephone,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
