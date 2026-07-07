import 'cart_item.dart';

enum ModePaiement { especes, carte, credit }

extension ModePaiementLabel on ModePaiement {
  String get label {
    switch (this) {
      case ModePaiement.especes:
        return 'Espèces';
      case ModePaiement.carte:
        return 'Carte';
      case ModePaiement.credit:
        return 'Crédit';
    }
  }
}

class Sale {
  final String id;
  final DateTime dateHeure;
  final List<CartItem> lignes;
  final ModePaiement modePaiement;
  final String? clientId;
  final String? employeeId;

  const Sale({
    required this.id,
    required this.dateHeure,
    required this.lignes,
    required this.modePaiement,
    this.clientId,
    this.employeeId,
  });

  double get total => lignes.fold(0, (sum, l) => sum + l.sousTotal);
  int get nombreArticles => lignes.length;
}
