class Client {
  final String id;
  final String nom;
  final String telephone;
  final double creditTotal;
  final DateTime dernierAchat;

  const Client({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.creditTotal,
    required this.dernierAchat,
  });

  Client copyWith({double? creditTotal}) => Client(
    id: id,
    nom: nom,
    telephone: telephone,
    creditTotal: creditTotal ?? this.creditTotal,
    dernierAchat: dernierAchat,
  );
}
