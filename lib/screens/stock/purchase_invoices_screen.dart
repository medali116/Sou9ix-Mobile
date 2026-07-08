import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../models/purchase_invoice.dart';
import '../../providers/purchase_invoices_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/segmented_tabs.dart';
import 'record_payment_sheet.dart';

/// Supplier-side mirror of the client karné: every stock receipt logged
/// from the Caisse screen lands here, with its invoice photo, product
/// lines, and how much of it is still owed.
class PurchaseInvoicesScreen extends ConsumerStatefulWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  ConsumerState<PurchaseInvoicesScreen> createState() => _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState extends ConsumerState<PurchaseInvoicesScreen> {
  bool _onlyUnsettled = false;

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(purchaseInvoicesProvider);
    final unsettled = ref.watch(unsettledInvoicesProvider);
    final totalUnpaid = ref.watch(totalUnpaidPurchasesProvider);
    final invoices = _onlyUnsettled ? unsettled : allInvoices;

    return Scaffold(
      appBar: AppBar(title: const Text('Achats fournisseurs')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL FACTURES IMPAYÉES',
                        style: TextStyle(
                          color: AppColors.tealLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormat.dt(totalUnpaid),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${unsettled.length} facture${unsettled.length > 1 ? 's' : ''} non soldée${unsettled.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.warning),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedTabs(
              labels: const ['Toutes', 'Non soldées'],
              selectedIndex: _onlyUnsettled ? 1 : 0,
              onChanged: (i) => setState(() => _onlyUnsettled = i == 1),
            ),
          ),
          Expanded(
            child: invoices.isEmpty
                ? const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Aucun achat enregistré',
                    message: 'Les réceptions de marchandise\napparaîtront ici.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: invoices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];
                      return _InvoiceTile(invoice: invoice)
                          .animate()
                          .fadeIn(duration: 220.ms, delay: (18 * index).ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  final PurchaseInvoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = invoice.montantTotal == 0 ? 1.0 : (invoice.montantPaye / invoice.montantTotal).clamp(0, 1).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: invoice.photoBytes != null
                ? Image.memory(invoice.photoBytes!, width: 44, height: 44, fit: BoxFit.cover)
                : Container(
                    width: 44,
                    height: 44,
                    color: AppColors.surfaceMuted,
                    child: const Icon(Icons.receipt_outlined, color: AppColors.textFaint, size: 20),
                  ),
          ),
          title: Text(invoice.fournisseur ?? 'Fournisseur non précisé',
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
            '${DateFormat('dd/MM/yyyy').format(invoice.date)} · ${invoice.lignes.length} produit${invoice.lignes.length > 1 ? 's' : ''} · ${AppFormat.dt(invoice.montantTotal)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation(invoice.soldee ? AppColors.success : AppColors.warning),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.soldee ? 'Soldée' : 'Reste ${AppFormat.dtShort(invoice.montantRestant)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: invoice.soldee ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          children: [
            for (final line in invoice.lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(line.productName, style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${line.quantite.toStringAsFixed(line.venduAuPoids ? 3 : 0)} ${line.unite}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        AppFormat.dtShort(line.montant),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            if (!invoice.soldee) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: PressScale(
                  onTap: () => RecordPaymentSheet.show(context, invoice),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Text(
                      'Régler un paiement',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
