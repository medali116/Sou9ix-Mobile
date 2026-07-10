import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/shell/tab_navigation_provider.dart';
import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/features/analytics/viewmodel/analytics_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/dashboard/view/global_search_sheet.dart';
import 'package:sou9ix/features/dashboard/viewmodel/dashboard_provider.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/view/invoice_detail_sheet.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _openCustomizeSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, sheetRef, _) {
          final visible = sheetRef.watch(dashboardVisibleSectionsProvider);
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Personnaliser le tableau de bord',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                ),
                for (final section in DashboardSection.values)
                  CheckboxListTile(
                    value: visible.contains(section),
                    onChanged: (checked) {
                      final next = {...visible};
                      if (checked == true) {
                        next.add(section);
                      } else {
                        next.remove(section);
                      }
                      sheetRef
                              .read(dashboardVisibleSectionsProvider.notifier)
                              .state =
                          next;
                    },
                    title: Text(section.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.teal,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final totalAlerts = ref.watch(totalAlertsCountProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final yesterdayRevenue = ref.watch(yesterdayRevenueProvider);
    final todayProfit = ref.watch(todayProfitProvider);
    final yesterdayProfit = ref.watch(yesterdayProfitProvider);
    final todayTickets = ref.watch(todaySalesProvider).length;
    final todayExpenses = ref.watch(todayExpensesTotalProvider);
    final paymentBreakdown = ref.watch(todayPaymentBreakdownProvider);
    final avgTicket = ref.watch(avgTicketTodayProvider);
    final avgBasket = ref.watch(avgBasketSizeTodayProvider);
    final clientsToday = ref.watch(clientsTodayCountProvider);
    final topProducts = ref.watch(topProductsProvider);
    final productsTrend = ref.watch(topProductsTrendProvider);
    final recentSales = ref.watch(recentSalesProvider);
    final creditClients = ref.watch(creditClientsPreviewProvider);
    final lowStock = ref.watch(lowStockProvider).take(3).toList();
    final unpaidInvoices = ref.watch(unpaidInvoicesPreviewProvider);
    final visibleSections = ref.watch(dashboardVisibleSectionsProvider);
    final expanded = ref.watch(dashboardExpandedProvider);
    final insight = dashboardInsightText(ref);

    double trendOf(double today, double yesterday) => yesterday > 0
        ? ((today - yesterday) / yesterday * 100).abs()
        : (today > 0 ? 100.0 : 0.0);
    final revenueTrendUp = todayRevenue >= yesterdayRevenue;
    final profitTrendUp = todayProfit >= yesterdayProfit;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.tealGradient,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user?.initiales ?? 'S9',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, ${user?.nom.split(' ').first ?? ''} 👋',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        AppFormat.fullDate(DateTime.now()),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showGlobalSearchSheet(context),
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Rechercher',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (v) {
                    if (v == 'analytics') context.push('/analytics');
                    if (v == 'customize') _openCustomizeSheet(context, ref);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'analytics',
                      child: ListTile(
                        leading: Icon(Icons.query_stats_rounded),
                        title: Text('Centre d\'analyse'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'customize',
                      child: ListTile(
                        leading: Icon(Icons.tune_rounded),
                        title: Text('Personnaliser'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  label: 'Recette du jour',
                  value: AppFormat.dt(todayRevenue),
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                  trend:
                      '${trendOf(todayRevenue, yesterdayRevenue).toStringAsFixed(0)}%',
                  trendUp: revenueTrendUp,
                ),
                StatCard(
                  label: 'Bénéfice net',
                  value: AppFormat.dt(todayProfit),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.goldDark,
                  trend:
                      '${trendOf(todayProfit, yesterdayProfit).toStringAsFixed(0)}%',
                  trendUp: profitTrendUp,
                ),
                StatCard(
                  label: 'Tickets émis',
                  value: '$todayTickets',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.info,
                ),
                PressScale(
                  onTap: () => context.push('/alerts'),
                  child: StatCard(
                    label: 'Alertes',
                    value: '$totalAlerts',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hier : ${AppFormat.dtShort(yesterdayRevenue)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Hier : ${AppFormat.dtShort(yesterdayProfit)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (todayTickets == 0)
              _EmptySalesCard(
                onCreateTicket: () =>
                    ref.read(requestedTabIndexProvider.notifier).state = 1,
              ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0)
            else
              _SummaryCard(
                recettes: todayRevenue,
                depenses: todayExpenses,
                benefice: todayRevenue - todayExpenses,
                especes: paymentBreakdown[ModePaiement.especes] ?? 0,
                carte: paymentBreakdown[ModePaiement.carte] ?? 0,
                credit: paymentBreakdown[ModePaiement.credit] ?? 0,
                ticketMoyen: avgTicket,
                clientsAujourdhui: clientsToday,
                panierMoyen: avgBasket,
              ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0),
            if (insight != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeader(title: 'Actions rapides'),
            const SizedBox(height: 14),
            SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _QuickAction(
                    icon: Icons.add_shopping_cart_rounded,
                    label: 'Nouvelle vente',
                    color: AppColors.teal,
                    onTap: () =>
                        ref.read(requestedTabIndexProvider.notifier).state = 1,
                  ),
                  _QuickAction(
                    icon: Icons.inventory_2_outlined,
                    label: 'Ajouter produit',
                    color: AppColors.goldDark,
                    onTap: () => context.push('/products/new'),
                  ),
                  _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Nouveau client',
                    color: AppColors.info,
                    onTap: () => context.push('/clients'),
                  ),
                  _QuickAction(
                    icon: Icons.local_shipping_outlined,
                    label: 'Facture fournisseur',
                    color: AppColors.tealDark,
                    onTap: () => context.push('/stock/receipt'),
                  ),
                  _QuickAction(
                    icon: Icons.warehouse_outlined,
                    label: 'Inventaire',
                    color: AppColors.info,
                    onTap: () =>
                        ref.read(requestedTabIndexProvider.notifier).state = 2,
                  ),
                  _QuickAction(
                    icon: Icons.wallet_outlined,
                    label: 'Nouvelle dépense',
                    color: AppColors.warning,
                    onTap: () => context.push('/expenses'),
                  ),
                  _QuickAction(
                    icon: Icons.payments_outlined,
                    label: 'Encaisser crédit',
                    color: AppColors.teal,
                    onTap: () => context.push('/clients'),
                  ),
                  _QuickAction(
                    icon: Icons.add_business_outlined,
                    label: 'Ajouter fournisseur',
                    color: AppColors.tealDark,
                    onTap: () => context.push('/suppliers/new'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _AlertsSummaryCard(onTap: () => context.push('/alerts')),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Dernières ventes',
              actionLabel: 'Voir tout',
              onAction: () => context.push('/history'),
            ),
            const SizedBox(height: 14),
            if (recentSales.isEmpty)
              const _EmptyCard(message: 'Aucune vente récente.')
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  children: [
                    for (final s in recentSales) _RecentSaleTile(sale: s),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(dashboardExpandedProvider.notifier).state =
                        !expanded,
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(expanded ? 'Voir moins' : 'Voir plus'),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              _ActivitySummaryCard(onTap: () => context.push('/activity-log')),
              const SizedBox(height: 24),
              const _RevenueChartSection(),
              if (visibleSections.contains(DashboardSection.topProduits)) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Top produits',
                  actionLabel: 'Statistiques',
                  onAction: () => context.push('/statistics'),
                ),
                const SizedBox(height: 14),
                if (topProducts.isEmpty)
                  const _EmptyCard(
                    message: 'Aucune vente enregistrée pour l\'instant.',
                  )
                else
                  Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          children: List.generate(topProducts.length, (i) {
                            final p = topProducts[i];
                            final maxRevenue = topProducts.first.revenue;
                            final trend = productsTrend[p.product.id];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: i == 0
                                          ? AppColors.gold.withValues(
                                              alpha: 0.2,
                                            )
                                          : AppColors.surfaceMuted,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: i == 0
                                            ? AppColors.goldDark
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    p.product.emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.product.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(
                                              begin: 0,
                                              end: p.revenue / maxRevenue,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 700,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, _) =>
                                                LinearProgressIndicator(
                                                  value: value,
                                                  minHeight: 6,
                                                  backgroundColor:
                                                      AppColors.surfaceMuted,
                                                  valueColor:
                                                      const AlwaysStoppedAnimation(
                                                        AppColors.teal,
                                                      ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            AppFormat.dtShort(p.revenue),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (trend != null) ...[
                                            const SizedBox(width: 3),
                                            Icon(
                                              trend >= 0
                                                  ? Icons.arrow_upward_rounded
                                                  : Icons
                                                        .arrow_downward_rounded,
                                              size: 11,
                                              color: trend >= 0
                                                  ? AppColors.success
                                                  : AppColors.danger,
                                            ),
                                            Text(
                                              '${trend.abs().toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: trend >= 0
                                                    ? AppColors.success
                                                    : AppColors.danger,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        '${p.ventes} ticket${p.ventes > 1 ? 's' : ''}'
                                        '${p.product.venduAuPoids ? ' · ${p.quantite.toStringAsFixed(1)} kg' : ''}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textFaint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.05, end: 0),
              ],
              if (visibleSections.contains(DashboardSection.clientsCredit)) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Clients crédit',
                  actionLabel: 'Voir tout',
                  onAction: () => context.push('/clients'),
                ),
                const SizedBox(height: 14),
                if (creditClients.isEmpty)
                  const _EmptyCard(message: 'Aucun client avec un solde dû.')
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        for (final c in creditClients)
                          _CreditClientTile(client: c),
                      ],
                    ),
                  ),
              ],
              if (visibleSections.contains(DashboardSection.stockFaible)) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Stock faible',
                  actionLabel: 'Voir tout',
                  onAction: () => context.push('/alerts'),
                ),
                const SizedBox(height: 14),
                if (lowStock.isEmpty)
                  const _EmptyCard(
                    message: 'Tous les produits sont bien approvisionnés.',
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        for (final p in lowStock) _LowStockTile(product: p),
                      ],
                    ),
                  ),
              ],
              if (visibleSections.contains(
                DashboardSection.facturesFournisseurs,
              )) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Factures fournisseurs à payer',
                  actionLabel: 'Voir tout',
                  onAction: () => context.push('/purchases'),
                ),
                const SizedBox(height: 14),
                if (unpaidInvoices.isEmpty)
                  const _EmptyCard(
                    message: 'Aucune facture fournisseur en attente.',
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      children: [
                        for (final i in unpaidInvoices)
                          _UnpaidInvoiceTile(invoice: i),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              const SectionHeader(title: 'Aperçu approfondi'),
              const SizedBox(height: 14),
              const _DeeperInsightsGrid(),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeeperInsightsGrid extends ConsumerWidget {
  const _DeeperInsightsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestCashier = ref.watch(bestCashierTodayProvider);
    final newClients = ref.watch(newClientsThisMonthProvider);
    final neverSold = ref.watch(neverSoldProductsProvider).length;
    final loss = ref.watch(expiredStockLossProvider);
    final margin = ref.watch(averageMarginPctProvider);
    final bestClient = ref.watch(topClientThisMonthProvider);
    final suppliers = ref.watch(topSuppliersProvider);
    final payments = ref.watch(todayPaymentBreakdownProvider);
    final paymentsTotal = payments.values.fold<double>(0, (sum, v) => sum + v);

    String pct(double v) =>
        paymentsTotal > 0 ? '${(v / paymentsTotal * 100).round()}%' : '0%';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _InsightTile(
          icon: Icons.emoji_events_outlined,
          label: 'Meilleur caissier',
          value: bestCashier != null ? bestCashier.name.split(' ').first : '—',
          sub: bestCashier != null
              ? '${AppFormat.dtShort(bestCashier.revenue)} · ${bestCashier.tickets} tickets'
              : 'Aucune vente',
          onTap: () => context.push('/analytics'),
        ),
        _InsightTile(
          icon: Icons.person_add_alt_1_outlined,
          label: 'Nouveaux clients',
          value: '$newClients',
          sub: 'ce mois',
        ),
        _InsightTile(
          icon: Icons.inventory_outlined,
          label: 'Jamais vendus',
          value: '$neverSold',
          sub: 'produits',
          onTap: () => context.push('/analytics'),
        ),
        _InsightTile(
          icon: Icons.delete_outline_rounded,
          label: 'Perte (expirés)',
          value: AppFormat.dtShort(loss),
          sub: 'au prix d\'achat',
          valueColor: loss > 0 ? AppColors.danger : null,
        ),
        _InsightTile(
          icon: Icons.percent_rounded,
          label: 'Marge moyenne',
          value: margin != null ? '${margin.toStringAsFixed(0)}%' : '—',
          sub: 'catalogue',
        ),
        _InsightTile(
          icon: Icons.pie_chart_outline_rounded,
          label: 'Paiements (jour)',
          value: pct(payments[ModePaiement.especes] ?? 0),
          sub:
              'espèces · ${pct(payments[ModePaiement.carte] ?? 0)} carte · ${pct(payments[ModePaiement.credit] ?? 0)} crédit',
        ),
        _InsightTile(
          icon: Icons.star_outline_rounded,
          label: 'Meilleur client',
          value: bestClient != null
              ? bestClient.client.nom.split(' ').first
              : '—',
          sub: bestClient != null
              ? '${AppFormat.dtShort(bestClient.total)} ce mois'
              : 'Aucun achat',
          onTap: bestClient != null
              ? () => context.push('/clients/detail', extra: bestClient.client)
              : null,
        ),
        _InsightTile(
          icon: Icons.local_shipping_outlined,
          label: 'Meilleur fournisseur',
          value: suppliers.isNotEmpty ? suppliers.first.nom : '—',
          sub: suppliers.isNotEmpty
              ? '${suppliers.first.factures} factures'
              : 'Aucun achat',
          onTap: () => context.push('/suppliers'),
        ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap ?? () {},
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
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double recettes;
  final double depenses;
  final double benefice;
  final double especes;
  final double carte;
  final double credit;
  final double? ticketMoyen;
  final int? clientsAujourdhui;
  final double? panierMoyen;

  const _SummaryCard({
    required this.recettes,
    required this.depenses,
    required this.benefice,
    required this.especes,
    required this.carte,
    required this.credit,
    this.ticketMoyen,
    this.clientsAujourdhui,
    this.panierMoyen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.inkGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RÉSUMÉ AUJOURD\'HUI',
            style: TextStyle(
              color: AppColors.tealLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Recettes',
                  AppFormat.dtShort(recettes),
                  big: true,
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Dépenses',
                  AppFormat.dtShort(depenses),
                  big: true,
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Bénéfice',
                  AppFormat.dtShort(benefice),
                  big: true,
                  color: benefice >= 0 ? AppColors.tealLight : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryItem('Espèces', AppFormat.dtShort(especes)),
              ),
              Expanded(child: _summaryItem('Carte', AppFormat.dtShort(carte))),
              Expanded(
                child: _summaryItem('Crédit', AppFormat.dtShort(credit)),
              ),
            ],
          ),
          if (ticketMoyen != null ||
              clientsAujourdhui != null ||
              panierMoyen != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                if (ticketMoyen != null)
                  Expanded(
                    child: _summaryItem(
                      'Ticket moyen',
                      AppFormat.dtShort(ticketMoyen!),
                    ),
                  ),
                if (clientsAujourdhui != null)
                  Expanded(
                    child: _summaryItem('Clients', '$clientsAujourdhui'),
                  ),
                if (panierMoyen != null)
                  Expanded(
                    child: _summaryItem(
                      'Panier moyen',
                      '${panierMoyen!.toStringAsFixed(1)} art.',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(
    String label,
    String value, {
    bool big = false,
    Color color = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: big ? 16 : 13.5,
          ),
        ),
      ],
    );
  }
}

class _EmptySalesCard extends StatelessWidget {
  final VoidCallback onCreateTicket;
  const _EmptySalesCard({required this.onCreateTicket});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.inkGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.point_of_sale_rounded,
            color: AppColors.tealLight,
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'Aucune vente aujourd\'hui',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCreateTicket,
              child: const Text('Créer votre premier ticket'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsSummaryCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _AlertsSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider).length;
    final expiringSoon = ref.watch(expiringSoonProvider).length;
    final expired = ref.watch(expiredProductsProvider).length;
    final unsettled = ref.watch(unsettledInvoicesProvider).length;
    final overLimit = ref.watch(clientsOverLimitProvider).length;
    final lossProducts = ref.watch(lossProductsProvider).length;
    final staleProducts = ref.watch(staleProductsProvider).length;
    final todayPriceChanges = ref.watch(todayPriceChangesProvider).length;
    final frequentDeletions = ref.watch(hasFrequentTicketDeletionsProvider);

    final cards = <(String, String, IconData, Color)>[
      if (lowStock > 0)
        (
          '$lowStock produit${lowStock > 1 ? 's' : ''}',
          'Sous le seuil',
          Icons.inventory_2_outlined,
          AppColors.warning,
        ),
      if (expired > 0)
        (
          '$expired produit${expired > 1 ? 's' : ''}',
          'Périmés',
          Icons.report_outlined,
          AppColors.danger,
        ),
      if (expiringSoon > 0)
        (
          '$expiringSoon produit${expiringSoon > 1 ? 's' : ''}',
          'Proche péremption',
          Icons.hourglass_bottom_rounded,
          AppColors.warning,
        ),
      if (unsettled > 0)
        (
          '$unsettled facture${unsettled > 1 ? 's' : ''}',
          'Fournisseur impayée',
          Icons.receipt_long_outlined,
          AppColors.danger,
        ),
      if (overLimit > 0)
        (
          '$overLimit client${overLimit > 1 ? 's' : ''}',
          'Limite dépassée',
          Icons.person_outline_rounded,
          AppColors.danger,
        ),
      if (lossProducts > 0)
        (
          '$lossProducts produit${lossProducts > 1 ? 's' : ''}',
          'Vendus à perte',
          Icons.trending_down_rounded,
          AppColors.danger,
        ),
      if (staleProducts > 0)
        (
          '$staleProducts produit${staleProducts > 1 ? 's' : ''}',
          'Sans vente 30j',
          Icons.pause_circle_outline_rounded,
          AppColors.warning,
        ),
      if (todayPriceChanges > 0)
        (
          '$todayPriceChanges prix',
          'Modifiés',
          Icons.sell_outlined,
          AppColors.info,
        ),
      if (frequentDeletions)
        (
          'Tickets',
          'Beaucoup de suppressions',
          Icons.report_gmailerrorred_rounded,
          AppColors.danger,
        ),
    ];

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cards.isEmpty
              ? AppColors.surface
              : AppColors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: cards.isEmpty
                ? AppColors.border
                : AppColors.warning.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  cards.isEmpty
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: cards.isEmpty ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alertes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textFaint,
                ),
              ],
            ),
            if (cards.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Tout est en ordre',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label, icon, color) in cards.take(6))
                    Container(
                      width: 104,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 15, color: color),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivitySummaryCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _ActivitySummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseen = ref.watch(unseenActivityCountProvider);
    final recent = ref.watch(activityLogProvider).take(4).toList();

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Activités récentes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textFaint,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              unseen > 0
                  ? '$unseen nouvelle${unseen > 1 ? 's' : ''} activité${unseen > 1 ? 's' : ''}'
                  : 'Rien de nouveau',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final e in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: e.impact.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.action}${e.targetName != null ? ' — ${e.targetName}' : ''}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _relativeTime(e.date),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RevenueChartSection extends ConsumerWidget {
  const _RevenueChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(revenuePeriodProvider);
    final metric = ref.watch(chartMetricProvider);
    final chart = ref.watch(revenueChartDataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: metric.label),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              for (final m in ChartMetric.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m.label),
                    selected: metric == m,
                    onSelected: (_) =>
                        ref.read(chartMetricProvider.notifier).state = m,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: RevenuePeriod.values.map((p) {
              final selected = p == period;
              return Expanded(
                child: PressScale(
                  onTap: () =>
                      ref.read(revenuePeriodProvider.notifier).state = p,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: selected ? AppShadows.card : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: selected
                            ? AppColors.teal
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 190,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: chart.values.every((v) => v == 0)
              ? const Center(
                  child: Text(
                    'Aucune donnée sur cette période',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12.5,
                    ),
                  ),
                )
              : _RevenueBarChart(
                  values: chart.values,
                  labels: chart.labels,
                  metric: metric,
                ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final ChartMetric metric;
  const _RevenueBarChart({
    required this.values,
    required this.labels,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 1.0 : maxValue * 1.25;
    final step = (values.length / 8).ceil().clamp(1, values.length);
    final isMonetary =
        metric == ChartMetric.recettes || metric == ChartMetric.benefices;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final isLast = i == values.length - 1;
                if (!isLast && i % step != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                      color: isLast ? AppColors.teal : AppColors.textFaint,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  isMonetary
                      ? AppFormat.dt(rod.toY)
                      : rod.toY.toStringAsFixed(0),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
          ),
        ),
        barGroups: List.generate(values.length, (i) {
          final isLast = i == values.length - 1;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                width: values.length > 15 ? 6 : 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: isLast
                      ? [AppColors.tealDark, AppColors.tealLight]
                      : [AppColors.surfaceMuted, AppColors.border],
                ),
              ),
            ],
          );
        }),
      ),
      duration: const Duration(milliseconds: 500),
    );
  }
}

class _RecentSaleTile extends StatelessWidget {
  final Sale sale;
  const _RecentSaleTile({required this.sale});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => context.push('/history/edit', extra: sale),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(
                sale.modePaiement.icon,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ticket #${sale.id.length > 6 ? sale.id.substring(sale.id.length - 6).toUpperCase() : sale.id.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    DateFormat('HH:mm').format(sale.dateHeure),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormat.dtShort(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sale.modePaiement.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    sale.modePaiement.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: sale.modePaiement.color,
                    ),
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

extension _ModePaiementColor on ModePaiement {
  Color get color => switch (this) {
    ModePaiement.especes => AppColors.success,
    ModePaiement.carte => AppColors.info,
    ModePaiement.credit => AppColors.warning,
  };
}

class _CreditClientTile extends StatelessWidget {
  final Client client;
  const _CreditClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    final limite = client.limiteCredit;
    final ratio = limite != null && limite > 0
        ? (client.creditTotal / limite).clamp(0.0, 1.0)
        : null;

    return PressScale(
      onTap: () => context.push('/clients/detail', extra: client),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                  foregroundColor: AppColors.tealDark,
                  child: Text(
                    client.nom.substring(0, 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    client.nom,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  limite != null
                      ? '${client.creditTotal.toStringAsFixed(0)} / ${limite.toStringAsFixed(0)} DT'
                      : AppFormat.dtShort(client.creditTotal),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: AppColors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(
                    ratio >= 1 ? AppColors.danger : AppColors.warning,
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

class _LowStockTile extends StatelessWidget {
  final Product product;
  const _LowStockTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final ratio = product.seuilAlerte > 0
        ? (product.stock / product.seuilAlerte).clamp(0.0, 1.0)
        : 0.0;

    return PressScale(
      onTap: () => context.push('/products/edit', extra: product),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(product.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${product.stock.toStringAsFixed(product.venduAuPoids ? 1 : 0)} ${product.unite}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.warning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Min ${product.seuilAlerte.toStringAsFixed(product.venduAuPoids ? 1 : 0)} ${product.unite}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textFaint,
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

class _UnpaidInvoiceTile extends StatelessWidget {
  final PurchaseInvoice invoice;
  const _UnpaidInvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysOpen = now.difference(invoice.date).inDays;
    final isToday = daysOpen == 0 && invoice.date.day == now.day;

    return PressScale(
      onTap: () => showInvoiceDetailSheet(context, invoice),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
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
                    isToday
                        ? 'Aujourd\'hui'
                        : 'Ouverte depuis $daysOpen jour${daysOpen > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: daysOpen >= oldUnpaidInvoiceThresholdDays
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight: daysOpen >= oldUnpaidInvoiceThresholdDays
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              AppFormat.dtShort(invoice.montantRestant),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textFaint, fontSize: 12.5),
      ),
    );
  }
}
