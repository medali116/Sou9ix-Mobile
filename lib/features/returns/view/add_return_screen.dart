import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/returns/model/stock_return.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/returns/service/stock_service.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';

/// Records a product write-off (expired, damaged, stolen…): decrements
/// stock and logs the loss at cost price for later review in the Retours
/// & pertes screen.
class AddReturnScreen extends ConsumerStatefulWidget {
  /// Preselects the product being returned — e.g. when reached from a
  /// ticket's "Retourner un produit" action — so the cashier doesn't have
  /// to search for it again.
  final Product? initialProduct;

  const AddReturnScreen({super.key, this.initialProduct});

  @override
  ConsumerState<AddReturnScreen> createState() => _AddReturnScreenState();
}

class _AddReturnScreenState extends ConsumerState<AddReturnScreen> {
  Product? _selectedProduct;
  String _productQuery = '';
  final _quantiteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  RetourMotif _motif = RetourMotif.peremption;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _quantiteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final product = _selectedProduct;
    if (product == null) {
      _showError('Sélectionnez le produit concerné');
      return;
    }
    final quantite = double.tryParse(_quantiteCtrl.text.replaceAll(',', '.'));
    if (quantite == null || quantite <= 0) {
      _showError('Indiquez une quantité valide');
      return;
    }
    if (quantite > product.stock) {
      _showError(
        'Quantité supérieure au stock disponible (${product.stock.toStringAsFixed(product.venduAuPoids ? 3 : 0)})',
      );
      return;
    }

    setState(() => _saving = true);

    ref
        .read(stockServiceProvider)
        .recordReturn(
          product: product,
          quantite: quantite,
          motif: _motif,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final filtered = products
        .where(
          (p) =>
              _productQuery.isEmpty ||
              p.name.toLowerCase().contains(_productQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer un retour')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _label('Produit concerné'),
          if (_selectedProduct == null) ...[
            TextField(
              onChanged: (v) => setState(() => _productQuery = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit par nom…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            ...filtered
                .take(8)
                .map(
                  (p) => PressScale(
                    onTap: () => setState(() => _selectedProduct = p),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
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
                            size: 38,
                          ),
                          const SizedBox(width: 10),
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
                                  'Stock actuel : ${p.venduAuPoids ? '${p.stock.toStringAsFixed(3)} kg' : '${p.stock.toInt()} pcs'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  ProductAvatar(
                    emoji: _selectedProduct!.emoji,
                    photoBytes: _selectedProduct!.photoBytes,
                    size: 42,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedProduct!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Stock actuel : ${_selectedProduct!.venduAuPoids ? '${_selectedProduct!.stock.toStringAsFixed(3)} kg' : '${_selectedProduct!.stock.toInt()} pcs'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedProduct = null),
                    child: const Text('Changer'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _label(
            _selectedProduct != null && _selectedProduct!.venduAuPoids
                ? 'Quantité (kg)'
                : 'Quantité (pièces)',
          ),
          TextField(
            controller: _quantiteCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          _label('Motif'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RetourMotif.values.map((m) {
              final selected = m == _motif;
              return ChoiceChip(
                label: Text(m.label),
                selected: selected,
                onSelected: (_) => setState(() => _motif = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _label('Note (optionnel)'),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Détails supplémentaires…',
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer le retour'),
                ),
              )
              .animate(target: _saving ? 1 : 0, onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1100.ms,
                color: Colors.white.withValues(alpha: 0.45),
              ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}
