import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/features/caisse/view/close_cash_session_sheet.dart';
import 'package:sou9ix/shared/features/caisse/view/open_cash_session_sheet.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';

/// Staff roster: clock employees in/out (which also sets who sales get
/// attributed to), add/edit staff, and drill into an employee's activity.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);
    final openShifts = ref.watch(openShiftsProvider);
    final activeEmployeeId = ref.watch(activeEmployeeProvider);
    final allShifts = ref.watch(shiftsProvider);
    final list = employees.where((e) => _showArchived || e.actif).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employés'),
        actions: [
          IconButton(
            onPressed: () => context.push('/employees/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Ajouter un employé',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EN SERVICE MAINTENANT',
                        style: TextStyle(
                          color: AppColors.tealLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${openShifts.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${employees.where((e) => e.actif).length} employé${employees.where((e) => e.actif).length > 1 ? 's' : ''} actif${employees.where((e) => e.actif).length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.tealLight,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Afficher les employés archivés',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Switch(
                  value: _showArchived,
                  activeThumbColor: AppColors.teal,
                  onChanged: (v) => setState(() => _showArchived = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'Aucun employé',
                    message:
                        'Ajoutez vos employés pour suivre\nleurs ventes et leurs horaires.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final e = list[index];
                      final onShift = openShifts.any(
                        (s) => s.employeeId == e.id,
                      );
                      return _EmployeeTile(
                        employee: e,
                        onShift: onShift,
                        isActive: e.id == activeEmployeeId,
                        onTap: () =>
                            context.push('/employees/detail', extra: e),
                        onToggleShift: () {
                          if (onShift) {
                            final shift = allShifts.firstWhere(
                              (s) => s.employeeId == e.id && s.enCours,
                            );
                            showCloseCashSessionSheet(context, shift, e);
                          } else {
                            showOpenCashSessionSheet(context, ref, e);
                          }
                        },
                      ).animate().fadeIn(
                        duration: 220.ms,
                        delay: (18 * index).ms,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  final bool onShift;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onToggleShift;

  const _EmployeeTile({
    required this.employee,
    required this.onShift,
    required this.isActive,
    required this.onTap,
    required this.onToggleShift,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: employee.actif ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employee.nom,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'En caisse',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                        if (!employee.actif) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '(archivé)',
                            style: TextStyle(
                              color: AppColors.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${employee.poste} · ${employee.telephone}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (employee.actif)
                PressScale(
                  onTap: onToggleShift,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (onShift ? AppColors.warning : AppColors.success)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      onShift ? 'Sortie' : 'Entrée',
                      style: TextStyle(
                        color: onShift ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
