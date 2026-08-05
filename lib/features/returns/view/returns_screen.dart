import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';
import 'package:sou9ix/features/returns/model/stock_return.dart';
import 'package:sou9ix/features/returns/service/stock_service.dart';
import 'package:sou9ix/features/returns/view/add_return_screen.dart';
import 'package:sou9ix/features/returns/viewmodel/stock_returns_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

const _dateTimeFormat = 'dd/MM/yyyy · HH:mm';

/// Log of stock write-offs (expired, damaged, stolen, returned to a
/// supplier…) with the resulting loss valued at cost price — lets the
/// owner see shrinkage over time, who logged it, and where it's
/// concentrated.
class ReturnsScreen extends ConsumerWidget {
  const ReturnsScreen({super.key});

  void _openAddMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allReturns = ref.watch(stockReturnsProvider);
    final filtered = ref.watch(filteredStockReturnsProvider);
    final canRecord = ref.watch(
      hasModuleProvider(EmployeeModule.stockProduits),
    );
    final alerts = ref.watch(frequentLossAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retours & pertes'),
        actions: [
          if (canRecord)
            IconButton(
              onPressed: () => _openAddMenu(context),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Enregistrer une perte',
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _TodaySummaryRow()),
          const SliverToBoxAdapter(child: _TotalLossCard()),
          if (alerts.isNotEmpty)
            SliverToBoxAdapter(child: _FrequentLossBanner(alerts: alerts)),
          const SliverToBoxAdapter(child: _FiltersSection()),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.remove_shopping_cart_outlined,
                title: allReturns.isEmpty
                    ? 'Aucune perte enregistrée'
                    : 'Aucun résultat',
                message: allReturns.isEmpty
                    ? 'Les produits périmés, cassés ou retournés\nau fournisseur apparaîtront ici.'
                    : 'Aucune perte ne correspond à ces filtres.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final r = filtered[index];
                  return _ReturnTile(
                    stockReturn: r,
                  ).animate().fadeIn(duration: 220.ms, delay: (18 * index).ms);
                },
              ),
            ),
          if (allReturns.isNotEmpty)
            const SliverToBoxAdapter(child: _AnalyticsSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ---- Header: today's breakdown ----

class _TodaySummaryRow extends ConsumerWidget {
  const _TodaySummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayLoss = ref.watch(todayLossProvider);
    if (todayLoss <= 0) return const SizedBox.shrink();
    final byMotif = ref.watch(todayLossByMotifProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Text(
            'Aujourd\'hui',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            AppFormat.dt(todayLoss),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
          for (final entry in byMotif.entries)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: entry.key.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${entry.key.label} · ${AppFormat.dt(entry.value)}',
                style: TextStyle(
                  color: entry.key.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- Header: total loss card ----

class _TotalLossCard extends ConsumerWidget {
  const _TotalLossCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returns = ref.watch(stockReturnsProvider);
    final totalLoss = ref.watch(totalLossProvider);
    final monthLoss = ref.watch(thisMonthLossProvider);
    final lastMonthLoss = ref.watch(lastMonthLossProvider);
    final delta = monthLoss - lastMonthLoss;
    final showTrend = monthLoss > 0 || lastMonthLoss > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.inkGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PERTES',
                      style: TextStyle(
                        color: AppColors.tealLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppFormat.dt(totalLoss),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${returns.length} perte${returns.length > 1 ? 's' : ''} enregistrée${returns.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.remove_shopping_cart_outlined,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          if (showTrend) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  delta > 0
                      ? Icons.trending_up_rounded
                      : delta < 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_flat_rounded,
                  size: 16,
                  color: delta > 0
                      ? AppColors.danger
                      : delta < 0
                      ? AppColors.success
                      : Colors.white54,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delta == 0
                        ? 'Ce mois : ${AppFormat.dt(monthLoss)} · identique au mois dernier'
                        : 'Ce mois : ${AppFormat.dt(monthLoss)} · ${delta > 0 ? '+' : ''}${AppFormat.dt(delta)} vs mois dernier',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0);
  }
}

// ---- Recurring-loss alert banner ----

class _FrequentLossBanner extends StatelessWidget {
  final List<ProductLossStat> alerts;
  const _FrequentLossBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final top = alerts.first;
    final rest = alerts.length - 1;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rest > 0
                  ? '« ${top.productName} » perdu ${top.occurrences} fois cette semaine, et $rest autre${rest > 1 ? 's' : ''} produit${rest > 1 ? 's' : ''} récurrent${rest > 1 ? 's' : ''}'
                  : '« ${top.productName} » perdu ${top.occurrences} fois cette semaine',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Filters: search, motif, date ----

class _FiltersSection extends ConsumerWidget {
  const _FiltersSection();

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: ref.read(returnsCustomRangeProvider),
    );
    if (range == null) return;
    ref.read(returnsCustomRangeProvider.notifier).state = range;
    ref.read(returnsDateFilterProvider.notifier).state =
        ReturnsDateFilter.personnalise;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motifFilter = ref.watch(returnsMotifFilterProvider);
    final dateFilter = ref.watch(returnsDateFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) =>
                ref.read(returnsSearchProvider.notifier).state = v,
            decoration: const InputDecoration(
              hintText: 'Rechercher un produit…',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: motifFilter == null,
                  onSelected: (_) =>
                      ref.read(returnsMotifFilterProvider.notifier).state =
                          null,
                ),
                const SizedBox(width: 8),
                for (final m in RetourMotif.values) ...[
                  ChoiceChip(
                    avatar: Icon(
                      m.icon,
                      size: 16,
                      color: motifFilter == m ? Colors.white : m.color,
                    ),
                    label: Text(m.label),
                    selected: motifFilter == m,
                    selectedColor: m.color,
                    labelStyle: TextStyle(
                      color: motifFilter == m ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) =>
                        ref.read(returnsMotifFilterProvider.notifier).state =
                            motifFilter == m ? null : m,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in ReturnsDateFilter.values) ...[
                  ChoiceChip(
                    label: Text(f.label),
                    selected: dateFilter == f,
                    onSelected: (_) {
                      if (f == ReturnsDateFilter.personnalise) {
                        _pickCustomRange(context, ref);
                      } else {
                        ref.read(returnsDateFilterProvider.notifier).state = f;
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Loss list tile ----

class _ReturnTile extends ConsumerWidget {
  final StockReturn stockReturn;
  const _ReturnTile({required this.stockReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = stockReturn.motif.color;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _ReturnDetailSheet(stockReturn: stockReturn),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.card,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stockReturn.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stockReturn.quantite.toStringAsFixed(stockReturn.venduAuPoids ? 3 : 0)} ${stockReturn.unite} · ${AppFormat.dt(stockReturn.prixAchatUnitaire)}/unité',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(_dateTimeFormat).format(stockReturn.date),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textFaint,
                    ),
                  ),
                  Text(
                    'par ${stockReturn.employeeName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textFaint,
                    ),
                  ),
                  if (stockReturn.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stockReturn.note!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stockReturn.motif.icon, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(
                          stockReturn.motif.label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${AppFormat.dt(stockReturn.perte)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                if (stockReturn.photoBytes != null) ...[
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.photo_outlined,
                    size: 16,
                    color: AppColors.textFaint,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Detail sheet ----

class _ReturnDetailSheet extends ConsumerStatefulWidget {
  final StockReturn stockReturn;
  const _ReturnDetailSheet({required this.stockReturn});

  @override
  ConsumerState<_ReturnDetailSheet> createState() => _ReturnDetailSheetState();
}

class _ReturnDetailSheetState extends ConsumerState<_ReturnDetailSheet> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette perte ?'),
        content: Text(
          'Le stock de « ${widget.stockReturn.productName} » sera recrédité de '
          '${widget.stockReturn.quantite.toStringAsFixed(widget.stockReturn.venduAuPoids ? 3 : 0)} ${widget.stockReturn.unite}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(stockServiceProvider).deleteReturn(widget.stockReturn);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Échec de la suppression : $e')));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.stockReturn;
    final canRecord = ref.watch(
      hasModuleProvider(EmployeeModule.stockProduits),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 12),
            Text(r.productName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: r.motif.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.motif.icon, size: 13, color: r.motif.color),
                    const SizedBox(width: 4),
                    Text(
                      r.motif.label,
                      style: TextStyle(
                        color: r.motif.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (r.photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.memory(
                  r.photoBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            _detailRow(
              'Quantité',
              '${r.quantite.toStringAsFixed(r.venduAuPoids ? 3 : 0)} ${r.unite}',
            ),
            _detailRow(
              'Prix d\'achat unitaire',
              AppFormat.dt(r.prixAchatUnitaire),
            ),
            _detailRow('Valeur perdue (coût)', AppFormat.dt(r.perte)),
            if (r.prixVenteUnitaire > 0)
              _detailRow(
                'Valeur vente perdue',
                AppFormat.dt(r.valeurVentePerdue),
              ),
            _detailRow('Date', DateFormat(_dateTimeFormat).format(r.date)),
            _detailRow('Employé', r.employeeName),
            if (r.note != null) _detailRow('Note', r.note!),
            if (canRecord) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleting ? null : _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: const Text('Supprimer cette perte'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    ),
  );
}

// ---- Analytics ----

class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byMotif = ref.watch(lossByMotifProvider);
    final topProducts = ref.watch(mostLostProductsProvider).take(3).toList();
    final totalCout = ref.watch(totalLossProvider);
    final totalVente = ref
        .watch(stockReturnsProvider)
        .fold(0.0, (sum, r) => sum + r.valeurVentePerdue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Répartition par motif',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 160,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 30,
                            sections: [
                              for (final entry in byMotif.entries)
                                PieChartSectionData(
                                  value: entry.value,
                                  color: entry.key.color,
                                  radius: 42,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in byMotif.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: entry.key.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${entry.key.label} · ${totalCout > 0 ? (entry.value / totalCout * 100).toStringAsFixed(0) : '0'}%',
                                        style: const TextStyle(fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (topProducts.isNotEmpty)
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Produits les plus perdus',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < topProducts.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            ['🥇', '🥈', '🥉'][i],
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topProducts[i].productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${AppFormat.dt(topProducts[i].totalPerte)} · ${topProducts[i].occurrences}x',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Coût perdu',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormat.dt(totalCout),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valeur vente perdue',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormat.dt(totalVente),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

// ---- "+" menu: choose a loss type before picking the product ----

class _AddMenuSheet extends StatelessWidget {
  const _AddMenuSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Type de perte',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 4),
          _menuTile(
            context,
            motif: RetourMotif.retourFournisseur,
            title: 'Retour fournisseur',
          ),
          _menuTile(
            context,
            motif: RetourMotif.peremption,
            title: 'Produit périmé',
          ),
          _menuTile(context, motif: RetourMotif.casse, title: 'Produit cassé'),
          _menuTile(context, motif: RetourMotif.autre, title: 'Autre perte'),
        ],
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required RetourMotif motif,
    required String title,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: motif.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(motif.icon, color: motif.color, size: 19),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        context.push('/returns/new', extra: AddReturnArgs(motif: motif));
      },
    );
  }
}
