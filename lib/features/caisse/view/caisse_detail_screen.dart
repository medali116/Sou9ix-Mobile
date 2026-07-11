import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/view/caisse_adjustment_sheet.dart';
import 'package:sou9ix/features/caisse/view/close_cash_session_sheet.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/section_header.dart';

/// Full journal for one employee's cash session — every movement that
/// makes up "espèces attendues", plus the reconciliation outcome if the
/// session is closed.
class CaisseDetailScreen extends ConsumerWidget {
  final Shift shift;
  const CaisseDetailScreen({super.key, required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(employeesProvider);
    final matches = employees.where((e) => e.id == shift.employeeId);
    final Employee? employee = matches.isEmpty ? null : matches.first;
    final employeeName = employee?.nom ?? 'Employé';
    final movements = ref.watch(cashMovementsForShiftProvider(shift));
    final attendu = ref.watch(expectedCashForShiftProvider(shift));
    final ecart = ref.watch(cashDiscrepancyForShiftProvider(shift));

    double sumOf(CashMovementType t) => movements
        .where((m) => m.type == t)
        .fold<double>(0, (sum, m) => sum + m.montant);
    final ajustements = sumOf(CashMovementType.ajustement);

    return Scaffold(
      appBar: AppBar(
        title: Text(employeeName),
        actions: [
          if (shift.enCours && employee != null) ...[
            IconButton(
              onPressed: () =>
                  showCaisseAdjustmentSheet(context, ref, preselected: shift),
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Mouvement de caisse',
            ),
            IconButton(
              onPressed: () =>
                  showCloseCashSessionSheet(context, shift, employee),
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Clôturer la caisse',
            ),
          ],
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
                Row(
                  children: [
                    Expanded(
                      child: _label(
                        'Début',
                        DateFormat('dd/MM HH:mm').format(shift.clockIn),
                      ),
                    ),
                    Expanded(
                      child: _label(
                        'Fin',
                        shift.clockOut != null
                            ? DateFormat('dd/MM HH:mm').format(shift.clockOut!)
                            : 'En cours',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _label(
                        'Fond initial',
                        AppFormat.dt(shift.fondInitial),
                      ),
                    ),
                    Expanded(
                      child: _label('Espèces attendues', AppFormat.dt(attendu)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Origine du fond : ${shift.fondSource}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
                if (shift.montantCompte != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _label(
                          'Espèces comptées',
                          AppFormat.dt(shift.montantCompte!),
                        ),
                      ),
                      Expanded(
                        child: _label(
                          'Écart',
                          '${ecart! >= 0 ? '+' : ''}${AppFormat.dt(ecart)}',
                          color: ecart.abs() < 0.001
                              ? AppColors.tealLight
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SectionHeader(title: 'Calcul des espèces attendues'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _breakdownRow('Fond initial', shift.fondInitial),
                _breakdownRow('Ventes espèces', sumOf(CashMovementType.vente)),
                _breakdownRow(
                  'Encaissements clients',
                  sumOf(CashMovementType.encaissement),
                ),
                _breakdownRow('Dépenses', sumOf(CashMovementType.depense)),
                if (sumOf(CashMovementType.achat) != 0)
                  _breakdownRow(
                    'Paiements fournisseurs',
                    sumOf(CashMovementType.achat),
                  ),
                if (ajustements != 0)
                  _breakdownRow('Ajouts / retraits', ajustements),
                _breakdownRow(
                  'Espèces attendues',
                  attendu,
                  bold: true,
                  isLast: true,
                ),
              ],
            ),
          ),
          if (shift.ecartMotif != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motif : ${shift.ecartMotif}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (shift.ecartCommentaire != null)
                          Text(
                            shift.ecartCommentaire!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionHeader(title: 'Journal des mouvements'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [for (final m in movements) _MovementTile(movement: m)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    double value, {
    bool bold = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            '${value >= 0 && bold
                ? ''
                : value >= 0
                ? '+'
                : ''}${AppFormat.dt(value)}',
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String label, String value, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  final CashMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final up = movement.montant >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: movement.type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(
              movement.type.icon,
              size: 16,
              color: movement.type.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  DateFormat('HH:mm').format(movement.date),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '${up ? '+' : ''}${AppFormat.dt(movement.montant)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: up ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
