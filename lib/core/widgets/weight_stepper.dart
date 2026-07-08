import 'package:flutter/material.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';

/// A -/+ control for weighed cart lines, mirroring [QuantityStepper]'s look
/// but stepping by the line's per-unit weight (e.g. 2kg entered once →
/// tapping + adds another 2kg) instead of a flat 1. Tapping the total-weight
/// label itself hands off to [onTapLabel] to re-type an exact weight.
class WeightStepper extends StatelessWidget {
  final double totalKg;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTapLabel;
  final double buttonSize;
  final double minWidth;
  final Color buttonColor;
  final double buttonSpacing;

  const WeightStepper({
    super.key,
    required this.totalKg,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTapLabel,
    this.buttonSize = 26,
    this.minWidth = 72,
    this.buttonColor = AppColors.surfaceMuted,
    this.buttonSpacing = 2,
  });

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
        _button(icon: Icons.remove_rounded, onTap: onDecrement),
        SizedBox(
          width: minWidth,
          child: PressScale(
            onTap: onTapLabel,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppFormat.kg(totalKg),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        _button(icon: Icons.add_rounded, onTap: onIncrement),
      ],
    );
  }
}
