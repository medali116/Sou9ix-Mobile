import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sou9ix/core/formatters.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/auth/model/user.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/features/pos/view/barcode_capture_screen.dart';
import 'package:sou9ix/core/theme/app_colors.dart';
import 'package:sou9ix/core/theme/app_theme.dart';
import 'package:sou9ix/core/widgets/empty_state.dart';
import 'package:sou9ix/core/widgets/press_scale.dart';
import 'package:sou9ix/core/widgets/product_avatar.dart';
import 'package:sou9ix/core/widgets/sheet_handle.dart';

enum _SortOption {
  defaut,
  prixAsc,
  prixDesc,
  stockAsc,
  stockDesc,
  nomAsc,
  nomDesc,
  faible,
}

extension on _SortOption {
  String get label => switch (this) {
    _SortOption.defaut => 'Par défaut',
    _SortOption.prixAsc => 'Prix ↑',
    _SortOption.prixDesc => 'Prix ↓',
    _SortOption.stockAsc => 'Stock ↑',
    _SortOption.stockDesc => 'Stock ↓',
    _SortOption.nomAsc => 'Nom A-Z',
    _SortOption.nomDesc => 'Nom Z-A',
    _SortOption.faible => 'Produits faibles',
  };

  IconData get icon => switch (this) {
    _SortOption.defaut => Icons.sort_rounded,
    _SortOption.prixAsc => Icons.arrow_upward_rounded,
    _SortOption.prixDesc => Icons.arrow_downward_rounded,
    _SortOption.stockAsc => Icons.arrow_upward_rounded,
    _SortOption.stockDesc => Icons.arrow_downward_rounded,
    _SortOption.nomAsc => Icons.sort_by_alpha_rounded,
    _SortOption.nomDesc => Icons.sort_by_alpha_rounded,
    _SortOption.faible => Icons.warning_amber_rounded,
  };
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _categoryId;
  _SortOption _sort = _SortOption.defaut;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final result = await showModalBottomSheet<_SortOption>(
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
                    for (final option in _SortOption.values)
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

  Future<void> _confirmAndDelete(Product p) async {
    final motifCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Supprimer ce produit ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '« ${p.name} » sera retiré du catalogue. Cette action est réversible depuis la Corbeille.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: motifCtrl,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motif (obligatoire)',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                  hintText: 'Ex. Produit discontinué',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: motifCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(productsProvider.notifier).remove(p.id, motif: motifCtrl.text.trim());
    }
  }

