import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/core/models/discount.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/cart_provider.dart';
import 'package:sou9ix/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/features/pos/viewmodel/pending_sale_provider.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/live_barcode_scanner.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/quantity_stepper.dart';
import 'package:sou9ix/core/routing/app_router.dart';
import 'package:sou9ix/features/pos/view/add_without_barcode_sheet.dart';
import 'package:sou9ix/features/pos/view/client_picker_sheet.dart';
import 'package:sou9ix/features/pos/view/pos_screen.dart';
import 'package:sou9ix/features/pos/view/scanner_screen.dart';
import 'package:sou9ix/features/pos/view/weight_entry_sheet.dart';

/// Main "Caisse" screen: a persistent live-scan panel sits above a running
/// cart that fills up as products are scanned — mirroring how a real
/// handheld POS scanner is used, instead of scan-then-navigate-away.
class ScanSaleScreen extends ConsumerStatefulWidget {
  /// Whether this is the currently selected bottom-nav tab. The screen
  /// stays mounted (via `IndexedStack`) even when another tab is showing,
  /// so its camera must be told explicitly to stand down.
  final bool isActive;

  const ScanSaleScreen({super.key, this.isActive = true});

  @override
  ConsumerState<ScanSaleScreen> createState() => _ScanSaleScreenState();
}

class _ScanSaleScreenState extends ConsumerState<ScanSaleScreen> with RouteAware {
  String? _confirmation;
  bool _confirmationIsError = false;
  int _scanToken = 0;
  bool _isTopRoute = true;

  bool get _cameraActive => widget.isActive && _isTopRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => setState(() => _isTopRoute = false);

  @override
  void didPopNext() => setState(() => _isTopRoute = true);

  /// Fires on every real barcode the live camera decodes.
  void _handleScannedCode(String code) {
    final products = ref.read(productsProvider);
    final matches = products.where((p) => p.codeBarres == code);
    if (matches.isEmpty) {
      _showConfirmation('Code non reconnu : $code', isError: true);
      return;
    }
    _handleResolvedProduct(matches.first);
  }

  /// Demo helper for environments without a usable camera — long-press the
  /// scan panel to simulate reading a random product from the catalogue.
  Future<void> _simulateScan() async {
    final products = ref.read(productsProvider);
    if (products.isEmpty) return;
    final product = products[Random().nextInt(products.length)];
    await _handleResolvedProduct(product);
  }

