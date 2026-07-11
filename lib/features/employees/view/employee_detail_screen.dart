import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/section_header.dart';
import 'package:sou9ix/core/widgets/segmented_tabs.dart';
import 'package:sou9ix/core/widgets/stat_card.dart';

/// Per-employee activity: revenue/tickets attributed to them over a
/// period, how many distinct customers they served, and their shift
/// (attendance) history with computed worked duration.
class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  int _period = 1; // 0 jour, 1 semaine, 2 mois

  bool _withinPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case 0:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case 2:
        return now.difference(date).inDays <= 30;
      default:
        return now.difference(date).inDays <= 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    final allSales = ref.watch(employeeSalesProvider(employee.id));
    final sales = allSales.where((s) => _withinPeriod(s.dateHeure)).toList();
    final revenue = sales.fold<double>(0, (sum, s) => sum + s.total);
    final distinctClients = sales
        .where((s) => s.clientId != null)
        .map((s) => s.clientId)
        .toSet()
        .length;
    final panierMoyen = sales.isEmpty ? null : revenue / sales.length;
    final articlesParTicket = sales.isEmpty
        ? null
        : sales.fold<int>(0, (sum, s) => sum + s.lignes.length) / sales.length;
    final especes = sales
        .where((s) => s.modePaiement == ModePaiement.especes)
        .fold<double>(0, (sum, s) => sum + s.total);
    final carte = sales
        .where((s) => s.modePaiement == ModePaiement.carte)
        .fold<double>(0, (sum, s) => sum + s.total);
    final credit = sales
        .where((s) => s.modePaiement == ModePaiement.credit)
        .fold<double>(0, (sum, s) => sum + s.total);

    final shifts = ref.watch(shiftsForEmployeeProvider(employee.id));
    final shiftsInPeriod = shifts
        .where((s) => _withinPeriod(s.clockIn))
        .toList();
    final closedShifts = shiftsInPeriod.where((s) => !s.enCours).toList();
    var ecartsCount = 0;
    var ecartTotal = 0.0;
    for (final s in closedShifts) {
      final ecart = ref.watch(cashDiscrepancyForShiftProvider(s)) ?? 0;
      if (ecart.abs() > 0.001) ecartsCount++;
      ecartTotal += ecart;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(employee.nom),
        actions: [
          IconButton(
            onPressed: () => context.push('/employees/edit', extra: employee),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(AppColors.teal),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    employee.initiales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.poste,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        employee.telephone,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SegmentedTabs(
            labels: const ['Jour', 'Semaine', 'Mois'],
            selectedIndex: _period,
            onChanged: (i) => setState(() => _period = i),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Chiffre d\'affaires',
                  value: AppFormat.dt(revenue),
                  icon: Icons.payments_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Tickets',
                  value: '${sales.length}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Panier moyen',
                  value: panierMoyen != null
                      ? AppFormat.dtShort(panierMoyen)
                      : '—',
                  icon: Icons.shopping_basket_outlined,
                  color: AppColors.goldDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Articles / ticket',
                  value: articlesParTicket != null
                      ? articlesParTicket.toStringAsFixed(1)
                      : '—',
                  icon: Icons.category_outlined,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'Clients servis (distincts)',
            value: '$distinctClients',
            icon: Icons.people_alt_rounded,
            color: AppColors.goldDark,
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Paiements encaissés'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _paymentRow(context, 'Espèces', especes),
                _paymentRow(context, 'Carte', carte),
                _paymentRow(context, 'Crédit', credit, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Sessions de caisse'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Sessions clôturées',
                  value: '${closedShifts.length}',
                  icon: Icons.point_of_sale_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Écarts de caisse',
                  value: '$ecartsCount',
                  icon: Icons.warning_amber_rounded,
                  color: ecartsCount > 0
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StatCard(
            label: 'Écart total',
            value: '${ecartTotal >= 0 ? '+' : ''}${AppFormat.dt(ecartTotal)}',
            icon: Icons.balance_rounded,
            color: ecartTotal.abs() < 0.001
                ? AppColors.success
                : AppColors.danger,
          ),
          const SizedBox(height: 26),
          const SectionHeader(title: 'Historique de présence'),
          const SizedBox(height: 14),
          if (shifts.isEmpty)
            const EmptyState(
              icon: Icons.schedule_rounded,
              title: 'Aucun pointage',
              message: 'Les entrées/sorties de cet employé\napparaîtront ici.',
            )
          else
            ...shifts.map((s) => _ShiftTile(shift: s)),
        ],
      ),
    );
  }

  Widget _paymentRow(
    BuildContext context,
    String label,
    double value, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            AppFormat.dtShort(value),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class _ShiftTile extends ConsumerWidget {
  final Shift shift;
  const _ShiftTile({required this.shift});

  String _formatDuree(Duration d) =>
      '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ecart = shift.enCours
        ? null
        : ref.watch(cashDiscrepancyForShiftProvider(shift));

    return InkWell(
      onTap: shift.enCours
          ? null
          : () => context.push('/caisses/detail', extra: shift),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (shift.enCours
                                ? AppColors.teal
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: shift.enCours
                        ? AppColors.teal
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(shift.clockIn),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${DateFormat('HH:mm').format(shift.clockIn)} → ${shift.clockOut != null ? DateFormat('HH:mm').format(shift.clockOut!) : 'en cours'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDuree(shift.duree),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (ecart != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (ecart.abs() < 0.001
                              ? AppColors.success
                              : AppColors.danger)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  ecart.abs() < 0.001
                      ? '🟢 Caisse équilibrée'
                      : '${ecart >= 0 ? '↑' : '↓'} Écart ${AppFormat.dtShort(ecart.abs())}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ecart.abs() < 0.001
                        ? AppColors.success
                        : AppColors.danger,
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
