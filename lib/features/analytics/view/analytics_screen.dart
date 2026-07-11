import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/analytics/viewmodel/analytics_provider.dart';
import 'package:sou9ix/features/dashboard/viewmodel/dashboard_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/section_header.dart';

/// The layer above the dashboard: who's actually driving sales, when the
/// shop is busiest, which products are dead weight or quietly losing
/// money, and a simple stockout forecast — the kind of analysis that
/// turns a POS app into a real decision-support tool.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiers = ref.watch(topCashiersProvider);
    final hours = ref.watch(hourlyRevenueProvider).take(5).toList();
    final neverSold = ref.watch(neverSoldProductsProvider);
    final profitable = ref
        .watch(mostProfitableProductsProvider)
        .take(5)
        .toList();
    final topClients = ref.watch(topClientsProvider).take(5).toList();
    final topSuppliers = ref.watch(topSuppliersProvider).take(5).toList();
    final profitEvolution = ref.watch(profitEvolutionProvider);
    final expensesEvolution = ref.watch(expensesEvolutionProvider);
    final stockValue = ref.watch(currentStockValueProvider);
    final stockout = ref.watch(stockoutForecastProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Centre d\'analyse')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VALEUR DU STOCK ACTUEL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormat.dt(stockValue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Au prix d\'achat',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Aperçu approfondi'),
          const SizedBox(height: 12),
          const _DeeperInsightsGrid(),
          const SizedBox(height: 26),
          SectionHeader(title: 'Prévision de rupture de stock'),
          const SizedBox(height: 4),
          const Text(
            'Basé sur le rythme de vente des 14 derniers jours',
            style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 12),
          if (stockout.isEmpty)
            const _EmptyCard(
              message: 'Aucun produit ne risque la rupture prochainement.',
            )
          else
            _Card(
              children: [
                for (final f in stockout)
                  _Row(
                    onTap: () =>
                        context.push('/products/edit', extra: f.product),
                    leading: ProductAvatar(
                      emoji: f.product.emoji,
                      photoBytes: f.product.photoBytes,
                      size: 34,
                    ),
                    title: f.product.name,
                    subtitle:
                        'Rythme : ${f.dailyVelocity.toStringAsFixed(1)} ${f.product.unite}/jour',
                    trailing: Text(
                      f.daysLeft <= 0 ? 'Rupture' : '${f.daysLeft} j',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: f.daysLeft <= 3
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Top caissiers'),
          const SizedBox(height: 12),
          if (cashiers.isEmpty)
            const _EmptyCard(
              message: 'Aucune vente attribuée à un employé pour l\'instant.',
            )
          else
            _Card(
              children: [
                for (var i = 0; i < cashiers.length; i++)
                  _Row(
                    leading: _RankBadge(rank: i),
                    title: cashiers[i].employeeName,
                    subtitle:
                        '${cashiers[i].tickets} ticket${cashiers[i].tickets > 1 ? 's' : ''}',
                    trailing: Text(
                      AppFormat.dtShort(cashiers[i].revenue),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Heures les plus rentables'),
          const SizedBox(height: 12),
          if (hours.isEmpty)
            const _EmptyCard(message: 'Pas encore assez de ventes.')
          else
            _Card(
              children: [
                for (final (hour, revenue) in hours)
                  _Row(
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    title:
                        '${hour.toString().padLeft(2, '0')}:00 — ${(hour + 1).toString().padLeft(2, '0')}:00',
                    subtitle: null,
                    trailing: Text(
                      AppFormat.dtShort(revenue),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Produits les plus rentables'),
          const SizedBox(height: 4),
          const Text(
            'Classés par bénéfice réel, pas par chiffre d\'affaires',
            style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 12),
          if (profitable.isEmpty)
            const _EmptyCard(
              message: 'Aucune vente enregistrée pour l\'instant.',
            )
          else
            _Card(
              children: [
                for (final p in profitable)
                  _Row(
                    onTap: () =>
                        context.push('/products/edit', extra: p.product),
                    leading: ProductAvatar(
                      emoji: p.product.emoji,
                      photoBytes: p.product.photoBytes,
                      size: 34,
                    ),
                    title: p.product.name,
                    subtitle: 'CA ${AppFormat.dtShort(p.revenue)}',
                    trailing: Text(
                      '+${AppFormat.dtShort(p.profit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Produits jamais vendus'),
          const SizedBox(height: 12),
          if (neverSold.isEmpty)
            const _EmptyCard(
              message: 'Chaque produit du catalogue s\'est déjà vendu.',
            )
          else
            _Card(
              children: [
                for (final p in neverSold)
                  _Row(
                    onTap: () => context.push('/products/edit', extra: p),
                    leading: ProductAvatar(
                      emoji: p.emoji,
                      photoBytes: p.photoBytes,
                      size: 34,
                    ),
                    title: p.name,
                    subtitle: 'Ajouté au catalogue, jamais vendu',
                    trailing: Text(
                      AppFormat.dt(p.prixVente),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Clients qui achètent le plus'),
          const SizedBox(height: 12),
          if (topClients.isEmpty)
            const _EmptyCard(
              message: 'Aucun achat client enregistré pour l\'instant.',
            )
          else
            _Card(
              children: [
                for (final c in topClients)
                  _Row(
                    onTap: () =>
                        context.push('/clients/detail', extra: c.client),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                      foregroundColor: AppColors.tealDark,
                      child: Text(
                        c.client.nom.substring(0, 1),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    title: c.client.nom,
                    subtitle: '${c.tickets} achat${c.tickets > 1 ? 's' : ''}',
                    trailing: Text(
                      AppFormat.dtShort(c.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Fournisseurs les plus utilisés'),
          const SizedBox(height: 12),
          if (topSuppliers.isEmpty)
            const _EmptyCard(
              message: 'Aucun achat fournisseur enregistré pour l\'instant.',
            )
          else
            _Card(
              children: [
                for (final s in topSuppliers)
                  _Row(
                    onTap: () => context.push('/purchases'),
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    title: s.nom,
                    subtitle:
                        '${s.factures} facture${s.factures > 1 ? 's' : ''}',
                    trailing: Text(
                      AppFormat.dtShort(s.total),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Évolution du bénéfice'),
          const SizedBox(height: 12),
          _MiniChart(
            values: profitEvolution.values,
            labels: profitEvolution.labels,
            color: AppColors.teal,
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Évolution des dépenses'),
          const SizedBox(height: 12),
          _MiniChart(
            values: expensesEvolution.values,
            labels: expensesEvolution.labels,
            color: AppColors.warning,
          ),
        ],
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

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: rank == 0
            ? AppColors.gold.withValues(alpha: 0.2)
            : AppColors.surfaceMuted,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${rank + 1}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: rank == 0 ? AppColors.goldDark : AppColors.textSecondary,
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

class _MiniChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  const _MiniChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return const _EmptyCard(
        message: 'Aucune donnée sur les 6 derniers mois.',
      );
    }
    final maxY = maxValue * 1.25;

    return Container(
      height: 170,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: BarChart(
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
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                        color: isLast ? color : AppColors.textFaint,
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
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  color: i == values.length - 1
                      ? color
                      : AppColors.surfaceMuted,
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}
