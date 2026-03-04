class Equipe {
  final String id;
  final String nom;
  final String magasin;
  final String chefId;
  final List<String> membreIds;

  Equipe({
    required this.id,
    required this.nom,
    required this.magasin,
    required this.chefId,
    this.membreIds = const [],
  });

  Equipe copyWith({
    String? nom,
    String? magasin,
    String? chefId,
    List<String>? membreIds,
  }) {
    return Equipe(
      id: id,
      nom: nom ?? this.nom,
      magasin: magasin ?? this.magasin,
      chefId: chefId ?? this.chefId,
      membreIds: membreIds ?? this.membreIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'magasin': magasin,
      'chefId': chefId,
      'membreIds': membreIds,
    };
  }

  static Equipe fromMap(Map<String, dynamic> map) {
    final membreIds = map['membreIds'];
    return Equipe(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      magasin: map['magasin'] as String? ?? '',
      chefId: map['chefId'] as String? ?? '',
      membreIds: membreIds is List<dynamic>
          ? membreIds.map((e) => e.toString()).toList()
          : const [],
    );
  }
}