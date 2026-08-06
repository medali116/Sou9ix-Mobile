import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sou9ix/shared/features/products/model/product.dart';

/// Firestore-backed CRUD for `shops/{shopCode}/products`. Deliberately does
/// not persist [Product.photoBytes] — photo sync needs Firebase Storage,
/// out of scope for this stage (see [SuppliersRepository] for the same
/// note). Stock mutations use [FieldValue.increment] rather than a
/// read-then-write, so `ProductsNotifier`'s `decrementStock`/`restock`/
/// `adjustStock` stay safe under concurrent writes from both apps without
/// needing a transaction of their own.
class ProductsRepository {
  ProductsRepository(this._firestore, this._shopCode);

  final FirebaseFirestore _firestore;
  final String _shopCode;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(_shopCode).collection('products');

  Stream<List<Product>> watchAll() => _collection.snapshots().map(
    (snap) => snap.docs.map((d) => _fromFirestore(d.id, d.data())).toList(),
  );

  Future<void> upsert(Product product) =>
      _collection.doc(product.id).set(productToFirestore(product));

  Future<void> remove(String id) => _collection.doc(id).delete();

  Future<void> incrementStock(String id, double delta) =>
      _collection.doc(id).update({'stock': FieldValue.increment(delta)});

  Future<void> setPurchasePrice(String id, double prixAchat) =>
      _collection.doc(id).update({'prixAchat': prixAchat});

  Future<void> bootstrapIfEmpty(List<Product> seed) async {
    final snapshot = await _collection.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final product in seed) {
      batch.set(_collection.doc(product.id), productToFirestore(product));
    }
    await batch.commit();
  }

  static Product _fromFirestore(String id, Map<String, dynamic> data) =>
      productFromFirestore(id, data);
}

/// Public so domains that embed a full [Product] snapshot (e.g. [Sale]'s
/// cart lines, via `CartItem.product`) can reuse the exact same codec
/// instead of duplicating it.
Map<String, dynamic> productToFirestore(Product product) => {
  'name': product.name,
  'emoji': product.emoji,
  'prixVente': product.prixVente,
  'prixAchat': product.prixAchat,
  'codeBarres': product.codeBarres,
  'venduAuPoids': product.venduAuPoids,
  'categorieId': product.categorieId,
  'stock': product.stock,
  'seuilAlerte': product.seuilAlerte,
  'datePeremption': product.datePeremption == null
      ? null
      : Timestamp.fromDate(product.datePeremption!),
};

Product productFromFirestore(String id, Map<String, dynamic> data) => Product(
  id: id,
  name: data['name'] as String? ?? '',
  emoji: data['emoji'] as String? ?? '',
  prixVente: (data['prixVente'] as num?)?.toDouble() ?? 0,
  prixAchat: (data['prixAchat'] as num?)?.toDouble() ?? 0,
  codeBarres: data['codeBarres'] as String?,
  venduAuPoids: data['venduAuPoids'] as bool? ?? false,
  categorieId: data['categorieId'] as String? ?? '',
  stock: (data['stock'] as num?)?.toDouble() ?? 0,
  seuilAlerte: (data['seuilAlerte'] as num?)?.toDouble() ?? 0,
  datePeremption: (data['datePeremption'] as Timestamp?)?.toDate(),
);
