import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/view/invoice_detail_sheet.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';

/// A supplier's own page: contact details and their whole purchase
/// history (every invoice recorded against them), mirroring how
/// [EmployeeDetailScreen] surfaces an employee's activity. Each invoice can
/// be tapped to see its products and full payment timeline.
class SupplierDetailScreen extends ConsumerWidget {
  final Supplier supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(supplierInvoicesProvider(supplier.id));
    final totalAchats = invoices.fold<double>(
      0,
      (sum, i) => sum + i.montantTotal,
    );
    final totalRestant = invoices.fold<double>(
      0,
      (sum, i) => sum + i.montantRestant,
    );

    final invoicesByDateDesc = List.of(invoices)
      ..sort((a, b) => b.date.compareTo(a.date));
    final dernierAchat = invoices.isEmpty
        ? null
        : invoices.map((i) => i.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final tousPaiements = invoices.expand((i) => i.paiements).toList();
    final dernierPaiement = tousPaiements.isEmpty
        ? null
        : tousPaiements
              .map((p) => p.date)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    final delais = invoices
        .map((i) => i.delaiPaiementJours)
        .whereType<int>()
        .toList();
    final paiementMoyenJours = delais.isEmpty
        ? null
        : (delais.reduce((a, b) => a + b) / delais.length).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.nom),
        actions: [
          IconButton(
            onPressed: () => context.push('/suppliers/edit', extra: supplier),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(AppColors.teal),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'supplier-${supplier.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: supplier.photoBytes != null
                        ? Image.memory(
                            supplier.photoBytes!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: Colors.white.withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.local_shipping_outlined,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (supplier.telephone.isNotEmpty)
                        Text(
                          supplier.telephone,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      if (supplier.adresse.isNotEmpty)
                        Text(
                          supplier.adresse,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Total achats',
                  value: AppFormat.dt(totalAchats),
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Reste à payer',
                  value: AppFormat.dt(totalRestant),
                  icon: Icons.warning_amber_rounded,
                  color: totalRestant > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.event_available_outlined,
                  label: 'Dernier achat',
                  value: dernierAchat != null
                      ? DateFormat('dd/MM/yyyy').format(dernierAchat)
                      : '—',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.paid_outlined,
                  label: 'Dernier paiement',
                  value: dernierPaiement != null
                      ? DateFormat('dd/MM/yyyy').format(dernierPaiement)
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.receipt_long_outlined,
                  label: 'Nombre de factures',
                  value:
                      '${invoices.length} facture${invoices.length > 1 ? 's' : ''}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  icon: Icons.timer_outlined,
                  label: 'Paiement moyen',
                  value: paiementMoyenJours != null
                      ? '$paiementMoyenJours jours'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Historique des achats'),
          const SizedBox(height: 14),
          if (invoicesByDateDesc.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucun achat',
              message:
                  'Les factures reçues de ce fournisseur\napparaîtront ici.',
            )
          else
            for (final i in invoicesByDateDesc)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SupplierInvoiceTile(
                  invoice: i,
                  onTap: () => showInvoiceDetailSheet(context, i),
                ),
              ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.teal, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _SupplierInvoiceTile extends StatelessWidget {
  final PurchaseInvoice invoice;
  final VoidCallback onTap;
  const _SupplierInvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: invoice.photoBytes != null
                  ? Image.memory(
                      invoice.photoBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : const ProductAvatar(
                      emoji: '📄',
                      photoBytes: null,
                      size: 40,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Facture #${invoice.reference}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(invoice.date),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormat.dt(invoice.montantTotal),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  invoice.soldee
                      ? 'Soldée'
                      : 'Reste ${AppFormat.dtShort(invoice.montantRestant)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: invoice.soldee
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
