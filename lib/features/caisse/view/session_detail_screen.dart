import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/features/caisse/viewmodel/session_activity_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/section_header.dart';

/// Everything that happened during one cash session beyond the plain
/// movement totals already visible on "Ma caisse" — reached via "Voir le
/// détail" so that sheet can stay short. While the shift is still open,
/// Cash attendu/compté/Écart stay hidden here too (same blind-count
/// reasoning as `ma_caisse_sheet.dart`); once closed, they're safe to
/// show since the blind count already happened.
class SessionDetailScreen extends ConsumerWidget {
  final Shift shift;
  final Employee employee;

  const SessionDetailScreen({
    super.key,
    required this.shift,
    required this.employee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(cashMovementsForShiftProvider(shift));
    final stats = ref.watch(sessionActivityProvider(shift));

    return Scaffold(
      appBar: AppBar(title: Text('Détail de la session')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                  foregroundColor: AppColors.goldDark,
                  child: Text(
                    employee.initiales,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.nom,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        shift.clockOut != null
                            ? '${DateFormat('HH:mm').format(shift.clockIn)} — ${DateFormat('HH:mm').format(shift.clockOut!)}'
                            : 'Depuis ${DateFormat('HH:mm').format(shift.clockIn)} · en cours',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Activité de la session'),
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
                _StatRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'Tickets créés',
                  count: stats.ticketsCrees,
                ),
                _StatRow(
                  icon: Icons.cancel_outlined,
                  label: 'Tickets annulés',
                  count: stats.ticketsAnnules,
                  color: stats.ticketsAnnules > 0 ? AppColors.danger : null,
                ),
                _StatRow(
                  icon: Icons.keyboard_return_rounded,
                  label: 'Articles retournés',
                  count: stats.articlesRetournes,
                ),
                _StatRow(
                  icon: Icons.sell_outlined,
                  label: 'Réductions accordées',
                  count: stats.reductionsAccordees,
                ),
                _StatRow(
                  icon: Icons.price_change_outlined,
                  label: 'Prix modifiés',
                  count: stats.prixModifies,
                ),
                _StatRow(
                  icon: Icons.remove_shopping_cart_outlined,
                  label: 'Articles supprimés du panier',
                  count: stats.articlesSupprimesPanier,
                  isLast: true,
                ),
              ],
            ),
          ),
          if (!shift.enCours && shift.montantCompte != null) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Réconciliation'),
            const SizedBox(height: 12),
            _ReconciliationCard(shift: shift),
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
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color? color;
  final bool isLast;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.count,
    this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationCard extends ConsumerWidget {
  final Shift shift;
  const _ReconciliationCard({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendu = ref.watch(expectedCashForShiftProvider(shift));
    final ecart = ref.watch(cashDiscrepancyForShiftProvider(shift))!;
    final equilibree = ecart.abs() < 0.001;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          _row('Cash attendu', AppFormat.dt(attendu)),
          _row('Cash compté', AppFormat.dt(shift.montantCompte!)),
          _row(
            'Écart',
            '${ecart >= 0 ? '+' : ''}${AppFormat.dt(ecart)}',
            color: equilibree ? AppColors.success : AppColors.danger,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: color ?? AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
            child: Icon(movement.type.icon, size: 16, color: movement.type.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.label, style: Theme.of(context).textTheme.titleMedium),
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
