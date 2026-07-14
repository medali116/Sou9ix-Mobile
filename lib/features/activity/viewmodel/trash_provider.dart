import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';

/// Deleting a product, a client, a ticket or a supplier doesn't erase it
/// right away —
/// it lands here first so an admin can undo a mistaken (or someone else's)
/// delete instead of it being gone for good. "Supprimer définitivement" is
/// the only actual destructive step.
class _TrashNotifier<T> extends StateNotifier<List<T>> {
  _TrashNotifier() : super(const []);

  void add(T item) => state = [item, ...state];
}

class ProductsTrashNotifier extends _TrashNotifier<Product> {
  void removeById(String id) => state = state.where((p) => p.id != id).toList();
}

class ClientsTrashNotifier extends _TrashNotifier<Client> {
  void removeById(String id) => state = state.where((c) => c.id != id).toList();
}

class SalesTrashNotifier extends _TrashNotifier<Sale> {
  void removeById(String id) => state = state.where((s) => s.id != id).toList();
}

class SuppliersTrashNotifier extends _TrashNotifier<Supplier> {
  void removeById(String id) => state = state.where((s) => s.id != id).toList();
}

final productsTrashProvider =
    StateNotifierProvider<ProductsTrashNotifier, List<Product>>(
      (ref) => ProductsTrashNotifier(),
    );

final clientsTrashProvider =
    StateNotifierProvider<ClientsTrashNotifier, List<Client>>(
      (ref) => ClientsTrashNotifier(),
    );

final salesTrashProvider =
    StateNotifierProvider<SalesTrashNotifier, List<Sale>>(
      (ref) => SalesTrashNotifier(),
    );

final suppliersTrashProvider =
    StateNotifierProvider<SuppliersTrashNotifier, List<Supplier>>(
      (ref) => SuppliersTrashNotifier(),
    );
