import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_module.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/segmented_tabs.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final Employee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _posteCtrl;
  late final TextEditingController _pinCtrl;
  late Set<EmployeeModule> _modules;
  late UserRole _role;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _telephoneCtrl = TextEditingController(text: e?.telephone ?? '');
    _posteCtrl = TextEditingController(text: e?.poste ?? '');
    _pinCtrl = TextEditingController(text: e?.pin ?? '');
    _modules = {...e?.modules ?? defaultCashierModules};
    _role = e?.role ?? UserRole.caissier;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _posteCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de l\'employé est requis')),
      );
      return;
    }
    // Required, not just recommended — "Connexion employé" now matches on
    // nom + téléphone + PIN together, so an employee saved without a phone
    // number could never log in.
    if (normalizePhone(_telephoneCtrl.text.trim()).length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un numéro de téléphone valide est requis')),
      );
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (_role == UserRole.caissier) {
      if (pin.length != 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le code PIN doit contenir 4 chiffres')),
        );
        return;
      }
    } else {
      if (pin.length < 4 || pin.length > 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Le code PIN administrateur doit contenir 4 à 6 chiffres'),
          ),
        );
        return;
      }
      if (isWeakPin(pin)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ce code PIN est trop simple (ex. 1234, 0000) — choisissez-en un autre'),
          ),
        );
        return;
      }
    }
    // Login is by full name — two active employees sharing one would make
    // it impossible to tell them apart on the login screen.
    final normalizedNom = normalizeEmployeeName(_nomCtrl.text.trim());
    final duplicate = ref
        .read(employeesProvider)
        .where((e) => e.actif && e.id != widget.employee?.id)
        .any((e) => normalizeEmployeeName(e.nom) == normalizedNom);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Un employé actif nommé "${_nomCtrl.text.trim()}" existe déjà — utilisez un nom complet différent (ex. ajoutez une initiale).',
          ),
        ),
      );
      return;
    }
    final employee = Employee(
      id: widget.employee?.id ?? 'e${DateTime.now().microsecondsSinceEpoch}',
      shopCode: widget.employee?.shopCode ?? ref.read(currentShopCodeProvider)!,
      nom: _nomCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      poste: _posteCtrl.text.trim().isEmpty
          ? 'Vendeur'
          : _posteCtrl.text.trim(),
      actif: widget.employee?.actif ?? true,
      modules: _modules,
      pin: _pinCtrl.text.trim(),
      role: _role,
    );
    ref.read(employeesProvider.notifier).upsert(employee);
    context.pop();
  }

  Future<void> _archive() async {
    final motifCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Archiver cet employé ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'L\'employé n\'apparaîtra plus dans la liste active, mais son historique (ventes, shifts) reste intact.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: motifCtrl,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  hintText: 'Ex. Fin de contrat',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Retour'),
            ),
            TextButton(
              onPressed: motifCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Archiver', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(employeesProvider.notifier)
        .archive(widget.employee!.id, motif: motifCtrl.text.trim());
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier l\'employé' : 'Nouvel employé'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined, color: AppColors.danger),
              tooltip: 'Archiver',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _label('Nom complet'),
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(hintText: 'Ex. Karim Bouazizi'),
          ),
          const SizedBox(height: 18),
          _label('Téléphone'),
          TextField(
            controller: _telephoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: '+216 XX XXX XXX',
              helperText: 'Requis pour se connecter sur "Connexion employé"',
            ),
          ),
          const SizedBox(height: 18),
          _label('Poste'),
          TextField(
            controller: _posteCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex. Caissier, Vendeur, Gérant',
            ),
          ),
          const SizedBox(height: 18),
          _label('Interface à l\'ouverture de session'),
          SegmentedTabs(
            labels: const ['Caissier', 'Administrateur'],
            selectedIndex: _role == UserRole.admin ? 1 : 0,
            onChanged: (i) =>
                setState(() => _role = i == 1 ? UserRole.admin : UserRole.caissier),
          ),
          const SizedBox(height: 6),
          Text(
            'Détermine l\'interface ouverte après le PIN. Les accès réels sont définis module par module ci-dessous.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
          ),
          const SizedBox(height: 18),
          _label(
            _role == UserRole.admin
                ? 'Code PIN administrateur (4 à 6 chiffres)'
                : 'Code PIN (4 chiffres)',
          ),
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: _role == UserRole.admin ? 6 : 4,
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
              helperText: 'Utilisé pour ouvrir une session sur "Connexion employé"',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Accès de l\'employé'),
                    Text(
                      '${_modules.length}/${EmployeeModule.values.length} modules activés',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _modules = {...defaultCashierModules},
                ),
                child: const Text('Défaut caissier'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ModuleAccessCard(
            selected: _modules,
            onChanged: (m, granted) => setState(() {
              if (granted) {
                _modules.add(m);
              } else {
                _modules.remove(m);
              }
            }),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(
                _isEdit
                    ? 'Enregistrer les modifications'
                    : 'Ajouter l\'employé',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

/// One module per row, each a single toggle — replaces the old
/// category-of-checkboxes layout, since there's no grouping level left
/// once every module is already the atomic unit an admin thinks in.
class _ModuleAccessCard extends StatelessWidget {
  final Set<EmployeeModule> selected;
  final void Function(EmployeeModule module, bool granted) onChanged;

  const _ModuleAccessCard({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (final m in EmployeeModule.values)
            SwitchListTile(
              value: selected.contains(m),
              onChanged: (granted) => onChanged(m, granted),
              activeThumbColor: AppColors.teal,
              secondary: Icon(m.icon, color: AppColors.textSecondary),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      m.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                  if (m.sensitive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'sensible',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(m.description, style: const TextStyle(fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
