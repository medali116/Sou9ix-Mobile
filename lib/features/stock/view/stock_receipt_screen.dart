import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/stock/model/draft_invoice_line.dart';
import 'package:sou9ix/features/stock/service/purchase_service.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/photo_picker_field.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/features/stock/view/add_invoice_line_sheet.dart';

/// Builds one supplier invoice: one photo + fournisseur + as many product
/// lines as the paper invoice actually has, plus how much has been paid so
/// far. Nothing is written to any provider until "Enregistrer la facture"
/// is pressed — the lines are just a local draft list until then.
class StockReceiptScreen extends ConsumerStatefulWidget {
  const StockReceiptScreen({super.key});

  @override
  ConsumerState<StockReceiptScreen> createState() => _StockReceiptScreenState();
}

class _StockReceiptScreenState extends ConsumerState<StockReceiptScreen> {
  final List<DraftInvoiceLine> _lines = [];
  final _montantVerseCtrl = TextEditingController(text: '0');
  Uint8List? _invoicePhotoBytes;
  Supplier? _selectedSupplier;
  String _supplierQuery = '';
  bool _saving = false;

  double get _total => _lines.fold(0, (sum, l) => sum + l.montant);

  @override
  void dispose() {
    _montantVerseCtrl.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final line = await AddInvoiceLineSheet.show(context);
    if (line != null) setState(() => _lines.add(line));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      _showError('Ajoutez au moins une ligne à la facture');
      return;
    }
    final montantPaye = double.tryParse(_montantVerseCtrl.text.replaceAll(',', '.')) ?? 0;

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    ref.read(purchaseServiceProvider).receiveInvoice(
          lines: _lines,
          supplier: _selectedSupplier,
          photoBytes: _invoicePhotoBytes,
          montantPaye: montantPaye,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Facture enregistrée : ${_lines.length} produit${_lines.length > 1 ? 's' : ''}')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final filteredSuppliers = suppliers
        .where((s) => _supplierQuery.isEmpty || s.nom.toLowerCase().contains(_supplierQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réceptionner un achat'),
        actions: [
          IconButton(
            onPressed: () => context.push('/purchases'),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Historique des achats',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _label('Lignes de la facture'),
          if (_lines.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Aucun produit ajouté pour l\'instant.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            ...List.generate(_lines.length, (index) {
              final line = _lines[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    ProductAvatar(emoji: line.emoji, photoBytes: line.photoBytes, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.productName, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${line.quantite.toStringAsFixed(line.venduAuPoids ? 3 : 0)} ${line.venduAuPoids ? 'kg' : 'pcs'} × ${AppFormat.dtShort(line.prixAchatUnitaire)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(AppFormat.dtShort(line.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () => setState(() => _lines.removeAt(index)),
                      icon: const Icon(Icons.close_rounded, color: AppColors.danger, size: 18),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
          PressScale(
            onTap: _addLine,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.teal, width: 1.2),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: AppColors.teal, size: 18),
                  SizedBox(width: 6),
                  Text('Ajouter une ligne', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_lines.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.inkGradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL FACTURE', style: TextStyle(color: AppColors.tealLight, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(AppFormat.dt(_total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          _label('Fournisseur (optionnel)'),
          if (_selectedSupplier == null) ...[
            TextField(
              onChanged: (v) => setState(() => _supplierQuery = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un fournisseur par nom…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            ...filteredSuppliers.take(5).map((s) => PressScale(
                  onTap: () => setState(() => _selectedSupplier = s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                          foregroundColor: AppColors.tealDark,
                          child: Text(s.nom.substring(0, 1)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.nom, style: Theme.of(context).textTheme.titleMedium)),
                      ],
                    ),
                  ),
                )),
            PressScale(
              onTap: () => context.push('/suppliers/new'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.teal, width: 1.2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.teal, size: 18),
                    SizedBox(width: 6),
                    Text('Nouveau fournisseur', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                    foregroundColor: AppColors.tealDark,
                    child: Text(_selectedSupplier!.nom.substring(0, 1)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_selectedSupplier!.nom, style: Theme.of(context).textTheme.titleMedium)),
                  TextButton(
                    onPressed: () => setState(() => _selectedSupplier = null),
                    child: const Text('Changer'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _label('Photo de la facture'),
          PhotoPickerField(
            photoBytes: _invoicePhotoBytes,
            onChanged: (bytes) => setState(() => _invoicePhotoBytes = bytes),
            placeholderLabel: 'Ajouter une photo de la facture',
          ),
          const SizedBox(height: 18),
          _label('Statut de paiement'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _montantVerseCtrl.text = _total.toStringAsFixed(3)),
                  child: const Text('Payée intégralement'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _montantVerseCtrl.text = '0'),
                  child: const Text('Non payée'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _label('Montant versé maintenant (DT)'),
          TextField(
            controller: _montantVerseCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.000'),
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
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Enregistrer la facture'),
            ),
          ).animate(target: _saving ? 1 : 0, onPlay: (c) => c.repeat()).shimmer(
                duration: 1100.ms,
                color: Colors.white.withValues(alpha: 0.45),
              ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
