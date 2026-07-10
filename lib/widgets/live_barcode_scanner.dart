import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'scan_reticle.dart';

/// A real, live camera barcode scanner (via `mobile_scanner`) framed with
/// the app's scan reticle. Falls back to a friendly "no camera" panel with
/// a manual/demo action when the camera is unavailable or permission is
/// denied — e.g. running on a desktop without a webcam, or in a browser
/// that blocked the permission prompt.
class LiveBarcodeScanner extends StatefulWidget {
  final ValueChanged<String> onDetect;
  final VoidCallback? onManualFallbackTap;
  final BorderRadius borderRadius;

  /// Whether this scanner should be holding the camera right now. Only one
  /// camera session can be open at a time on most platforms/browsers, so
  /// any screen that keeps a [LiveBarcodeScanner] mounted in the background
  /// (e.g. a bottom-nav tab preserved by an `IndexedStack`) must flip this
  /// to false while another screen is on top or another tab is selected —
  /// otherwise the next scanner to start fails with "camera unavailable".
  final bool isActive;

  const LiveBarcodeScanner({
    super.key,
    required this.onDetect,
    this.onManualFallbackTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
    this.isActive = true,
  });

  @override
  State<LiveBarcodeScanner> createState() => _LiveBarcodeScannerState();
}

class _LiveBarcodeScannerState extends State<LiveBarcodeScanner> {
  late final MobileScannerController _controller;
  String? _lastCode;
  DateTime? _lastDetectedAt;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: widget.isActive,
    );
  }

  @override
  void didUpdateWidget(covariant LiveBarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    final now = DateTime.now();
    final isRepeat =
        value == _lastCode &&
        _lastDetectedAt != null &&
        now.difference(_lastDetectedAt!) < const Duration(seconds: 2);
    if (isRepeat) return;

    _lastCode = value;
    _lastDetectedAt = now;
    widget.onDetect(value);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error, child) => _CameraFallback(
              error: error,
              onRetry: () => _controller.start(),
              onManualFallbackTap: widget.onManualFallbackTap,
            ),
          ),
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 0.5,
                child: ScanCornerMarks(
                  color: AppColors.gold.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ScannerToolButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: () => _controller.switchCamera(),
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (context, state, _) => _ScannerToolButton(
                    icon: state.torchState == TorchState.on
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () => _controller.toggleTorch(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ScannerToolButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback? onManualFallbackTap;

  const _CameraFallback({
    required this.error,
    required this.onRetry,
    this.onManualFallbackTap,
  });

  String get _message {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Accès à la caméra refusé.\nAutorisez la caméra pour scanner en direct.';
      case MobileScannerErrorCode.unsupported:
        return 'Caméra non disponible sur cet appareil.';
      default:
        return 'Impossible d\'ouvrir la caméra.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: AppColors.tealLight,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Text('Réessayer'),
              ),
              if (onManualFallbackTap != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onManualFallbackTap,
                  child: const Text('Saisir le code'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
