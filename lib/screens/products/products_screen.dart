import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/product_avatar.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final isAdmin = ref.watch(authProvider)?.role == UserRole.admin;

    final filtered = products
        .where((p) => _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          IconButton(
            onPressed: () => context.push('/stock/receipt'),
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Réceptionner un achat',
          ),
          if (isAdmin)
            IconButton(
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit',
                    message: 'Aucun produit ne correspond\nà votre recherche.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final cat = categories.firstWhere(
                        (c) => c.id == p.categorieId,
                        orElse: () => categories.first,
                      );
                      return PressScale(
                        onTap: isAdmin ? () => context.push('/products/edit', extra: p) : () {},
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: AppShadows.card,
                          ),
                          child: Row(
                            children: [
                              ProductAvatar(emoji: p.emoji, photoBytes: p.photoBytes, size: 46),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(cat.icon, size: 12, color: AppColors.textFaint),
                                        const SizedBox(width: 4),
                                        Text(cat.name, style: Theme.of(context).textTheme.bodyMedium),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Text('· marge ${p.margePct.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.w700)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p.venduAuPoids
                                        ? '${AppFormat.dtShort(p.prixVente)}/kg'
                                        : AppFormat.dtShort(p.prixVente),
                                    style: const TextStyle(
                                        color: AppColors.teal, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  _StockTag(product: p),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 220.ms, delay: (18 * index).ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockTag extends StatelessWidget {
  final Product product;
  const _StockTag({required this.product});

  @override
  Widget build(BuildContext context) {
    final low = product.stockFaible;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (low ? AppColors.warning : AppColors.success).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        product.venduAuPoids
            ? '${product.stock.toStringAsFixed(1)} kg'
            : '${product.stock.toInt()} pcs',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: low ? AppColors.warning : AppColors.success,
        ),
      ),
    );
  }
}
