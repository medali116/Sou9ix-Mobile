import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/client.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  ClientsNotifier() : super(buildMockClients());

  /// Adds (or, with a negative [montant], reverses) credit on a client's
  /// karné. Clamped at 0 like [settle] so reversing a past sale's credit
  /// impact can never push a balance negative.
  void addCredit(String clientId, double montant) {
    state = [
      for (final c in state)
        if (c.id == clientId)
          c.copyWith(creditTotal: (c.creditTotal + montant).clamp(0, double.infinity))
        else
          c,
    ];
  }

  void settle(String clientId, double montant) {
    state = [
      for (final c in state)
        if (c.id == clientId)
          c.copyWith(creditTotal: (c.creditTotal - montant).clamp(0, double.infinity))
        else
          c,
    ];
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>(
  (ref) => ClientsNotifier(),
);

final totalCreditProvider = Provider<double>((ref) {
  final clients = ref.watch(clientsProvider);
  return clients.fold(0, (sum, c) => sum + c.creditTotal);
});
