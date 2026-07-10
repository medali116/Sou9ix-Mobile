import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../models/employee.dart';
import '../../models/shift.dart';
import '../../providers/sales_provider.dart';
import '../../providers/shifts_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/stat_card.dart';

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
    final shifts = ref.watch(shiftsForEmployeeProvider(employee.id));

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
          StatCard(
            label: 'Clients servis (distincts)',
            value: '$distinctClients',
            icon: Icons.people_alt_rounded,
            color: AppColors.goldDark,
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
}

class _ShiftTile extends StatelessWidget {
  final Shift shift;
  const _ShiftTile({required this.shift});

  String _formatDuree(Duration d) =>
      '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (shift.enCours ? AppColors.teal : AppColors.textSecondary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 18,
              color: shift.enCours ? AppColors.teal : AppColors.textSecondary,
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
    );
  }
}
