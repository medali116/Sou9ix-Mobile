import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/auth/model/user.dart';
import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/returns/model/stock_return.dart';
import 'package:sou9ix/shared/features/returns/viewmodel/stock_returns_provider.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/view/adjust_stock_sheet.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/stock_movements_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/section_header.dart';

/// One timeline entry, either a real stock change ([StockMovement]) or a
/// declared loss ([StockReturn]) — the two are recorded through separate
/// flows (see [recordStockMovement] and `StockService.recordReturn`) but
/// belong in the same "what happened to this product's stock" view.
sealed class _TimelineEntry {
  DateTime get date;
}

class _MovementEntry extends _TimelineEntry {
  final StockMovement movement;
  _MovementEntry(this.movement);
  @override
  DateTime get date => movement.date;
}

class _LossEntry extends _TimelineEntry {
  final StockReturn stockReturn;
  _LossEntry(this.stockReturn);
  @override
  DateTime get date => stockReturn.date;
}

/// Per-product stock page: current numbers (stock, seuil, prix, valeur),
/// quick actions (ajuster / déclarer une perte), and the full movement
/// history — replaces the old sales-only "Historique" sheet on
/// [StockScreen] with a real reconstruction of every stock change.
class StockDetailScreen extends ConsumerWidget {
  final Product product;
  const StockDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(productMovementsProvider(product.id));
    final losses = ref
        .watch(stockReturnsProvider)
        .where((r) => r.productId == product.id)
        .toList();
    final timeline = <_TimelineEntry>[
      ...movements.map(_MovementEntry.new),
      ...losses.map(_LossEntry.new),
    ]..sort((a, b) => b.date.compareTo(a.date));

    final valeurStock = product.stock * product.prixAchat;
    final decimals = product.venduAuPoids ? 3 : 0;
    final isAdmin = ref.watch(authProvider)?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => context.push('/products/edit', extra: product),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier le produit',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                ProductAvatar(
                  emoji: product.emoji,
                  photoBytes: product.photoBytes,
                  size: 46,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.venduAuPoids
                            ? AppFormat.kg(product.stock)
                            : '${product.stock.toInt()} pcs',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        'en stock · valeur ${AppFormat.dt(valeurStock)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Seuil d\'alerte',
                  value:
                      '${product.seuilAlerte.toStringAsFixed(decimals)} ${product.unite}',
                ),
                _InfoRow(
                  label: 'Prix d\'achat',
                  value:
                      '${AppFormat.dt(product.prixAchat)} / ${product.unite}',
                ),
                _InfoRow(
                  label: 'Prix de vente',
                  value:
                      '${AppFormat.dt(product.prixVente)} / ${product.unite}',
                ),
                _InfoRow(
                  label: 'Valeur actuelle du stock',
                  value: AppFormat.dt(valeurStock),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.tune_rounded,
                  label: 'Ajuster',
                  color: AppColors.goldDark,
                  onTap: () => showAdjustStockSheet(context, ref, product),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: 'Déclarer une perte',
                  color: AppColors.danger,
                  onTap: () => context.push('/returns/new', extra: product),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Historique du stock'),
          const SizedBox(height: 12),
          if (timeline.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              title: 'Aucun mouvement',
              message: 'Les ventes, achats et ajustements\napparaîtront ici.',
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  for (final entry in timeline) _TimelineTile(entry: entry),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEntry entry;
  const _TimelineTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return switch (e) {
      _MovementEntry() => _tile(
        context,
        icon: e.movement.type.icon,
        color: e.movement.type.color,
        title: e.movement.type.label,
        subtitle: [
          if (e.movement.reference != null) e.movement.reference!,
          if (e.movement.motif != null) e.movement.motif!,
        ].join(' · '),
        quantiteLabel:
            '${e.movement.quantite >= 0 ? '+' : ''}${e.movement.quantite.toStringAsFixed(e.movement.quantite.truncateToDouble() == e.movement.quantite ? 0 : 2)}',
        employeeName: e.movement.employeeName,
        date: e.movement.date,
      ),
      _LossEntry() => _tile(
        context,
        icon: Icons.delete_outline_rounded,
        color: AppColors.danger,
        title: 'Perte · ${e.stockReturn.motif.label}',
        subtitle: e.stockReturn.note ?? '',
        quantiteLabel:
            '-${e.stockReturn.quantite.toStringAsFixed(e.stockReturn.venduAuPoids ? 2 : 0)}',
        employeeName: null,
        date: e.stockReturn.date,
      ),
    };
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String quantiteLabel,
    required String? employeeName,
    required DateTime date,
  }) {
    final quantiteUp = quantiteLabel.startsWith('+');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd/MM/yyyy HH:mm').format(date)}'
                  '${employeeName != null ? ' · $employeeName' : ''}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            quantiteLabel,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: quantiteUp ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
