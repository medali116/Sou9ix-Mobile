import 'package:flutter/material.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

/// A -/+ quantity control for piece-counted cart lines. The number always
/// stays centered in a fixed-width slot between two fixed-size buttons —
/// regardless of whether the quantity is 1 or 999 — instead of the digits
/// pushing the buttons around or overflowing. Tapping the number itself
/// opens a small dialog to type a quantity directly (e.g. 150) rather than
/// tapping + one at a time.
class QuantityStepper extends StatelessWidget {
  final double quantite;
  final ValueChanged<double> onChanged;
  final double buttonSize;
  final double minWidth;
  final Color buttonColor;
  final double buttonSpacing;

  const QuantityStepper({
    super.key,
    required this.quantite,
    required this.onChanged,
    this.buttonSize = 26,
    this.minWidth = 64,
    this.buttonColor = AppColors.surfaceMuted,
    this.buttonSpacing = 2,
  });

  Future<void> _editManually(BuildContext context) async {
    final ctrl = TextEditingController(text: quantite.toInt().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantité'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          onSubmitted: (v) => Navigator.pop(context, double.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) onChanged(result);
  }

  Widget _button({required IconData icon, required VoidCallback onTap}) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        margin: EdgeInsets.symmetric(horizontal: buttonSpacing),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          icon: Icons.remove_rounded,
          onTap: () => onChanged(quantite - 1),
        ),
        SizedBox(
          width: minWidth,
          child: PressScale(
            onTap: () => _editManually(context),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  quantite.toInt().toString(),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
        _button(icon: Icons.add_rounded, onTap: () => onChanged(quantite + 1)),
      ],
    );
  }
}
