import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/formatters.dart';
import '../../models/product.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/press_scale.dart';
import '../../widgets/product_avatar.dart';
import '../../widgets/sheet_handle.dart';

/// Bottom sheet for weight-based sales ("vente au poids"): a dedicated
/// numeric pad computes montant = prix/kg × poids saisi in real time.
class WeightEntrySheet extends StatefulWidget {
  final Product product;
  final double? initialKg;

  const WeightEntrySheet({super.key, required this.product, this.initialKg});

  static Future<double?> show(BuildContext context, Product product, {double? initialKg}) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeightEntrySheet(product: product, initialKg: initialKg),
    );
  }

  @override
  State<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<WeightEntrySheet> {
  late String _input = _formatInitial(widget.initialKg);

  bool get _isEdit => widget.initialKg != null;

  static String _formatInitial(double? value) {
    if (value == null || value <= 0) return '0';
    var text = value.toStringAsFixed(3);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text.isEmpty ? '0' : text;
  }

  double get _poids => double.tryParse(_input) ?? 0;
  double get _montant => _poids * widget.product.prixVente;

  void _tapKey(String key) {
    setState(() {
      if (key == 'back') {
        _input = _input.length > 1 ? _input.substring(0, _input.length - 1) : '0';
        return;
      }
      if (key == '.') {
        if (!_input.contains('.')) _input += '.';
        return;
      }
      if (_input == '0') {
        _input = key;
      } else {
        if (_input.contains('.') && _input.split('.')[1].length >= 3) return;
        _input += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                ProductAvatar(emoji: product.emoji, photoBytes: product.photoBytes, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        '${AppFormat.dtShort(product.prixVente)} / kg',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: AppColors.inkGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                const Text(
                  'POIDS (kg)',
                  style: TextStyle(
                    color: AppColors.tealLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _input,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate(key: ValueKey(_input)).fadeIn(duration: 120.ms),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_montant),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Montant calculé  ${AppFormat.dt(_montant)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NumPad(onKey: _tapKey),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _poids <= 0
                    ? null
                    : () => Navigator.pop(context, _poids),
                child: Text(_isEdit ? 'Mettre à jour' : 'Ajouter au panier'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onKey;

  const _NumPad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: keys.map((k) {
        return PressScale(
          onTap: () => onKey(k),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: k == 'back'
                ? const Icon(Icons.backspace_outlined, size: 19, color: AppColors.textPrimary)
                : Text(
                    k,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
          ),
        );
      }).toList(),
    );
  }
}
