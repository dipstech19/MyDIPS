class DistributionGroup {
  final String id;
  final String nom;
  final List<String> membreIds;

  DistributionGroup({
    required this.id,
    required this.nom,
    this.membreIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'membreIds': membreIds,
      };

  static DistributionGroup fromMap(Map<String, dynamic> map) {
    final ids = map['membreIds'];
    return DistributionGroup(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      membreIds: ids is List ? ids.map((e) => e.toString()).toList() : const [],
    );
  }
}

