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
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/dashboard/view/global_search_sheet.dart';
import 'package:sou9ix/features/dashboard/viewmodel/dashboard_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
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

  Future<void> _openMoreActionsSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Text(
              'Toutes les actions',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _MoreActionTile(
              icon: Icons.local_shipping_outlined,
              label: 'Facture fournisseur',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/stock/receipt');
              },
            ),
            _MoreActionTile(
              icon: Icons.warehouse_outlined,
              label: 'Inventaire',
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(requestedTabIndexProvider.notifier).state = 1;
              },
            ),
            _MoreActionTile(
              icon: Icons.wallet_outlined,
              label: 'Nouvelle dépense',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/expenses');
              },
            ),
            _MoreActionTile(
              icon: Icons.payments_outlined,
              label: 'Encaisser crédit',
              onTap: () {
                Navigator.pop(sheetContext);
                context.push('/clients');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final totalAlerts = ref.watch(totalAlertsCountProvider);
    final criticalAlerts = ref.watch(criticalAlertsCountProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final yesterdayRevenue = ref.watch(yesterdayRevenueProvider);
    final todayNetProfit = ref.watch(todayNetProfitProvider);
    final yesterdayNetProfit = ref.watch(yesterdayNetProfitProvider);
    final todayTickets = ref.watch(todaySalesProvider).length;
    final paymentBreakdown = ref.watch(todayPaymentBreakdownProvider);
    final avgTicket = ref.watch(avgTicketTodayProvider);
    final avgBasket = ref.watch(avgBasketSizeTodayProvider);
    final topProducts = ref.watch(topProductsProvider);
    final productsTrend = ref.watch(topProductsTrendProvider);
    final recentSales = ref.watch(recentSalesProvider);
    final creditClients = ref.watch(creditClientsPreviewProvider);
    final lowStock = ref.watch(lowStockProvider).take(3).toList();
    final unpaidInvoices = ref.watch(unpaidInvoicesPreviewProvider);
    final visibleSections = ref.watch(dashboardVisibleSectionsProvider);
    final expanded = ref.watch(dashboardExpandedProvider);
    final forecast = ref.watch(dashboardForecastProvider);

    double trendOf(double today, double yesterday) => yesterday > 0
        ? ((today - yesterday) / yesterday * 100).abs()
        : (today > 0 ? 100.0 : 0.0);
    final revenueTrendUp = todayRevenue >= yesterdayRevenue;
    final profitTrendUp = todayNetProfit >= yesterdayNetProfit;

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
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 640;
                final cards = [
                  StatCard(
                    compact: true,
                    horizontal: wide,
                    label: 'Recette du jour',
                    value: AppFormat.dt(todayRevenue),
                    icon: Icons.payments_rounded,
                    color: AppColors.teal,
                    trend:
                        '${trendOf(todayRevenue, yesterdayRevenue).toStringAsFixed(0)}% vs hier',
                    trendUp: revenueTrendUp,
                  ),
                  StatCard(
                    compact: true,
                    horizontal: wide,
                    label: 'Bénéfice net',
                    value: AppFormat.dt(todayNetProfit),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.goldDark,
                    trend:
                        '${trendOf(todayNetProfit, yesterdayNetProfit).toStringAsFixed(0)}% vs hier',
                    trendUp: profitTrendUp,
                  ),
                  StatCard(
                    compact: true,
                    horizontal: wide,
                    label: 'Tickets émis',
                    value: '$todayTickets',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                    subtitle: avgTicket != null
                        ? '${AppFormat.dtShort(avgTicket)} moy.'
                        : null,
                  ),
                  PressScale(
                    onTap: () => context.push('/alerts'),
                    child: StatCard(
                      compact: true,
                      horizontal: wide,
                      label: 'Alertes',
                      value: '$totalAlerts',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      subtitle: criticalAlerts > 0
                          ? '$criticalAlerts critique${criticalAlerts > 1 ? 's' : ''}'
                          : null,
                      subtitleColor: AppColors.danger,
                    ),
                  ),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // Fixed height instead of an aspect ratio — an aspect
                    // ratio scales with the available width, which on
                    // narrow phones stretched the cards well past their
                    // content and left a dead band at the bottom of each.
                    mainAxisExtent: wide ? 96 : 130,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, i) => cards[i],
                );
              },
            ),
            const SizedBox(height: 24),
            if (todayTickets == 0)
              _EmptySalesCard(
                onCreateTicket: () => context.push('/pos'),
              ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0)
            else
              _SummaryCard(
                tickets: todayTickets,
                ticketMoyen: avgTicket,
                especes: paymentBreakdown[ModePaiement.especes] ?? 0,
                carte: paymentBreakdown[ModePaiement.carte] ?? 0,
                credit: paymentBreakdown[ModePaiement.credit] ?? 0,
                articlesParTicket: avgBasket,
              ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0),
            if (forecast != null) ...[
              const SizedBox(height: 12),
              _ForecastCard(forecast: forecast),
            ],
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Actions rapides',
              actionLabel: 'Toutes les actions',
              onAction: () => _openMoreActionsSheet(context, ref),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 98,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.add_shopping_cart_rounded,
                      label: 'Vente',
                      color: AppColors.teal,
                      onTap: () => context.push('/pos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      label: 'Produit',
                      color: AppColors.goldDark,
                      onTap: () => context.push('/products/new'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Client',
                      color: AppColors.info,
                      onTap: () => context.push('/clients'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.add_business_outlined,
                      label: 'Fournisseur',
                      color: AppColors.tealDark,
                      onTap: () => context.push('/suppliers/new'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.local_shipping_outlined,
                      label: 'Facture fourn.',
                      color: AppColors.warning,
                      onTap: () => context.push('/stock/receipt'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.warehouse_outlined,
                      label: 'Inventaire',
                      color: AppColors.tealDark,
                      onTap: () =>
                          ref.read(requestedTabIndexProvider.notifier).state = 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.wallet_outlined,
                      label: 'Dépense',
                      color: AppColors.danger,
                      onTap: () => context.push('/expenses'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 74,
                    child: _QuickAction(
                      icon: Icons.payments_outlined,
                      label: 'Encaisser',
                      color: AppColors.success,
                      onTap: () => context.push('/clients'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _AlertsSummaryCard(),
            const SizedBox(height: 24),
            _CaisseSummaryCard(onTap: () => context.push('/caisses')),
            const SizedBox(height: 24),
            _ActivitySummaryCard(onTap: () => context.push('/activity-log')),
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
            const SizedBox(height: 28),
            const SectionHeader(title: 'Performance'),
            const SizedBox(height: 14),
            const _RevenueChartSection(),
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
              _TopProductsCard(products: topProducts, trends: productsTrend)
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideY(begin: 0.05, end: 0),
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
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      onTap: onTap,
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final DashboardForecast forecast;
  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final upVsLastWeek =
        forecast.vsLastWeekPct != null && forecast.vsLastWeekPct! >= 0;
    final lastWeekDay = AppFormat.weekdayFull(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('📈', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prévision du jour',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '≈ ${forecast.projected.toStringAsFixed(0)} DT de recettes',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDark,
                  ),
                ),
                Text(
                  forecast.vsLastWeekPct != null
                      ? 'Au rythme actuel · ${upVsLastWeek ? '↑' : '↓'} ${forecast.vsLastWeekPct!.abs().toStringAsFixed(0)}% vs $lastWeekDay dernier'
                      : 'Au rythme actuel',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.tealDark,
                  ),
                ),
                Text(
                  'Mise à jour à ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.tealDark.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int tickets;
  final double? ticketMoyen;
  final double especes;
  final double carte;
  final double credit;
  final double? articlesParTicket;

  const _SummaryCard({
    required this.tickets,
    this.ticketMoyen,
    required this.especes,
    required this.carte,
    required this.credit,
    this.articlesParTicket,
  });

  @override
  Widget build(BuildContext context) {
    final total = especes + carte + credit;
    // Round espèces/carte independently, then let crédit absorb the
    // remainder so the three percentages always sum to exactly 100 — three
    // separate roundings (e.g. 45.2/13.3/41.5 → 45/13/42) would otherwise
    // land on 99 or 101 and look like a math error.
    final espPct = total > 0 ? (especes / total * 100).round() : 0;
    final cartePct = total > 0 ? (carte / total * 100).round() : 0;
    final creditPct = total > 0 ? (100 - espPct - cartePct).clamp(0, 100) : 0;

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
              Expanded(child: _summaryItem('Tickets', '$tickets', big: true)),
              Expanded(
                child: _summaryItem(
                  'Panier moyen',
                  ticketMoyen != null ? AppFormat.dtShort(ticketMoyen!) : '—',
                  big: true,
                ),
              ),
              if (articlesParTicket != null)
                Expanded(
                  child: _summaryItem(
                    'Articles / ticket',
                    articlesParTicket!.toStringAsFixed(1),
                    big: true,
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
                child: _summaryItem(
                  'Espèces',
                  '${AppFormat.dtShort(especes)} ($espPct%)',
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Carte',
                  '${AppFormat.dtShort(carte)} ($cartePct%)',
                ),
              ),
              Expanded(
                child: _summaryItem(
                  'Crédit',
                  '${AppFormat.dtShort(credit)} ($creditPct%)',
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsSummaryCard extends ConsumerWidget {
  const _AlertsSummaryCard();

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
    final critical = ref.watch(criticalAlertsCountProvider);
    final total = ref.watch(totalAlertsCountProvider);

    // Danger-colored (🔴 critiques) entries first, then warning (🟠), then
    // info (🔵) — so the most urgent alerts are always the first ones seen.
    // The last element of each tuple is the section key AlertsScreen uses
    // to scroll straight to the matching detail on tap.
    final cards = <(String, String, IconData, Color, String)>[
      if (expired > 0)
        (
          '$expired produit${expired > 1 ? 's' : ''}',
          'Périmés',
          Icons.report_outlined,
          AppColors.danger,
          'expired',
        ),
      if (unsettled > 0)
        (
          '$unsettled facture${unsettled > 1 ? 's' : ''}',
          'Facture impayée',
          Icons.receipt_long_outlined,
          AppColors.danger,
          'unsettled',
        ),
      if (overLimit > 0)
        (
          '$overLimit client${overLimit > 1 ? 's' : ''}',
          'Limite dépassée',
          Icons.person_outline_rounded,
          AppColors.danger,
          'overLimit',
        ),
      if (lossProducts > 0)
        (
          '$lossProducts produit${lossProducts > 1 ? 's' : ''}',
          'Vendus à perte',
          Icons.trending_down_rounded,
          AppColors.danger,
          'lossProducts',
        ),
      if (frequentDeletions)
        (
          'Tickets',
          'Beaucoup de suppressions',
          Icons.report_gmailerrorred_rounded,
          AppColors.danger,
          'frequentDeletions',
        ),
      if (lowStock > 0)
        (
          '$lowStock produit${lowStock > 1 ? 's' : ''}',
          'Stock faible',
          Icons.inventory_2_outlined,
          AppColors.warning,
          'lowStock',
        ),
      if (expiringSoon > 0)
        (
          '$expiringSoon produit${expiringSoon > 1 ? 's' : ''}',
          'Proche péremption',
          Icons.hourglass_bottom_rounded,
          AppColors.warning,
          'expiringSoon',
        ),
      if (staleProducts > 0)
        (
          '$staleProducts produit${staleProducts > 1 ? 's' : ''}',
          'Sans vente · 30 j',
          Icons.pause_circle_outline_rounded,
          AppColors.warning,
          'staleProducts',
        ),
      if (todayPriceChanges > 0)
        (
          '$todayPriceChanges prix',
          todayPriceChanges > 1 ? 'Prix modifiés' : 'Prix modifié',
          Icons.sell_outlined,
          AppColors.info,
          'todayPriceChanges',
        ),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
          PressScale(
            onTap: () => context.push('/alerts'),
            child: Row(
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
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (critical > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$critical critique${critical > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textFaint,
                ),
              ],
            ),
          ),
          if (cards.isEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Tout est en ordre',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Sized so ~3 cards sit fully visible and the next one
                  // shows enough (~30%) to read as "swipe for more", not a
                  // rendering glitch — a fixed pixel width would only hit
                  // that ratio on one specific screen size.
                  const gap = 10.0;
                  const visibleCards = 3.3;
                  final cardWidth =
                      (constraints.maxWidth - gap * (visibleCards - 1)) /
                      visibleCards;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: gap),
                    itemBuilder: (context, index) {
                      final (value, label, icon, color, key) = cards[index];
                      return SizedBox(
                        width: cardWidth,
                        child: PressScale(
                          onTap: () => context.push('/alerts', extra: key),
                          child: Container(
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaisseSummaryCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _CaisseSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todayCaisseSummaryProvider);
    final hasEcart = summary.sessionsAvecEcart > 0;

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
                  Icons.point_of_sale_outlined,
                  color: AppColors.tealDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Caisse aujourd\'hui',
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (summary.sessionsOuvertes > 0)
                  _caisseBadge(
                    '🟢 ${summary.sessionsOuvertes} caisse${summary.sessionsOuvertes > 1 ? 's' : ''} ouverte${summary.sessionsOuvertes > 1 ? 's' : ''}',
                    AppColors.info,
                  ),
                if (summary.sessionsCloturees > 0)
                  _caisseBadge(
                    '✓ ${summary.sessionsCloturees} clôturée${summary.sessionsCloturees > 1 ? 's' : ''}',
                    AppColors.success,
                  ),
                if (hasEcart)
                  _caisseBadge(
                    '⚠️ ${summary.sessionsAvecEcart} écart${summary.sessionsAvecEcart > 1 ? 's' : ''} détecté${summary.sessionsAvecEcart > 1 ? 's' : ''}',
                    AppColors.danger,
                  ),
                if (summary.sessionsOuvertes == 0 &&
                    summary.sessionsCloturees == 0)
                  _caisseBadge(
                    'Aucune caisse ouverte aujourd\'hui',
                    AppColors.textFaint,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _caisseStat(
                    'CA aujourd\'hui',
                    AppFormat.dt(summary.caDuJour),
                  ),
                ),
                Expanded(
                  child: _caisseStat(
                    'Cash attendu',
                    summary.sessionsOuvertes > 0
                        ? AppFormat.dt(summary.cashAttenduOuvertes)
                        : '—',
                  ),
                ),
                Expanded(
                  child: _caisseStat(
                    'Écart du jour',
                    summary.sessionsCloturees > 0
                        ? '${summary.ecartCloturesTotal >= 0 ? '+' : ''}${AppFormat.dt(summary.ecartCloturesTotal)}'
                        : '—',
                    color: summary.sessionsCloturees == 0
                        ? null
                        : summary.ecartCloturesTotal.abs() < 0.001
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _caisseBadge(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    );
  }

  Widget _caisseStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ActivitySummaryCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _ActivitySummaryCard({required this.onTap});

  // Only the events worth a glance from the Home screen — suppressions
  // (always notable) plus price/stock/new-client changes. Routine edits
  // (e.g. "Client modifié", "Paiement fournisseur") are left for the full
  // Journal d'activité so this preview doesn't turn into noise.
  static const _importantActions = {
    'Prix modifié',
    'Stock ajusté',
    'Nouveau client',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseen = ref.watch(unseenActivityCountProvider);
    final recent = ref
        .watch(activityLogProvider)
        .where(
          (e) =>
              e.impact == ActivityImpact.suppression ||
              _importantActions.contains(e.action),
        )
        .take(4)
        .toList();

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

void _showBarDetailSheet(BuildContext context, ChartBarDetail detail) {
  final title = detail.isMonth
      ? '${_monthFullNames[detail.date.month - 1]} ${detail.date.year}'
      : AppFormat.fullDate(detail.date);
  final previous = detail.previousRevenue;
  String? comparison;
  if (previous != null) {
    final pct = (detail.revenue - previous) / previous * 100;
    final ref = detail.isMonth
        ? '${_monthFullNames[detail.date.month - 1]} l\'année dernière'
        : '${AppFormat.weekdayFull(detail.date)} dernier';
    comparison =
        '${pct >= 0 ? '↑' : '↓'} ${pct.abs().toStringAsFixed(0)}% vs $ref';
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
          if (comparison != null) ...[
            const SizedBox(height: 2),
            Text(
              comparison,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: detail.revenue >= previous!
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _barDetailRow(
            'Recettes',
            AppFormat.dt(detail.revenue),
            AppColors.teal,
          ),
          _barDetailRow(
            'Bénéfice',
            AppFormat.dt(detail.profit),
            AppColors.goldDark,
          ),
          _barDetailRow('Tickets', '${detail.tickets}', AppColors.info),
        ],
      ),
    ),
  );
}

Widget _barDetailRow(String label, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
      ],
    ),
  );
}

Widget _chartTotalStat(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

const _monthFullNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

class _RevenueChartSection extends ConsumerWidget {
  const _RevenueChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(revenuePeriodProvider);
    final metric = ref.watch(chartMetricProvider);
    final chart = ref.watch(revenueChartDataProvider);
    final isMonetary =
        metric == ChartMetric.recettes || metric == ChartMetric.benefices;
    final total = chart.values.fold<double>(0, (sum, v) => sum + v);
    final average = chart.values.isEmpty ? 0.0 : total / chart.values.length;
    final unitLabel = switch (period) {
      RevenuePeriod.j7 || RevenuePeriod.j30 => 'jour',
      RevenuePeriod.m12 => 'mois',
    };
    String fmt(double v) => isMonetary ? AppFormat.dt(v) : v.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0) ...[
          Row(
            children: [
              Expanded(
                child: _chartTotalStat('Total ${period.label}', fmt(total)),
              ),
              Expanded(
                child: _chartTotalStat('Moyenne / $unitLabel', fmt(average)),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
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
                  details: chart.details,
                  metric: metric,
                  onBarTap: (detail) => _showBarDetailSheet(context, detail),
                ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<ChartBarDetail> details;
  final ChartMetric metric;
  final ValueChanged<ChartBarDetail> onBarTap;
  const _RevenueBarChart({
    required this.values,
    required this.labels,
    required this.details,
    required this.metric,
    required this.onBarTap,
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
          touchCallback: (event, response) {
            final index = response?.spot?.touchedBarGroupIndex;
            if (event is FlTapUpEvent &&
                index != null &&
                index < details.length) {
              onBarTap(details[index]);
            }
          },
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

class _TopProductsCard extends StatelessWidget {
  final List<TopProductStat> products;
  final Map<String, double?> trends;
  const _TopProductsCard({required this.products, required this.trends});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = products.first.revenue;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: List.generate(products.length, (i) {
          final p = products[i];
          final trend = trends[p.product.id];
          final qtyPart = p.product.venduAuPoids
              ? '${p.quantite.toStringAsFixed(1)} kg vendus'
              : '${p.quantite.toStringAsFixed(0)} unité${p.quantite > 1 ? 's' : ''} vendues';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.gold.withValues(alpha: 0.2)
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
                Text(p.product.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: p.revenue / maxRevenue),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 6,
                                backgroundColor: AppColors.surfaceMuted,
                                valueColor: const AlwaysStoppedAnimation(
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
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (trend != null) ...[
                          const SizedBox(width: 3),
                          Icon(
                            trend >= 0
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
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
                      '$qtyPart • ${p.ventes} vente${p.ventes > 1 ? 's' : ''}',
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
    );
  }
}

class _RecentSaleTile extends ConsumerWidget {
  final Sale sale;
  const _RecentSaleTile({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = sale.employeeId;
    String? cashierName;
    if (employeeId != null) {
      for (final e in ref.watch(employeesProvider)) {
        if (e.id == employeeId) {
          cashierName = e.nom.split(' ').first;
          break;
        }
      }
    }

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
                    cashierName != null
                        ? '${DateFormat('HH:mm').format(sale.dateHeure)} • $cashierName'
                        : DateFormat('HH:mm').format(sale.dateHeure),
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
            const SizedBox(height: 8),
            if (ratio != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
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
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: ratio >= 1 ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                ],
              ),
              if (ratio >= 0.8) ...[
                const SizedBox(height: 4),
                Text(
                  '⚠️ Proche de la limite',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ratio >= 1 ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ],
            ] else
              const Text(
                'Aucune limite définie',
                style: TextStyle(fontSize: 11, color: AppColors.textFaint),
              ),
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
    final decimals = product.venduAuPoids ? 1 : 0;
    final manque = (product.seuilAlerte - product.stock).clamp(
      0,
      double.infinity,
    );

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
                  '${product.stock.toStringAsFixed(decimals)} ${product.unite}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Seuil : ${product.seuilAlerte.toStringAsFixed(decimals)} ${product.unite}'
              '${manque > 0 ? ' • Manque ${manque.toStringAsFixed(decimals)} ${product.unite}' : ''}',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _InvoiceState { aJour, bientotDue, enRetard }

extension on _InvoiceState {
  (String, Color) get labelAndColor => switch (this) {
    _InvoiceState.aJour => ('À jour', AppColors.success),
    _InvoiceState.bientotDue => ('Bientôt due', AppColors.warning),
    _InvoiceState.enRetard => ('En retard', AppColors.danger),
  };
}

class _UnpaidInvoiceTile extends StatelessWidget {
  final PurchaseInvoice invoice;
  const _UnpaidInvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysOpen = now.difference(invoice.date).inDays;
    final isToday = daysOpen == 0 && invoice.date.day == now.day;
    final state = daysOpen >= oldUnpaidInvoiceThresholdDays
        ? _InvoiceState.enRetard
        : daysOpen >= oldUnpaidInvoiceThresholdDays - 15
        ? _InvoiceState.bientotDue
        : _InvoiceState.aJour;
    final (stateLabel, stateColor) = state.labelAndColor;

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
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: stateColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        stateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: stateColor,
                        ),
                      ),
                      Text(
                        isToday
                            ? ' · aujourd\'hui'
                            : ' · ouverte depuis $daysOpen jour${daysOpen > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
