import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/scan_reticle.dart';

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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: widget.isActive,
    );
  }

  void _retry() {
    setState(() => _hasError = false);
    _controller.start();
  }

  /// `errorBuilder` runs during `build`, so flipping state right here would
  /// call `setState` mid-build — defer to the next frame instead.
  void _markError() {
    if (_hasError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasError = true);
    });
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
            errorBuilder: (context, error, child) {
              _markError();
              return _CameraFallback(
                error: error,
                onRetry: _retry,
                onManualFallbackTap: widget.onManualFallbackTap,
              );
            },
          ),
          // Corner marks + scan indicator only make sense once the camera is
          // actually live — showing them over the "access denied" panel would
          // suggest scanning is happening when it isn't.
          if (!_hasError)
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  heightFactor: 0.5,
                  child: Stack(
                    children: [
                      ScanCornerMarks(
                        color: AppColors.gold.withValues(alpha: 0.9),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          return state.isInitialized
                              ? const _ScanLine()
                              : const _ScanPlaceholder();
                        },
                      ),
                    ],
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
                  builder: (context, state, _) {
                    final torchOn = state.torchState == TorchState.on;
                    return _ScannerToolButton(
                      icon: torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      iconColor: torchOn ? AppColors.gold : Colors.white,
                      onTap: () => _controller.toggleTorch(),
                    );
                  },
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
  final Color iconColor;

  const _ScannerToolButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(child: Icon(icon, color: iconColor, size: 20)),
        ),
      ),
    );
  }
}

/// A thin glowing line sweeping top-to-bottom across the reticle to sell
/// "actively scanning" while the camera feed is live.
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment(0, -1 + 2 * _controller.value),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withValues(alpha: 0),
              AppColors.success,
              AppColors.success.withValues(alpha: 0),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.6),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown inside the reticle while the camera is still starting up (granted
/// but not yet streaming frames) so the frame never reads as blank — once
/// [MobileScannerState.isInitialized] flips, this is replaced by [_ScanLine].
class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            color: Colors.white.withValues(alpha: 0.55),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            'Scanner ici',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  static const _compactButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    minimumSize: WidgetStatePropertyAll(Size(0, 0)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    // This fallback also renders inside small fixed-height panels (e.g. the
    // compact Caisse scan widget), so it must never assume generous space —
    // scroll instead of overflow if the container is tighter than the
    // content needs.
    return Container(
      color: AppColors.ink,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_off_rounded,
                    color: AppColors.tealLight,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ElevatedButton(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                        ).merge(_compactButtonStyle),
                        child: const Text('Réessayer'),
                      ),
                      if (onManualFallbackTap != null)
                        TextButton(
                          onPressed: onManualFallbackTap,
                          style: _compactButtonStyle,
                          child: const Text('Saisir le code'),
                        ),
                      if (error.errorCode ==
                          MobileScannerErrorCode.permissionDenied)
                        TextButton.icon(
                          onPressed: () => AppSettings.openAppSettings(),
                          style: _compactButtonStyle,
                          icon: const Icon(
                            Icons.settings_outlined,
                            size: 15,
                            color: AppColors.tealLight,
                          ),
                          label: const Text(
                            'Paramètres',
                            style: TextStyle(color: AppColors.tealLight),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
