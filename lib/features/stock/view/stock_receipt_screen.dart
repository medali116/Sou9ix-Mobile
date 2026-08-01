import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/pos/view/barcode_capture_screen.dart';
import 'package:sou9ix/features/pos/view/discount_editor_sheet.dart';
import 'package:sou9ix/features/stock/model/draft_invoice_line.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/service/purchase_service.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/features/stock/view/add_invoice_line_sheet.dart';

enum _StatutPaiement { integrale, partielle, nonPayee }

/// Builds one supplier invoice: reference/dates, fournisseur, as many
/// product lines as the paper invoice actually has, VAT/remise, how much
/// has been paid so far and by what method, a photo, and free-text notes.
/// Nothing is written to any provider until "Enregistrer" is pressed — the
/// lines are just a local draft list until then.
class StockReceiptScreen extends ConsumerStatefulWidget {
  const StockReceiptScreen({super.key});

  @override
  ConsumerState<StockReceiptScreen> createState() => _StockReceiptScreenState();
}

class _StockReceiptScreenState extends ConsumerState<StockReceiptScreen> {
  final List<DraftInvoiceLine> _lines = [];
  final _numeroFournisseurCtrl = TextEditingController();
  final _montantVerseCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  DateTime _dateFacture = DateTime.now();
  DateTime _dateReception = DateTime.now();
  double _tvaRate = 13;
  Discount _discount = const Discount.none();
  PurchasePaymentMethod _modePaiement = PurchasePaymentMethod.especes;
  _StatutPaiement _statutPaiement = _StatutPaiement.nonPayee;
  Uint8List? _invoicePhotoBytes;
  String? _photoFileName;
  Supplier? _selectedSupplier;
  String _supplierQuery = '';
  bool _summaryExpanded = true;
  bool _saving = false;

  double get _sousTotal => _lines.fold(0, (sum, l) => sum + l.montant);
  double get _tvaAmount => _sousTotal * _tvaRate / 100;
  double get _totalTTC =>
      _discount.applyTo(_sousTotal + _tvaAmount).clamp(0, double.infinity);

