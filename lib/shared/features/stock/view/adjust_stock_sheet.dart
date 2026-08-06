import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/stock/model/stock_movement.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/stock_movements_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

/// Corrects a product's stock to a new absolute value, requiring a reason
/// once the value actually changes — shared between [StockScreen]'s swipe
/// action and [StockDetailScreen]'s "Ajuster" button so both go through the
/// exact same validation and movement logging.
Future<void> showAdjustStockSheet(
  BuildContext context,
  WidgetRef ref,
  Product p,
) async {
  final ctrl = TextEditingController(
    text: p.venduAuPoids
        ? p.stock.toStringAsFixed(2)
        : p.stock.toInt().toString(),
  );
  final causeCtrl = TextEditingController();
  final result = await showModalBottomSheet<(double, String?)>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
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
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final newValue = double.tryParse(ctrl.text);
            final changed = newValue != null && newValue != p.stock;
            final canSave =
                newValue != null &&
                (!changed || causeCtrl.text.trim().isNotEmpty);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: SheetHandle()),
                  const SizedBox(height: 8),
                  Text(
                    'Ajuster le stock',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(p.name, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Text(
                    p.venduAuPoids
                        ? 'Nouveau stock (kg)'
                        : 'Nouveau stock (pcs)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: causeCtrl,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: changed
                          ? 'Cause (obligatoire)'
                          : 'Cause (optionnel)',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      hintText: 'Ex. Produit cassé',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSave
                          ? () {
                              Navigator.pop(sheetContext, (
                                newValue,
                                causeCtrl.text.trim().isEmpty
                                    ? null
                                    : causeCtrl.text.trim(),
                              ));
                            }
                          : null,
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  if (result != null) {
    final (value, cause) = result;
    final delta = value - p.stock;
    ref
        .read(productsProvider.notifier)
        .upsert(p.copyWith(stock: value), motifStock: cause);
    if (delta != 0) {
      // recordStockMovement takes a plain Ref (matching every other
      // stock-mutating flow, which runs from a service/notifier); this
      // sheet only has a WidgetRef, so it logs the movement inline instead.
      ref
          .read(stockMovementsProvider.notifier)
          .record(
            StockMovement(
              id: '${DateTime.now().microsecondsSinceEpoch}${p.id}',
              date: DateTime.now(),
              productId: p.id,
              productName: p.name,
              type: StockMovementType.ajustement,
              quantite: delta,
              stockApres: value,
              motif: cause,
              employeeName: ref.read(authProvider)?.nom ?? 'Inconnu',
            ),
          );
    }
  }
}
