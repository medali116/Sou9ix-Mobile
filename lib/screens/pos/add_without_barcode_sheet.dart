import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/sheet_handle.dart';
import 'weight_entry_sheet.dart';

/// Lets the cashier add an item to the cart without scanning a barcode:
/// either by searching the existing catalogue, or by keying in a one-off
/// "article libre" (name + price) for something not in the catalogue at all
/// — e.g. a custom weighed mix, a favour price, a non-inventoried service.
class AddWithoutBarcodeSheet extends ConsumerStatefulWidget {
  const AddWithoutBarcodeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWithoutBarcodeSheet(),
    );
  }

  @override
  ConsumerState<AddWithoutBarcodeSheet> createState() =>
      _AddWithoutBarcodeSheetState();
}

class _AddWithoutBarcodeSheetState
    extends ConsumerState<AddWithoutBarcodeSheet> {
  bool _freeForm = false;
  String _query = '';

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  bool _venduAuPoids = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFromCatalogue(Product product) async {
    if (product.venduAuPoids) {
      final poids = await WeightEntrySheet.show(context, product);
      if (poids != null && poids > 0) {
        ref.read(cartProvider.notifier).addWeighted(product, poids);
        if (mounted) Navigator.pop(context);
      }
    } else {
      ref.read(cartProvider.notifier).addPiece(product);
      Navigator.pop(context);
    }
  }

  void _addFreeForm() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 1;

    if (name.isEmpty || price == null || price <= 0 || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseignez un nom et un prix valides')),
      );
      return;
    }

    final product = Product(
      id: 'libre_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      emoji: '🏷️',
      prixVente: price,
      prixAchat: price,
      venduAuPoids: _venduAuPoids,
      categorieId: 'epicerie',
      stock: 0,
      seuilAlerte: 0,
    );
    if (_venduAuPoids) {
      ref.read(cartProvider.notifier).addWeighted(product, qty);
    } else {
      ref.read(cartProvider.notifier).addPiece(product);
      if (qty > 1) {
        ref.read(cartProvider.notifier).updateQuantite(product.id, qty);
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final filtered = products
        .where(
          (p) =>
              _query.isEmpty ||
              p.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
                      'Ajouter sans code-barres',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: 'Depuis le catalogue',
                          selected: !_freeForm,
                          onTap: () => setState(() => _freeForm = false),
                        ),
                      ),
                      Expanded(
                        child: _ModeTab(
                          label: 'Article libre',
                          selected: _freeForm,
                          onTap: () => setState(() => _freeForm = true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _freeForm
                    ? _buildFreeForm(scrollController)
                    : _buildCatalogueSearch(scrollController, filtered),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogueSearch(
    ScrollController scrollController,
    List<Product> filtered,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Rechercher un produit par nom…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Aucun résultat',
                  message: 'Essayez un autre nom, ou créez\nun article libre.',
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return PressScale(
                      onTap: () => _addFromCatalogue(p),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            ProductAvatar(
                              emoji: p.emoji,
                              photoBytes: p.photoBytes,
                              size: 40,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    p.venduAuPoids
                                        ? '${AppFormat.dtShort(p.prixVente)}/kg'
                                        : AppFormat.dtShort(p.prixVente),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.add_circle_rounded,
                              color: AppColors.teal,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(
                      duration: 180.ms,
                      delay: (14 * index).ms,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFreeForm(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text('Nom du produit', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(hintText: 'Ex. Sachet cadeau'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prix (DT)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(hintText: '0.000'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _venduAuPoids ? 'Poids (kg)' : 'Quantité',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vendu au poids (kg)'),
            value: _venduAuPoids,
            activeThumbColor: AppColors.teal,
            onChanged: (v) => setState(() => _venduAuPoids = v),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addFreeForm,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter au panier'),
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: selected ? AppShadows.card : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: selected ? AppColors.teal : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
