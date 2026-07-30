import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_removal_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';

/// Sales rung up by this shift's employee, inside the shift's own time
/// window — mirrors the in-window filtering `cash_session_provider.dart`
/// already does for cash movements.
final sessionSalesProvider = Provider.family<List<Sale>, Shift>((ref, shift) {
  final end = shift.clockOut ?? DateTime.now();
  bool inWindow(DateTime d) => !d.isBefore(shift.clockIn) && !d.isAfter(end);
  return ref
      .watch(employeeSalesProvider(shift.employeeId))
      .where((s) => inWindow(s.dateHeure))
      .toList();
});

/// What happened during a shift beyond pure cash movement — how many
/// tickets, cancellations, returns, discounts and price edits — shown on
/// the "Voir le détail" session screen, never on "Ma caisse" itself.
class SessionActivityStats {
  final int ticketsCrees;
  final int ticketsAnnules;
  final int articlesRetournes;
  final int reductionsAccordees;
  final int prixModifies;
  final int articlesSupprimesPanier;

  const SessionActivityStats({
    required this.ticketsCrees,
    required this.ticketsAnnules,
    required this.articlesRetournes,
    required this.reductionsAccordees,
    required this.prixModifies,
    required this.articlesSupprimesPanier,
  });
}

final sessionActivityProvider = Provider.family<SessionActivityStats, Shift>((
  ref,
  shift,
) {
  final sales = ref.watch(sessionSalesProvider(shift));
  final reductions = sales
      .where(
        (s) => !s.discount.isNone || s.lignes.any((l) => !l.discount.isNone),
      )
      .length;

  final employees = ref.watch(employeesProvider);
  final matches = employees.where((e) => e.id == shift.employeeId);
  final employeeName = matches.isEmpty ? null : matches.first.nom;

  final end = shift.clockOut ?? DateTime.now();
  bool inWindow(DateTime d) => !d.isBefore(shift.clockIn) && !d.isAfter(end);
  final entries = employeeName == null
      ? const <ActivityLogEntry>[]
      : ref
            .watch(activityLogProvider)
            .where((e) => e.employeeName == employeeName && inWindow(e.date))
            .toList();

  final ticketsAnnules = entries
      .where(
        (e) =>
            e.category == ActivityCategory.tickets &&
            e.impact == ActivityImpact.suppression,
      )
      .length;
  final articlesRetournes = entries
      .where(
        (e) =>
            e.category == ActivityCategory.stock &&
            e.action == 'Perte enregistrée',
      )
      .length;
  final prixModifies = entries
      .where((e) => e.category == ActivityCategory.prix)
      .length;

  return SessionActivityStats(
    ticketsCrees: sales.length,
    ticketsAnnules: ticketsAnnules,
    articlesRetournes: articlesRetournes,
    reductionsAccordees: reductions,
    prixModifies: prixModifies,
    articlesSupprimesPanier: ref.watch(cartRemovalProvider)[shift.employeeId] ?? 0,
  );
});
