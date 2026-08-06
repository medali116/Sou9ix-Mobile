import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/shared/features/activity/service/trash_repository.dart';
import 'package:sou9ix/shared/features/clients/model/client.dart';
import 'package:sou9ix/shared/features/clients/service/clients_repository.dart';
import 'package:sou9ix/shared/features/products/model/product.dart';
import 'package:sou9ix/shared/features/products/service/products_repository.dart';
import 'package:sou9ix/shared/features/sales/model/sale.dart';
import 'package:sou9ix/shared/features/sales/service/sales_repository.dart';
import 'package:sou9ix/shared/features/settings/viewmodel/shop_code_provider.dart';
import 'package:sou9ix/shared/features/suppliers/model/supplier.dart';
import 'package:sou9ix/shared/features/suppliers/service/suppliers_repository.dart';

/// Deleting a product, a client, a ticket or a supplier doesn't erase it
/// right away —
/// it lands here first so an admin can undo a mistaken (or someone else's)
/// delete instead of it being gone for good. "Supprimer définitivement" is
/// the only actual destructive step.
class _TrashNotifier<T> extends StateNotifier<List<T>> {
  _TrashNotifier(this._repo, this._idOf) : super(const []) {
    final repo = _repo;
    if (repo != null) {
      _sub = repo.watchAll().listen((list) => state = list);
    }
  }

  final TrashRepository<T>? _repo;
  final String Function(T) _idOf;
  StreamSubscription<List<T>>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void add(T item) {
    state = [item, ...state];
    unawaited(_repo?.add(_idOf(item), item));
  }

  void removeById(String id) {
    state = state.where((item) => _idOf(item) != id).toList();
    unawaited(_repo?.removeById(id));
  }
}

class ProductsTrashNotifier extends _TrashNotifier<Product> {
  ProductsTrashNotifier(TrashRepository<Product>? repo)
    : super(repo, (p) => p.id);
}

class ClientsTrashNotifier extends _TrashNotifier<Client> {
  ClientsTrashNotifier(TrashRepository<Client>? repo)
    : super(repo, (c) => c.id);
}

class SalesTrashNotifier extends _TrashNotifier<Sale> {
  SalesTrashNotifier(TrashRepository<Sale>? repo) : super(repo, (s) => s.id);
}

class SuppliersTrashNotifier extends _TrashNotifier<Supplier> {
  SuppliersTrashNotifier(TrashRepository<Supplier>? repo)
    : super(repo, (s) => s.id);
}

final productsTrashProvider =
    StateNotifierProvider<ProductsTrashNotifier, List<Product>>((ref) {
      final shopCode = ref.watch(shopCodeProvider);
      final repo = shopCode == null
          ? null
          : TrashRepository<Product>(
              FirebaseFirestore.instance,
              shopCode,
              'trash_products',
              toFirestore: productToFirestore,
              fromFirestore: productFromFirestore,
            );
      return ProductsTrashNotifier(repo);
    });

final clientsTrashProvider =
    StateNotifierProvider<ClientsTrashNotifier, List<Client>>((ref) {
      final shopCode = ref.watch(shopCodeProvider);
      final repo = shopCode == null
          ? null
          : TrashRepository<Client>(
              FirebaseFirestore.instance,
              shopCode,
              'trash_clients',
              toFirestore: clientToFirestore,
              fromFirestore: clientFromFirestore,
            );
      return ClientsTrashNotifier(repo);
    });

final salesTrashProvider =
    StateNotifierProvider<SalesTrashNotifier, List<Sale>>((ref) {
      final shopCode = ref.watch(shopCodeProvider);
      final repo = shopCode == null
          ? null
          : TrashRepository<Sale>(
              FirebaseFirestore.instance,
              shopCode,
              'trash_sales',
              toFirestore: saleToFirestore,
              fromFirestore: saleFromFirestore,
            );
      return SalesTrashNotifier(repo);
    });

final suppliersTrashProvider =
    StateNotifierProvider<SuppliersTrashNotifier, List<Supplier>>((ref) {
      final shopCode = ref.watch(shopCodeProvider);
      final repo = shopCode == null
          ? null
          : TrashRepository<Supplier>(
              FirebaseFirestore.instance,
              shopCode,
              'trash_suppliers',
              toFirestore: supplierToFirestore,
              fromFirestore: supplierFromFirestore,
            );
      return SuppliersTrashNotifier(repo);
    });
