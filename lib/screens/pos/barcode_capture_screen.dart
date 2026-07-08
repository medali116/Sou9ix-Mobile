import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/live_barcode_scanner.dart';

/// Captures a raw barcode value to assign to a product — used when adding
/// or editing a product's own EAN, as opposed to [ScannerScreen] which
/// resolves an existing product from a scanned code during a sale.
class BarcodeCaptureScreen extends StatefulWidget {
  const BarcodeCaptureScreen({super.key});

  @override
  State<BarcodeCaptureScreen> createState() => _BarcodeCaptureScreenState();
}

class _BarcodeCaptureScreenState extends State<BarcodeCaptureScreen> {
  final _manualCtrl = TextEditingController();
  bool _captured = false;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _handleDetect(String code) {
    if (_captured) return;
    setState(() => _captured = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.pop(context, code);
    });
  }

  void _submitManual() {
    final code = _manualCtrl.text.trim();
    if (code.isEmpty) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  const Text(
                    'Code-barres du produit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Stack(
                  children: [
                    LiveBarcodeScanner(
                      onDetect: _handleDetect,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    if (_captured)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text(
                'Tenez le code-barres stable, à 15–20 cm de la caméra,\ndans un endroit bien éclairé — ou saisissez-le manuellement.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Code-barres (EAN)',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _submitManual,
                    style: IconButton.styleFrom(backgroundColor: AppColors.teal),
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
