class VarianteStock {
  final String unite;
  final int quantite;

  VarianteStock({required this.unite, required this.quantite});

  Map<String, dynamic> toMap() => {
    'unite': unite,
    'quantite': quantite,
  };

  factory VarianteStock.fromMap(Map<String, dynamic> map) => VarianteStock(
    unite: map['unite'] ?? '',
    quantite: map['quantite'] ?? 0,
  );

  VarianteStock copyWith({String? unite, int? quantite}) => VarianteStock(
    unite: unite ?? this.unite,
    quantite: quantite ?? this.quantite,
  );
}

class Produit {
  final String id;
  final String nom;
  final String reference;
  final String categorie;
  final String magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantiteStock;
  final List<VarianteStock> variantes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Produit({
    required this.id,
    required this.nom,
    required this.reference,
    required this.categorie,
    required this.magasin,
    required this.aVariantes,
    this.groupeUniteLabel,
    required this.quantiteStock,
    required this.variantes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get total => aVariantes 
      ? variantes.fold(0, (s, v) => s + v.quantite) 
      : quantiteStock;
  
  bool get rupture => total == 0;
  bool get bas => total > 0 && total <= 5;

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'reference': reference,
    'categorie': categorie,
    'magasin': magasin,
    'aVariantes': aVariantes,
    'groupeUniteLabel': groupeUniteLabel,
    'quantiteStock': quantiteStock,
    'variantes': variantes.map((v) => v.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Produit.fromMap(Map<String, dynamic> map) => Produit(
    id: map['id'] ?? '',
    nom: map['nom'] ?? '',
    reference: map['reference'] ?? '',
    categorie: map['categorie'] ?? '',
    magasin: map['magasin'] ?? '',
    aVariantes: map['aVariantes'] ?? false,
    groupeUniteLabel: map['groupeUniteLabel'],
    quantiteStock: map['quantiteStock'] ?? 0,
    variantes: (map['variantes'] as List<dynamic>?)
        ?.map((v) => VarianteStock.fromMap(v as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
  );

  Produit copyWith({
    String? id,
    String? nom,
    String? reference,
    String? categorie,
    String? magasin,
    bool? aVariantes,
    String? groupeUniteLabel,
    int? quantiteStock,
    List<VarianteStock>? variantes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Produit(
    id: id ?? this.id,
    nom: nom ?? this.nom,
    reference: reference ?? this.reference,
    categorie: categorie ?? this.categorie,
    magasin: magasin ?? this.magasin,
    aVariantes: aVariantes ?? this.aVariantes,
    groupeUniteLabel: groupeUniteLabel ?? this.groupeUniteLabel,
    quantiteStock: quantiteStock ?? this.quantiteStock,
    variantes: variantes ?? this.variantes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class LigneMouvement {
  final String unite;
  final int quantite;

  LigneMouvement({required this.unite, required this.quantite});

  Map<String, dynamic> toMap() => {
    'unite': unite,
    'quantite': quantite,
  };

  factory LigneMouvement.fromMap(Map<String, dynamic> map) => LigneMouvement(
    unite: map['unite'] ?? '',
    quantite: map['quantite'] ?? 0,
  );
}

class Mouvement {
  final String id;
  final String type; // 'entree' ou 'sortie'
  final String produitId;
  final String nomProduit;
  final String reference;
  final String categorie;
  final String magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantite;
  final List<LigneMouvement> lignes;
  final DateTime date;
  final String? preneurNom;

  Mouvement({
    required this.id,
    required this.type,
    required this.produitId,
    required this.nomProduit,
    required this.reference,
    required this.categorie,
    required this.magasin,
    required this.aVariantes,
    this.groupeUniteLabel,
    required this.quantite,
    required this.lignes,
    required this.date,
    this.preneurNom,
  });

  int get totalQte => aVariantes 
      ? lignes.fold(0, (s, l) => s + l.quantite) 
      : quantite;

  Map<String, dynamic> toMap() => {
    'type': type,
    'produitId': produitId,
    'nomProduit': nomProduit,
    'reference': reference,
    'categorie': categorie,
    'magasin': magasin,
    'aVariantes': aVariantes,
    'groupeUniteLabel': groupeUniteLabel,
    'quantite': quantite,
    'lignes': lignes.map((l) => l.toMap()).toList(),
    'date': date.toIso8601String(),
    'preneurNom': preneurNom,
  };

  factory Mouvement.fromMap(Map<String, dynamic> map) => Mouvement(
    id: map['id'] ?? '',
    type: map['type'] ?? 'entree',
    produitId: map['produitId'] ?? '',
    nomProduit: map['nomProduit'] ?? '',
    reference: map['reference'] ?? '',
    categorie: map['categorie'] ?? '',
    magasin: map['magasin'] ?? '',
    aVariantes: map['aVariantes'] ?? false,
    groupeUniteLabel: map['groupeUniteLabel'],
    quantite: map['quantite'] ?? 0,
    lignes: (map['lignes'] as List<dynamic>?)
        ?.map((l) => LigneMouvement.fromMap(l as Map<String, dynamic>))
        .toList() ?? [],
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    preneurNom: map['preneurNom'],
  );
}

class Categorie {
  final String id;
  final String nom;
  final DateTime createdAt;

  Categorie({
    required this.id,
    required this.nom,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Categorie.fromMap(Map<String, dynamic> map) => Categorie(
    id: map['id'] ?? '',
    nom: map['nom'] ?? '',
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
  );
}
