import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/features/caisse/viewmodel/caisse_adjustments_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/expenses/viewmodel/expenses_provider.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/stock/model/purchase_invoice.dart';
import 'package:sou9ix/features/stock/viewmodel/purchase_invoices_provider.dart';

enum CashMovementType { fond, vente, encaissement, depense, achat, ajustement }

extension CashMovementTypeStyle on CashMovementType {
  IconData get icon => switch (this) {
    CashMovementType.fond => Icons.savings_outlined,
    CashMovementType.vente => Icons.point_of_sale_rounded,
    CashMovementType.encaissement => Icons.payments_outlined,
    CashMovementType.depense => Icons.wallet_outlined,
    CashMovementType.achat => Icons.local_shipping_outlined,
    CashMovementType.ajustement => Icons.swap_vert_rounded,
  };

  Color get color => switch (this) {
    CashMovementType.fond => AppColors.info,
    CashMovementType.vente => AppColors.success,
    CashMovementType.encaissement => AppColors.success,
    CashMovementType.depense => AppColors.danger,
    CashMovementType.achat => AppColors.danger,
    CashMovementType.ajustement => AppColors.warning,
  };
}

/// One line of a cash session's journal — every dinar that moved the till
/// during a [Shift], signed (+in, -out), so "espèces attendues" is always
/// just the sum of these plus the starting float.
class CashMovement {
  final DateTime date;
  final CashMovementType type;
  final String label;
  final double montant;

  const CashMovement({
    required this.date,
    required this.type,
    required this.label,
    required this.montant,
  });
}

/// This app models a single active till (one [activeEmployeeProvider] at a
/// time — see shifts_provider.dart), so every cash-affecting record whose
/// timestamp falls inside a shift's window is attributed to that shift's
/// session, whether or not it carries the employee's id itself.
List<CashMovement> _movementsFor(Ref ref, Shift shift) {
  final end = shift.clockOut ?? DateTime.now();
  bool inWindow(DateTime d) => !d.isBefore(shift.clockIn) && !d.isAfter(end);

  final movements = <CashMovement>[
    CashMovement(
      date: shift.clockIn,
      type: CashMovementType.fond,
      label: 'Fond de caisse',
      montant: shift.fondInitial,
    ),
  ];

  for (final s in ref.watch(salesProvider)) {
    if (s.modePaiement != ModePaiement.especes) continue;
    if (!inWindow(s.dateHeure)) continue;
    final ref6 = s.id.length > 6
        ? s.id.substring(s.id.length - 6).toUpperCase()
        : s.id.toUpperCase();
    movements.add(
      CashMovement(
        date: s.dateHeure,
        type: CashMovementType.vente,
        label: 'Vente · Ticket #$ref6',
        montant: s.total,
      ),
    );
  }

  for (final c in ref.watch(clientsProvider)) {
    for (final t in c.transactions) {
      if (t.type != ClientTransactionType.paiement) continue;
      if (t.modePaiement != PaymentMethod.especes) continue;
      if (!inWindow(t.date)) continue;
      movements.add(
        CashMovement(
          date: t.date,
          type: CashMovementType.encaissement,
          label: 'Encaissement · ${c.nom}',
          montant: t.montant,
        ),
      );
    }
  }

  for (final e in ref.watch(expensesProvider)) {
    if (!e.paye || e.modePaiement != PaymentMethod.especes) continue;
    if (!inWindow(e.date)) continue;
    movements.add(
      CashMovement(
        date: e.date,
        type: CashMovementType.depense,
        label: 'Dépense · ${e.label}',
        montant: -e.montant,
      ),
    );
  }

  for (final invoice in ref.watch(purchaseInvoicesProvider)) {
    for (final p in invoice.paiements) {
      if (p.modePaiement != PurchasePaymentMethod.especes) continue;
      if (!inWindow(p.date)) continue;
      movements.add(
        CashMovement(
          date: p.date,
          type: CashMovementType.achat,
          label: 'Paiement fournisseur · Facture #${invoice.reference}',
          montant: -p.montant,
        ),
      );
    }
  }

  for (final a in ref.watch(caisseAdjustmentsProvider)) {
    // Tied to the specific employee it targets, not just a time window —
    // two cashiers can have overlapping open sessions, and a retrait/ajout
    // must never be silently absorbed into the wrong one's reconciliation.
    if (a.targetEmployeeId != shift.employeeId) continue;
    if (!inWindow(a.date)) continue;
    movements.add(
      CashMovement(
        date: a.date,
        type: CashMovementType.ajustement,
        label:
            '${a.motif} · Par ${a.recordedByName}${a.note != null ? ' — ${a.note}' : ''}',
        montant: a.montant,
      ),
    );
  }

  movements.sort((a, b) => a.date.compareTo(b.date));
  return movements;
}

