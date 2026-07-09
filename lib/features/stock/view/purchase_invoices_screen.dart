import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/service/purchase_export_service.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/segmented_tabs.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';
import 'package:sou9ix/features/stock/view/invoice_detail_sheet.dart';
import 'package:sou9ix/features/stock/view/record_payment_sheet.dart';

enum _DateFilter { toutes, aujourdhui, semaine, mois, personnalise }

extension on _DateFilter {
  String get label => switch (this) {
    _DateFilter.toutes => 'Toutes dates',
    _DateFilter.aujourdhui => 'Aujourd\'hui',
    _DateFilter.semaine => 'Cette semaine',
    _DateFilter.mois => 'Ce mois',
    _DateFilter.personnalise => 'Personnalisé',
  };
}

enum _Sort { recent, ancien, montant, reste }

extension on _Sort {
  String get label => switch (this) {
    _Sort.recent => 'Plus récent',
    _Sort.ancien => 'Plus ancien',
    _Sort.montant => 'Montant',
    _Sort.reste => 'Reste à payer',
  };
  IconData get icon => switch (this) {
    _Sort.recent => Icons.arrow_downward_rounded,
    _Sort.ancien => Icons.arrow_upward_rounded,
    _Sort.montant => Icons.payments_rounded,
    _Sort.reste => Icons.warning_amber_rounded,
  };
}

/// Supplier-side mirror of the client karné: every stock receipt logged
/// from the Caisse screen lands here, with its invoice photo, product
/// lines, and how much of it is still owed.
class PurchaseInvoicesScreen extends ConsumerStatefulWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  ConsumerState<PurchaseInvoicesScreen> createState() =>
      _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState
    extends ConsumerState<PurchaseInvoicesScreen> {
  bool _onlyUnsettled = false;
  String _query = '';
  _DateFilter _dateFilter = _DateFilter.toutes;
  DateTimeRange? _customRange;
  _Sort _sort = _Sort.recent;

  bool _matchesDate(PurchaseInvoice i) {
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    switch (_dateFilter) {
      case _DateFilter.toutes:
        return true;
      case _DateFilter.aujourdhui:
        return sameDay(i.date, now);
      case _DateFilter.semaine:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        return !i.date.isBefore(startOfWeek);
      case _DateFilter.mois:
        return i.date.year == now.year && i.date.month == now.month;
      case _DateFilter.personnalise:
        if (_customRange == null) return true;
        final d = DateTime(i.date.year, i.date.month, i.date.day);
        return !d.isBefore(_customRange!.start) &&
            !d.isAfter(_customRange!.end);
    }
  }

  Future<void> _selectDateFilter(_DateFilter f) async {
    if (f == _DateFilter.personnalise) {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _customRange,
      );
      if (range == null) return;
      setState(() {
        _dateFilter = f;
        _customRange = range;
      });
    } else {
      setState(() => _dateFilter = f);
    }
  }

  Future<void> _openSortSheet() async {
    final result = await showModalBottomSheet<_Sort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                  'Trier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final s in _Sort.values)
              ListTile(
                leading: Icon(
                  s.icon,
                  color: _sort == s ? AppColors.teal : AppColors.textSecondary,
                ),
                title: Text(
                  s.label,
                  style: TextStyle(
                    fontWeight: _sort == s ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                trailing: _sort == s
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _sort = result);
  }

  Future<void> _openExportSheet(List<PurchaseInvoice> invoices) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
                  'Exporter',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
              ),
              title: const Text('Exporter en PDF'),
              subtitle: Text(
                '${invoices.length} facture${invoices.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                purchaseExportService.exportPdf(invoices);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: AppColors.success,
              ),
              title: const Text('Exporter en Excel (CSV)'),
              subtitle: Text(
                '${invoices.length} facture${invoices.length > 1 ? 's' : ''} — vue actuelle',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                purchaseExportService.exportCsv(invoices);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(purchaseInvoicesProvider);
    final unsettled = ref.watch(unsettledInvoicesProvider);
    final totalUnpaid = ref.watch(totalUnpaidPurchasesProvider);
    final supplierCount = ref.watch(suppliersProvider).length;

    var invoices = _onlyUnsettled ? unsettled : allInvoices;
    invoices = invoices.where(_matchesDate).toList();
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      invoices = invoices
          .where(
            (i) =>
                (i.fournisseurNom ?? '').toLowerCase().contains(q) ||
                i.reference.toLowerCase().contains(q),
          )
          .toList();
    }
    invoices = [...invoices];
    switch (_sort) {
      case _Sort.recent:
        invoices.sort((a, b) => b.date.compareTo(a.date));
      case _Sort.ancien:
        invoices.sort((a, b) => a.date.compareTo(b.date));
      case _Sort.montant:
        invoices.sort((a, b) => b.montantTotal.compareTo(a.montantTotal));
      case _Sort.reste:
        invoices.sort((a, b) => b.montantRestant.compareTo(a.montantRestant));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats fournisseurs'),
        actions: [
          IconButton(
            onPressed: () => _openExportSheet(invoices),
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Exporter',
          ),
          IconButton(
            onPressed: () => context.push('/suppliers'),
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Fournisseurs',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Total dû',
                            value: AppFormat.dtShort(totalUnpaid),
                            color: totalUnpaid > 0
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.local_shipping_outlined,
                            label: 'Fournisseurs',
                            value: '$supplierCount',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStat(
                            icon: Icons.receipt_long_outlined,
                            label: 'Factures ouvertes',
                            value: '${unsettled.length}',
                            color: unsettled.isNotEmpty
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ],
                    )
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.05, end: 0),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un fournisseur ou une facture...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedTabs(
                  labels: const ['Toutes', 'Non soldées'],
                  selectedIndex: _onlyUnsettled ? 1 : 0,
                  onChanged: (i) => setState(() => _onlyUnsettled = i == 1),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final f in _DateFilter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    f == _DateFilter.personnalise &&
                                            _customRange != null
                                        ? '${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}'
                                        : f.label,
                                  ),
                                  selected: _dateFilter == f,
                                  onSelected: (_) => _selectDateFilter(f),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PressScale(
                      onTap: _openSortSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.swap_vert_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (invoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Aucun achat',
                      message: 'Aucun résultat pour ces filtres.',
                    ),
                  )
                else
                  ...invoices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final invoice = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InvoiceTile(invoice: invoice).animate().fadeIn(
                        duration: 220.ms,
                        delay: (18 * index).ms,
                      ),
                    );
                  }),
              ],
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
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.teal,
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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

