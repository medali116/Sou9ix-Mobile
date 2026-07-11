import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/model/employee_permission.dart';
import 'package:sou9ix/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';

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
  late Set<EmployeePermission> _permissions;

  bool get _isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nomCtrl = TextEditingController(text: e?.nom ?? '');
    _telephoneCtrl = TextEditingController(text: e?.telephone ?? '');
    _posteCtrl = TextEditingController(text: e?.poste ?? '');
    _permissions = {...e?.permissions ?? defaultCashierPermissions};
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de l\'employé est requis')),
      );
      return;
    }
    final employee = Employee(
      id: widget.employee?.id ?? 'e${DateTime.now().microsecondsSinceEpoch}',
      nom: _nomCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      poste: _posteCtrl.text.trim().isEmpty
          ? 'Vendeur'
          : _posteCtrl.text.trim(),
      actif: widget.employee?.actif ?? true,
      permissions: _permissions,
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
                ref
                    .read(employeesProvider.notifier)
                    .archive(widget.employee!.id);
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
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(hintText: 'Ex. Karim Bouazizi'),
          ),
          const SizedBox(height: 18),
          _label('Téléphone'),
          TextField(
            controller: _telephoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+216 XX XXX XXX'),
          ),
          const SizedBox(height: 18),
          _label('Poste'),
          TextField(
            controller: _posteCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex. Caissier, Vendeur, Gérant',
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
                    _label('Permissions'),
                    Text(
                      '${_permissions.length}/${EmployeePermission.values.length} sélectionnées',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _permissions = {...defaultCashierPermissions},
                ),
                child: const Text('Défaut caissier'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final category in PermissionCategory.values) ...[
            _PermissionGroupCard(
              category: category,
              selected: _permissions,
              onChanged: (p, checked) => setState(() {
                if (checked) {
                  _permissions.add(p);
                } else {
                  _permissions.remove(p);
                }
              }),
            ),
            const SizedBox(height: 10),
          ],
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

extension _PermissionCategoryIcon on PermissionCategory {
  IconData get icon => switch (this) {
    PermissionCategory.vente => Icons.point_of_sale_rounded,
    PermissionCategory.clients => Icons.people_alt_rounded,
    PermissionCategory.fournisseurs => Icons.local_shipping_rounded,
    PermissionCategory.catalogue => Icons.inventory_2_rounded,
    PermissionCategory.magasin => Icons.storefront_rounded,
  };
}

/// One collapsible-looking (but always-open) card per [PermissionCategory],
/// each permission a compact toggle row with a small "sensible" tag on
/// destructive/store-wide actions — replaces the old flat 9-item checkbox
/// list, which gave an admin no sense of grouping or risk at a glance.
class _PermissionGroupCard extends StatelessWidget {
  final PermissionCategory category;
  final Set<EmployeePermission> selected;
  final void Function(EmployeePermission permission, bool checked) onChanged;

  const _PermissionGroupCard({
    required this.category,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final permissions = EmployeePermission.values
        .where((p) => p.category == category)
        .toList();
    final selectedCount = permissions.where(selected.contains).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Icon(category.icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  category.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount/${permissions.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final p in permissions)
            CheckboxListTile(
              value: selected.contains(p),
              onChanged: (checked) => onChanged(p, checked == true),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      p.label,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                  if (p.risky) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
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
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.teal,
              dense: true,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
