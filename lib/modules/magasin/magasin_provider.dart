import 'package:flutter/material.dart';
import 'models/magasin_model.dart';

class MagasinProvider extends ChangeNotifier {
  bool _loading = false;
  bool get loading => _loading;

  bool get firebaseAvailable => true;

  String? _error;
  String? get error => _error;

  final List<Produit> _produits = [];
  List<Produit> get produits => List.unmodifiable(_produits);

  final List<Mouvement> _entrees = [];
  List<Mouvement> get entrees => List.unmodifiable(_entrees);

  final List<Mouvement> _sorties = [];
  List<Mouvement> get sorties => List.unmodifiable(_sorties);

  final List<String> _categories = [];
  List<String> get categoryNames => List.unmodifiable(_categories);

  int get totalProduits => _produits.length;

  Future<String> addProduit(Produit p) async {
    _loading = true;
    notifyListeners();
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _produits.add(Produit(
        id: id,
        nom: p.nom,
        reference: p.reference,
        categorie: p.categorie,
        magasin: p.magasin,
        aVariantes: p.aVariantes,
        groupeUniteLabel: p.groupeUniteLabel,
        quantiteStock: p.quantiteStock,
        variantes: p.variantes,
        siteId: p.siteId,
      ));
      notifyListeners();
      return id;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addCategorie(String name) async {
    if (name.trim().isEmpty || _categories.contains(name.trim())) return;
    _categories.add(name.trim());
    notifyListeners();
  }

  Future<void> addEntree(Mouvement m) async {
    _entrees.add(Mouvement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: m.type,
      produitId: m.produitId,
      nomProduit: m.nomProduit,
      reference: m.reference,
      categorie: m.categorie,
      magasin: m.magasin,
      aVariantes: m.aVariantes,
      groupeUniteLabel: m.groupeUniteLabel,
      quantite: m.quantite,
      lignes: m.lignes,
      date: m.date,
      preneurNom: m.preneurNom,
      siteId: m.siteId,
    ));
    notifyListeners();
  }

  Future<void> addSortie(Mouvement m) async {
    _sorties.add(Mouvement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: m.type,
      produitId: m.produitId,
      nomProduit: m.nomProduit,
      reference: m.reference,
      categorie: m.categorie,
      magasin: m.magasin,
      aVariantes: m.aVariantes,
      groupeUniteLabel: m.groupeUniteLabel,
      quantite: m.quantite,
      lignes: m.lignes,
      date: m.date,
      preneurNom: m.preneurNom,
      siteId: m.siteId,
    ));
    notifyListeners();
  }

  Future<void> deleteEntree(String id) async {
    _entrees.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  Future<void> deleteSortie(String id) async {
    _sorties.removeWhere((m) => m.id == id);
    notifyListeners();
  }
}
