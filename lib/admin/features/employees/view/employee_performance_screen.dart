import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/segmented_tabs.dart';

class _EmployeePerf {
  final Employee employee;
  final double ca;
  final int tickets;
  final double? panierMoyen;
  final double ecart;

  const _EmployeePerf({
    required this.employee,
    required this.ca,
    required this.tickets,
    required this.panierMoyen,
    required this.ecart,
  });
}

/// Ranks every active employee by revenue over a chosen window, alongside
/// their basket size and cumulative cash-drawer écart — the single place
/// an admin checks "who's actually driving sales, and whose till keeps
/// coming up short".
class EmployeePerformanceScreen extends ConsumerStatefulWidget {
  const EmployeePerformanceScreen({super.key});

  @override
  ConsumerState<EmployeePerformanceScreen> createState() =>
      _EmployeePerformanceScreenState();
}

class _EmployeePerformanceScreenState
    extends ConsumerState<EmployeePerformanceScreen> {
  int _period = 0; // 0 aujourd'hui, 1 7j, 2 30j, 3 ce mois

  bool _withinPeriod(DateTime date) {
    final now = DateTime.now();
    switch (_period) {
      case 0:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case 1:
        return now.difference(date).inDays <= 7;
      case 2:
        return now.difference(date).inDays <= 30;
      default:
        return date.year == now.year && date.month == now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref
        .watch(employeesProvider)
        .where((e) => e.actif)
        .toList();
    final allSales = ref.watch(salesProvider);
    final allShifts = ref.watch(shiftsProvider);

    final perf = employees.map((e) {
      final sales = allSales
          .where((s) => s.employeeId == e.id && _withinPeriod(s.dateHeure))
          .toList();
      final ca = sales.fold<double>(0, (sum, s) => sum + s.total);
      final shifts = allShifts.where(
        (s) => s.employeeId == e.id && !s.enCours && _withinPeriod(s.clockIn),
      );
      var ecart = 0.0;
      for (final s in shifts) {
        ecart += ref.watch(cashDiscrepancyForShiftProvider(s)) ?? 0;
      }
      return _EmployeePerf(
        employee: e,
        ca: ca,
        tickets: sales.length,
        panierMoyen: sales.isEmpty ? null : ca / sales.length,
        ecart: ecart,
      );
    }).toList()..sort((a, b) => b.ca.compareTo(a.ca));

    return Scaffold(
      appBar: AppBar(title: const Text('Performance des employés')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedTabs(
            labels: const ['Aujourd\'hui', '7 jours', '30 jours', 'Ce mois'],
            selectedIndex: _period,
            onChanged: (i) => setState(() => _period = i),
          ),
          const SizedBox(height: 18),
          if (perf.isEmpty)
            const EmptyState(
              icon: Icons.badge_outlined,
              title: 'Aucun employé actif',
              message: 'Ajoutez des employés pour suivre\nleurs performances.',
            )
          else
            for (var i = 0; i < perf.length; i++)
              _PerfTile(rank: i, perf: perf[i]),
        ],
      ),
    );
  }
}

class _PerfTile extends StatelessWidget {
  final int rank;
  final _EmployeePerf perf;
  const _PerfTile({required this.rank, required this.perf});

  @override
  Widget build(BuildContext context) {
    final hasEcart = perf.ecart.abs() > 0.001;
    return PressScale(
      onTap: () => context.push('/employees/detail', extra: perf.employee),
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
                      color: rank == 0
                          ? AppColors.goldDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    perf.employee.nom,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  AppFormat.dtShort(perf.ca),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${perf.tickets} ticket${perf.tickets > 1 ? 's' : ''} · panier ${perf.panierMoyen != null ? AppFormat.dtShort(perf.panierMoyen!) : '—'}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  hasEcart
                      ? 'Écart ${perf.ecart >= 0 ? '+' : ''}${AppFormat.dtShort(perf.ecart)}'
                      : '🟢 Écart 0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: hasEcart ? AppColors.danger : AppColors.success,
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
