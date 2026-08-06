import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';

/// Tappable field for an optional product expiry date ("date de péremption"),
/// wrapping the built-in [showDatePicker] — no new dependency needed.
class ExpiryDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const ExpiryDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_outlined,
              size: 19,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value != null
                    ? DateFormat('dd/MM/yyyy').format(value!)
                    : 'Aucune',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textFaint,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