class _InvoiceTile extends ConsumerWidget {
  final PurchaseInvoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = invoice.montantTotal == 0
        ? 1.0
        : (invoice.montantPaye / invoice.montantTotal).clamp(0, 1).toDouble();
    final joursOuverte = DateTime.now().difference(invoice.date).inDays;
    final showLateBadge = !invoice.soldee && joursOuverte >= 15;
    final lateColor = joursOuverte >= 30 ? AppColors.danger : AppColors.warning;

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
                ? Image.memory(
                    invoice.photoBytes!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: AppColors.surfaceMuted,
                    child: const Icon(
                      Icons.receipt_outlined,
                      color: AppColors.textFaint,
                      size: 20,
                    ),
                  ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  invoice.fournisseurNom ?? 'Fournisseur non précisé',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                AppFormat.dtShort(invoice.montantTotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Facture #${invoice.reference} · ${DateFormat('dd/MM/yyyy').format(invoice.date)} · ${invoice.lignes.length} produit${invoice.lignes.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceMuted,
                          valueColor: AlwaysStoppedAnimation(
                            invoice.soldee
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: invoice.soldee
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.soldee
                      ? '${(ratio * 100).round()}% payé · Soldée'
                      : '${(ratio * 100).round()}% payé · Reste ${AppFormat.dtShort(invoice.montantRestant)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: invoice.soldee
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ),
                if (showLateBadge) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: lateColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Facture impayée depuis $joursOuverte jours',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: lateColor,
                        ),
                      ),
                    ],
                  ),
                ],
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
                      child: Text(
                        line.productName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: PressScale(
                onTap: () => showInvoiceDetailSheet(context, invoice),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text(
                    '📜 Historique des paiements',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
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
                      '💳 Payer le fournisseur',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
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
