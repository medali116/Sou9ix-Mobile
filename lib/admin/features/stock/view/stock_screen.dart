import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/stock/viewmodel/stock_value_provider.dart';
import 'package:sou9ix/shared/features/pos/view/barcode_capture_screen.dart';
import 'package:sou9ix/shared/features/stock/view/adjust_stock_sheet.dart';
import 'package:sou9ix/shared/core/shell/bottom_nav_visibility_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/empty_state.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/press_scale.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';
import 'package:sou9ix/shared/core/widgets/stock_bar.dart';

enum _StockSort { defaut, nom, quantite, categorie, date }

extension on _StockSort {
  String get label => switch (this) {
    _StockSort.defaut => 'Par défaut',
    _StockSort.nom => 'Nom',
    _StockSort.quantite => 'Quantité',
    _StockSort.categorie => 'Catégorie',
    _StockSort.date => 'Date de péremption',
  };

  IconData get icon => switch (this) {
    _StockSort.defaut => Icons.swap_vert_rounded,
    _StockSort.nom => Icons.sort_by_alpha_rounded,
    _StockSort.quantite => Icons.numbers_rounded,
    _StockSort.categorie => Icons.category_rounded,
    _StockSort.date => Icons.event_outlined,
  };
}

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final _searchCtrl = TextEditingController();
  bool _onlyLow = false;
  bool _statsVisible = true;
  String _query = '';
  String? _categoryId;
  _StockSort _sort = _StockSort.defaut;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _statsVisible) {
      setState(() => _statsVisible = false);
      ref.read(bottomNavVisibleProvider.notifier).state = false;
    } else if (notification.direction == ScrollDirection.forward &&
        !_statsVisible) {
      setState(() => _statsVisible = true);
      ref.read(bottomNavVisibleProvider.notifier).state = true;
    }
    return false;
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const BarcodeCaptureScreen(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      setState(() {
        _searchCtrl.text = code;
        _query = code;
      });
    }
  }

  Future<void> _openSortSheet() async {
    final result = await showModalBottomSheet<_StockSort>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trier par',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in _StockSort.values)
                      ListTile(
                        leading: Icon(
                          option.icon,
                          color: _sort == option
                              ? AppColors.teal
                              : AppColors.textFaint,
                        ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: _sort == option
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _sort == option
                                ? AppColors.teal
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: _sort == option
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.teal,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, option),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _sort = result);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final categories = ref.watch(categoriesProvider);

    final ruptureCount = products.where((p) => p.stock <= 0).length;
    final faibleCount = products
        .where((p) => p.stockFaible && p.stock > 0)
        .length;
    final stockValue = ref.watch(currentStockValueProvider);

    var list = (_onlyLow ? lowStock : products)
        .where(
          (p) =>
              _query.isEmpty ||
              p.name.toLowerCase().contains(_query.toLowerCase()) ||
              (p.codeBarres?.contains(_query) ?? false),
        )
        .where((p) => _categoryId == null || p.categorieId == _categoryId)
        .toList();

    switch (_sort) {
      case _StockSort.defaut:
        break;
      case _StockSort.nom:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _StockSort.quantite:
        list.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case _StockSort.categorie:
        String catName(String id) => categories
            .firstWhere((c) => c.id == id, orElse: () => categories.first)
            .name;
        list.sort(
          (a, b) => catName(a.categorieId).compareTo(catName(b.categorieId)),
        );
        break;
      case _StockSort.date:
        list.sort((a, b) {
          if (a.datePeremption == null && b.datePeremption == null) return 0;
          if (a.datePeremption == null) return 1;
          if (b.datePeremption == null) return -1;
          return a.datePeremption!.compareTo(b.datePeremption!);
        });
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de stock'),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/new'),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nouveau produit',
          ),
          IconButton(
            onPressed: () => context.push('/stock/receipt'),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            tooltip: 'Réceptionner un achat',
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_statsVisible
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _QuickStat(
                                icon: Icons.inventory_2_outlined,
                                color: AppColors.teal,
                                value: '${products.length}',
                                label: 'Total produits',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickStat(
                                icon: Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                value: '$faibleCount',
                                label: 'Stock faible',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickStat(
                                icon: Icons.remove_circle_outline_rounded,
                                color: AppColors.danger,
                                value: '$ruptureCount',
                                label: 'Rupture',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.inkGradient,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: AppColors.tealLight,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Valeur du stock · au prix d\'achat',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                AppFormat.dt(stockValue),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Tous'),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        onSelected: (_) => setState(() => _categoryId = c.id),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: _scanBarcode,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.teal,
                        ),
                        tooltip: 'Scanner un code-barres',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PressScale(
                  onTap: _openSortSheet,
                  child: Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _sort == _StockSort.defaut
                          ? AppColors.surface
                          : AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _sort == _StockSort.defaut
                            ? AppColors.border
                            : AppColors.teal,
                        width: 1.3,
                      ),
                    ),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: _sort == _StockSort.defaut
                          ? AppColors.textPrimary
                          : AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lowStock.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_statsVisible
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      margin: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${lowStock.length} produit${lowStock.length > 1 ? 's' : ''} à réapprovisionner',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _onlyLow = !_onlyLow),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.warning,
                            ),
                            child: Text(
                              _onlyLow
                                  ? 'Tous les produits'
                                  : 'Voir les ${lowStock.length} produits →',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
            ),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScrollNotification,
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Tout est en ordre',
                      message: 'Aucun produit en stock faible\npour le moment.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = list[index];
                        return Slidable(
                          key: ValueKey(p.id),
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.28,
                            children: [
                              SlidableAction(
                                onPressed: (_) =>
                                    context.push('/products/edit', extra: p),
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                icon: Icons.edit_outlined,
                                label: 'Modifier',
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ],
                          ),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.5,
                            children: [
                              SlidableAction(
                                onPressed: (_) =>
                                    showAdjustStockSheet(context, ref, p),
                                backgroundColor: AppColors.goldDark,
                                foregroundColor: Colors.white,
                                icon: Icons.tune_rounded,
                                label: 'Ajuster',
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              SlidableAction(
                                onPressed: (_) =>
                                    context.push('/returns/new', extra: p),
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                icon: Icons.remove_shopping_cart_outlined,
                                label: 'Perte',
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ],
                          ),
                          child: Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              onTap: () =>
                                  context.push('/stock/detail', extra: p),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ProductAvatar(
                                          emoji: p.emoji,
                                          photoBytes: p.photoBytes,
                                          size: 32,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        Text(
                                          p.venduAuPoids
                                              ? AppFormat.kg(p.stock)
                                              : '${p.stock.toInt()} pcs',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: p.stock <= 0
                                                ? AppColors.danger
                                                : p.stockFaible
                                                ? AppColors.warning
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    StockBar(
                                      quantite: p.stock,
                                      seuil: p.seuilAlerte,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Seuil d\'alerte : ${p.seuilAlerte.toStringAsFixed(1)} ${p.unite}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        _StockStatusBadge(product: p),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          duration: 220.ms,
                          delay: (18 * index).ms,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _QuickStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockStatusBadge extends StatelessWidget {
  final Product product;
  const _StockStatusBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    final rupture = product.stock <= 0;
    final faible = !rupture && product.stockFaible;
    final color = rupture
        ? AppColors.danger
        : (faible ? AppColors.warning : AppColors.success);
    final label = rupture ? 'Rupture' : (faible ? 'Stock faible' : 'En stock');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
