import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/core/models/discount.dart';
import 'package:sou9ix/shared/features/auth/model/user.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/alerts/viewmodel/alerts_provider.dart';
import 'package:sou9ix/shared/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/shared/features/caisse/view/ma_caisse_sheet.dart';
import 'package:sou9ix/shared/features/caisse/view/open_cash_session_sheet.dart';
import 'package:sou9ix/shared/features/employees/model/employee.dart';
import 'package:sou9ix/shared/features/employees/model/shift.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/employees_provider.dart';
import 'package:sou9ix/shared/features/employees/viewmodel/shifts_provider.dart';
import 'package:sou9ix/shared/features/pos/viewmodel/cart_provider.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/live_barcode_scanner.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/quantity_stepper.dart';
import 'package:sou9ix/shared/core/widgets/weight_stepper.dart';
import 'package:sou9ix/shared/core/routing/route_observer.dart';
import 'package:sou9ix/shared/features/pos/view/add_without_barcode_sheet.dart';
import 'package:sou9ix/shared/features/pos/view/pos_screen.dart';
import 'package:sou9ix/shared/features/pos/view/scanner_screen.dart';
import 'package:sou9ix/shared/features/pos/view/weight_entry_sheet.dart';

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

class _ScanSaleScreenState extends ConsumerState<ScanSaleScreen>
    with RouteAware {
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
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
        fullscreenDialog: true,
      ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Valider'),
          ),
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

  Future<void> _editWeight(Product product, double currentKg) async {
    final updated = await WeightEntrySheet.show(
      context,
      product,
      initialKg: currentKg,
    );
    if (updated != null) {
      ref.read(cartProvider.notifier).updateQuantite(product.id, updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final cart = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);

    final activeEmployeeId = ref.watch(activeEmployeeProvider);
    Shift? openShift;
    Employee? activeEmployee;
    if (activeEmployeeId != null) {
      for (final s in ref.watch(shiftsProvider)) {
        if (s.employeeId == activeEmployeeId && s.enCours) {
          openShift = s;
          break;
        }
      }
      for (final e in ref.watch(employeesProvider)) {
        if (e.id == activeEmployeeId) {
          activeEmployee = e;
          break;
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Caisse',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            if (openShift != null) ...[
                              const SizedBox(width: 8),
                              const _StatusPill(
                                label: 'Ouvert',
                                color: AppColors.success,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          user?.magasin ?? 'Sou9ix',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.point_of_sale_rounded,
                    tooltip: 'Caisse',
                    onTap: () {
                      if (openShift != null && activeEmployee != null) {
                        showMaCaisseSheet(context, openShift, activeEmployee);
                        return;
                      }
                      final employeeId = user?.employeeId;
                      final matches = employeeId == null
                          ? const <Employee>[]
                          : ref
                                .read(employeesProvider)
                                .where((e) => e.id == employeeId);
                      if (matches.isNotEmpty) {
                        showOpenCashSessionSheet(context, ref, matches.first);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconButton(
                    icon: Icons.grid_view_rounded,
                    tooltip: 'Modules',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PosScreen()),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconButton(
                    icon: Icons.notifications_none_rounded,
                    tooltip: 'Alertes',
                    badgeCount: ref.watch(totalAlertsCountProvider),
                    onTap: () => context.push('/alerts'),
                  ),
                  if (user != null) ...[
                    const SizedBox(width: 8),
                    _UserChip(user: user),
                  ],
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
                    'Panier (${cart.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (cart.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).clear();
                        ref.read(cartDiscountProvider.notifier).state =
                            const Discount.none();
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
                      message:
                          'Touchez la zone de scan ou ajoutez\nun produit sans code-barres.',
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
                              onQuantiteChanged: (q) => ref
                                  .read(cartProvider.notifier)
                                  .updateQuantite(item.product.id, q),
                              onEditWeight: () =>
                                  _editWeight(item.product, item.quantite),
                              onIncrementWeight: () => ref
                                  .read(cartProvider.notifier)
                                  .incrementWeightUnit(item.product.id),
                              onDecrementWeight: () => ref
                                  .read(cartProvider.notifier)
                                  .decrementWeightUnit(item.product.id),
                              onRemove: () => ref
                                  .read(cartProvider.notifier)
                                  .removeItem(item.product.id),
                            )
                            .animate()
                            .fadeIn(duration: 200.ms)
                            .slideX(begin: 0.03, end: 0);
                      },
                    ),
            ),
            if (cart.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _CartSummaryRow(
                  itemCount: cart.length,
                  total: total,
                  discountOff: discount.amountOff(subtotal),
                ),
              ),
            _BottomActionBar(
              cartEmpty: cart.isEmpty,
              total: total,
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
      child: Center(
        // Narrower than the full available width — this panel only needs
        // to frame a barcode, not stretch edge to edge.
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: GestureDetector(
            // A real barcode is picked up automatically by the live camera
            // feed; long-press is only a demo shortcut for environments
            // without one.
            onLongPress: onDemoScan,
            child: Container(
              // Just tall enough to frame a barcode — the panel's job is
              // scanning, not filling the screen, so it stays compact and
              // leaves more room for the cart below.
              height: 148,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: confirmationIsError
                                    ? AppColors.danger
                                    : AppColors.success,
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
                                      confirmationIsError
                                          ? confirmation!
                                          : 'Ajouté : $confirmation',
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
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  final VoidCallback onIncrementWeight;
  final VoidCallback onDecrementWeight;
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
    required this.onIncrementWeight,
    required this.onDecrementWeight,
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
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
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
          if (venduAuPoids) ...[
            WeightStepper(
              totalKg: quantite,
              onIncrement: onIncrementWeight,
              onDecrement: onDecrementWeight,
              onTapLabel: onEditWeight,
            ),
            _smallIconBtn(
              icon: Icons.delete_outline_rounded,
              onTap: onRemove,
              color: AppColors.danger,
            ),
          ] else ...[
            QuantityStepper(quantite: quantite, onChanged: onQuantiteChanged),
            _smallIconBtn(
              icon: Icons.delete_outline_rounded,
              onTap: onRemove,
              color: AppColors.danger,
            ),
          ],
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

  Widget _smallIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
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
  final VoidCallback onPayer;

  const _BottomActionBar({
    required this.cartEmpty,
    required this.total,
    required this.onPayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 88),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: cartEmpty ? null : onPayer,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          child: Text('Payer${cartEmpty ? '' : ' · ${AppFormat.dt(total)}'}'),
        ),
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
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded status badge next to the "Caisse" title — e.g. "Ouvert"
/// while a shift is running.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Who's signed in, shown top-right of the Caisse header — tapping it
/// offers to sign out, without needing a trip to the Profil tab.
class _UserChip extends ConsumerWidget {
  final AppUser user;

  const _UserChip({required this.user});

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final action = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(1000, 80, 20, 0),
      items: const [
        PopupMenuItem(value: 'logout', child: Text('Se déconnecter')),
      ],
    );
    if (action == 'logout' && context.mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/login');
    }
  }

  String _roleLabel(UserRole role) =>
      role == UserRole.admin ? 'Administrateur' : 'Caissier';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressScale(
      onTap: () => _handleTap(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.teal.withValues(alpha: 0.12),
              foregroundColor: AppColors.tealDark,
              backgroundImage: user.photoBytes != null
                  ? MemoryImage(user.photoBytes!)
                  : null,
              child: user.photoBytes != null
                  ? null
                  : const Icon(Icons.person_rounded, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.nom,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _roleLabel(user.role),
                  style: const TextStyle(
                    color: AppColors.textFaint,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three labeled shortcuts under the header (Caisse/Modules/
/// Alertes) — icon + label together, instead of a bare icon, so each
/// button's purpose is legible at a glance.
/// Small round icon button for the header row (Caisse/Modules/Alertes) —
/// sits right next to the user chip, so no room (or need) for a text
/// label; the [tooltip] carries the same meaning on long-press.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: AppShadows.card,
          ),
          child: Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            child: Icon(icon, color: AppColors.textPrimary, size: 17),
          ),
        ),
      ),
    );
  }
}

/// Compact "Articles / Total / Remise" recap shown above the payment bar
/// once the cart isn't empty — so the running numbers are clear without
/// having to read every line.
class _CartSummaryRow extends StatelessWidget {
  final int itemCount;
  final double total;
  final double discountOff;

  const _CartSummaryRow({
    required this.itemCount,
    required this.total,
    required this.discountOff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            color: AppColors.teal,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: _summaryCell(context, 'Articles', '$itemCount')),
          Expanded(child: _summaryCell(context, 'Total', AppFormat.dt(total))),
          Expanded(
            child: _summaryCell(
              context,
              'Remise',
              AppFormat.dt(discountOff),
              valueColor: discountOff > 0 ? AppColors.goldDark : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
