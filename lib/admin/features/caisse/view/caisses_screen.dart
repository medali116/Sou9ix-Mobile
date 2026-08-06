import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/caisse/view/caisse_adjustment_sheet.dart';
import 'package:sou9ix/shared/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/shift.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';

bool _isToday(DateTime d) {
  final now = DateTime.now();
  return d.year == now.year && d.month == now.month && d.day == now.day;
}

/// Admin overview: today's global cash reconciliation, plus every
/// employee's session (open or closed) so an absent admin can see who
/// worked, what they sold, and whether their till matched.
class CaissesScreen extends ConsumerWidget {
  const CaissesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts =
        ref
            .watch(shiftsProvider)
            .where((s) => _isToday(s.clockIn) || s.enCours)
            .toList()
          ..sort((a, b) => b.clockIn.compareTo(a.clockIn));
    final employees = {for (final e in ref.watch(employeesProvider)) e.id: e};
    final todaySales = ref
        .watch(salesProvider)
        .where((s) => _isToday(s.dateHeure))
        .toList();

    final especes = todaySales
        .where((s) => s.modePaiement == ModePaiement.especes)
        .fold<double>(0, (sum, s) => sum + s.total);
    final carte = todaySales
        .where((s) => s.modePaiement == ModePaiement.carte)
        .fold<double>(0, (sum, s) => sum + s.total);
    final credit = todaySales
        .where((s) => s.modePaiement == ModePaiement.credit)
        .fold<double>(0, (sum, s) => sum + s.total);

    final summary = ref.watch(todayCaisseSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisses & clôtures'),
        actions: [
          IconButton(
            onPressed: () => showCaisseAdjustmentSheet(context, ref),
            icon: const Icon(Icons.swap_vert_rounded),
            tooltip: 'Retrait / Ajout de caisse',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RÉSUMÉ DU MAGASIN · AUJOURD\'HUI',
                  style: TextStyle(
                    color: AppColors.tealLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppFormat.dt(summary.caDuJour),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Chiffre d\'affaires total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _heroStat('Espèces', especes, AppColors.tealLight),
                    ),
                    Expanded(child: _heroStat('Carte', carte, Colors.white)),
                    Expanded(child: _heroStat('Crédit', credit, Colors.white)),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SITUATION DES CAISSES',
                  style: TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    if (summary.sessionsOuvertes > 0)
                      Text(
                        '🔵 ${summary.sessionsOuvertes} ouverte${summary.sessionsOuvertes > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    if (summary.sessionsCloturees > 0)
                      Text(
                        '🟢 ${summary.sessionsCloturees} clôturée${summary.sessionsCloturees > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    if (summary.sessionsAvecEcart > 0)
                      Text(
                        '🟠 ${summary.sessionsAvecEcart} avec écart',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    if (summary.sessionsOuvertes == 0 &&
                        summary.sessionsCloturees == 0)
                      const Text(
                        'Aucune caisse ouverte aujourd\'hui',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _dashStat(
                        'Cash actuellement attendu',
                        summary.sessionsOuvertes > 0
                            ? AppFormat.dt(summary.cashAttenduOuvertes)
                            : '—',
                      ),
                    ),
                    Expanded(
                      child: _dashStat(
                        'Écarts clôturés aujourd\'hui',
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
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 22),
          Text(
            'Sessions des employés',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (shifts.isEmpty)
            const EmptyState(
              icon: Icons.badge_outlined,
              title: 'Aucune session aujourd\'hui',
              message: 'Les caisses ouvertes et clôturées\napparaîtront ici.',
            )
          else
            for (var i = 0; i < shifts.length; i++)
              _SessionTile(
                shift: shifts[i],
                employee: employees[shifts[i].employeeId],
              ).animate().fadeIn(duration: 220.ms, delay: (18 * i).ms),
        ],
      ),
    );
  }

  Widget _heroStat(
    String label,
    double value,
    Color color, {
    bool signed = false,
  }) {
    final text = signed && value >= 0
        ? '+${AppFormat.dt(value)}'
        : AppFormat.dt(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _dashStat(String label, String value, {Color? color}) {
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
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends ConsumerWidget {
  final Shift shift;
  final Employee? employee;
  const _SessionTile({required this.shift, required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref
        .watch(salesProvider)
        .where(
          (s) =>
              s.employeeId == shift.employeeId &&
              !s.dateHeure.isBefore(shift.clockIn) &&
              !s.dateHeure.isAfter(shift.clockOut ?? DateTime.now()),
        )
        .toList();
    final ca = sales.fold<double>(0, (sum, s) => sum + s.total);
    final ecart = ref.watch(cashDiscrepancyForShiftProvider(shift));
    final attendu = ref.watch(expectedCashForShiftProvider(shift));

    final (statusIcon, statusColor) = shift.enCours
        ? ('🟡', AppColors.info)
        : ecart == null || ecart.abs() < 0.001
        ? ('🟢', AppColors.success)
        : ecart.abs() > 5
        ? ('🔴', AppColors.danger)
        : ('🟠', AppColors.warning);

    return PressScale(
      onTap: () => context.push('/caisses/detail', extra: shift),
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
                Text(statusIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    employee?.nom ?? 'Employé',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${DateFormat('HH:mm').format(shift.clockIn)} → ${shift.clockOut != null ? DateFormat('HH:mm').format(shift.clockOut!) : 'en cours'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${sales.length} ticket${sales.length > 1 ? 's' : ''} · CA ${AppFormat.dtShort(ca)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (shift.enCours)
                  const Text(
                    '● Caisse ouverte',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  )
                else
                  Text(
                    'Écart ${ecart! >= 0 ? '+' : ''}${AppFormat.dtShort(ecart)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
              ],
            ),
            if (!shift.enCours) ...[
              const SizedBox(height: 2),
              Text(
                'Attendu ${AppFormat.dtShort(attendu)} · Compté ${AppFormat.dtShort(shift.montantCompte!)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
