import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/sales/service/sale_service.dart';
import 'package:sou9ix/shared/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';

/// Where deleted products, clients, tickets and suppliers land instead of
/// vanishing right away — "Supprimer définitivement" is the only truly
/// destructive step, so a mistaken (or malicious) delete is always
/// recoverable.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Corbeille'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Produits'),
              Tab(text: 'Clients'),
              Tab(text: 'Tickets'),
              Tab(text: 'Fournisseurs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ProductsTrashTab(),
            _ClientsTrashTab(),
            _TicketsTrashTab(),
            _SuppliersTrashTab(),
          ],
        ),
      ),
    );
  }
}

class _ProductsTrashTab extends ConsumerWidget {
  const _ProductsTrashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(productsTrashProvider);
    if (trash.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Corbeille vide',
        message: 'Les produits supprimés\napparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: trash.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = trash[index];
        return _TrashTile(
          leading: ProductAvatar(
            emoji: p.emoji,
            photoBytes: p.photoBytes,
            size: 40,
          ),
          title: p.name,
          subtitle: AppFormat.dt(p.prixVente),
          onRestore: () {
            ref.read(productsProvider.notifier).upsert(p);
            ref.read(productsTrashProvider.notifier).removeById(p.id);
          },
          onPurge: () => _confirmPurge(
            context,
            p.name,
            () => ref.read(productsTrashProvider.notifier).removeById(p.id),
          ),
        );
      },
    );
  }
}

class _ClientsTrashTab extends ConsumerWidget {
  const _ClientsTrashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(clientsTrashProvider);
    if (trash.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Corbeille vide',
        message: 'Les clients supprimés\napparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: trash.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = trash[index];
        return _TrashTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            foregroundColor: AppColors.tealDark,
            child: Text(
              c.nom.substring(0, 1),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          title: c.nom,
          subtitle: c.telephone,
          onRestore: () {
            ref.read(clientsProvider.notifier).restore(c);
            ref.read(clientsTrashProvider.notifier).removeById(c.id);
          },
          onPurge: () => _confirmPurge(
            context,
            c.nom,
            () => ref.read(clientsTrashProvider.notifier).removeById(c.id),
          ),
        );
      },
    );
  }
}

class _TicketsTrashTab extends ConsumerWidget {
  const _TicketsTrashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(salesTrashProvider);
    if (trash.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Corbeille vide',
        message: 'Les tickets annulés\napparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: trash.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = trash[index];
        final reference = s.id.length > 6
            ? s.id.substring(s.id.length - 6).toUpperCase()
            : s.id.toUpperCase();
        return _TrashTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Icon(
              Icons.receipt_outlined,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
          title: 'Ticket #$reference',
          subtitle:
              '${DateFormat('dd/MM/yyyy · HH:mm').format(s.dateHeure)} · ${AppFormat.dt(s.total)}',
          onRestore: () => ref.read(saleServiceProvider).restoreSale(s),
          onPurge: () => _confirmPurge(
            context,
            'Ticket #$reference',
            () => ref.read(salesTrashProvider.notifier).removeById(s.id),
          ),
        );
      },
    );
  }
}

class _SuppliersTrashTab extends ConsumerWidget {
  const _SuppliersTrashTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trash = ref.watch(suppliersTrashProvider);
    if (trash.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'Corbeille vide',
        message: 'Les fournisseurs supprimés\napparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: trash.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = trash[index];
        return _TrashTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            foregroundColor: AppColors.tealDark,
            backgroundImage: s.photoBytes != null ? MemoryImage(s.photoBytes!) : null,
            child: s.photoBytes != null
                ? null
                : Text(
                    s.nom.substring(0, 1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          title: s.nom,
          subtitle: s.telephone.isEmpty ? s.adresse : s.telephone,
          onRestore: () {
            ref.read(suppliersProvider.notifier).upsert(s);
            ref.read(suppliersTrashProvider.notifier).removeById(s.id);
          },
          onPurge: () => _confirmPurge(
            context,
            s.nom,
            () => ref.read(suppliersTrashProvider.notifier).removeById(s.id),
          ),
        );
      },
    );
  }
}

Future<void> _confirmPurge(
  BuildContext context,
  String name,
  VoidCallback onConfirm,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Supprimer définitivement ?'),
      content: Text(
        '« $name » sera supprimé pour de bon — cette action est irréversible.',
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
  if (confirmed == true) onConfirm();
}

class _TrashTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrashTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRestore,
    required this.onPurge,
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
          Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_rounded, size: 17),
                  label: const Text('Restaurer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPurge,
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 17,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'Supprimer déf.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
