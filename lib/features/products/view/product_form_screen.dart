import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/products/model/category.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/expiry_date_field.dart';
import 'package:sou9ix/core/widgets/photo_picker_field.dart';
import 'package:sou9ix/features/pos/view/barcode_capture_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _prixVenteCtrl;
  late final TextEditingController _prixAchatCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _seuilCtrl;
  late bool _venduAuPoids;
  late String _categorieId;
  Uint8List? _photoBytes;
  DateTime? _datePeremption;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _prixVenteCtrl = TextEditingController(
      text: p != null ? p.prixVente.toStringAsFixed(3) : '',
    );
    _prixAchatCtrl = TextEditingController(
      text: p != null ? p.prixAchat.toStringAsFixed(3) : '',
    );
    _codeCtrl = TextEditingController(text: p?.codeBarres ?? '');
    _stockCtrl = TextEditingController(
      text: p != null ? p.stock.toStringAsFixed(2) : '0',
    );
    _seuilCtrl = TextEditingController(
      text: p != null ? p.seuilAlerte.toStringAsFixed(2) : '2',
    );
    _venduAuPoids = p?.venduAuPoids ?? false;
    _categorieId = p?.categorieId ?? 'epicerie';
    _photoBytes = p?.photoBytes;
    _datePeremption = p?.datePeremption;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _prixVenteCtrl.dispose();
    _prixAchatCtrl.dispose();
    _codeCtrl.dispose();
    _stockCtrl.dispose();
    _seuilCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _codeCtrl.text = code);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du produit est requis')),
      );
      return;
    }
    final prixVente = double.tryParse(_prixVenteCtrl.text) ?? 0;
    final prixAchat = double.tryParse(_prixAchatCtrl.text) ?? 0;
    final product = Product(
      id: widget.product?.id ?? 'p${DateTime.now().microsecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      emoji: widget.product?.emoji ?? '📦',
      photoBytes: _photoBytes,
      prixVente: prixVente,
      prixAchat: prixAchat,
      codeBarres: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
      venduAuPoids: _venduAuPoids,
      categorieId: _categorieId,
      stock: double.tryParse(_stockCtrl.text) ?? 0,
      seuilAlerte: double.tryParse(_seuilCtrl.text) ?? 0,
      datePeremption: _datePeremption,
    );

    String? motifPrix;
    final old = widget.product;
    final prixChange =
        old != null &&
        (old.prixVente != prixVente || old.prixAchat != prixAchat);
    if (prixChange) {
      motifPrix = await _promptMotifPrix(context);
      if (motifPrix == null) return; // cancelled — required, so bail out
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(productsProvider.notifier)
          .upsert(product, motifPrix: motifPrix);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'enregistrement : $e')),
      );
      return;
    }
    if (!mounted) return;
    context.pop();
  }

  Future<String?> _promptMotifPrix(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Motif du changement de prix'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(
              labelText: 'Motif',
              prefixIcon: Icon(Icons.edit_note_rounded),
              hintText: 'Ex. Nouveau tarif fournisseur',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, ctrl.text.trim()),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final motifCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Supprimer ce produit ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '« ${widget.product!.name} » sera déplacé vers la Corbeille — vous pourrez le restaurer.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: motifCtrl,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  hintText: 'Ex. Produit discontinué',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: motifCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      ref
          .read(productsProvider.notifier)
          .remove(widget.product!.id, motif: motifCtrl.text.trim());
      context.pop();
    }
  }

  Future<void> _createNewCategory() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ex. Produits laitiers'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, nameCtrl.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final category = ProductCategory(
      id: 'cat${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      icon: Icons.category_rounded,
    );
    try {
      await ref.read(categoriesProvider.notifier).add(category);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de l\'ajout : $e')));
      return;
    }
    if (!mounted) return;
    setState(() => _categorieId = category.id);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _label('Photo du produit (optionnel)'),
          PhotoPickerField(
            photoBytes: _photoBytes,
            onChanged: (bytes) => setState(() => _photoBytes = bytes),
            placeholderLabel: 'Ajouter une photo du produit',
            placeholderIcon: Icons.inventory_2_outlined,
            height: 120,
          ),
          const SizedBox(height: 18),
          _label('Nom du produit'),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex. Amandes décortiquées',
            ),
          ),
          const SizedBox(height: 18),
          _label('Catégorie'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...categories.map((c) {
                final selected = c.id == _categorieId;
                return ChoiceChip(
                  label: Text(c.name),
                  selected: selected,
                  onSelected: (_) => setState(() => _categorieId = c.id),
                );
              }),
              ActionChip(
                avatar: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: AppColors.teal,
                ),
                label: const Text(
                  'Nouvelle catégorie',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _createNewCategory,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Prix de vente (DT)'),
                    TextField(
                      controller: _prixVenteCtrl,
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
                    _label('Prix d\'achat (DT)'),
                    TextField(
                      controller: _prixAchatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(hintText: '0.000'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label('Code-barres (EAN)'),
          TextField(
            controller: _codeCtrl,
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vente au poids (kg)'),
              subtitle: const Text('Active le pavé numérique de pesée'),
              value: _venduAuPoids,
              activeThumbColor: AppColors.teal,
              onChanged: (v) => setState(() => _venduAuPoids = v),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      _venduAuPoids
                          ? 'Stock actuel (kg)'
                          : 'Stock actuel (pcs)',
                    ),
                    TextField(
                      controller: _stockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
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
                    _label('Seuil d\'alerte'),
                    TextField(
                      controller: _seuilCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label('Date de péremption (optionnel)'),
          ExpiryDateField(
            value: _datePeremption,
            onChanged: (d) => setState(() => _datePeremption = d),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? 'Enregistrer les modifications'
                          : 'Ajouter le produit',
                    ),
            ),
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