  @override
  void dispose() {
    _numeroFournisseurCtrl.dispose();
    _montantVerseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _addLine() async {
    final line = await AddInvoiceLineSheet.show(context);
    if (line != null) setState(() => _lines.add(line));
  }

  Future<void> _editLine(int index) async {
    final line = await AddInvoiceLineSheet.show(
      context,
      initial: _lines[index],
    );
    if (line != null) setState(() => _lines[index] = line);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scanNumeroFournisseur() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _numeroFournisseurCtrl.text = code);
    }
  }

  Future<void> _pickDate({required bool isFacture}) async {
    final initial = isFacture ? _dateFacture : _dateReception;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFacture) {
        _dateFacture = picked;
      } else {
        _dateReception = picked;
      }
    });
  }

  Future<void> _editTva() async {
    final ctrl = TextEditingController(text: _tvaRate.toStringAsFixed(0));
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Taux de TVA'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0', suffixText: '%'),
          onSubmitted: (v) => Navigator.pop(dialogContext, double.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, double.tryParse(ctrl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _tvaRate = result.clamp(0, 100));
  }

  Future<void> _editDiscount() async {
    final result = await DiscountEditorSheet.show(
      context,
      title: 'Remise fournisseur',
      initial: _discount,
    );
    if (result != null) setState(() => _discount = result);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _invoicePhotoBytes = bytes;
      _photoFileName = file.name.isNotEmpty
          ? file.name
          : 'facture_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.jpg';
    });
  }

  void _setMontantVerse(String text) {
    _montantVerseCtrl.text = text;
    final value = double.tryParse(text) ?? 0;
    setState(() {
      if (value <= 0) {
        _statutPaiement = _StatutPaiement.nonPayee;
      } else if (value >= _totalTTC) {
        _statutPaiement = _StatutPaiement.integrale;
      } else {
        _statutPaiement = _StatutPaiement.partielle;
      }
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      _showError('Ajoutez au moins une ligne à la facture');
      return;
    }
    final montantPaye =
        double.tryParse(_montantVerseCtrl.text.replaceAll(',', '.')) ?? 0;

    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));

    ref
        .read(purchaseServiceProvider)
        .receiveInvoice(
          lines: _lines,
          supplier: _selectedSupplier,
          photoBytes: _invoicePhotoBytes,
          montantPaye: montantPaye,
          numeroFournisseur: _numeroFournisseurCtrl.text.trim().isEmpty
              ? null
              : _numeroFournisseurCtrl.text.trim(),
          dateFacture: _dateFacture,
          dateReception: _dateReception,
          tvaRate: _tvaRate,
          discount: _discount,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          modePaiement: montantPaye > 0 ? _modePaiement : null,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Facture enregistrée : ${_lines.length} produit${_lines.length > 1 ? 's' : ''}',
        ),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(suppliersProvider);
    final filteredSuppliers = suppliers
        .where(
          (s) =>
              _supplierQuery.isEmpty ||
              s.nom.toLowerCase().contains(_supplierQuery.toLowerCase()),
        )
        .toList();
    final dateFmt = DateFormat('dd/MM/yyyy');

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
          _label('Informations de la facture'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('N° Facture fournisseur'),
                TextField(
                  controller: _numeroFournisseurCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ex. FA-2026-08-0012',
                    suffixIcon: IconButton(
                      onPressed: _scanNumeroFournisseur,
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.teal,
                      ),
                      tooltip: 'Scanner le numéro',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Date de la facture'),
                          _DateField(
                            label: dateFmt.format(_dateFacture),
                            onTap: () => _pickDate(isFacture: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Date de réception'),
                          _DateField(
                            label: dateFmt.format(_dateReception),
                            onTap: () => _pickDate(isFacture: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _label('Fournisseur'),
          if (_selectedSupplier == null) ...[
            TextField(
              onChanged: (v) => setState(() => _supplierQuery = v),
              decoration: const InputDecoration(
                hintText: 'Rechercher un fournisseur par nom…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            ...filteredSuppliers
                .take(5)
                .map(
                  (s) => PressScale(
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
                            backgroundColor: AppColors.teal.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: AppColors.tealDark,
                            child: Text(s.nom.substring(0, 1)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.nom,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                    Text(
                      'Nouveau fournisseur',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            PressScale(
              onTap: () =>
                  context.push('/suppliers/detail', extra: _selectedSupplier),
              child: Container(
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
                    CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                      foregroundColor: AppColors.tealDark,
                      child: Text(_selectedSupplier!.nom.substring(0, 1)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSupplier!.nom,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_selectedSupplier!.telephone.isNotEmpty)
                            Text(
                              'Téléphone : ${_selectedSupplier!.telephone}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textFaint,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _selectedSupplier = null),
                child: const Text('Changer'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lignes de la facture', style: _labelStyle),
              PressScale(
                onTap: _addLine,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.teal, width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: AppColors.teal, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Ajouter une ligne',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                    ProductAvatar(
                      emoji: line.emoji,
                      photoBytes: line.photoBytes,
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.productName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${line.quantite.toStringAsFixed(line.venduAuPoids ? 3 : 0)} ${line.venduAuPoids ? 'kg' : 'pcs'} × ${AppFormat.dtShort(line.prixAchatUnitaire)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      AppFormat.dtShort(line.montant),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: () => _editLine(index),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.teal,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _lines.removeAt(index)),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: 10),
            _label('Résumé'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                children: [
                  _summaryRow('Sous-total', AppFormat.dt(_sousTotal)),
                  const SizedBox(height: 6),
                  PressScale(
                    onTap: _editTva,
                    child: _summaryRow(
                      'TVA (${_tvaRate.toStringAsFixed(_tvaRate.truncateToDouble() == _tvaRate ? 0 : 1)}%)',
                      AppFormat.dt(_tvaAmount),
                    ),
                  ),
                  const SizedBox(height: 6),
                  PressScale(
                    onTap: _editDiscount,
                    child: _summaryRow(
                      'Remise',
                      _discount.isNone
                          ? AppFormat.dt(0)
                          : _discount.label(AppFormat.dt),
                      valueColor: _discount.isNone ? null : AppColors.danger,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total à payer',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.tealDark),
                      ),
                      Text(
                        AppFormat.dt(_totalTTC),
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _label('Statut de paiement'),
          Row(
            children: [
              Expanded(
                child: _StatusChip(
                  label: 'Payée intégralement',
                  selected: _statutPaiement == _StatutPaiement.integrale,
                  onTap: () => _setMontantVerse(_totalTTC.toStringAsFixed(3)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  label: 'Partiellement payée',
                  selected: _statutPaiement == _StatutPaiement.partielle,
                  onTap: () => setState(
                    () => _statutPaiement = _StatutPaiement.partielle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  label: 'Non payée',
                  selected: _statutPaiement == _StatutPaiement.nonPayee,
                  onTap: () => _setMontantVerse('0'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _label('Mode de paiement'),
          Row(
            children: PurchasePaymentMethod.values.map((m) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: m != PurchasePaymentMethod.values.last ? 8 : 0,
                  ),
                  child: _PaymentMethodChip(
                    method: m,
                    selected: _modePaiement == m,
                    onTap: () => setState(() => _modePaiement = m),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          _label('Montant versé (DT)'),
          TextField(
            controller: _montantVerseCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.000'),
            onChanged: _setMontantVerse,
          ),
          const SizedBox(height: 18),
          _label('Photo de la facture (optionnel)'),
          _InvoicePhotoField(
            photoBytes: _invoicePhotoBytes,
            fileName: _photoFileName,
            onTakePhoto: () => _pickPhoto(ImageSource.camera),
            onPickGallery: () => _pickPhoto(ImageSource.gallery),
            onScan: () => _pickPhoto(ImageSource.camera),
            onRemove: () => setState(() {
              _invoicePhotoBytes = null;
              _photoFileName = null;
            }),
          ),
          const SizedBox(height: 18),
          _label('Observations (optionnel)'),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Ex. Achat mensuel — livraison complète.',
            ),
          ),
          const SizedBox(height: 12),
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
                      : const Text('Enregistrer la facture'),
                ),
              )
              .animate(target: _saving ? 1 : 0, onPlay: (c) => c.repeat())
              .shimmer(
                duration: 1100.ms,
                color: Colors.white.withValues(alpha: 0.45),
              ),
        ],
      ),
      bottomNavigationBar: _lines.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: AppShadows.soft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_lines.length} Produit${_lines.length > 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_summaryExpanded)
                            Text(
                              'Sous-total ${AppFormat.dt(_sousTotal)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          AppFormat.dt(_totalTTC),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    PressScale(
                      onTap: () =>
                          setState(() => _summaryExpanded = !_summaryExpanded),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _summaryExpanded
                              ? Icons.expand_more_rounded
                              : Icons.expand_less_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: _labelStyle),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textFaint,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final PurchasePaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              method.icon,
              size: 18,
              color: selected ? AppColors.teal : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              method.label,
              style: TextStyle(
                color: selected ? AppColors.teal : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows either the 3-way capture row (Prendre photo/Galerie/Scanner) or a
/// compact file row once a photo is attached — matching how a paper
/// document is handled, rather than a full-bleed image preview.
///
/// "Scanner" reuses the camera capture, same as "Prendre photo" — this app
/// has no document-scanning (edge-detection) capability, so it's an alias
/// rather than a distinct flow.
class _InvoicePhotoField extends StatelessWidget {
  final Uint8List? photoBytes;
  final String? fileName;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final VoidCallback onScan;
  final VoidCallback onRemove;

  const _InvoicePhotoField({
    required this.photoBytes,
    required this.fileName,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onScan,
    required this.onRemove,
  });

  String _formatSize(int bytes) => '${(bytes / 1024).toStringAsFixed(0)} KB';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (photoBytes != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photoBytes!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName ?? 'facture.jpg',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        _formatSize(photoBytes!.lengthInBytes),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _photoActionButton(
                context,
                icon: Icons.photo_camera_outlined,
                label: 'Prendre photo',
                onTap: onTakePhoto,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _photoActionButton(
                context,
                icon: Icons.image_outlined,
                label: 'Galerie',
                onTap: onPickGallery,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _photoActionButton(
                context,
                icon: Icons.document_scanner_outlined,
                label: 'Scanner',
                onTap: onScan,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _photoActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
