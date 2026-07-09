import 'package:flutter/material.dart';

import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

/// Small sheet to set (or clear) a [Discount] — reused for both a cart
/// line's own discount and the whole ticket's discount at checkout, so the
/// two never drift into different UIs for the same concept.
class DiscountEditorSheet extends StatefulWidget {
  final String title;
  final Discount initial;

  const DiscountEditorSheet({
    super.key,
    required this.title,
    required this.initial,
  });

  static Future<Discount?> show(
    BuildContext context, {
    required String title,
    required Discount initial,
  }) {
    return showModalBottomSheet<Discount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DiscountEditorSheet(title: title, initial: initial),
    );
  }

  @override
  State<DiscountEditorSheet> createState() => _DiscountEditorSheetState();
}

class _DiscountEditorSheetState extends State<DiscountEditorSheet> {
  late DiscountType _type;
  late final TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initial.isNone ? DiscountType.percent : widget.initial.type;
    _valueCtrl = TextEditingController(
      text: widget.initial.isNone
          ? ''
          : widget.initial.value.toStringAsFixed(
              widget.initial.value.truncateToDouble() == widget.initial.value
                  ? 0
                  : 3,
            ),
    );
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (value == null || value <= 0) {
      Navigator.pop(context, const Discount.none());
      return;
    }
    Navigator.pop(
      context,
      _type == DiscountType.percent
          ? Discount.percent(value.clamp(0, 100))
          : Discount.amount(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Pourcentage (%)'),
                    selected: _type == DiscountType.percent,
                    onSelected: (_) =>
                        setState(() => _type = DiscountType.percent),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Montant (DT)'),
                    selected: _type == DiscountType.amount,
                    onSelected: (_) =>
                        setState(() => _type = DiscountType.amount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Valeur',
                prefixIcon: const Icon(Icons.local_offer_outlined),
                hintText: _type == DiscountType.percent ? '0 %' : '0.000 DT',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (!widget.initial.isNone)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, const Discount.none()),
                      child: const Text('Retirer la remise'),
                    ),
                  ),
                if (!widget.initial.isNone) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
