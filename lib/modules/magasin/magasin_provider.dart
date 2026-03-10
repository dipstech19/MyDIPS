import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/magasin_model.dart';
import 'data/magasin_repository.dart';

class MagasinProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  MagasinRepository? _repo;

  List<Produit> _produits = [];
  List<Mouvement> _entrees = [];
  List<Mouvement> _sorties = [];
  List<Categorie> _categories = [];
  bool _loading = true;
  String? _error;

  List<Produit> get produits => List.unmodifiable(_produits);
  List<Mouvement> get entrees => List.unmodifiable(_entrees);
  List<Mouvement> get sorties => List.unmodifiable(_sorties);
  List<Categorie> get categories => List.unmodifiable(_categories);
  List<String> get categoryNames => _categories.map((c) => c.nom).toList();
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  int get totalProduits => _produits.length;
  int get totalStock => _produits.fold(0, (sum, p) => sum + p.total);
  int get ruptureCount => _produits.where((p) => p.rupture).length;
  int get basCount => _produits.where((p) => p.bas).length;

  StreamSubscription? _subProduits;
  StreamSubscription? _subEntrees;
  StreamSubscription? _subSorties;
  StreamSubscription? _subCategories;

  MagasinProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = MagasinRepository();
    _subscribe();
  }

  void _subscribe() {
    _loading = true;
    _error = null;
    notifyListeners();

    _subProduits?.cancel();
    _subEntrees?.cancel();
    _subSorties?.cancel();
    _subCategories?.cancel();

    final repo = _repo!;

    _subProduits = repo.watchProduits().listen(
      (list) {
        _produits = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );

    _subEntrees = repo.watchEntrees().listen(
      (list) {
        _entrees = list;
        notifyListeners();
      },
      onError: (e) {
        _error = _error ?? e.toString();
        notifyListeners();
      },
    );

    _subSorties = repo.watchSorties().listen(
      (list) {
        _sorties = list;
        notifyListeners();
      },
      onError: (e) {
        _error = _error ?? e.toString();
        notifyListeners();
      },
    );

    _subCategories = repo.watchCategories().listen(
      (list) {
        _categories = list;
        notifyListeners();
      },
      onError: (e) {
        _error = _error ?? e.toString();
        notifyListeners();
      },
    );
  }

  // ——— Produits ———

  Future<String> addProduit(Produit p) async {
    if (!_firebaseAvailable) return '';
    return await _repo!.addProduit(p);
  }

  Future<void> updateProduit(Produit p) async {
    if (!_firebaseAvailable) return;
    await _repo!.updateProduit(p);
  }

  Future<void> deleteProduit(String id) async {
    if (!_firebaseAvailable) return;
    await _repo!.deleteProduit(id);
  }

  // ——— Mouvements ———

  Future<void> addEntree(Mouvement m) async {
    if (!_firebaseAvailable) return;
    
    await _repo!.addMouvement(m);
    
    final p = _produits.firstWhere((x) => x.id == m.produitId, orElse: () => _produits.first);
    if (p.aVariantes) {
      final updatedVariantes = List<VarianteStock>.from(p.variantes);
      for (final lg in m.lignes) {
        final idx = updatedVariantes.indexWhere((v) => v.unite == lg.unite);
        if (idx >= 0) {
          updatedVariantes[idx] = VarianteStock(
            unite: lg.unite,
            quantite: updatedVariantes[idx].quantite + lg.quantite,
          );
        } else {
          updatedVariantes.add(VarianteStock(unite: lg.unite, quantite: lg.quantite));
        }
      }
      await _repo!.updateProduitVariantes(p.id, updatedVariantes);
    } else {
      await _repo!.updateProduitStock(p.id, p.quantiteStock + m.quantite);
    }
  }

  Future<void> addSortie(Mouvement m) async {
    if (!_firebaseAvailable) return;
    
    await _repo!.addMouvement(m);
    
    final p = _produits.firstWhere((x) => x.id == m.produitId, orElse: () => _produits.first);
    if (p.aVariantes) {
      final updatedVariantes = List<VarianteStock>.from(p.variantes);
      for (final lg in m.lignes) {
        final idx = updatedVariantes.indexWhere((v) => v.unite == lg.unite);
        if (idx >= 0) {
          final newQte = (updatedVariantes[idx].quantite - lg.quantite).clamp(0, 99999);
          updatedVariantes[idx] = VarianteStock(unite: lg.unite, quantite: newQte);
        }
      }
      await _repo!.updateProduitVariantes(p.id, updatedVariantes);
    } else {
      final newQte = (p.quantiteStock - m.quantite).clamp(0, 99999);
      await _repo!.updateProduitStock(p.id, newQte);
    }
  }

  Future<void> deleteEntree(String id) async {
    if (!_firebaseAvailable) return;
    
    final m = _entrees.firstWhere((x) => x.id == id);
    final p = _produits.firstWhere((x) => x.id == m.produitId, orElse: () => _produits.first);
    
    if (p.aVariantes) {
      final updatedVariantes = List<VarianteStock>.from(p.variantes);
      for (final lg in m.lignes) {
        final idx = updatedVariantes.indexWhere((v) => v.unite == lg.unite);
        if (idx >= 0) {
          final newQte = (updatedVariantes[idx].quantite - lg.quantite).clamp(0, 99999);
          updatedVariantes[idx] = VarianteStock(unite: lg.unite, quantite: newQte);
        }
      }
      await _repo!.updateProduitVariantes(p.id, updatedVariantes);
    } else {
      final newQte = (p.quantiteStock - m.quantite).clamp(0, 99999);
      await _repo!.updateProduitStock(p.id, newQte);
    }
    
    await _repo!.deleteMouvement(id);
  }

  Future<void> deleteSortie(String id) async {
    if (!_firebaseAvailable) return;
    
    final m = _sorties.firstWhere((x) => x.id == id);
    final p = _produits.firstWhere((x) => x.id == m.produitId, orElse: () => _produits.first);
    
    if (p.aVariantes) {
      final updatedVariantes = List<VarianteStock>.from(p.variantes);
      for (final lg in m.lignes) {
        final idx = updatedVariantes.indexWhere((v) => v.unite == lg.unite);
        if (idx >= 0) {
          updatedVariantes[idx] = VarianteStock(
            unite: lg.unite,
            quantite: updatedVariantes[idx].quantite + lg.quantite,
          );
        } else {
          updatedVariantes.add(VarianteStock(unite: lg.unite, quantite: lg.quantite));
        }
      }
      await _repo!.updateProduitVariantes(p.id, updatedVariantes);
    } else {
      await _repo!.updateProduitStock(p.id, p.quantiteStock + m.quantite);
    }
    
    await _repo!.deleteMouvement(id);
  }

  // ——— Catégories ———

  Future<void> addCategorie(String nom) async {
    if (!_firebaseAvailable) return;
    if (_categories.any((c) => c.nom == nom)) return;
    await _repo!.addCategorie(Categorie(id: '', nom: nom));
  }

  Future<void> deleteCategorie(String id) async {
    if (!_firebaseAvailable) return;
    await _repo!.deleteCategorie(id);
  }

  @override
  void dispose() {
    _subProduits?.cancel();
    _subEntrees?.cancel();
    _subSorties?.cancel();
    _subCategories?.cancel();
    super.dispose();
  }
}