  void _showDetailsSheet(Product p) {
    final categories = ref.read(categoriesProvider);
    final catMatches = categories.where((c) => c.id == p.categorieId);
    final cat = catMatches.isEmpty ? null : catMatches.first;
    showModalBottomSheet(
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
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: SheetHandle()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ProductAvatar(
                      emoji: p.emoji,
                      photoBytes: p.photoBytes,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                cat?.icon ?? Icons.category_rounded,
                                size: 13,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cat?.name ?? 'Sans catégorie',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow(
                  'Prix de vente',
                  p.venduAuPoids
                      ? '${AppFormat.dtShort(p.prixVente)} / kg'
                      : AppFormat.dtShort(p.prixVente),
                ),
                _detailRow(
                  'Prix d\'achat',
                  p.venduAuPoids
                      ? '${AppFormat.dtShort(p.prixAchat)} / kg'
                      : AppFormat.dtShort(p.prixAchat),
                ),
                _detailRow('Marge', '${p.margePct.toStringAsFixed(0)}%'),
                _detailRow(
                  'Stock',
                  p.venduAuPoids
                      ? AppFormat.kg(p.stock)
                      : '${p.stock.toInt()} pcs',
                ),
                _detailRow(
                  'Seuil d\'alerte',
                  p.venduAuPoids
                      ? AppFormat.kg(p.seuilAlerte)
                      : '${p.seuilAlerte.toInt()} pcs',
                ),
                if (p.codeBarres != null)
                  _detailRow('Code-barres', p.codeBarres!),
                if (p.datePeremption != null)
                  _detailRow(
                    'Péremption',
                    DateFormat('dd/MM/yyyy').format(p.datePeremption!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    ),
  );

  void _showHistorySheet(Product p) {
    final sales = ref.read(salesProvider);
    final moves = <({DateTime date, double quantite})>[];
    for (final s in sales) {
      for (final l in s.lignes) {
        if (l.product.id == p.id) {
          moves.add((date: s.dateHeure, quantite: l.quantite));
        }
      }
    }
    moves.sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Historique · ${p.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: moves.isEmpty
                    ? const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Aucun mouvement',
                        message: 'Les ventes de ce produit\napparaîtront ici.',
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: moves.length,
                        separatorBuilder: (_, _) => const Divider(height: 18),
                        itemBuilder: (context, index) {
                          final m = moves[index];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(m.date),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '- ${p.venduAuPoids ? AppFormat.kg(m.quantite) : '${m.quantite.toInt()} pcs'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openProductActions(Product p, bool isAdmin) async {
    final action = await showModalBottomSheet<String>(
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
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAdmin)
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Modifier'),
                        onTap: () => Navigator.pop(context, 'edit'),
                      ),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Voir détails'),
                      onTap: () => Navigator.pop(context, 'details'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Historique'),
                      onTap: () => Navigator.pop(context, 'history'),
                    ),
                    if (isAdmin)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Supprimer',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: () => Navigator.pop(context, 'delete'),
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

    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        context.push('/products/edit', extra: p);
        break;
      case 'delete':
        _confirmAndDelete(p);
        break;
      case 'history':
        _showHistorySheet(p);
        break;
      case 'details':
        _showDetailsSheet(p);
        break;
    }
  }

  Widget _swipeBackground({required bool isEdit}) {
    final color = isEdit ? AppColors.teal : AppColors.danger;
    final icon = isEdit ? Icons.edit_outlined : Icons.delete_outline_rounded;
    final label = isEdit ? 'Modifier' : 'Supprimer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: isEdit ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isEdit
            ? [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ]
            : [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color),
              ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final isAdmin = ref.watch(authProvider)?.role == UserRole.admin;

    var filtered = products
        .where(
          (p) =>
              _query.isEmpty ||
              p.name.toLowerCase().contains(_query.toLowerCase()) ||
              (p.codeBarres?.contains(_query) ?? false),
        )
        .where((p) => _categoryId == null || p.categorieId == _categoryId)
        .toList();

    switch (_sort) {
      case _SortOption.defaut:
        break;
      case _SortOption.prixAsc:
        filtered.sort((a, b) => a.prixVente.compareTo(b.prixVente));
        break;
      case _SortOption.prixDesc:
        filtered.sort((a, b) => b.prixVente.compareTo(a.prixVente));
        break;
      case _SortOption.stockAsc:
        filtered.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case _SortOption.stockDesc:
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case _SortOption.nomAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortOption.nomDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case _SortOption.faible:
        filtered = filtered.where((p) => p.stockFaible).toList()
          ..sort((a, b) => a.stock.compareTo(b.stock));
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Ajouter un produit',
            ),
        ],
      ),
      body: Column(
        children: [
          if (categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom…',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} produit${filtered.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                PressScale(
                  onTap: _openSortSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _sort == _SortOption.defaut
                          ? AppColors.surface
                          : AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _sort == _SortOption.defaut
                            ? AppColors.border
                            : AppColors.teal,
                        width: 1.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_vert_rounded,
                          size: 19,
                          color: _sort == _SortOption.defaut
                              ? AppColors.textPrimary
                              : AppColors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sort == _SortOption.defaut ? 'Trier' : _sort.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _sort == _SortOption.defaut
                                ? AppColors.textPrimary
                                : AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit',
                    message: 'Aucun produit ne correspond\nà votre recherche.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final catMatches = categories.where(
                        (c) => c.id == p.categorieId,
                      );
                      final cat = catMatches.isEmpty ? null : catMatches.first;
                      final card = PressScale(
                        onTap: () => _openProductActions(p, isAdmin),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ProductAvatar(
                                emoji: p.emoji,
                                photoBytes: p.photoBytes,
                                size: 46,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          cat?.icon ?? Icons.category_rounded,
                                          size: 12,
                                          color: AppColors.textFaint,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          cat?.name ?? 'Sans catégorie',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '· marge ${p.margePct.toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    p.venduAuPoids
                                        ? '${AppFormat.dtShort(p.prixVente)} / kg'
                                        : AppFormat.dtShort(p.prixVente),
                                    style: const TextStyle(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _StockTag(product: p),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );

                      final tile = isAdmin
                          ? Dismissible(
                              key: ValueKey(p.id),
                              direction: DismissDirection.horizontal,
                              background: _swipeBackground(isEdit: true),
                              secondaryBackground: _swipeBackground(
                                isEdit: false,
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  context.push('/products/edit', extra: p);
                                } else {
                                  await _confirmAndDelete(p);
                                }
                                return false;
                              },
                              child: card,
                            )
                          : card;

                      return tile.animate().fadeIn(
                        duration: 220.ms,
                        delay: (18 * index).ms,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockTag extends StatelessWidget {
  final Product product;
  const _StockTag({required this.product});

  @override
  Widget build(BuildContext context) {
    final rupture = product.stock <= 0;
    final faible = !rupture && product.stockFaible;
    final color = rupture
        ? AppColors.danger
        : (faible ? AppColors.warning : AppColors.success);
    final label = rupture
        ? 'Rupture'
        : product.venduAuPoids
        ? '${product.stock.toStringAsFixed(1)} kg'
        : '${product.stock.toInt()} pcs';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
