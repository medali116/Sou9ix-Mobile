/// A custom "type d'activité" created from the admin onboarding wizard when
/// none of the built-in [TypeActivite] values fit — same pattern as
/// [ProductCategory]'s "+ Nouvelle catégorie", just for shop activity types.
class ActivityType {
  final String id;
  final String name;

  const ActivityType({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'nom': name};

  factory ActivityType.fromMap(String id, Map<String, dynamic> map) =>
      ActivityType(id: id, name: (map['nom'] ?? map['name']) as String);
}
