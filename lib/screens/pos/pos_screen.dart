import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/product_tile.dart';
import 'cart_sheet.dart';
import 'weight_entry_sheet.dart';

/// Full catalogue grid, reachable from the Caisse screen's "browse" icon —
/// useful for visually finding a product by category when scanning isn't
/// practical. Tapping a tile adds it to the same shared cart.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';
  String? _categoryId;

  Future<void> _handleProductTap(Product product) async {
    if (product.venduAuPoids) {
      final poids = await WeightEntrySheet.show(context, product);
      if (poids != null && poids > 0) {
        ref.read(cartProvider.notifier).addWeighted(product, poids);
        _confirmAdded(product);
      }
    } else {
      ref.read(cartProvider.notifier).addPiece(product);
      _confirmAdded(product);
    }
  }

  void _confirmAdded(Product product) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          margin: const EdgeInsets.only(bottom: 110, left: 60, right: 60),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.tealLight, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text('${product.name} ajouté', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);

    final filtered = products.where((p) {
      final matchesQuery = _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      final matchesCat = _categoryId == null || p.categorieId == _categoryId;
      return matchesQuery && matchesCat;
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catalogue', style: Theme.of(context).textTheme.displaySmall),
                        Text(
                          user?.magasin ?? 'Sou9ix',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un produit…',
                  prefixIcon: Icon(Icons.search_rounded, size: 22),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip(
                    label: 'Tous',
                    selected: _categoryId == null,
                    onTap: () => setState(() => _categoryId = null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: c.name,
                          selected: _categoryId == c.id,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun produit',
                      message: 'Aucun résultat pour cette recherche\nou cette catégorie.',
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, cart.isEmpty ? 24 : 110),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.92,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final inCart = cart.where((i) => i.product.id == product.id);
                        return ProductTile(
                          product: product,
                          quantiteInCart: inCart.isEmpty ? 0 : inCart.first.quantite,
                          onTap: () => _handleProductTap(product),
                        ).animate().fadeIn(duration: 260.ms, delay: (20 * index).ms);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: cart.isEmpty
          ? null
          : PressScale(
              onTap: () => CartSheet.show(context),
              child: Container(
                margin: const EdgeInsets.only(bottom: 74),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.tealGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: AppShadows.colored(AppColors.teal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '${cart.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Voir le panier · ${AppFormat.dt(cartTotal)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
