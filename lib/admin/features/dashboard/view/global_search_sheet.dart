import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sou9ix/shared/core/formatters.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/viewmodel/clients_provider.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/viewmodel/products_provider.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/viewmodel/sales_provider.dart';
import 'package:sou9ix/shared/features/suppliers/model/supplier.dart';
import 'package:sou9ix/shared/features/suppliers/viewmodel/suppliers_provider.dart';
import 'package:sou9ix/shared/core/theme/app_colors.dart';
import 'package:sou9ix/shared/core/theme/app_theme.dart';
import 'package:sou9ix/shared/core/widgets/product_avatar.dart';
import 'package:sou9ix/shared/core/widgets/sheet_handle.dart';

void showGlobalSearchSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _GlobalSearchSheet(),
  );
}

/// One search box across everything the app knows about — produits,
/// clients, tickets, fournisseurs — so an admin doesn't need to remember
/// which tab a given record lives under.
class _GlobalSearchSheet extends ConsumerStatefulWidget {
  const _GlobalSearchSheet();

  @override
  ConsumerState<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<_GlobalSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    List<Product> products = const [];
    List<Client> clients = const [];
    List<Supplier> suppliers = const [];
    List<Sale> sales = const [];

    if (q.isNotEmpty) {
      products = ref
          .watch(productsProvider)
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                (p.codeBarres ?? '').contains(q),
          )
          .take(6)
          .toList();
      clients = ref
          .watch(clientsProvider)
          .where(
            (c) => c.nom.toLowerCase().contains(q) || c.telephone.contains(q),
          )
          .take(6)
          .toList();
      suppliers = ref
          .watch(suppliersProvider)
          .where((s) => s.nom.toLowerCase().contains(q))
          .take(6)
          .toList();
      sales = ref
          .watch(salesProvider)
          .where((s) {
            final reference = s.id.length > 6
                ? s.id.substring(s.id.length - 6).toLowerCase()
                : s.id.toLowerCase();
            return reference.contains(q) ||
                s.lignes.any((l) => l.product.name.toLowerCase().contains(q));
          })
          .take(6)
          .toList();
    }
    final hasResults =
        products.isNotEmpty ||
        clients.isNotEmpty ||
        suppliers.isNotEmpty ||
        sales.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText:
                    'Rechercher un produit, client, ticket, fournisseur...',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ),
          Flexible(
            child: q.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Tapez pour rechercher dans toute l\'application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : !hasResults
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Aucun résultat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    shrinkWrap: true,
                    children: [
                      if (products.isNotEmpty)
                        ..._section(context, 'Produits', [
                          for (final p in products)
                            ListTile(
                              leading: ProductAvatar(
                                emoji: p.emoji,
                                photoBytes: p.photoBytes,
                                size: 36,
                              ),
                              title: Text(p.name),
                              subtitle: Text(AppFormat.dt(p.prixVente)),
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/products/edit', extra: p);
                              },
                            ),
                        ]),
                      if (clients.isNotEmpty)
                        ..._section(context, 'Clients', [
                          for (final c in clients)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.teal.withValues(
                                  alpha: 0.12,
                                ),
                                foregroundColor: AppColors.tealDark,
                                child: Text(c.nom.substring(0, 1)),
                              ),
                              title: Text(c.nom),
                              subtitle: Text(c.telephone),
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/clients/detail', extra: c);
                              },
                            ),
                        ]),
                      if (suppliers.isNotEmpty)
                        ..._section(context, 'Fournisseurs', [
                          for (final s in suppliers)
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.surfaceMuted,
                                child: Icon(
                                  Icons.local_shipping_outlined,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                              title: Text(s.nom),
                              subtitle: Text(s.telephone),
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/suppliers/detail', extra: s);
                              },
                            ),
                        ]),
                      if (sales.isNotEmpty)
                        ..._section(context, 'Tickets', [
                          for (final s in sales)
                            ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.surfaceMuted,
                                child: Icon(
                                  Icons.receipt_outlined,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                'Ticket #${s.id.length > 6 ? s.id.substring(s.id.length - 6).toUpperCase() : s.id.toUpperCase()}',
                              ),
                              subtitle: Text(AppFormat.dt(s.total)),
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/receipt', extra: s);
                              },
                            ),
                        ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<Widget> tiles,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textFaint,
            letterSpacing: 0.5,
          ),
        ),
      ),
      ...tiles,
    ];
  }
}
