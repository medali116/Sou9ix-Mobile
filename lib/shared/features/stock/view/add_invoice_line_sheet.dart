import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/stock/model/draft_invoice_line.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/expiry_date_field.dart';
import 'package:sou9ix/shared/core/widgets/photo_picker_field.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/segmented_tabs.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';
import 'package:sou9ix/shared/features/pos/view/barcode_capture_screen.dart';

/// Bottom sheet to build one [DraftInvoiceLine]: restock an existing
/// product or define a brand-new one, its received quantity and unit cost.
class AddInvoiceLineSheet extends ConsumerStatefulWidget {
  /// When editing an already-staged line, its current values pre-fill the
  /// form and "Ajouter" becomes "Modifier".
  final DraftInvoiceLine? initial;

  const AddInvoiceLineSheet({super.key, this.initial});

  static Future<DraftInvoiceLine?> show(
    BuildContext context, {
    DraftInvoiceLine? initial,
  }) {
    return showModalBottomSheet<DraftInvoiceLine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddInvoiceLineSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddInvoiceLineSheet> createState() =>
      _AddInvoiceLineSheetState();
}

class _AddInvoiceLineSheetState extends ConsumerState<AddInvoiceLineSheet> {
  bool _newProduct = false;
  Product? _selectedProduct;
  String _productQuery = '';

  final _newNameCtrl = TextEditingController();
  final _newPrixVenteCtrl = TextEditingController();
  final _newCodeCtrl = TextEditingController();
  bool _newVenduAuPoids = false;
  String _newCategorieId = 'epicerie';
  final _newSeuilCtrl = TextEditingController(text: '2');
  DateTime? _newDatePeremption;
  Uint8List? _productPhotoBytes;

