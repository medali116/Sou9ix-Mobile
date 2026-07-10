import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'press_scale.dart';
import 'product_avatar.dart';

/// Product tile used in the POS grid. Tapping adds directly to cart
/// (pieces) or opens the weight-entry pad for products sold by weight.
class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final double quantiteInCart;

  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.quantiteInCart = 0,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = quantiteInCart > 0;
    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: inCart ? AppColors.teal : AppColors.border,
            width: inCart ? 1.6 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductAvatar(
                    emoji: product.emoji,
                    photoBytes: product.photoBytes,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 13.5),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.venduAuPoids
                              ? '${AppFormat.dtShort(product.prixVente)}/kg'
                              : AppFormat.dtShort(product.prixVente),
                          style: const TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (product.venduAuPoids)
                        const Icon(
                          Icons.scale_rounded,
                          size: 14,
                          color: AppColors.textFaint,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (product.stockFaible)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (inCart)
              Positioned(
                top: 6,
                left: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    product.venduAuPoids
                        ? '${quantiteInCart.toStringAsFixed(3)} kg'
                        : quantiteInCart.toInt().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
