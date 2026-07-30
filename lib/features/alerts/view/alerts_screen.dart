import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/clients/model/client.dart';
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
///
/// [focusCategory] — one of the section keys below ('lowStock',
/// 'expiringSoon', 'expired', 'unsettled', 'overLimit', 'lossProducts',
/// 'staleProducts', 'todayPriceChanges', 'frequentDeletions') — scrolls
/// straight to that section on open, so tapping a specific alert chip on
/// the dashboard lands on its detail instead of the top of a long list.
class AlertsScreen extends ConsumerStatefulWidget {
  final String? focusCategory;
  const AlertsScreen({super.key, this.focusCategory});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final _sectionKeys = <String, GlobalKey>{
    'frequentDeletions': GlobalKey(),
    'lowStock': GlobalKey(),
    'expiringSoon': GlobalKey(),
    'expired': GlobalKey(),
    'unsettled': GlobalKey(),
    'overLimit': GlobalKey(),
    'lossProducts': GlobalKey(),
    'staleProducts': GlobalKey(),
    'todayPriceChanges': GlobalKey(),
  };
  bool _didScrollToFocus = false;

  /// The target section only gets a real [BuildContext] once its widgets
  /// have actually been laid out, so this schedules the check for after
  /// the current frame — and re-schedules on every build until it
  /// succeeds, since the very first build (before alert data resolves)
  /// may not have rendered that section yet.
  void _scheduleScrollToFocus() {
    if (_didScrollToFocus || widget.focusCategory == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToFocus) return;
      final targetContext = _sectionKeys[widget.focusCategory]?.currentContext;
      if (targetContext == null) return;
      _didScrollToFocus = true;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final lowStock = ref.watch(lowStockProvider);
    final expiringSoon = ref.watch(expiringSoonProvider);
    final expired = ref.watch(expiredProductsProvider);
    final unsettled = ref.watch(unsettledInvoicesProvider);
    final oldUnpaidIds = ref
        .watch(oldUnpaidInvoicesProvider)
        .map((i) => i.id)
        .toSet();
    final overLimit = ref.watch(clientsOverLimitProvider);
    final lossProducts = ref.watch(lossProductsProvider);
    final staleProducts = ref.watch(staleProductsProvider);
    final todayPriceChanges = ref.watch(todayPriceChangesProvider);
    final frequentDeletions = ref.watch(hasFrequentTicketDeletionsProvider);
    final warningDays = ref.watch(expiryWarningDaysProvider);

    final hasAny =
        lowStock.isNotEmpty ||
        expiringSoon.isNotEmpty ||
        expired.isNotEmpty ||
        unsettled.isNotEmpty ||
        overLimit.isNotEmpty ||
        lossProducts.isNotEmpty ||
        staleProducts.isNotEmpty ||
        todayPriceChanges.isNotEmpty ||
        frequentDeletions;

    _scheduleScrollToFocus();

    return Scaffold(
      appBar: AppBar(title: const Text('Alertes')),
      body: !hasAny
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Tout est en ordre',
              message:
                  'Aucune alerte de stock, de péremption\nou de facture en attente.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Alerter avant péremption (jours)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.remove_rounded,
                        onTap: warningDays > 1
                            ? () =>
                                  ref
                                          .read(
                                            expiryWarningDaysProvider.notifier,
                                          )
                                          .state =
                                      warningDays - 1
                            : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$warningDays',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add_rounded,
                        onTap: () =>
                            ref.read(expiryWarningDaysProvider.notifier).state =
                                warningDays + 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (frequentDeletions) ...[
                  KeyedSubtree(
                    key: _sectionKeys['frequentDeletions'],
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.report_gmailerrorred_rounded,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Beaucoup de tickets supprimés récemment (${ref.watch(recentTicketDeletionsProvider).length} en $frequentDeletionWindowDays jours)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (lowStock.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['lowStock'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Stock faible'),
                        const SizedBox(height: 12),
                        ...lowStock.map((p) => _ProductAlertTile(product: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (expiringSoon.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['expiringSoon'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Expire bientôt'),
                        const SizedBox(height: 12),
                        ...expiringSoon.map((p) => _ProductAlertTile(product: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (expired.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['expired'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Expiré'),
                        const SizedBox(height: 12),
                        ...expired.map((p) => _ProductAlertTile(product: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (unsettled.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['unsettled'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Factures fournisseurs impayées',
                        ),
                        const SizedBox(height: 12),
                        ...unsettled.map(
                          (i) => _InvoiceAlertTile(
                            invoice: i,
                            isCritical: oldUnpaidIds.contains(i.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (overLimit.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['overLimit'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                          title: 'Clients au-dessus de leur limite',
                        ),
                        const SizedBox(height: 12),
                        ...overLimit.map((c) => _ClientAlertTile(client: c)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (lossProducts.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['lossProducts'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Produits vendus à perte'),
                        const SizedBox(height: 12),
                        ...lossProducts.map((p) => _LossProductTile(product: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (staleProducts.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['staleProducts'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title:
                              'Sans vente depuis $staleProductThresholdDays jours',
                        ),
                        const SizedBox(height: 12),
                        ...staleProducts.map((p) => _StaleProductTile(product: p)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (todayPriceChanges.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _sectionKeys['todayPriceChanges'],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'Prix modifiés aujourd\'hui'),
                        const SizedBox(height: 12),
                        ...todayPriceChanges.map(
                          (e) => _PriceChangeTile(entry: e),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ClientAlertTile extends StatelessWidget {
  final Client client;
  const _ClientAlertTile({required this.client});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressScale(
        onTap: () => context.push('/clients/detail', extra: client),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.nom,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Limite ${AppFormat.dtShort(client.limiteCredit!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Text(
                AppFormat.dtShort(client.creditTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ),
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
                  ProductAvatar(
                    emoji: product.emoji,
                    photoBytes: product.photoBytes,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (product.datePeremption != null)
                    Text(
                      DateFormat('dd/MM/yyyy').format(product.datePeremption!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
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
  final bool isCritical;
  const _InvoiceAlertTile({required this.invoice, this.isCritical = false});

  @override
  Widget build(BuildContext context) {
    final color = isCritical ? AppColors.danger : AppColors.warning;
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
            border: isCritical
                ? Border.all(color: color.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.fournisseurNom ?? 'Fournisseur non précisé',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(invoice.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (isCritical)
                      Text(
                        'Impayée depuis ${DateTime.now().difference(invoice.date).inDays} jours',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'Reste ${AppFormat.dtShort(invoice.montantRestant)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LossProductTile extends StatelessWidget {
  final Product product;
  const _LossProductTile({required this.product});

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
          child: Row(
            children: [
              ProductAvatar(
                emoji: product.emoji,
                photoBytes: product.photoBytes,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Achat ${AppFormat.dtShort(product.prixAchat)} · Vente ${AppFormat.dtShort(product.prixVente)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.trending_down_rounded, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleProductTile extends StatelessWidget {
  final Product product;
  const _StaleProductTile({required this.product});

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
          child: Row(
            children: [
              ProductAvatar(
                emoji: product.emoji,
                photoBytes: product.photoBytes,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Stock : ${product.stock.toStringAsFixed(product.venduAuPoids ? 1 : 0)} ${product.unite}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceChangeTile extends StatelessWidget {
  final ActivityLogEntry entry;
  const _PriceChangeTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            const Icon(Icons.sell_rounded, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.targetName ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${entry.champ} : ${entry.ancienneValeur} → ${entry.nouvelleValeur}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('HH:mm').format(entry.date),
              style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
            ),
          ],
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
          color: onTap == null
              ? AppColors.surfaceMuted.withValues(alpha: 0.5)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: onTap == null ? AppColors.textFaint : AppColors.textPrimary,
        ),
      ),
    );
  }
}
