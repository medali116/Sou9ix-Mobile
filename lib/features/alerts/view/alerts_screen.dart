import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/features/alerts/viewmodel/settings_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/stock_bar.dart';

/// Aggregates every in-app alert in one place: low stock, expiring/expired
/// products, and unsettled supplier invoices — reached from the dashboard's
/// "Alertes" card and the notification bell on the Caisse screen.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider);
    final expiringSoon = ref.watch(expiringSoonProvider);
    final expired = ref.watch(expiredProductsProvider);
    final unsettled = ref.watch(unsettledInvoicesProvider);
    final warningDays = ref.watch(expiryWarningDaysProvider);

    final hasAny = lowStock.isNotEmpty || expiringSoon.isNotEmpty || expired.isNotEmpty || unsettled.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: !hasAny
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Tout est en ordre',
              message: 'Aucune alerte de stock, de péremption\nou de facture en attente.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Alerter avant péremption (jours)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      _StepperButton(
                        icon: Icons.remove_rounded,
                        onTap: warningDays > 1
                            ? () => ref.read(expiryWarningDaysProvider.notifier).state = warningDays - 1
                            : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text('$warningDays', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      _StepperButton(
                        icon: Icons.add_rounded,
                        onTap: () => ref.read(expiryWarningDaysProvider.notifier).state = warningDays + 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (lowStock.isNotEmpty) ...[
                  const SectionHeader(title: 'Stock faible'),
                  const SizedBox(height: 12),
                  ...lowStock.map((p) => _ProductAlertTile(product: p)),
                  const SizedBox(height: 22),
                ],
                if (expiringSoon.isNotEmpty) ...[
                  const SectionHeader(title: 'Expire bientôt'),
                  const SizedBox(height: 12),
                  ...expiringSoon.map((p) => _ProductAlertTile(product: p)),
                  const SizedBox(height: 22),
                ],
                if (expired.isNotEmpty) ...[
                  const SectionHeader(title: 'Expiré'),
                  const SizedBox(height: 12),
                  ...expired.map((p) => _ProductAlertTile(product: p)),
                  const SizedBox(height: 22),
                ],
                if (unsettled.isNotEmpty) ...[
                  const SectionHeader(title: 'Factures fournisseurs impayées'),
                  const SizedBox(height: 12),
                  ...unsettled.map((i) => _InvoiceAlertTile(invoice: i)),
                ],
              ],
            ),
    );
  }
}

class _ProductAlertTile extends StatelessWidget {
  final Product product;
  const _ProductAlertTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: () => context.push('/products/edit', extra: product),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductAvatar(emoji: product.emoji, photoBytes: product.photoBytes, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Text(product.name, style: Theme.of(context).textTheme.titleMedium)),
                  if (product.datePeremption != null)
                    Text(
                      DateFormat('dd/MM/yyyy').format(product.datePeremption!),
                      style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              StockBar(quantite: product.stock, seuil: product.seuilAlerte),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceAlertTile extends StatelessWidget {
  final PurchaseInvoice invoice;
  const _InvoiceAlertTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: () => context.push('/purchases'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.fournisseurNom ?? 'Fournisseur non précisé', style: Theme.of(context).textTheme.titleMedium),
                    Text(DateFormat('dd/MM/yyyy').format(invoice.date), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Text(
                'Reste ${AppFormat.dtShort(invoice.montantRestant)}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.surfaceMuted.withValues(alpha: 0.5) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: onTap == null ? AppColors.textFaint : AppColors.textPrimary),
      ),
    );
  }
}
