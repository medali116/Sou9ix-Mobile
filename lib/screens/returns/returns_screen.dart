import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../models/stock_return.dart';
import '../../providers/stock_returns_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

/// Log of stock write-offs (expired, damaged, stolen…) with the resulting
/// loss valued at cost price — lets the owner see shrinkage over time.
class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(stockReturnsProvider);
    final totalLoss = ref.watch(totalLossProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retours & pertes'),
        actions: [
          IconButton(
            onPressed: () => context.push('/returns/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Enregistrer un retour',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                        'TOTAL PERTES',
                        style: TextStyle(
                          color: AppColors.tealLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormat.dt(totalLoss),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${returns.length} retour${returns.length > 1 ? 's' : ''} enregistré${returns.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove_shopping_cart_outlined, color: AppColors.danger),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          Expanded(
            child: returns.isEmpty
                ? const EmptyState(
                    icon: Icons.remove_shopping_cart_outlined,
                    title: 'Aucun retour enregistré',
                    message: 'Les produits périmés ou endommagés\nretirés du stock apparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: returns.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = returns[index];
                      return _ReturnTile(stockReturn: r)
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

class _ReturnTile extends StatelessWidget {
  final StockReturn stockReturn;
  const _ReturnTile({required this.stockReturn});

  Color get _motifColor {
    switch (stockReturn.motif) {
      case RetourMotif.peremption:
        return AppColors.warning;
      case RetourMotif.casse:
      case RetourMotif.vol:
        return AppColors.danger;
      case RetourMotif.autre:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stockReturn.productName, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${stockReturn.quantite.toStringAsFixed(stockReturn.venduAuPoids ? 3 : 0)} ${stockReturn.unite} · ${DateFormat('dd/MM/yyyy').format(stockReturn.date)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (stockReturn.note != null) ...[
                  const SizedBox(height: 4),
                  Text(stockReturn.note!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _motifColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    stockReturn.motif.label,
                    style: TextStyle(color: _motifColor, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Text('-${AppFormat.dt(stockReturn.perte)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
        ],
      ),
    );
  }
}