final cashMovementsForShiftProvider =
    Provider.family<List<CashMovement>, Shift>(
      (ref, shift) => _movementsFor(ref, shift),
    );

/// Espèces attendues dans le tiroir : fond initial + tout ce qui a bougé
/// pendant la session.
final expectedCashForShiftProvider = Provider.family<double, Shift>((
  ref,
  shift,
) {
  return ref
      .watch(cashMovementsForShiftProvider(shift))
      .fold<double>(0, (sum, m) => sum + m.montant);
});

/// Null while the session is still open (nothing counted yet).
final cashDiscrepancyForShiftProvider = Provider.family<double?, Shift>((
  ref,
  shift,
) {
  if (shift.montantCompte == null) return null;
  return shift.montantCompte! - ref.watch(expectedCashForShiftProvider(shift));
});

class CaisseDaySummary {
  final int sessionsOuvertes;
  final int sessionsCloturees;
  final int sessionsAvecEcart;

  /// Store-wide revenue for the day — independent of who had a session
  /// open when it was rung up (a sale can predate any session, or the
  /// employee attribution can be missing entirely).
  final double caDuJour;

  /// Espèces actuellement dans les tiroirs encore ouverts — meaningless
  /// (and never shown) for sessions that are already clôturées, since
  /// those have a real [cashCompteClotures] instead.
  final double cashAttenduOuvertes;

  /// Sum of what was physically counted across sessions clôturées today.
  final double cashCompteClotures;

  /// Sum of écarts across sessions clôturées today — 0 whenever
  /// [sessionsCloturees] is 0, which callers should render as "—", not
  /// as a real balanced total.
  final double ecartCloturesTotal;

  const CaisseDaySummary({
    required this.sessionsOuvertes,
    required this.sessionsCloturees,
    required this.sessionsAvecEcart,
    required this.caDuJour,
    required this.cashAttenduOuvertes,
    required this.cashCompteClotures,
    required this.ecartCloturesTotal,
  });
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The dashboard/Caisses-screen "at a glance" numbers for today: how many
/// tills are open vs. closed, how many closed with a non-zero écart, and
/// the day's aggregate cash reconciliation — kept strictly separate from
/// the store-wide chiffre d'affaires (see [CaisseDaySummary] docs).
final todayCaisseSummaryProvider = Provider<CaisseDaySummary>((ref) {
  final now = DateTime.now();
  final shifts = ref
      .watch(shiftsProvider)
      .where((s) => _isSameDay(s.clockIn, now) || s.enCours)
      .toList();
  final ca = ref
      .watch(salesProvider)
      .where((s) => _isSameDay(s.dateHeure, now))
      .fold<double>(0, (sum, s) => sum + s.total);

  var attenduOuvertes = 0.0;
  var compteClotures = 0.0;
  var ecartTotal = 0.0;
  var ouvertes = 0;
  var cloturees = 0;
  var avecEcart = 0;
  for (final s in shifts) {
    if (s.enCours) {
      ouvertes++;
      attenduOuvertes += ref.watch(expectedCashForShiftProvider(s));
      continue;
    }
    cloturees++;
    compteClotures += s.montantCompte!;
    final ecart = ref.watch(cashDiscrepancyForShiftProvider(s)) ?? 0;
    ecartTotal += ecart;
    if (ecart.abs() > 0.001) avecEcart++;
  }

  return CaisseDaySummary(
    sessionsOuvertes: ouvertes,
    sessionsCloturees: cloturees,
    sessionsAvecEcart: avecEcart,
    caDuJour: ca,
    cashAttenduOuvertes: attenduOuvertes,
    cashCompteClotures: compteClotures,
    ecartCloturesTotal: ecartTotal,
  );
});
