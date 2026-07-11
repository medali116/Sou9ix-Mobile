import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/view/close_cash_session_sheet.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

/// The cashier's own mid-shift view of their session — deliberately never
/// shows "espèces attendues" here (only at clôture, after they've counted
/// blind) so they can't just copy the number the app expects.
void showMaCaisseSheet(BuildContext context, Shift shift, Employee employee) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final movements = ref.watch(cashMovementsForShiftProvider(shift));
        double sumOf(CashMovementType t) => movements
            .where((m) => m.type == t)
            .fold<double>(0, (sum, m) => sum + m.montant);
        final sorties = movements
            .where(
              (m) =>
                  m.type != CashMovementType.fond &&
                  m.type != CashMovementType.vente &&
                  m.type != CashMovementType.encaissement &&
                  m.montant < 0,
            )
            .fold<double>(0, (sum, m) => sum + m.montant);

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 8),
              Text(
                'Ma caisse',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              Text(
                'Session ouverte depuis ${DateFormat('HH:mm').format(shift.clockIn)}',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    _row('Fond initial', shift.fondInitial),
                    _row('Ventes espèces', sumOf(CashMovementType.vente)),
                    _row('Encaissements', sumOf(CashMovementType.encaissement)),
                    _row('Sorties caisse', sorties),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Statut : Ouverte',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showCloseCashSessionSheet(context, shift, employee);
                  },
                  child: const Text('Clôturer ma caisse'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _row(String label, double value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${value >= 0 ? '+' : ''}${AppFormat.dt(value)}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    ),
  );
}
