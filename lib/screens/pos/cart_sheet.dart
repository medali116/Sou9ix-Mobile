import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/sheet_handle.dart';

class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Panier · ${items.length} article${items.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            ref.read(cartProvider.notifier).clear(),
                        child: const Text('Vider'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(
                        icon: Icons.shopping_basket_outlined,
                        title: 'Panier vide',
                        message:
                            'Ajoutez des produits depuis la caisse\npour commencer une vente.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ProductAvatar(
                                      emoji: item.product.emoji,
                                      photoBytes: item.product.photoBytes,
                                      size: 42,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.product.venduAuPoids
                                                ? '${AppFormat.kg(item.quantite)} × ${AppFormat.dtShort(item.product.prixVente)}'
                                                : '${item.quantite.toInt()} × ${AppFormat.dtShort(item.product.prixVente)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!item.product.venduAuPoids)
                                      Row(
                                        children: [
                                          _qtyBtn(
                                            icon: Icons.remove_rounded,
                                            onTap: () => ref
                                                .read(cartProvider.notifier)
                                                .updateQuantite(
                                                  item.product.id,
                                                  item.quantite - 1,
                                                ),
                                          ),
                                          SizedBox(
                                            width: 26,
                                            child: Text(
                                              item.quantite.toInt().toString(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          _qtyBtn(
                                            icon: Icons.add_rounded,
                                            onTap: () => ref
                                                .read(cartProvider.notifier)
                                                .updateQuantite(
                                                  item.product.id,
                                                  item.quantite + 1,
                                                ),
                                          ),
                                        ],
                                      )
                                    else
                                      IconButton(
                                        onPressed: () => ref
                                            .read(cartProvider.notifier)
                                            .removeItem(item.product.id),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.danger,
                                          size: 20,
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 66,
                                      child: Text(
                                        AppFormat.dtShort(item.sousTotal),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 220.ms)
                              .slideX(begin: 0.04, end: 0);
                        },
                      ),
              ),
              if (items.isNotEmpty)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            AppFormat.dt(total),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/checkout');
                          },
                          child: const Text('Passer à l\'encaissement'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _qtyBtn({required IconData icon, required VoidCallback onTap}) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15),
      ),
    );
  }
}
