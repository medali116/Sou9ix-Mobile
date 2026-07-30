import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/employees/model/employee.dart';
import 'package:sou9ix/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_removal_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

/// Starts an employee's cash-register session: they declare how much is
/// already in the till before their first sale, so the end-of-shift
/// reconciliation has a real starting point instead of assuming zero.
Future<void> showOpenCashSessionSheet(
  BuildContext context,
  WidgetRef ref,
  Employee employee,
) async {
  final fondCtrl = TextEditingController(text: '0');
  final result = await showModalBottomSheet<double>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SheetHandle()),
            const SizedBox(height: 8),
            Text(
              'Ouvrir la caisse',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            Text(
              employee.nom,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            const Text(
              'Fond de caisse initial',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ce qui est déjà dans le tiroir avant la première vente (monnaie pour les clients).',
              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: fondCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '0.000',
                suffixText: 'DT',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final value =
                      double.tryParse(fondCtrl.text.replaceAll(',', '.')) ?? 0;
                  Navigator.pop(sheetContext, value.clamp(0, double.infinity));
                },
                child: const Text('Ouvrir la caisse'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (result != null) {
    ref.read(shiftsProvider.notifier).clockIn(employee.id, fondInitial: result);
    ref.read(activeEmployeeProvider.notifier).state = employee.id;
    ref.read(cartRemovalProvider.notifier).reset(employee.id);
  }
}
