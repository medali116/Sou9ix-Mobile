import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/sales/service/sale_service.dart';
import 'package:sou9ix/features/sales/service/ticket_pdf_service.dart';
import 'package:sou9ix/features/settings/viewmodel/company_settings_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/date_range_picker_sheet.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/pos/view/barcode_capture_screen.dart';

enum _Period { tous, today, yesterday, week, month, custom }

extension on _Period {
  String get label => switch (this) {
    _Period.tous => 'Toutes les dates',
    _Period.today => 'Aujourd\'hui',
    _Period.yesterday => 'Hier',
    _Period.week => 'Cette semaine',
    _Period.month => 'Ce mois',
    _Period.custom => 'Personnalisé',
  };

  IconData get icon => switch (this) {
    _Period.tous => Icons.all_inclusive_rounded,
    _Period.today => Icons.today_rounded,
    _Period.yesterday => Icons.history_rounded,
    _Period.week => Icons.view_week_rounded,
    _Period.month => Icons.calendar_month_rounded,
    _Period.custom => Icons.edit_calendar_rounded,
  };
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _employeeFilter;
  _Period _period = _Period.tous;
  DateTimeRange? _customRange;
  ModePaiement? _modeFilter;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Scans the QR code printed/shown on a ticket (it encodes the sale's
  /// full `id`) and searches by its last 6 characters — the same short
  /// reference the UI already shows as "Ticket #XXXXXX".
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      final ticketRef = code.length > 6
          ? code.substring(code.length - 6)
          : code;
      setState(() {
        _searchCtrl.text = ticketRef;
        _query = ticketRef;
      });
    }
  }

  /// Resolves the filter button's label against the *full* roster (not just
  /// active employees) so it still shows a name that was selected before
  /// that employee was archived.
  String _employeeFilterLabel() {
    if (_employeeFilter == null) return 'Tous les caissiers';
    final matches = ref
        .read(employeesProvider)
        .where((e) => e.id == _employeeFilter);
    return matches.isEmpty ? 'Tous les caissiers' : matches.first.nom;
  }

  String _dateFilterLabel() {
    if (_period == _Period.custom && _customRange != null) {
      final fmt = DateFormat('dd/MM');
      return '${fmt.format(_customRange!.start)} - ${fmt.format(_customRange!.end)}';
    }
    return _period.label;
  }

  String _modeFilterLabel() =>
      _modeFilter == null ? 'Tous les modes' : _modeFilter!.label;

  /// Shared row style for every filter bottom sheet: the active choice gets
  /// a light green background, a green border and a trailing checkmark —
  /// not just colored text, which is easy to miss at a glance.
  ///
  /// [icon] covers the common case; pass [iconBuilder] instead when the row
  /// needs a composite icon (e.g. "Personnalisé"'s calendar+pencil) that
  /// still needs to follow the same selected/unselected color.
  Widget _filterListTile({
    required bool selected,
    IconData? icon,
    Widget Function(Color color)? iconBuilder,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppColors.success : AppColors.textFaint;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? AppColors.success.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? AppColors.success.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              leading: iconBuilder != null
                  ? iconBuilder(color)
                  : Icon(icon, color: color),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? AppColors.success : AppColors.textPrimary,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded, color: AppColors.success)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Calendar icon with a small pencil badge, so "Personnalisé" reads at a
  /// glance as "pick a date range" rather than a plain preset.
  Widget _calendarEditIcon(Color color) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.calendar_month_rounded, color: color, size: 22),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_rounded, size: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmployeeFilterSheet(List<Employee> activeEmployees) async {
    const allSentinel = '__all__';
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                  'Filtrer par caissier',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterListTile(
                      selected: _employeeFilter == null,
                      icon: Icons.people_alt_rounded,
                      label: 'Tous les caissiers',
                      onTap: () => Navigator.pop(context, allSentinel),
                    ),
                    for (final e in activeEmployees)
                      _filterListTile(
                        selected: _employeeFilter == e.id,
                        icon: Icons.person_rounded,
                        label: e.nom,
                        onTap: () => Navigator.pop(context, e.id),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _employeeFilter = result == allSentinel ? null : result);
    }
  }

  Future<void> _openDateFilterSheet() async {
    const presets = [
      _Period.tous,
      _Period.today,
      _Period.yesterday,
      _Period.week,
      _Period.month,
    ];
    final result = await showModalBottomSheet<_Period>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                  'Filtrer par date',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in presets)
                      _filterListTile(
                        selected: _period == p,
                        icon: p.icon,
                        label: p.label,
                        onTap: () => Navigator.pop(context, p),
                      ),
                    _filterListTile(
                      selected: _period == _Period.custom,
                      iconBuilder: _calendarEditIcon,
                      label: _period == _Period.custom && _customRange != null
                          ? _dateFilterLabel()
                          : 'Personnalisé',
                      onTap: () => Navigator.pop(context, _Period.custom),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (result == _Period.custom) {
      if (!mounted) return;
      final range = await showAppDateRangeSheet(
        context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialRange:
            _customRange ??
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
      );
      // A cancelled range picker leaves the previous filter untouched instead
      // of silently switching to an unset "Personnalisé" with no bounds.
      if (range != null) {
        setState(() {
          _period = _Period.custom;
          _customRange = range;
        });
      }
    } else {
      setState(() => _period = result);
    }
  }

  Future<void> _openModeFilterSheet() async {
    const allSentinel = '__all__';
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
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
                  'Filtrer par mode de paiement',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterListTile(
                      selected: _modeFilter == null,
                      icon: Icons.payments_outlined,
                      label: 'Tous les modes',
                      onTap: () => Navigator.pop(context, allSentinel),
                    ),
                    for (final m in ModePaiement.values)
                      _filterListTile(
                        selected: _modeFilter == m,
                        icon: m.icon,
                        label: m.label,
                        onTap: () => Navigator.pop(context, m.name),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _modeFilter = result == allSentinel
            ? null
            : ModePaiement.values.firstWhere((m) => m.name == result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeEmployees = ref.watch(activeEmployeesProvider);
    final allSales = ref
        .watch(salesProvider)
        .where((s) => s.lignes.isNotEmpty)
        .toList();
    var sales = allSales;
    if (_employeeFilter != null) {
      sales = sales.where((s) => s.employeeId == _employeeFilter).toList();
    }

    final now = DateTime.now();
    switch (_period) {
      case _Period.tous:
        break;
      case _Period.today:
        sales = sales.where((s) => _sameDay(s.dateHeure, now)).toList();
        break;
      case _Period.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        sales = sales.where((s) => _sameDay(s.dateHeure, yesterday)).toList();
        break;
      case _Period.week:
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        sales = sales.where((s) => !s.dateHeure.isBefore(startOfWeek)).toList();
        break;
      case _Period.month:
        sales = sales
            .where(
              (s) =>
                  s.dateHeure.year == now.year &&
                  s.dateHeure.month == now.month,
            )
            .toList();
        break;
      case _Period.custom:
        if (_customRange != null) {
          final start = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
          );
          final end = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
          );
          sales = sales
              .where(
                (s) =>
                    !s.dateHeure.isBefore(start) && !s.dateHeure.isAfter(end),
              )
              .toList();
        }
        break;
    }

    if (_modeFilter != null) {
      sales = sales.where((s) => s.modePaiement == _modeFilter).toList();
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      sales = sales.where((s) {
        final ticketId = s.id.substring(s.id.length - 6).toLowerCase();
        return ticketId.contains(q) ||
            s.lignes.any((l) => l.product.name.toLowerCase().contains(q));
      }).toList();
    }
    final todaySales = allSales
        .where((s) => _sameDay(s.dateHeure, now))
        .toList();
    final todayTotal = todaySales.fold<double>(0, (sum, s) => sum + s.total);
    final todayCreditTotal = todaySales
        .where((s) => s.modePaiement == ModePaiement.credit)
        .fold<double>(0, (sum, s) => sum + s.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des ventes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: _HistoryStatCard(
                    icon: Icons.payments_rounded,
                    color: AppColors.teal,
                    label: 'Aujourd\'hui',
                    value: AppFormat.dtShort(todayTotal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HistoryStatCard(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.warning,
                    label: 'Crédit',
                    value: AppFormat.dtShort(todayCreditTotal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HistoryStatCard(
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                    label: 'Tickets',
                    value: '${todaySales.length}',
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un ticket ou un produit…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  onPressed: _scanBarcode,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.teal,
                  ),
                  tooltip: 'Scanner le QR du ticket',
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                if (activeEmployees.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      leading: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.teal.withValues(alpha: 0.14),
                        foregroundColor: AppColors.teal,
                        child: const Icon(Icons.person_rounded, size: 13),
                      ),
                      label: _employeeFilterLabel(),
                      active: _employeeFilter != null,
                      onTap: () => _openEmployeeFilterSheet(activeEmployees),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterPill(
                    leading: Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _period == _Period.tous
                          ? AppColors.textSecondary
                          : AppColors.teal,
                    ),
                    label: _dateFilterLabel(),
                    active: _period != _Period.tous,
                    onTap: _openDateFilterSheet,
                  ),
                ),
                _FilterPill(
                  leading: Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: _modeFilter == null
                        ? AppColors.textSecondary
                        : AppColors.teal,
                  ),
                  label: _modeFilterLabel(),
                  active: _modeFilter != null,
                  onTap: _openModeFilterSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: 260.ms,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              // Keyed on the *filter* state only (not the search query) so
              // picking a caissier/date/mode replays the fade+slide, while
              // typing in the search box just swaps items instantly.
              child: KeyedSubtree(
                key: ValueKey(
                  '$_employeeFilter|$_period|${_customRange?.start}|${_customRange?.end}|$_modeFilter',
                ),
                child: sales.isEmpty
                    ? EmptyState(
                        icon: _query.isEmpty
                            ? Icons.receipt_long_outlined
                            : Icons.search_off_rounded,
                        title: _query.isEmpty
                            ? 'Aucune vente'
                            : 'Aucun résultat',
                        message: _query.isEmpty
                            ? 'Les ventes réalisées à la caisse\napparaîtront ici.'
                            : 'Aucun ticket ou produit ne correspond\nà cette recherche.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        itemCount: sales.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final sale = sales[index];
                          return _SaleTile(sale: sale).animate().fadeIn(
                            duration: 220.ms,
                            delay: (18 * index).ms,
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends ConsumerWidget {
  final Sale sale;
  const _SaleTile({required this.sale});

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
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
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Voir le ticket'),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Imprimer'),
              onTap: () => Navigator.pop(context, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            if (sale.lignes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const Text('Retourner un produit'),
                onTap: () => Navigator.pop(context, 'return'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Annuler la vente',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'view') {
      context.push('/receipt', extra: sale);
    } else if (action == 'print') {
      final settings = ref.read(companySettingsProvider);
      ticketPdfService.printOrShare(
        sale,
        nomTicket: settings.ticketName,
        logoBytes: settings.logoBytes,
      );
    } else if (action == 'edit') {
      context.push('/history/edit', extra: sale);
    } else if (action == 'return') {
      _startReturn(context, ref);
    } else if (action == 'cancel') {
      _confirmCancel(context, ref);
    }
  }

  Future<void> _startReturn(BuildContext context, WidgetRef ref) async {
    if (sale.lignes.length == 1) {
      context.push('/returns/new', extra: sale.lignes.first.product);
      return;
    }
    final product = await showModalBottomSheet<Product>(
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
                  'Quel produit retourner ?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final l in sale.lignes)
              ListTile(
                title: Text(l.product.name),
                subtitle: Text(
                  l.product.venduAuPoids
                      ? AppFormat.kg(l.quantite)
                      : '${l.quantite.toInt()} pcs',
                ),
                onTap: () => Navigator.pop(context, l.product),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (product != null && context.mounted) {
      context.push('/returns/new', extra: product);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final motifCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Annuler cette vente ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Le stock des articles vendus sera restitué et le crédit client (si applicable) annulé. Cette action est irréversible.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: motifCtrl,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  hintText: 'Ex. Erreur de saisie',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Retour'),
            ),
            TextButton(
              onPressed: motifCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Annuler la vente',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    ref
        .read(saleServiceProvider)
        .deleteSale(sale, motif: motifCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? employeeName;
    if (sale.employeeId != null) {
      final matches = ref
          .watch(employeesProvider)
          .where((e) => e.id == sale.employeeId);
      employeeName = matches.isEmpty ? 'Employé supprimé' : matches.first.nom;
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('/receipt', extra: sale),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  sale.modePaiement.icon,
                  color: AppColors.teal,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ticket #${sale.id.substring(sale.id.length - 6).toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${DateFormat('HH:mm').format(sale.dateHeure)} · ${sale.nombreArticles} article${sale.nombreArticles > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    _ModePaiementBadge(mode: sale.modePaiement),
                    if (employeeName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textFaint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                AppFormat.dt(sale.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => _openMenu(context, ref),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textFaint,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact dropdown-style trigger used for the caissier/date/mode filters —
/// shrink-wrapped so several can sit side by side instead of each claiming
/// a full-width row.
class _FilterPill extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.leading,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? AppColors.teal : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.teal : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: active ? AppColors.teal : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _HistoryStatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePaiementBadge extends StatelessWidget {
  final ModePaiement mode;
  const _ModePaiementBadge({required this.mode});

  Color get _color => switch (mode) {
    ModePaiement.especes => AppColors.success,
    ModePaiement.carte => AppColors.info,
    ModePaiement.credit => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            mode.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
