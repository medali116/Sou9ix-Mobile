import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/pos/model/cart_item.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/sales/service/sale_service.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/quantity_stepper.dart';
import 'package:sou9ix/shared/features/pos/view/weight_entry_sheet.dart';

/// Lets an admin correct a past sale: adjust quantities or remove lines,
/// change payment mode/client. Adding brand-new products to an existing
/// sale is intentionally out of scope — delete + re-ring is the path for
/// that; re-plumbing the full scan/cart flow into this screen isn't worth
/// it for how rarely that's needed.
///
/// On save, stock and client credit are reconciled against the *original*
/// sale (mirroring how [CheckoutScreen] applies them in the first place),
/// then the sale record itself is replaced.
class EditSaleScreen extends ConsumerStatefulWidget {
  final Sale sale;

  const EditSaleScreen({super.key, required this.sale});

  @override
  ConsumerState<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends ConsumerState<EditSaleScreen> {
  late List<CartItem> _lignes;
  late ModePaiement _mode;
  String? _clientId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lignes = List.of(widget.sale.lignes);
    _mode = widget.sale.modePaiement;
    _clientId = widget.sale.clientId;
  }

  double get _total => widget.sale.discount.applyTo(
    _lignes.fold(0, (sum, l) => sum + l.sousTotal),
  );

  double _originalQuantiteFor(String productId) {
    final matches = widget.sale.lignes.where((l) => l.product.id == productId);
    return matches.isEmpty ? 0 : matches.first.quantite;
  }

  void _updateQuantite(int index, double quantite) {
    if (quantite <= 0) {
      setState(() => _lignes.removeAt(index));
      return;
    }
    final item = _lignes[index];
    // Soft guard: don't let an increase eat into stock beyond what this
    // sale originally consumed — checkout itself has no such check today,
    // so this is a net-new safety improvement, not parity work.
    final produits = ref.read(productsProvider);
    final produit = produits.where((p) => p.id == item.product.id);
    if (produit.isNotEmpty) {
      final disponible =
          produit.first.stock + _originalQuantiteFor(item.product.id);
      if (quantite > disponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock insuffisant (max ${disponible.toStringAsFixed(item.product.venduAuPoids ? 3 : 0)})',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _lignes[index] = item.copyWith(quantite: quantite));
  }

  Future<void> _editWeight(int index) async {
    final item = _lignes[index];
    final updated = await WeightEntrySheet.show(
      context,
      item.product,
      initialKg: item.quantite,
    );
    if (updated != null) _updateQuantite(index, updated);
  }

  Future<void> _save() async {
    if (_lignes.isEmpty) return;
    if (_mode == ModePaiement.credit && _clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un client pour le crédit')),
      );
      return;
    }

    setState(() => _saving = true);

    ref
        .read(saleServiceProvider)
        .updateSale(
          original: widget.sale,
          lignes: _lignes,
          modePaiement: _mode,
          clientId: _clientId,
          discount: widget.sale.discount,
        );

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la vente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
        children: [
          if (_lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Aucun article — utilisez « Supprimer » depuis l\'historique pour annuler cette vente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...List.generate(_lignes.length, (index) {
              final item = _lignes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EditableLineRow(
                  item: item,
                  onQuantiteChanged: (q) => _updateQuantite(index, q),
                  onEditWeight: () => _editWeight(index),
                  onRemove: () => setState(() => _lignes.removeAt(index)),
                ),
              );
            }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nouveau total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  AppFormat.dt(_total),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Mode de paiement',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: ModePaiement.values.map((m) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: m != ModePaiement.values.last ? 10 : 0,
                  ),
                  child: _ModeOption(
                    label: m.label,
                    selected: _mode == m,
                    onTap: () => setState(() => _mode = m),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_mode == ModePaiement.credit) ...[
            const SizedBox(height: 20),
            Text(
              'Client (karné)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            ...clients.map((c) {
              final selected = c.id == _clientId;
              return PressScale(
                onTap: () => setState(() => _clientId = c.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.teal.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected ? AppColors.teal : AppColors.border,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                        foregroundColor: AppColors.goldDark,
                        child: Text(c.nom.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.nom,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Solde dû : ${AppFormat.dt(c.creditTotal)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected ? AppColors.teal : AppColors.textFaint,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || _lignes.isEmpty) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enregistrer les modifications'),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableLineRow extends StatelessWidget {
  final CartItem item;
  final ValueChanged<double> onQuantiteChanged;
  final VoidCallback onEditWeight;
  final VoidCallback onRemove;

  const _EditableLineRow({
    required this.item,
    required this.onQuantiteChanged,
    required this.onEditWeight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          ProductAvatar(
            emoji: product.emoji,
            photoBytes: product.photoBytes,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  product.venduAuPoids
                      ? '${AppFormat.kg(item.quantite)} × ${AppFormat.dtShort(product.prixVente)}'
                      : '${item.quantite.toInt()} × ${AppFormat.dtShort(product.prixVente)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (product.venduAuPoids)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _smallIconBtn(icon: Icons.edit_rounded, onTap: onEditWeight),
                _smallIconBtn(
                  icon: Icons.delete_outline_rounded,
                  onTap: onRemove,
                  color: AppColors.danger,
                ),
              ],
            )
          else
            QuantityStepper(
              quantite: item.quantite,
              onChanged: onQuantiteChanged,
            ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                AppFormat.dtShort(item.sousTotal),
                maxLines: 1,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color ?? AppColors.textPrimary),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
          boxShadow: selected
              ? AppShadows.colored(AppColors.teal)
              : AppShadows.card,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
