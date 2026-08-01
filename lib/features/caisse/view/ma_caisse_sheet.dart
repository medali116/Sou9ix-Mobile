import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/service/caisse_report_pdf_service.dart';
import 'package:sou9ix/features/caisse/view/caisse_adjustment_sheet.dart';
import 'package:sou9ix/features/caisse/view/close_cash_session_sheet.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

/// The cashier's own mid-shift view of their session — deliberately never
/// shows "espèces attendues" here (only at clôture, after they've counted
/// blind) so they can't just copy the number the app expects. The printed
/// report ("Imprimer le rapport") keeps the same restriction — see
/// [CaisseReportPdfService].
void showMaCaisseSheet(BuildContext context, Shift shift, Employee employee) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Consumer(
      builder: (sheetContext, ref, _) {
        final movements = ref.watch(cashMovementsForShiftProvider(shift));
        double sumOf(CashMovementType t) => movements
            .where((m) => m.type == t)
            .fold<double>(0, (sum, m) => sum + m.montant);
        final ajouts = movements
            .where(
              (m) => m.type == CashMovementType.ajustement && m.montant > 0,
            )
            .fold<double>(0, (sum, m) => sum + m.montant);
        final retraits = movements
            .where(
              (m) => m.type == CashMovementType.ajustement && m.montant < 0,
            )
            .fold<double>(0, (sum, m) => sum + m.montant);
        final fournisseurs = sumOf(CashMovementType.achat);

        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: SheetHandle()),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.point_of_sale_rounded,
                          color: AppColors.tealDark,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Ma caisse',
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.titleLarge,
                                ),
                                const SizedBox(width: 8),
                                const _StatusPillSmall(
                                  label: 'Ouverte',
                                  color: AppColors.success,
                                ),
                              ],
                            ),
                            Text(
                              'Session ouverte depuis ${DateFormat('HH:mm').format(shift.clockIn)}',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => caisseReportPdfService.printOrShare(
                        shift: shift,
                        employee: employee,
                        movements: movements,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Imprimer le rapport'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        _row(
                          Icons.account_balance_wallet_outlined,
                          'Fond initial',
                          shift.fondInitial,
                        ),
                        _row(
                          Icons.bar_chart_rounded,
                          'Ventes espèces',
                          sumOf(CashMovementType.vente),
                        ),
                        _row(
                          Icons.credit_card_rounded,
                          'Paiements crédit',
                          sumOf(CashMovementType.encaissement),
                        ),
                        _row(
                          Icons.call_made_rounded,
                          'Ajouts de fonds',
                          ajouts,
                        ),
                        _row(
                          Icons.call_received_rounded,
                          'Retraits caisse',
                          retraits,
                        ),
                        _row(
                          Icons.payments_outlined,
                          'Dépenses cash',
                          sumOf(CashMovementType.depense),
                        ),
                        if (fournisseurs != 0)
                          _row(
                            Icons.local_shipping_outlined,
                            'Paiements fournisseurs',
                            fournisseurs,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Statut : Ouverte',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.success,
                              ),
                            ),
                            Text(
                              'Tout fonctionne bien',
                              style: Theme.of(
                                sheetContext,
                              ).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.push(
                            '/caisses/session-detail',
                            extra: (shift, employee),
                          );
                        },
                        child: const Text('Voir le détail →'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.add_rounded,
                          label: 'Ajouter des fonds',
                          color: AppColors.teal,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            showCaisseAdjustmentSheet(
                              context,
                              ref,
                              preselected: shift,
                              startAsAjout: true,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.remove_rounded,
                          label: 'Retirer de la caisse',
                          color: AppColors.warning,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            showCaisseAdjustmentSheet(
                              context,
                              ref,
                              preselected: shift,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.lock_outline_rounded,
                          label: 'Fermer la caisse',
                          color: AppColors.danger,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            showCloseCashSessionSheet(context, shift, employee);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 18,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Conseil : Fermez votre caisse à la fin de votre journée de travail.',
                            style: Theme.of(sheetContext).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _row(IconData icon, String label, double value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.tealDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
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

class _StatusPillSmall extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPillSmall({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
