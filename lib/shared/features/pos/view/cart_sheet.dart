import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/core/models/discount.dart';
import 'package:sou9ix/shared/features/pos/view/discount_editor_sheet.dart';
import 'package:sou9ix/shared/features/pos/viewmodel/cart_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/quantity_stepper.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';
import 'package:sou9ix/shared/core/widgets/weight_stepper.dart';
import 'package:sou9ix/shared/features/pos/view/weight_entry_sheet.dart';

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
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(cartTotalProvider);
    final ticketDiscount = ref.watch(cartDiscountProvider);

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
                        onPressed: () {
                          ref.read(cartProvider.notifier).clear();
                          ref.read(cartDiscountProvider.notifier).state =
                              const Discount.none();
                        },
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
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
                                      const SizedBox(height: 4),
                                      PressScale(
                                        onTap: () async {
                                          final result =
                                              await DiscountEditorSheet.show(
                                                context,
                                                title:
                                                    'Remise sur ${item.product.name}',
                                                initial: item.discount,
                                              );
                                          if (result != null) {
                                            ref
                                                .read(cartProvider.notifier)
                                                .setDiscount(
                                                  item.product.id,
                                                  result,
                                                );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: item.discount.isNone
                                                ? AppColors.surface
                                                : AppColors.gold.withValues(
                                                    alpha: 0.16,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            border: Border.all(
                                              color: item.discount.isNone
                                                  ? AppColors.border
                                                  : AppColors.gold,
                                            ),
                                          ),
                                          child: Text(
                                            item.discount.isNone
                                                ? 'Remise'
                                                : 'Remise ${item.discount.label(AppFormat.dtShort)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: item.discount.isNone
                                                  ? AppColors.textSecondary
                                                  : AppColors.goldDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!item.product.venduAuPoids) ...[
                                  QuantityStepper(
                                    quantite: item.quantite,
                                    buttonColor: AppColors.surface,
                                    buttonSpacing: 0,
                                    onChanged: (q) => ref
                                        .read(cartProvider.notifier)
                                        .updateQuantite(item.product.id, q),
                                  ),
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
                                ] else ...[
                                  WeightStepper(
                                    totalKg: item.quantite,
                                    buttonColor: AppColors.surface,
                                    onIncrement: () => ref
                                        .read(cartProvider.notifier)
                                        .incrementWeightUnit(item.product.id),
                                    onDecrement: () => ref
                                        .read(cartProvider.notifier)
                                        .decrementWeightUnit(item.product.id),
                                    onTapLabel: () async {
                                      final updated =
                                          await WeightEntrySheet.show(
                                            context,
                                            item.product,
                                            initialKg: item.quantite,
                                          );
                                      if (updated != null) {
                                        ref
                                            .read(cartProvider.notifier)
                                            .updateQuantite(
                                              item.product.id,
                                              updated,
                                            );
                                      }
                                    },
                                  ),
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
                                ],
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 66,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!item.discount.isNone)
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            AppFormat.dtShort(
                                              item.sousTotalAvantRemise,
                                            ),
                                            maxLines: 1,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textFaint,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          AppFormat.dtShort(item.sousTotal),
                                          maxLines: 1,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.04, end: 0);
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
                            'Sous-total',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            AppFormat.dtShort(subtotal),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PressScale(
                            onTap: () async {
                              final result = await DiscountEditorSheet.show(
                                context,
                                title: 'Remise sur le ticket',
                                initial: ticketDiscount,
                              );
                              if (result != null) {
                                ref.read(cartDiscountProvider.notifier).state =
                                    result;
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.sell_outlined,
                                  size: 15,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ticketDiscount.isNone
                                      ? 'Ajouter une remise'
                                      : 'Remise ticket',
                                  style: const TextStyle(
                                    color: AppColors.teal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!ticketDiscount.isNone)
                            Text(
                              ticketDiscount.label(AppFormat.dtShort),
                              style: const TextStyle(
                                color: AppColors.goldDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
}
