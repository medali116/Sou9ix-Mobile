import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/shell/tab_navigation_provider.dart';
import 'package:sou9ix/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
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
import 'package:sou9ix/core/widgets/stat_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final totalAlerts = ref.watch(totalAlertsCountProvider);
    final todayRevenue = ref.watch(todayRevenueProvider);
    final yesterdayRevenue = ref.watch(yesterdayRevenueProvider);
    final todayProfit = ref.watch(todayProfitProvider);
    final todayTickets = ref.watch(todaySalesProvider).length;
    final todayExpenses = ref.watch(todayExpensesTotalProvider);
    final paymentBreakdown = ref.watch(todayPaymentBreakdownProvider);
    final topProducts = ref.watch(topProductsProvider);
    final recentSales = ref.watch(recentSalesProvider);
    final creditClients = ref.watch(creditClientsPreviewProvider);
    final lowStock = ref.watch(lowStockProvider).take(3).toList();
    final unpaidInvoices = ref.watch(unpaidInvoicesPreviewProvider);

    final trendUp = todayRevenue >= yesterdayRevenue;
    final trendPct = yesterdayRevenue > 0
        ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100).abs()
        : (todayRevenue > 0 ? 100.0 : 0.0);

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
                        user?.magasin ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 22),
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
                  trend: '${trendPct.toStringAsFixed(0)}%',
                  trendUp: trendUp,
                ),
                StatCard(
                  label: 'Bénéfice net',
                  value: AppFormat.dt(todayProfit),
                  icon: Icons.trending_up_rounded,
                  color: AppColors.goldDark,
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
            const SizedBox(height: 20),
            _SummaryCard(
              recettes: todayRevenue,
              depenses: todayExpenses,
              benefice: todayRevenue - todayExpenses,
              especes: paymentBreakdown[ModePaiement.especes] ?? 0,
              carte: paymentBreakdown[ModePaiement.carte] ?? 0,
              credit: paymentBreakdown[ModePaiement.credit] ?? 0,
            ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 26),
            const SectionHeader(title: 'Actions rapides'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.add_shopping_cart_rounded,
                    label: 'Nouvelle vente',
                    color: AppColors.teal,
                    onTap: () =>
                        ref.read(requestedTabIndexProvider.notifier).state = 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.inventory_2_outlined,
                    label: 'Ajouter produit',
                    color: AppColors.goldDark,
                    onTap: () => context.push('/products/new'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_1_rounded,
                    label: 'Nouveau client',
                    color: AppColors.info,
                    onTap: () => context.push('/clients'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_shipping_outlined,
                    label: 'Facture fournisseur',
                    color: AppColors.tealDark,
                    onTap: () => context.push('/stock/receipt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _AlertsSummaryCard(onTap: () => context.push('/alerts')),
            const SizedBox(height: 26),
            const _RevenueChartSection(),
            const SizedBox(height: 26),
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
                              Text(
                                p.product.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.product.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
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
                                  Text(
                                    AppFormat.dtShort(p.revenue),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    p.product.venduAuPoids
                                        ? '${p.quantite.toStringAsFixed(1)} kg vendus'
                                        : '${p.ventes} ventes',
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
            const SizedBox(height: 26),
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
            const SizedBox(height: 26),
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
                    for (final c in creditClients) _CreditClientTile(client: c),
                  ],
                ),
              ),
            const SizedBox(height: 26),
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
            const SizedBox(height: 26),
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

  const _SummaryCard({
    required this.recettes,
    required this.depenses,
    required this.benefice,
    required this.especes,
    required this.carte,
    required this.credit,
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
              Expanded(child: _summaryItem('Recettes', recettes, big: true)),
              Expanded(child: _summaryItem('Dépenses', depenses, big: true)),
              Expanded(
                child: _summaryItem(
                  'Bénéfice',
                  benefice,
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
              Expanded(child: _summaryItem('Espèces', especes)),
              Expanded(child: _summaryItem('Carte', carte)),
              Expanded(child: _summaryItem('Crédit', credit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String label,
    double value, {
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
          AppFormat.dtShort(value),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
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
  final VoidCallback onTap;
  const _AlertsSummaryCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(lowStockProvider).length;
    final expiringSoon = ref.watch(expiringSoonProvider).length;
    final expired = ref.watch(expiredProductsProvider).length;
    final unsettled = ref.watch(unsettledInvoicesProvider).length;
    final overLimit = ref.watch(clientsOverLimitProvider).length;

    final lines = <String>[
      if (lowStock > 0)
        '$lowStock produit${lowStock > 1 ? 's' : ''} sous le seuil',
      if (expired > 0)
        '$expired produit${expired > 1 ? 's' : ''} périmé${expired > 1 ? 's' : ''}',
      if (expiringSoon > 0)
        '$expiringSoon produit${expiringSoon > 1 ? 's' : ''} proche${expiringSoon > 1 ? 's' : ''} de la péremption',
      if (unsettled > 0)
        '$unsettled facture${unsettled > 1 ? 's' : ''} fournisseur impayée${unsettled > 1 ? 's' : ''}',
      if (overLimit > 0)
        '$overLimit client${overLimit > 1 ? 's' : ''} dépasse${overLimit > 1 ? 'nt' : ''} leur limite',
    ];

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lines.isEmpty
              ? AppColors.surface
              : AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: lines.isEmpty
                ? AppColors.border
                : AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  lines.isEmpty
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: lines.isEmpty ? AppColors.success : AppColors.warning,
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
            if (lines.isEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Tout est en ordre',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '•  $line',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
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

class _RevenueChartSection extends ConsumerWidget {
  const _RevenueChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(revenuePeriodProvider);
    final chart = ref.watch(revenueChartDataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recettes'),
        const SizedBox(height: 14),
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
                    'Aucune recette sur cette période',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 12.5,
                    ),
                  ),
                )
              : _RevenueBarChart(values: chart.values, labels: chart.labels),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  const _RevenueBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue == 0 ? 1.0 : maxValue * 1.25;
    final step = (values.length / 8).ceil().clamp(1, values.length);

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
                  AppFormat.dt(rod.toY),
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
              child: const Icon(
                Icons.receipt_outlined,
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
            Text(
              AppFormat.dtShort(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditClientTile extends StatelessWidget {
  final Client client;
  const _CreditClientTile({required this.client});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: () => context.push('/clients/detail', extra: client),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
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
              AppFormat.dtShort(client.creditTotal),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.danger,
              ),
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
    return PressScale(
      onTap: () => context.push('/products/edit', extra: product),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
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
    final isToday =
        invoice.date.year == now.year &&
        invoice.date.month == now.month &&
        invoice.date.day == now.day;

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
                        : DateFormat('dd/MM/yyyy').format(invoice.date),
                    style: Theme.of(context).textTheme.bodyMedium,
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
