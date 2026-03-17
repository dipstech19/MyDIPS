/// نماذج المستودع — مستخدمة في gestion_magasin_firebase و MagasinProvider

class VarianteStock {
  String unite;
  int quantite;
  VarianteStock({required this.unite, required this.quantite});
}

class Produit {
  final String id;
  String nom;
  String reference;
  String categorie;
  String magasin;
  bool aVariantes;
  String? groupeUniteLabel;
  int quantiteStock;
  List<VarianteStock> variantes;
  final String siteId;

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
    this.siteId = 'all',
  });

  int get total => aVariantes ? variantes.fold(0, (s, v) => s + v.quantite) : quantiteStock;
  bool get rupture => total == 0;
  bool get bas => total > 0 && total <= 5;

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
    String? siteId,
  }) {
    return Produit(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      reference: reference ?? this.reference,
      categorie: categorie ?? this.categorie,
      magasin: magasin ?? this.magasin,
      aVariantes: aVariantes ?? this.aVariantes,
      groupeUniteLabel: groupeUniteLabel ?? this.groupeUniteLabel,
      quantiteStock: quantiteStock ?? this.quantiteStock,
      variantes: variantes ?? this.variantes,
      siteId: siteId ?? this.siteId,
    );
  }
}

class LigneMouvement {
  String unite;
  int quantite;
  LigneMouvement({required this.unite, required this.quantite});
}

class Mouvement {
  final String id;
  final String type;
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
  final String siteId;

  const Mouvement({
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
    this.siteId = 'all',
  });

  int get totalQte => aVariantes ? lignes.fold(0, (s, l) => s + l.quantite) : quantite;
}