  late final _quantiteCtrl = TextEditingController(
    text: widget.initial != null
        ? widget.initial!.quantite.toStringAsFixed(
            widget.initial!.venduAuPoids ? 3 : 0,
          )
        : '',
  );
  late final _prixAchatCtrl = TextEditingController(
    text: widget.initial?.prixAchatUnitaire.toStringAsFixed(3) ?? '',
  );

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _newProduct = initial.newProductDraft != null;
      _selectedProduct = initial.existingProduct;
      if (initial.newProductDraft != null) {
        final p = initial.newProductDraft!;
        _newNameCtrl.text = p.name;
        _newPrixVenteCtrl.text = p.prixVente.toStringAsFixed(3);
        _newCodeCtrl.text = p.codeBarres ?? '';
        _newVenduAuPoids = p.venduAuPoids;
        _newCategorieId = p.categorieId;
        _newSeuilCtrl.text = p.seuilAlerte.toStringAsFixed(2);
        _newDatePeremption = p.datePeremption;
        _productPhotoBytes = p.photoBytes;
      }
    }
  }

  @override
  void dispose() {
    _newNameCtrl.dispose();
    _newPrixVenteCtrl.dispose();
    _newCodeCtrl.dispose();
    _newSeuilCtrl.dispose();
    _quantiteCtrl.dispose();
    _prixAchatCtrl.dispose();
    super.dispose();
  }

  bool get _venduAuPoids => _newProduct
      ? _newVenduAuPoids
      : (_selectedProduct?.venduAuPoids ?? false);

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _newCodeCtrl.text = code);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final quantite = double.tryParse(_quantiteCtrl.text.replaceAll(',', '.'));
    final prixAchat = double.tryParse(_prixAchatCtrl.text.replaceAll(',', '.'));

    if (quantite == null || quantite <= 0) {
      _showError('Indiquez une quantité reçue valide');
      return;
    }
    if (prixAchat == null || prixAchat <= 0) {
      _showError('Indiquez un prix d\'achat valide');
      return;
    }

    if (_newProduct) {
      final name = _newNameCtrl.text.trim();
      final prixVente = double.tryParse(
        _newPrixVenteCtrl.text.replaceAll(',', '.'),
      );
      if (name.isEmpty) {
        _showError('Le nom du nouveau produit est requis');
        return;
      }
      if (prixVente == null || prixVente <= 0) {
        _showError('Indiquez un prix de vente valide');
        return;
      }
      final newProduct = Product(
        id:
            widget.initial?.newProductDraft?.id ??
            'p${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        emoji: '📦',
        photoBytes: _productPhotoBytes,
        prixVente: prixVente,
        prixAchat: prixAchat,
        codeBarres: _newCodeCtrl.text.trim().isEmpty
            ? null
            : _newCodeCtrl.text.trim(),
        venduAuPoids: _newVenduAuPoids,
        categorieId: _newCategorieId,
        stock: quantite,
        seuilAlerte: double.tryParse(_newSeuilCtrl.text) ?? 2,
        datePeremption: _newDatePeremption,
      );
      Navigator.pop(
        context,
        DraftInvoiceLine(
          newProductDraft: newProduct,
          quantite: quantite,
          prixAchatUnitaire: prixAchat,
        ),
      );
    } else {
      if (_selectedProduct == null) {
        _showError('Sélectionnez le produit à réapprovisionner');
        return;
      }
      Navigator.pop(
        context,
        DraftInvoiceLine(
          existingProduct: _selectedProduct,
          quantite: quantite,
          prixAchatUnitaire: prixAchat,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final filtered = products
        .where(
          (p) =>
              _productQuery.isEmpty ||
              p.name.toLowerCase().contains(_productQuery.toLowerCase()),
        )
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Modifier la ligne' : 'Ajouter une ligne',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SegmentedTabs(
                    labels: const ['Réapprovisionner', 'Nouveau produit'],
                    selectedIndex: _newProduct ? 1 : 0,
                    onChanged: (i) => setState(() => _newProduct = i == 1),
                  ),
                  const SizedBox(height: 20),
                  if (!_newProduct) ...[
                    _label('Produit à réapprovisionner'),
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
                          .take(6)
                          .map(
                            (p) => PressScale(
                              onTap: () => setState(() {
                                _selectedProduct = p;
                                _prixAchatCtrl.text = p.prixAchat
                                    .toStringAsFixed(3);
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
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
                                      emoji: p.emoji,
                                      photoBytes: p.photoBytes,
                                      size: 38,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          Text(
                                            'Stock actuel : ${p.venduAuPoids ? '${p.stock.toStringAsFixed(3)} kg' : '${p.stock.toInt()} pcs'}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
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
                              child: Text(
                                _selectedProduct!.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _selectedProduct = null),
                              child: const Text('Changer'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                  ] else ...[
                    _label('Photo du produit (optionnel)'),
                    PhotoPickerField(
                      photoBytes: _productPhotoBytes,
                      onChanged: (bytes) =>
                          setState(() => _productPhotoBytes = bytes),
                      placeholderLabel: 'Ajouter une photo du produit',
                      placeholderIcon: Icons.inventory_2_outlined,
                      height: 110,
                    ),
                    const SizedBox(height: 16),
                    _label('Nom du produit'),
                    TextField(
                      controller: _newNameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Noisettes grillées',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Code-barres (EAN)'),
                    TextField(
                      controller: _newCodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Optionnel — scannez ou saisissez',
                        suffixIcon: IconButton(
                          onPressed: _scanBarcode,
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            color: AppColors.teal,
                          ),
                          tooltip: 'Scanner le code-barres',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Catégorie'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((c) {
                        final selected = c.id == _newCategorieId;
                        return ChoiceChip(
                          label: Text(c.name),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _newCategorieId = c.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _label('Prix de vente (DT)'),
                    TextField(
                      controller: _newPrixVenteCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(hintText: '0.000'),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Vendu au poids (kg)'),
                        value: _newVenduAuPoids,
                        activeThumbColor: AppColors.teal,
                        onChanged: (v) => setState(() => _newVenduAuPoids = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Seuil d\'alerte de stock'),
                    TextField(
                      controller: _newSeuilCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Date de péremption (optionnel)'),
                    ExpiryDateField(
                      value: _newDatePeremption,
                      onChanged: (d) => setState(() => _newDatePeremption = d),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(
                              _newProduct
                                  ? 'Quantité initiale'
                                  : 'Quantité reçue',
                            ),
                            TextField(
                              controller: _quantiteCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                hintText: _venduAuPoids ? 'kg' : 'pièces',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Prix d\'achat unitaire (DT)'),
                            TextField(
                              controller: _prixAchatCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: '0.000',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(
                        _isEdit ? 'Modifier la ligne' : 'Ajouter la ligne',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
