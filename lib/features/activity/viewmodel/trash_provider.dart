import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/service/trash_repository.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/products/model/product.dart';
import 'package:sou9ix/features/sales/model/sale.dart';
import 'package:sou9ix/features/suppliers/model/supplier.dart';

/// Deleting a product, a client, a ticket or a supplier doesn't erase it
/// right away — it lands here first so an admin can undo a mistaken (or
/// someone else's) delete instead of it being gone for good. "Supprimer
/// définitivement" is the only actual destructive step.
class _TrashNotifier<T> extends StateNotifier<List<T>> {
  _TrashNotifier({
    required String? shopCode,
    required String collectionName,
    required Map<String, dynamic> Function(T) toMap,
    required T Function(String, Map<String, dynamic>) fromMap,
    required this.idOf,
  }) : _repo = shopCode == null
           ? null
           : TrashRepository<T>(
               shopCode: shopCode,
               collectionName: collectionName,
               toMap: toMap,
               fromMap: fromMap,
             ),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((items) => state = items);
    }
  }

  final TrashRepository<T>? _repo;
  final String Function(T) idOf;
  StreamSubscription<List<T>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void add(T item) {
    state = [item, ...state];
    _repo?.add(idOf(item), item);
  }

  void _removeMatching(String id, bool Function(T item, String id) matches) {
    state = state.where((item) => !matches(item, id)).toList();
    _repo?.removeById(id);
  }
}

class ProductsTrashNotifier extends _TrashNotifier<Product> {
  ProductsTrashNotifier({required super.shopCode})
    : super(
        collectionName: 'trashProducts',
        toMap: (p) => p.toMap(),
        fromMap: Product.fromMap,
        idOf: (p) => p.id,
      );

  void removeById(String id) => _removeMatching(id, (p, id) => p.id == id);
}

class ClientsTrashNotifier extends _TrashNotifier<Client> {
  ClientsTrashNotifier({required super.shopCode})
    : super(
        collectionName: 'trashClients',
        toMap: (c) => c.toMap(),
        fromMap: Client.fromMap,
        idOf: (c) => c.id,
      );

  void removeById(String id) => _removeMatching(id, (c, id) => c.id == id);
}

class SalesTrashNotifier extends _TrashNotifier<Sale> {
  SalesTrashNotifier({required super.shopCode})
    : super(
        collectionName: 'trashSales',
        toMap: (s) => s.toMap(),
        fromMap: Sale.fromMap,
        idOf: (s) => s.id,
      );

  void removeById(String id) => _removeMatching(id, (s, id) => s.id == id);
}

class SuppliersTrashNotifier extends _TrashNotifier<Supplier> {
  SuppliersTrashNotifier({required super.shopCode})
    : super(
        collectionName: 'trashSuppliers',
        toMap: (s) => s.toMap(),
        fromMap: Supplier.fromMap,
        idOf: (s) => s.id,
      );

  void removeById(String id) => _removeMatching(id, (s, id) => s.id == id);
}

final productsTrashProvider =
    StateNotifierProvider<ProductsTrashNotifier, List<Product>>(
      (ref) => ProductsTrashNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );

final clientsTrashProvider =
    StateNotifierProvider<ClientsTrashNotifier, List<Client>>(
      (ref) => ClientsTrashNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );

final salesTrashProvider =
    StateNotifierProvider<SalesTrashNotifier, List<Sale>>(
      (ref) => SalesTrashNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );

final suppliersTrashProvider =
    StateNotifierProvider<SuppliersTrashNotifier, List<Supplier>>(
      (ref) => SuppliersTrashNotifier(shopCode: ref.watch(currentShopCodeProvider)),
    );
