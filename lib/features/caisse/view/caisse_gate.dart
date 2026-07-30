import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_removal_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

/// Blocks the Caisse screen behind a real "session de caisse". Who's
/// opening it is resolved from the logged-in [AppUser] — via
/// [AppUser.employeeId] — instead of asking them to pick themselves from a
/// list, which would let anyone open a session under someone else's name
/// and break the audit trail. They only have to count the starting float
/// before their first sale; every ticket sold afterwards is tied to that
/// specific employee/session automatically.
class CaisseGate extends ConsumerWidget {
  final Widget child;
  const CaisseGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeEmployeeProvider);
    final shifts = ref.watch(shiftsProvider);
    Shift? openShift;
    if (activeId != null) {
      for (final s in shifts) {
        if (s.employeeId == activeId && s.enCours) {
          openShift = s;
          break;
        }
      }
    }
    if (openShift == null && !ref.watch(caisseOpeningDeferredProvider)) {
      return const _OpenCaisseScreen();
    }
    return child;
  }
}

class _OpenCaisseScreen extends ConsumerStatefulWidget {
  const _OpenCaisseScreen();

  @override
  ConsumerState<_OpenCaisseScreen> createState() => _OpenCaisseScreenState();
}

class _OpenCaisseScreenState extends ConsumerState<_OpenCaisseScreen> {
  final _montantCtrl = TextEditingController();
  final _ecartMotifCtrl = TextEditingController();

  @override
  void dispose() {
    _montantCtrl.dispose();
    _ecartMotifCtrl.dispose();
    super.dispose();
  }

  double? get _montant =>
      double.tryParse(_montantCtrl.text.replaceAll(',', '.'));

  Shift? _lastClosedShiftFor(String employeeId, List<Shift> allShifts) {
    Shift? last;
    for (final s in allShifts) {
      if (s.employeeId != employeeId || s.enCours || s.montantCompte == null) {
        continue;
      }
      if (last == null || s.clockIn.isAfter(last.clockIn)) last = s;
    }
    return last;
  }

  Future<void> _confirmAndOpen(
    Employee employee,
    double montant,
    double? ecart,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer l\'ouverture ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Caissier', employee.nom),
            _confirmRow('Montant compté', AppFormat.dt(montant)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ouvrir la caisse'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final hasEcart = ecart != null && ecart.abs() > 0.001;
    ref
        .read(shiftsProvider.notifier)
        .clockIn(
          employee.id,
          fondInitial: montant,
          fondSource: ecart != null ? 'Report de caisse' : 'Nouveau fond',
        );
    ref.read(activeEmployeeProvider.notifier).state = employee.id;
    ref.read(cartRemovalProvider.notifier).reset(employee.id);

    if (hasEcart) {
      ref
          .read(activityLogProvider.notifier)
          .log(
            ActivityLogEntry(
              id: '${DateTime.now().microsecondsSinceEpoch}',
              date: DateTime.now(),
              employeeName: employee.nom,
              category: ActivityCategory.employes,
              impact: ActivityImpact.modification,
              action: 'Écart à l\'ouverture',
              targetName: employee.nom,
              difference: ecart,
              motif: _ecartMotifCtrl.text.trim().isEmpty
                  ? null
                  : _ecartMotifCtrl.text.trim(),
              platform: currentPlatformLabel(),
            ),
          );
    }
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final employees = ref.watch(employeesProvider);
    Employee? employee;
    if (user?.employeeId != null) {
      for (final e in employees) {
        if (e.id == user!.employeeId) {
          employee = e;
          break;
        }
      }
    }

    if (employee == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 34,
                    color: AppColors.textFaint,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun profil employé n\'est associé à ce compte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contactez l\'administrateur pour lier votre compte à un employé.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final allShifts = ref.watch(shiftsProvider);
    final lastClosed = _lastClosedShiftFor(employee.id, allShifts);
    final reference = lastClosed?.montantCompte;
    final montant = _montant;
    final ecart = (reference != null && montant != null)
        ? montant - reference
        : null;
    final hasEcart = ecart != null && ecart.abs() > 0.001;
    final matches = reference != null && montant != null && !hasEcart;
    final canSave =
        montant != null &&
        (!hasEcart || _ecartMotifCtrl.text.trim().isNotEmpty);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.teal,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'Ouverture de caisse',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${AppFormat.fullDate(DateTime.now())} · ${DateFormat('HH:mm').format(DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
            ),
            const SizedBox(height: 4),
            const Text(
              'Comptez ce qu\'il y a déjà dans le tiroir avant de vendre.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
            ),
            const SizedBox(height: 18),
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
                    radius: 18,
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
                        const Text(
                          'Connecté en tant que',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textFaint,
                          ),
                        ),
                        Text(
                          employee.nom,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          employee.poste,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (reference != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fond attendu (report de la précédente clôture)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            AppFormat.dt(reference),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.info,
                            ),
                          ),
                          if (lastClosed?.clockOut != null)
                            Text(
                              'Clôturée le ${DateFormat('dd/MM/yyyy à HH:mm').format(lastClosed!.clockOut!)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Montant compté',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _montantCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '0.000',
                suffixText: 'DT',
              ),
            ),
            if (matches) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Le montant correspond au fond attendu.',
                    style: TextStyle(fontSize: 12, color: AppColors.success),
                  ),
                ],
              ),
            ],
            if (hasEcart) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Écart d\'ouverture : ${ecart >= 0 ? '+' : ''}${AppFormat.dt(ecart)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ecartMotifCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif de l\'écart (obligatoire)',
                  hintText: 'Ex. Erreur de comptage de la veille',
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSave
                    ? () => _confirmAndOpen(employee!, montant, ecart)
                    : null,
                child: const Text('Ouvrir ma caisse'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    ref.read(caisseOpeningDeferredProvider.notifier).state =
                        true,
                child: const Text('Plus tard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
