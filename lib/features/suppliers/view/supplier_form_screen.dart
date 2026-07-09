import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/features/suppliers/model/supplier.dart';
import 'package:sou9ix/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/widgets/photo_picker_field.dart';

class SupplierFormScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;

  const SupplierFormScreen({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _adresseCtrl;
  Uint8List? _photoBytes;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nomCtrl = TextEditingController(text: s?.nom ?? '');
    _telephoneCtrl = TextEditingController(text: s?.telephone ?? '');
    _adresseCtrl = TextEditingController(text: s?.adresse ?? '');
    _photoBytes = s?.photoBytes;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nomCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du fournisseur est requis')),
      );
      return;
    }
    final supplier = Supplier(
      id: widget.supplier?.id ?? 'f${DateTime.now().microsecondsSinceEpoch}',
      nom: _nomCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim(),
      photoBytes: _photoBytes,
    );
    ref.read(suppliersProvider.notifier).upsert(supplier);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
        ),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: () {
                ref
                    .read(suppliersProvider.notifier)
                    .remove(widget.supplier!.id);
                context.pop();
              },
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _label('Photo (optionnel)'),
          PhotoPickerField(
            photoBytes: _photoBytes,
            onChanged: (bytes) => setState(() => _photoBytes = bytes),
            placeholderLabel: 'Ajouter une photo du fournisseur',
            placeholderIcon: Icons.local_shipping_outlined,
            height: 120,
          ),
          const SizedBox(height: 18),
          _label('Nom du fournisseur'),
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex. Grossiste Fruits Secs Sfax',
            ),
          ),
          const SizedBox(height: 18),
          _label('Téléphone'),
          TextField(
            controller: _telephoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+216 XX XXX XXX'),
          ),
          const SizedBox(height: 18),
          _label('Adresse'),
          TextField(
            controller: _adresseCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ex. Zone industrielle, Sfax',
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text(
                _isEdit
                    ? 'Enregistrer les modifications'
                    : 'Ajouter le fournisseur',
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
