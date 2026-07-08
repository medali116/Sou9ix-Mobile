import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';

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

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _telephoneCtrl = TextEditingController(text: e?.telephone ?? '');
    _posteCtrl = TextEditingController(text: e?.poste ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _posteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Le nom de l\'employé est requis')));
      return;
    }
    final employee = Employee(
      id: widget.employee?.id ?? 'e${DateTime.now().microsecondsSinceEpoch}',
      nom: _nomCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      poste: _posteCtrl.text.trim().isEmpty ? 'Vendeur' : _posteCtrl.text.trim(),
      actif: widget.employee?.actif ?? true,
    );
    ref.read(employeesProvider.notifier).upsert(employee);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier l\'employé' : 'Nouvel employé'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: () {
                ref.read(employeesProvider.notifier).archive(widget.employee!.id);
                context.pop();
              },
              icon: const Icon(Icons.archive_outlined, color: AppColors.danger),
              tooltip: 'Archiver',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _label('Nom complet'),
          TextField(controller: _nomCtrl, decoration: const InputDecoration(hintText: 'Ex. Karim Bouazizi')),
          const SizedBox(height: 18),
          _label('Téléphone'),
          TextField(
            controller: _telephoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+216 XX XXX XXX'),
          ),
          const SizedBox(height: 18),
          _label('Poste'),
          TextField(controller: _posteCtrl, decoration: const InputDecoration(hintText: 'Ex. Caissier, Vendeur, Gérant')),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Enregistrer les modifications' : 'Ajouter l\'employé'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
