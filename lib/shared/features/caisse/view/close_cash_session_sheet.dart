import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/caisse/viewmodel/cash_session_provider.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/shift.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

/// Above this, an écart is flagged 🔴 "important" instead of 🟠 "mineur" —
/// no per-shop admin setting exists yet, so this is a sensible fixed
/// default rather than a fabricated configurable one.
const double _ecartImportantSeuil = 5.0;
const double _ecartMineurSeuil = 1.0;

enum _EcartMotif { erreurMonnaie, depenseNonEnregistree, erreurComptage, autre }

extension on _EcartMotif {
  String get label => switch (this) {
    _EcartMotif.erreurMonnaie => 'Erreur de monnaie',
    _EcartMotif.depenseNonEnregistree => 'Dépense non enregistrée',
    _EcartMotif.erreurComptage => 'Erreur de comptage',
    _EcartMotif.autre => 'Autre',
  };
}

Future<void> showCloseCashSessionSheet(
  BuildContext context,
  Shift shift,
  Employee employee,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _CloseCashSessionSheet(shift: shift, employee: employee),
  );
}

class _CloseCashSessionSheet extends ConsumerStatefulWidget {
  final Shift shift;
  final Employee employee;
  const _CloseCashSessionSheet({required this.shift, required this.employee});

  @override
  ConsumerState<_CloseCashSessionSheet> createState() =>
      _CloseCashSessionSheetState();
}

class _CloseCashSessionSheetState
    extends ConsumerState<_CloseCashSessionSheet> {
  int _step = 0;
  final _compteCtrl = TextEditingController();
  _EcartMotif? _motif;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _compteCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  double? get _montantCompte =>
      double.tryParse(_compteCtrl.text.replaceAll(',', '.'));

  void _confirm() {
    ref
        .read(shiftsProvider.notifier)
        .closeCashSession(
          widget.shift.id,
          montantCompte: _montantCompte!,
          ecartMotif: _motif?.label,
          ecartCommentaire: _commentCtrl.text.trim().isEmpty
              ? null
              : _commentCtrl.text.trim(),
        );
    if (ref.read(activeEmployeeProvider) == widget.employee.id) {
      ref.read(activeEmployeeProvider.notifier).state = null;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: _step == 0 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 8),
        Text(
          'Clôture de caisse',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          widget.employee.nom,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _labelValue(
                'Début du service',
                DateFormat('HH:mm').format(widget.shift.clockIn),
              ),
            ),
            Expanded(
              child: _labelValue(
                'Fin du service',
                DateFormat('HH:mm').format(DateTime.now()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Montant compté dans la caisse',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        const Text(
          'Comptez physiquement l\'argent dans le tiroir — le montant attendu ne s\'affichera qu\'après.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _compteCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '0.000',
            suffixText: 'DT',
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _montantCompte != null
                ? () => setState(() => _step = 1)
                : null,
            child: const Text('Continuer'),
          ),
        ),
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final movements = ref.watch(cashMovementsForShiftProvider(widget.shift));
    final attendu = movements.fold<double>(0, (sum, m) => sum + m.montant);
    final compte = _montantCompte!;
    final ecart = compte - attendu;
    final equilibree = ecart.abs() < 0.001;
    final mineur = !equilibree && ecart.abs() <= _ecartMineurSeuil;
    final important = ecart.abs() > _ecartImportantSeuil;
    final (statusIcon, statusLabel, statusColor) = equilibree
        ? ('🟢', 'Équilibrée', AppColors.success)
        : important
        ? ('🔴', 'Écart important', AppColors.danger)
        : mineur
        ? ('🟠', 'Écart mineur', AppColors.warning)
        : ('🟠', 'Écart', AppColors.warning);

    double sumOf(CashMovementType t) => movements
        .where((m) => m.type == t)
        .fold<double>(0, (sum, m) => sum + m.montant);

    final canConfirm = equilibree || _motif != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: SheetHandle()),
        const SizedBox(height: 8),
        Text(
          'Récapitulatif de clôture',
          style: Theme.of(context).textTheme.titleLarge,
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
              _recapRow('Fond initial', widget.shift.fondInitial),
              _recapRow('Ventes espèces', sumOf(CashMovementType.vente)),
              _recapRow(
                'Encaissements clients',
                sumOf(CashMovementType.encaissement),
              ),
              _recapRow('Dépenses', sumOf(CashMovementType.depense)),
              if (sumOf(CashMovementType.achat) != 0)
                _recapRow(
                  'Paiements fournisseurs',
                  sumOf(CashMovementType.achat),
                ),
              if (sumOf(CashMovementType.ajustement) != 0)
                _recapRow(
                  'Ajustements caisse',
                  sumOf(CashMovementType.ajustement),
                ),
              const Divider(height: 20),
              _recapRow('Espèces attendues', attendu, bold: true),
              _recapRow('Espèces comptées', compte, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Text(statusIcon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      'Écart : ${ecart >= 0 ? '+' : ''}${AppFormat.dt(ecart)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!equilibree) ...[
          const SizedBox(height: 18),
          const Text(
            'Motif (obligatoire)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _EcartMotif.values.map((m) {
              return ChoiceChip(
                label: Text(m.label),
                selected: _motif == m,
                onSelected: (_) => setState(() => _motif = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Commentaire (optionnel)',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Détails supplémentaires…',
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirm : null,
            child: const Text('Confirmer la clôture'),
          ),
        ),
      ],
    );
  }

  Widget _recapRow(String label, double value, {bool bold = false}) {
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
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            AppFormat.dt(value),
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