  Future<void> _openFullScanner() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => const ScannerScreen(), fullscreenDialog: true),
    );
    if (product != null) await _handleResolvedProduct(product);
  }

  /// Compact fallback for a barcode the camera can't read cleanly — types
  /// the EAN directly instead of scanning it.
  Future<void> _manualCodeEntry() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saisir le code-barres'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Code-barres (EAN)'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Valider')),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) {
      _handleScannedCode(code.trim());
    }
  }

  Future<void> _handleResolvedProduct(Product product) async {
    if (product.venduAuPoids) {
      final poids = await WeightEntrySheet.show(context, product);
      if (poids != null && poids > 0) {
        ref.read(cartProvider.notifier).addWeighted(product, poids);
        _showConfirmation(product.name);
      }
    } else {
      ref.read(cartProvider.notifier).addPiece(product);
      _showConfirmation(product.name);
    }
  }

  void _showConfirmation(String text, {bool isError = false}) {
    final token = ++_scanToken;
    setState(() {
      _confirmation = text;
      _confirmationIsError = isError;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && token == _scanToken) setState(() => _confirmation = null);
    });
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerSheet.show(context);
    if (client != null) ref.read(pendingClientProvider.notifier).state = client.id;
  }

  Future<void> _editWeight(Product product, double currentKg) async {
    final updated = await WeightEntrySheet.show(context, product, initialKg: currentKg);
    if (updated != null) {
      ref.read(cartProvider.notifier).updateQuantite(product.id, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final pendingClientId = ref.watch(pendingClientProvider);
    final clients = ref.watch(clientsProvider);
    Client? pendingClient;
    if (pendingClientId != null) {
      final matches = clients.where((c) => c.id == pendingClientId);
      pendingClient = matches.isEmpty ? null : matches.first;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Caisse', style: Theme.of(context).textTheme.displaySmall),
                        Text(
                          user?.magasin ?? 'Sou9ix',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.grid_view_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PosScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: ref.watch(totalAlertsCountProvider) > 0,
                    label: Text('${ref.watch(totalAlertsCountProvider)}'),
                    child: _RoundIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: () => context.push('/alerts'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ScanPanel(
              confirmation: _confirmation,
              confirmationIsError: _confirmationIsError,
              cameraActive: _cameraActive,
              onDetect: _handleScannedCode,
              onDemoScan: _simulateScan,
              onExpand: _openFullScanner,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'Sans code-barres',
                      color: AppColors.teal,
                      onTap: () => AddWithoutBarcodeSheet.show(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.keyboard_alt_outlined,
                      label: 'Saisir le code',
                      color: AppColors.goldDark,
                      onTap: _manualCodeEntry,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cart.isEmpty
                        ? 'Panier'
                        : 'Panier · ${cart.length} article${cart.length > 1 ? 's' : ''} · ${AppFormat.dt(total)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (cart.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).clear();
                        ref.read(cartDiscountProvider.notifier).state = const Discount.none();
                      },
                      child: const Text('Vider'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: cart.isEmpty
                  ? const EmptyState(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scannez pour commencer',
                      message: 'Touchez la zone de scan ou ajoutez\nun produit sans code-barres.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 190),
                      itemCount: cart.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return _CartRow(
                          quantite: item.quantite,
                          sousTotal: item.sousTotal,
                          emoji: item.product.emoji,
                          photoBytes: item.product.photoBytes,
                          name: item.product.name,
                          prixVente: item.product.prixVente,
                          venduAuPoids: item.product.venduAuPoids,
                          onQuantiteChanged: (q) =>
                              ref.read(cartProvider.notifier).updateQuantite(item.product.id, q),
                          onEditWeight: () => _editWeight(item.product, item.quantite),
                          onRemove: () => ref.read(cartProvider.notifier).removeItem(item.product.id),
                        ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.03, end: 0);
                      },
                    ),
            ),
            _BottomActionBar(
              cartEmpty: cart.isEmpty,
              total: total,
              client: pendingClient,
              onScanClient: _pickClient,
              onClearClient: () => ref.read(pendingClientProvider.notifier).state = null,
              onPayer: () => context.push('/checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanPanel extends StatelessWidget {
  final String? confirmation;
  final bool confirmationIsError;
  final bool cameraActive;
  final ValueChanged<String> onDetect;
  final VoidCallback onDemoScan;
  final VoidCallback onExpand;

  const _ScanPanel({
    required this.confirmation,
    required this.confirmationIsError,
    required this.cameraActive,
    required this.onDetect,
    required this.onDemoScan,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        // A real barcode is picked up automatically by the live camera feed;
        // long-press is only a demo shortcut for environments without one.
        onLongPress: onDemoScan,
        child: Container(
          height: 190,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.soft,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: LiveBarcodeScanner(
                  onDetect: onDetect,
                  onManualFallbackTap: onExpand,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  isActive: cameraActive,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 56,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: confirmation == null
                      ? const SizedBox.shrink(key: ValueKey('empty'))
                      : Container(
                          key: ValueKey(confirmation),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: confirmationIsError ? AppColors.danger : AppColors.success,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                confirmationIsError
                                    ? Icons.error_rounded
                                    : Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  confirmationIsError ? confirmation! : 'Ajouté : $confirmation',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onExpand,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final String emoji;
  final Uint8List? photoBytes;
  final String name;
  final double prixVente;
  final bool venduAuPoids;
  final double quantite;
  final double sousTotal;
  final ValueChanged<double> onQuantiteChanged;
  final VoidCallback onEditWeight;
  final VoidCallback onRemove;

  const _CartRow({
    required this.emoji,
    this.photoBytes,
    required this.name,
    required this.prixVente,
    required this.venduAuPoids,
    required this.quantite,
    required this.sousTotal,
    required this.onQuantiteChanged,
    required this.onEditWeight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          ProductAvatar(emoji: emoji, photoBytes: photoBytes, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  venduAuPoids
                      ? '${AppFormat.kg(quantite)} × ${AppFormat.dtShort(prixVente)}'
                      : '${quantite.toInt()} × ${AppFormat.dtShort(prixVente)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (venduAuPoids)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _smallIconBtn(icon: Icons.edit_rounded, onTap: onEditWeight),
                _smallIconBtn(icon: Icons.delete_outline_rounded, onTap: onRemove, color: AppColors.danger),
              ],
            )
          else
            QuantityStepper(quantite: quantite, onChanged: onQuantiteChanged),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                AppFormat.dtShort(sousTotal),
                maxLines: 1,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallIconBtn({required IconData icon, required VoidCallback onTap, Color? color}) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color ?? AppColors.textPrimary),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool cartEmpty;
  final double total;
  final Client? client;
  final VoidCallback onScanClient;
  final VoidCallback onClearClient;
  final VoidCallback onPayer;

  const _BottomActionBar({
    required this.cartEmpty,
    required this.total,
    required this.client,
    required this.onScanClient,
    required this.onClearClient,
    required this.onPayer,
  });

  @override
  Widget build(BuildContext context) {
    final attachedClient = client;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachedClient != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: AppColors.teal),
                        const SizedBox(width: 6),
                        Text(
                          'Client : ${attachedClient.nom}',
                          style: const TextStyle(
                              color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onClearClient,
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScanClient,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scanner client'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: cartEmpty ? null : onPayer,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: Text('Payer${cartEmpty ? '' : ' · ${AppFormat.dt(total)}'}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: AppShadows.card,
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}
