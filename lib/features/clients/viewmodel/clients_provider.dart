import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/activity/model/activity_log_entry.dart';
import 'package:sou9ix/features/activity/viewmodel/activity_log_provider.dart';
import 'package:sou9ix/features/activity/viewmodel/trash_provider.dart';
import 'package:sou9ix/features/auth/viewmodel/auth_provider.dart';
import 'package:sou9ix/features/clients/model/client.dart';
import 'package:sou9ix/features/clients/service/clients_repository.dart';
import 'package:sou9ix/features/sales/model/sale.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  ClientsNotifier(
    this._ref, {
    required String? shopCode,
    ClientsRepository? repository,
  }) : _repo = shopCode == null
           ? null
           : (repository ?? ClientsRepository(shopCode: shopCode)),
       super([]) {
    final repo = _repo;
    if (repo != null) {
      _subscription = repo.watchAll().listen((clients) => state = clients);
    }
  }

  final Ref _ref;
  final ClientsRepository? _repo;
  StreamSubscription<List<Client>>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Brings a client back from the Corbeille.
  void restore(Client client) {
    state = [...state, client];
    _repo?.upsert(client);
  }

  /// Registers a new client on the fly (e.g. from the checkout screen when
  /// a credit customer isn't in the karné yet) and returns it so the caller
  /// can immediately select it.
  Client addClient({required String nom, required String telephone}) {
    final client = Client(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nom: nom,
      telephone: telephone,
      creditTotal: 0,
      dernierAchat: DateTime.now(),
    );
    state = [...state, client];
    _repo?.upsert(client);
    logActivity(
      _ref,
      category: ActivityCategory.clients,
      impact: ActivityImpact.ajout,
      action: 'Nouveau client',
      targetName: client.nom,
    );
    return client;
  }

  /// Adds (or, with a negative [montant], reverses) credit on a client's
  /// karné as a *side effect of a sale* (see [SaleService]) — clamped at 0
  /// like [settle]. Deliberately not logged as a [ClientTransaction]: the
  /// [Sale] record itself is the timeline entry for this change.
  void addCredit(String clientId, double montant) {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal + montant).clamp(0, double.infinity),
          ))
        else
          c,
    ];
    if (updated != null) _repo?.upsert(updated);
  }

  /// Manual credit adjustment from the "Ajouter crédit" action — unlike
  /// [addCredit], this has no [Sale] behind it, so it's logged as an
  /// [ClientTransactionType.ajustement] to keep the client's timeline
  /// complete.
  void addManualCredit(String clientId, double montant, {String? notes}) {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal + montant).clamp(0, double.infinity),
            transactions: [
              ...c.transactions,
              ClientTransaction(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                type: ClientTransactionType.ajustement,
                montant: montant,
                date: DateTime.now(),
                notes: notes,
              ),
            ],
          ))
        else
          c,
    ];
    if (updated != null) _repo?.upsert(updated);
  }

  /// Records a payment collected against a client's karné — clamps the
  /// balance at 0 and logs a [ClientTransaction] so it shows up in their
  /// timeline (unlike [addCredit], which isn't itself a payment).
  ///
  /// [creditSalesOldestFirst] — that client's credit [Sale]s, oldest first —
  /// is used to allocate the payment FIFO: the oldest unpaid/partially-paid
  /// ticket is settled first, then the next, until the payment is used up.
  /// Any leftover past the last tracked ticket (e.g. a legacy balance with
  /// no ticket behind it) is simply not tied to a specific ticket.
  void settle(
    String clientId,
    double montant, {
    List<Sale> creditSalesOldestFirst = const [],
    PaymentMethod? modePaiement,
    String? notes,
  }) {
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == clientId)
          (updated = c.copyWith(
            creditTotal: (c.creditTotal - montant).clamp(0, double.infinity),
            transactions: [
              ...c.transactions,
              ClientTransaction(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                type: ClientTransactionType.paiement,
                montant: montant,
                date: DateTime.now(),
                modePaiement: modePaiement,
                notes: notes,
                allocations: _allocateFifo(c, montant, creditSalesOldestFirst),
              ),
            ],
          ))
        else
          c,
    ];
    if (updated != null) _repo?.upsert(updated);
    final client = state.where((c) => c.id == clientId);
    logActivity(
      _ref,
      category: ActivityCategory.clients,
      impact: ActivityImpact.paiement,
      action: 'Paiement client',
      targetName: client.isEmpty ? null : client.first.nom,
      montant: montant,
      motif: notes,
    );
  }

  List<PaymentAllocation> _allocateFifo(
    Client c,
    double montant,
    List<Sale> creditSalesOldestFirst,
  ) {
    final alreadyPaid = <String, double>{};
    for (final t in c.transactions) {
      for (final a in t.allocations) {
        alreadyPaid[a.saleId] = (alreadyPaid[a.saleId] ?? 0) + a.montant;
      }
    }

    var remaining = montant;
    final allocations = <PaymentAllocation>[];
    for (final sale in creditSalesOldestFirst) {
      if (remaining <= 0) break;
      final saleRemaining = sale.total - (alreadyPaid[sale.id] ?? 0);
      if (saleRemaining <= 0) continue;
      final toApply = remaining < saleRemaining ? remaining : saleRemaining;
      allocations.add(PaymentAllocation(saleId: sale.id, montant: toApply));
      remaining -= toApply;
    }
    return allocations;
  }

  void updateClient(
    String id, {
    required String nom,
    required String telephone,
    String? adresse,
    String? notes,
    double? limiteCredit,
  }) {
    final matches = state.where((c) => c.id == id);
    final old = matches.isEmpty ? null : matches.first;
    Client? updated;
    state = [
      for (final c in state)
        if (c.id == id)
          (updated = c.copyWith(
            nom: nom,
            telephone: telephone,
            adresse: adresse,
            notes: notes,
            limiteCredit: limiteCredit,
          ))
        else
          c,
    ];
    if (updated != null) _repo?.upsert(updated);
    if (old != null) {
      if (old.nom != nom) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Nom',
          ancienneValeur: old.nom,
          nouvelleValeur: nom,
        );
      }
      if (old.telephone != telephone) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Téléphone',
          ancienneValeur: old.telephone,
          nouvelleValeur: telephone,
        );
      }
      if (old.adresse != adresse) {
        logActivity(
          _ref,
          category: ActivityCategory.clients,
          impact: ActivityImpact.modification,
          action: 'Client modifié',
          targetName: nom,
          champ: 'Adresse',
          ancienneValeur: old.adresse ?? '—',
          nouvelleValeur: adresse ?? '—',
        );
      }
    }
  }

  void removeClient(String id, {required String motif}) {
    final matches = state.where((c) => c.id == id);
    final client = matches.isEmpty ? null : matches.first;
    state = state.where((c) => c.id != id).toList();
    if (client != null) {
      _repo?.remove(id);
      _ref.read(clientsTrashProvider.notifier).add(client);
      logActivity(
        _ref,
        category: ActivityCategory.clients,
        impact: ActivityImpact.suppression,
        action: 'Client supprimé',
        targetName: client.nom,
        motif: motif,
      );
    }
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>(
  (ref) => ClientsNotifier(ref, shopCode: ref.watch(currentShopCodeProvider)),
);

final totalCreditProvider = Provider<double>((ref) {
  final clients = ref.watch(clientsProvider);
  return clients.fold(0, (sum, c) => sum + c.creditTotal);
});
