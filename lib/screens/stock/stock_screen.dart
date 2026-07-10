import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/stock_bar.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  bool _onlyLow = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final list = _onlyLow ? lowStock : products;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de stock'),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouveau produit',
          ),
          IconButton(
            onPressed: () => context.push('/stock/receipt'),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            tooltip: 'Réceptionner un achat',
          ),
        ],
      ),
      body: Column(
        children: [
          if (lowStock.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${lowStock.length} produit${lowStock.length > 1 ? 's' : ''} à réapprovisionner',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _onlyLow,
                    activeThumbColor: AppColors.warning,
                    onChanged: (v) => setState(() => _onlyLow = v),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Tout est en ordre',
                    message: 'Aucun produit en stock faible\npour le moment.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = list[index];
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
                                ProductAvatar(
                                  emoji: p.emoji,
                                  photoBytes: p.photoBytes,
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    p.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Text(
                                  p.venduAuPoids
                                      ? AppFormat.kg(p.stock)
                                      : '${p.stock.toInt()} pcs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: p.stockFaible
                                        ? AppColors.warning
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            StockBar(quantite: p.stock, seuil: p.seuilAlerte),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Seuil d\'alerte : ${p.seuilAlerte.toStringAsFixed(1)} ${p.unite}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (p.stockFaible)
                                  const Text(
                                    'FAIBLE ⚠',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  )
                                else
                                  const Text(
                                    'OK',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
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
