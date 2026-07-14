import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/analytics/viewmodel/analytics_provider.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/dashboard/viewmodel/dashboard_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/stats/viewmodel/statistics_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/date_range_picker_sheet.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';

/// The layer above the dashboard: who's actually driving sales, when the
/// shop is busiest, which products are dead weight or quietly losing
/// money, and a simple stockout forecast — the kind of analysis that
/// turns a POS app into a real decision-support tool.
///
/// Organized into tabs (Vue d'ensemble / Rentabilité / Stock / Équipe /
/// Clients) rather than one long scroll, so each visit answers a specific
/// question instead of dumping every metric at once.
enum _AnalyticsTab { apercu, rentabilite, stock, equipe, clients }

extension on _AnalyticsTab {
  String get label => switch (this) {
    _AnalyticsTab.apercu => 'Vue d\'ensemble',
    _AnalyticsTab.rentabilite => 'Rentabilité',
    _AnalyticsTab.stock => 'Stock',
    _AnalyticsTab.equipe => 'Équipe',
    _AnalyticsTab.clients => 'Clients',
  };
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _AnalyticsTab _tab = _AnalyticsTab.apercu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Centre d\'analyse')),
      body: Column(
        children: [
          SizedBox(
            height: 42,
            child: _EdgeFade(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                children: [
                  for (final t in _AnalyticsTab.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t.label),
                        selected: _tab == t,
                        onSelected: (_) => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: switch (_tab) {
                _AnalyticsTab.apercu => [
                  _ApercuTab(onSwitchTab: (t) => setState(() => _tab = t)),
                ],
                _AnalyticsTab.rentabilite => const [_RentabiliteTab()],
                _AnalyticsTab.stock => const [_StockTab()],
                _AnalyticsTab.equipe => const [_EquipeTab()],
                _AnalyticsTab.clients => const [_ClientsTab()],
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ApercuTab extends ConsumerWidget {
  final void Function(_AnalyticsTab) onSwitchTab;
  const _ApercuTab({required this.onSwitchTab});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showAppDateRangeSheet(
      context,
      initialRange: ref.read(statsCustomRangeProvider),
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
    );
    if (range != null) {
      ref.read(statsCustomRangeProvider.notifier).state = range;
      ref.read(statsPeriodProvider.notifier).state = StatsPeriod.personnalise;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final customRange = ref.watch(statsCustomRangeProvider);
    final stockValue = ref.watch(currentStockValueProvider);
    final kpis = ref.watch(statsKpisProvider);
    final financial = ref.watch(statsFinancialBreakdownProvider);
    final marginRate = financial.revenue > 0 ? financial.grossMargin / financial.revenue * 100 : null;
    final isLoss = kpis.netProfit < 0;

    final urgentStockouts = ref.watch(stockoutForecastProvider).where((f) => f.daysLeft <= 3).length;
    final neverSoldCount = ref.watch(neverSoldProductsProvider).length;

    final bestCashier = ref.watch(periodBestCashierProvider);
    final bestClient = ref.watch(periodBestClientProvider);
    final topSupplier = ref.watch(periodTopSupplierProvider);

    final watchItems = <_WatchItem>[
      if (urgentStockouts > 0)
        _WatchItem(
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          text: '$urgentStockouts rupture${urgentStockouts > 1 ? 's' : ''} proche${urgentStockouts > 1 ? 's' : ''} de stock',
          onTap: () => onSwitchTab(_AnalyticsTab.stock),
        ),
      if (neverSoldCount > 0)
        _WatchItem(
          icon: Icons.inventory_outlined,
          color: AppColors.warning,
          text: '$neverSoldCount produit${neverSoldCount > 1 ? 's' : ''} jamais vendu${neverSoldCount > 1 ? 's' : ''}',
          onTap: () => onSwitchTab(_AnalyticsTab.stock),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: _EdgeFade(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in StatsPeriod.values.where((p) => p != StatsPeriod.jour && p != StatsPeriod.personnalise))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PeriodChip(
                      label: p.label,
                      selected: period == p,
                      onTap: () => ref.read(statsPeriodProvider.notifier).state = p,
                    ),
                  ),
                _PeriodChip(
                  icon: Icons.calendar_month_rounded,
                  label: period == StatsPeriod.personnalise && customRange != null
                      ? '${customRange.start.day}/${customRange.start.month} → ${customRange.end.day}/${customRange.end.month}'
                      : 'Personnalisé',
                  selected: period == StatsPeriod.personnalise,
                  onTap: () => _pickCustomRange(context, ref),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Performance'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                compact: true,
                dense: true,
                label: 'Chiffre d\'affaires',
                value: AppFormat.dtGrouped(kpis.revenue),
                icon: Icons.payments_rounded,
                color: AppColors.teal,
                trend: kpis.revenueChangePct != null
                    ? '${kpis.revenueChangePct!.abs().toStringAsFixed(1)}%'
                    : null,
                trendUp: (kpis.revenueChangePct ?? 0) >= 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                compact: true,
                dense: true,
                label: isLoss ? 'Perte nette' : 'Bénéfice net',
                value: AppFormat.dtGrouped(kpis.netProfit),
                icon: isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                color: isLoss ? AppColors.danger : AppColors.success,
                trend: kpis.netProfitChangePct != null
                    ? '${kpis.netProfitChangePct!.abs().toStringAsFixed(1)}%'
                    : null,
                trendUp: (kpis.netProfitChangePct ?? 0) >= 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                compact: true,
                dense: true,
                label: 'Marge brute',
                value: marginRate != null ? '${marginRate.toStringAsFixed(1)}%' : '—',
                icon: Icons.percent_rounded,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                compact: true,
                dense: true,
                label: 'Valeur du stock',
                value: AppFormat.dtGrouped(stockValue),
                icon: Icons.inventory_2_outlined,
                color: AppColors.tealDark,
              ),
            ),
          ],
        ),
        if (watchItems.isNotEmpty) ...[
          const SizedBox(height: 26),
          const SectionHeader(title: 'À surveiller'),
          const SizedBox(height: 12),
          _Card(children: [for (final w in watchItems) _WatchRow(item: w)]),
        ],
        const SizedBox(height: 26),
        const SectionHeader(title: 'Leaders de la période'),
        const SizedBox(height: 12),
        _Card(
          children: [
            _Row(
              onTap: () => onSwitchTab(_AnalyticsTab.equipe),
              leading: const _LeaderIcon(icon: Icons.emoji_events_outlined),
              title: bestCashier?.employeeName ?? '—',
              subtitle: bestCashier != null
                  ? '${bestCashier.tickets} ticket${bestCashier.tickets > 1 ? 's' : ''} · Meilleur caissier'
                  : 'Aucune vente sur la période',
              trailing: Text(
                bestCashier != null ? AppFormat.dtGrouped(bestCashier.revenue) : '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _Row(
              onTap: bestClient != null ? () => context.push('/clients/detail', extra: bestClient.client) : null,
              leading: const _LeaderIcon(icon: Icons.star_outline_rounded),
              title: bestClient?.client.nom ?? '—',
              subtitle: bestClient != null
                  ? '${bestClient.tickets} achat${bestClient.tickets > 1 ? 's' : ''} · Meilleur client'
                  : 'Aucun achat client sur la période',
              trailing: Text(
                bestClient != null ? AppFormat.dtGrouped(bestClient.total) : '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _Row(
              onTap: () => context.push('/purchases'),
              leading: const _LeaderIcon(icon: Icons.local_shipping_outlined),
              title: topSupplier?.nom ?? '—',
              subtitle: topSupplier != null
                  ? '${topSupplier.factures} facture${topSupplier.factures > 1 ? 's' : ''} · Fournisseur principal'
                  : 'Aucun achat fournisseur sur la période',
              trailing: Text(
                topSupplier != null ? AppFormat.dtGrouped(topSupplier.total) : '',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fades the right edge of a horizontally scrollable row so a partially
/// visible next chip reads as "more to scroll" instead of a layout
/// overflow — used on the tab row and the period-picker row, both of
/// which run 4-5 chips wide on a typical phone.
class _EdgeFade extends StatelessWidget {
  final Widget child;
  const _EdgeFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0.0, 0.88, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _LeaderIcon extends StatelessWidget {
  final IconData icon;
  const _LeaderIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Icon(icon, size: 16, color: AppColors.textSecondary),
    );
  }
}

class _WatchItem {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;
  const _WatchItem({required this.icon, required this.color, required this.text, this.onTap});
}

class _WatchRow extends StatelessWidget {
  final _WatchItem item;
  const _WatchRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(item.icon, size: 16, color: item.color),
          const SizedBox(width: 10),
          Expanded(child: Text(item.text, style: Theme.of(context).textTheme.bodyLarge)),
          if (item.onTap != null)
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textFaint),
        ],
      ),
    );
    return item.onTap == null ? content : InkWell(onTap: item.onTap, child: content);
  }
}

class _RentabiliteTab extends ConsumerWidget {
  const _RentabiliteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profitable = ref.watch(mostProfitableProductsProvider).take(5).toList();
    final profitEvolution = ref.watch(profitEvolutionProvider);
    final expensesEvolution = ref.watch(expensesEvolutionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Produits les plus rentables'),
        const SizedBox(height: 4),
        const Text(
          'Classés par bénéfice réel, pas par chiffre d\'affaires',
          style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 12),
        if (profitable.isEmpty)
          const _EmptyCard(message: 'Aucune vente enregistrée pour l\'instant.')
        else
          _Card(
            children: [
              for (final p in profitable)
                _Row(
                  onTap: () => context.push('/products/edit', extra: p.product),
                  leading: ProductAvatar(emoji: p.product.emoji, photoBytes: p.product.photoBytes, size: 34),
                  title: p.product.name,
                  subtitle: 'CA ${AppFormat.dtShort(p.revenue)}',
                  trailing: Text(
                    '+${AppFormat.dtShort(p.profit)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Évolution du bénéfice'),
        const SizedBox(height: 12),
        _MiniChart(values: profitEvolution.values, labels: profitEvolution.labels, color: AppColors.teal),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Évolution des dépenses'),
        const SizedBox(height: 12),
        _MiniChart(values: expensesEvolution.values, labels: expensesEvolution.labels, color: AppColors.warning),
      ],
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockout = ref.watch(stockoutForecastProvider);
    final neverSold = ref.watch(neverSoldProductsProvider);
    final loss = ref.watch(expiredStockLossProvider);
    final topSuppliers = ref.watch(topSuppliersProvider).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Prévision de rupture de stock'),
        const SizedBox(height: 4),
        const Text(
          'Basé sur le rythme de vente des 14 derniers jours',
          style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 12),
        if (stockout.isEmpty)
          const _EmptyCard(message: 'Aucun produit ne risque la rupture prochainement.')
        else
          _Card(
            children: [
              for (final f in stockout)
                _Row(
                  onTap: () => context.push('/products/edit', extra: f.product),
                  leading: ProductAvatar(emoji: f.product.emoji, photoBytes: f.product.photoBytes, size: 34),
                  title: f.product.name,
                  subtitle: 'Rythme : ${f.dailyVelocity.toStringAsFixed(1)} ${f.product.unite}/jour',
                  trailing: Text(
                    f.daysLeft <= 0 ? 'Rupture' : '${f.daysLeft} j',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: f.daysLeft <= 3 ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Produits jamais vendus'),
        const SizedBox(height: 12),
        if (neverSold.isEmpty)
          const _EmptyCard(message: 'Chaque produit du catalogue s\'est déjà vendu.')
        else
          _Card(
            children: [
              for (final p in neverSold)
                _Row(
                  onTap: () => context.push('/products/edit', extra: p),
                  leading: ProductAvatar(emoji: p.emoji, photoBytes: p.photoBytes, size: 34),
                  title: p.name,
                  subtitle: 'Ajouté au catalogue, jamais vendu',
                  trailing: Text(
                    AppFormat.dt(p.prixVente),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textFaint),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Pertes (produits expirés)'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: loss > 0 ? AppColors.danger : AppColors.textFaint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loss > 0
                      ? 'Stock actuellement périmé, valorisé au prix d\'achat.'
                      : 'Aucune perte liée à des produits expirés.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                AppFormat.dtShort(loss),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: loss > 0 ? AppColors.danger : AppColors.textFaint,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Fournisseurs les plus utilisés'),
        const SizedBox(height: 12),
        if (topSuppliers.isEmpty)
          const _EmptyCard(message: 'Aucun achat fournisseur enregistré pour l\'instant.')
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
                    child: const Icon(Icons.local_shipping_outlined, size: 16, color: AppColors.textSecondary),
                  ),
                  title: s.nom,
                  subtitle: '${s.factures} facture${s.factures > 1 ? 's' : ''}',
                  trailing: Text(AppFormat.dtShort(s.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
      ],
    );
  }
}

class _EquipeTab extends ConsumerWidget {
  const _EquipeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiers = ref.watch(topCashiersProvider);
    final hours = ref.watch(hourlyRevenueProvider).take(5).toList();
    final employees = {for (final e in ref.watch(employeesProvider)) e.id: e.nom};
    final discrepancies = ref
        .watch(shiftsProvider)
        .where((s) => !s.enCours && s.montantCompte != null)
        .map((s) => (
              shift: s,
              name: employees[s.employeeId] ?? s.employeeId,
              ecart: ref.watch(cashDiscrepancyForShiftProvider(s)) ?? 0,
            ))
        .where((e) => e.ecart.abs() > 0.001)
        .toList()
      ..sort((a, b) => b.ecart.abs().compareTo(a.ecart.abs()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Top caissiers'),
        const SizedBox(height: 12),
        if (cashiers.isEmpty)
          const _EmptyCard(message: 'Aucune vente attribuée à un employé pour l\'instant.')
        else
          _Card(
            children: [
              for (var i = 0; i < cashiers.length; i++)
                _Row(
                  leading: _RankBadge(rank: i),
                  title: cashiers[i].employeeName,
                  subtitle: '${cashiers[i].tickets} ticket${cashiers[i].tickets > 1 ? 's' : ''}',
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
                    child: const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
                  ),
                  title: '${hour.toString().padLeft(2, '0')}:00 — ${(hour + 1).toString().padLeft(2, '0')}:00',
                  subtitle: null,
                  trailing: Text(AppFormat.dtShort(revenue), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        const SizedBox(height: 26),
        SectionHeader(title: 'Écarts de caisse'),
        const SizedBox(height: 4),
        const Text(
          'Différence entre les espèces comptées et les espèces attendues à la clôture',
          style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 12),
        if (discrepancies.isEmpty)
          const _EmptyCard(message: 'Aucun écart de caisse enregistré pour l\'instant.')
        else
          _Card(
            children: [
              for (final d in discrepancies)
                _Row(
                  leading: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (d.ecart < 0 ? AppColors.danger : AppColors.success).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      size: 16,
                      color: d.ecart < 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  title: d.name,
                  subtitle: d.shift.clockOut != null
                      ? '${d.shift.clockOut!.day}/${d.shift.clockOut!.month}/${d.shift.clockOut!.year}'
                      : null,
                  trailing: Text(
                    '${d.ecart > 0 ? '+' : ''}${AppFormat.dtShort(d.ecart)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: d.ecart < 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topClients = ref.watch(topClientsProvider).take(5).toList();
    final newClients = ref.watch(newClientsThisMonthProvider);
    final totalCredit = ref.watch(totalCreditProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PressScale(
                onTap: () => context.push('/clients'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppFormat.dt(totalCredit),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: totalCredit > 0 ? AppColors.warning : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Crédit en cours', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$newClients', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    const Text('Nouveaux clients (ce mois)', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'Clients qui achètent le plus'),
        const SizedBox(height: 12),
        if (topClients.isEmpty)
          const _EmptyCard(message: 'Aucun achat client enregistré pour l\'instant.')
        else
          _Card(
            children: [
              for (final c in topClients)
                _Row(
                  onTap: () => context.push('/clients/detail', extra: c.client),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                    foregroundColor: AppColors.tealDark,
                    child: Text(c.client.nom.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: c.client.nom,
                  subtitle: '${c.tickets} achat${c.tickets > 1 ? 's' : ''}',
                  trailing: Text(AppFormat.dtShort(c.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
      ],
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
