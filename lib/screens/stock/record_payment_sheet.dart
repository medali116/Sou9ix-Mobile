import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../models/purchase_invoice.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/sheet_handle.dart';

/// Small sheet to record an additional (partial or final) payment against
/// a supplier invoice that isn't fully settled yet.
class RecordPaymentSheet extends ConsumerStatefulWidget {
  final PurchaseInvoice invoice;

  const RecordPaymentSheet({super.key, required this.invoice});

  static Future<void> show(BuildContext context, PurchaseInvoice invoice) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(invoice: invoice),
    );
  }

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _montantCtrl =
      TextEditingController(text: widget.invoice.montantRestant.toStringAsFixed(3));

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(',', '.'));
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez un montant valide')),
      );
      return;
    }
    ref.read(purchaseInvoicesProvider.notifier).recordPayment(widget.invoice.id, montant);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Régler un paiement', style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reste à payer : ${AppFormat.dt(widget.invoice.montantRestant)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _montantCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: '0.000'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirm,
                child: const Text('Enregistrer le paiement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
