import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sou9ix/features/clients/model/client.dart';

List<Client> _buildMockClients() => [
      Client(
        id: 'c1',
        nom: 'Mohamed Trabelsi',
        telephone: '+216 20 123 456',
        creditTotal: 45.500,
        dernierAchat: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Client(
        id: 'c2',
        nom: 'Amira Ben Salah',
        telephone: '+216 22 987 654',
        creditTotal: 0,
        dernierAchat: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Client(
        id: 'c3',
        nom: 'Sami Gharbi',
        telephone: '+216 55 741 258',
        creditTotal: 128.000,
        dernierAchat: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Client(
        id: 'c4',
        nom: 'Café Central',
        telephone: '+216 71 456 789',
        creditTotal: 260.750,
        dernierAchat: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

class ClientsNotifier extends StateNotifier<List<Client>> {
  ClientsNotifier() : super(_buildMockClients());

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
