import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/caisse/model/caisse_adjustment.dart';
import 'package:sou9ix/features/caisse/viewmodel/caisse_adjustments_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/shift.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

enum _Direction { retrait, ajout }

/// Records cash that left or entered a specific cashier's till outside a
/// normal sale, payment or expense — e.g. an admin pulling money out for
/// the bank deposit, or topping up the drawer with extra change. Always
/// tied to one open session ([preselected], or picked here when several
/// are open) so it can never be absorbed into the wrong cashier's
/// reconciliation. Every dinar shows up in that session's movement
/// journal via [caisseAdjustmentsProvider].
Future<void> showCaisseAdjustmentSheet(
  BuildContext context,
  WidgetRef ref, {
  Shift? preselected,
  bool startAsAjout = false,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CaisseAdjustmentSheet(
      preselected: preselected,
      startAsAjout: startAsAjout,
    ),
  );
}

class _CaisseAdjustmentSheet extends ConsumerStatefulWidget {
  final Shift? preselected;
  final bool startAsAjout;
  const _CaisseAdjustmentSheet({
    this.preselected,
    this.startAsAjout = false,
  });

  @override
  ConsumerState<_CaisseAdjustmentSheet> createState() =>
      _CaisseAdjustmentSheetState();
}

class _CaisseAdjustmentSheetState
    extends ConsumerState<_CaisseAdjustmentSheet> {
  Shift? _shift;
  _Direction _direction = _Direction.retrait;
  final _montantCtrl = TextEditingController();
  RetraitMotif _retraitMotif = RetraitMotif.versementCoffre;
  AjoutMotif _ajoutMotif = AjoutMotif.monnaie;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shift = widget.preselected;
    _direction = widget.startAsAjout ? _Direction.ajout : _Direction.retrait;
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double? get _montant =>
      double.tryParse(_montantCtrl.text.replaceAll(',', '.'));

  String get _motifLabel => _direction == _Direction.retrait
      ? _retraitMotif.label
      : _ajoutMotif.label;

  Future<void> _confirmAndSave(Employee employee) async {
    final montant = _montant!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _direction == _Direction.retrait
              ? 'Confirmer le retrait ?'
              : 'Confirmer l\'ajout ?',
        ),
        content: Text(
          '${_direction == _Direction.retrait ? 'Retirer' : 'Ajouter'} '
          '${AppFormat.dt(montant)} ${_direction == _Direction.retrait ? 'de' : 'à'} '
          'la caisse de ${employee.nom}.\n\nMotif : $_motifLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(caisseAdjustmentsProvider.notifier)
        .add(
          montant: _direction == _Direction.retrait ? -montant : montant,
          targetEmployeeId: employee.id,
          motif: _motifLabel,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final openShifts = ref.watch(openShiftsProvider);
    final employees = {for (final e in ref.watch(employeesProvider)) e.id: e};

    // Exactly one open session — skip the picker entirely.
    if (_shift == null && openShifts.length == 1) _shift = openShifts.first;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 8),
              Text(
                'Mouvement de caisse',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_shift == null)
                _buildShiftPicker(openShifts, employees)
              else
                _buildForm(employees[_shift!.employeeId]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftPicker(
    List<Shift> openShifts,
    Map<String, Employee> employees,
  ) {
    if (openShifts.isEmpty) {
      return const Text(
        'Aucune caisse n\'est ouverte pour le moment.',
        style: TextStyle(color: AppColors.textFaint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Caisse concernée',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        for (final s in openShifts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.teal,
            ),
            title: Text(employees[s.employeeId]?.nom ?? 'Employé'),
            subtitle: Text(
              'Ouverte depuis ${TimeOfDay.fromDateTime(s.clockIn).format(context)}',
            ),
            onTap: () => setState(() => _shift = s),
          ),
      ],
    );
  }

  Widget _buildForm(Employee? employee) {
    if (employee == null) {
      return const Text(
        'Employé introuvable.',
        style: TextStyle(color: AppColors.textFaint),
      );
    }
    final canSave = _montant != null && _montant! > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.preselected == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Caisse : ${employee.nom}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _shift = null),
                  child: const Text('Changer'),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('Retrait de caisse'),
                avatar: Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 16,
                  color: _direction == _Direction.retrait
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                selected: _direction == _Direction.retrait,
                selectedColor: AppColors.danger,
                onSelected: (_) =>
                    setState(() => _direction = _Direction.retrait),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Ajout de fonds'),
                avatar: Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: _direction == _Direction.ajout
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                selected: _direction == _Direction.ajout,
                selectedColor: AppColors.success,
                onSelected: (_) =>
                    setState(() => _direction = _Direction.ajout),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Montant',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _montantCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '0.000',
            suffixText: 'DT',
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Motif',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _direction == _Direction.retrait
              ? RetraitMotif.values.map((m) {
                  return ChoiceChip(
                    label: Text(m.label),
                    selected: _retraitMotif == m,
                    onSelected: (_) => setState(() => _retraitMotif = m),
                  );
                }).toList()
              : AjoutMotif.values.map((m) {
                  return ChoiceChip(
                    label: Text(m.label),
                    selected: _ajoutMotif == m,
                    onSelected: (_) => setState(() => _ajoutMotif = m),
                  );
                }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Note (optionnelle)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(
            hintText: 'Détails supplémentaires…',
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canSave ? () => _confirmAndSave(employee) : null,
            child: const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }
}
