import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/magasin_model.dart';

class MagasinRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _produitsCollection = 'produits';
  static const String _mouvementsCollection = 'mouvements';
  static const String _categoriesCollection = 'categories';

  // ——— Produits ———

  Stream<List<Produit>> watchProduits() {
    return _firestore
        .collection(_produitsCollection)
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Produit.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<Produit?> getProduit(String id) async {
    final doc = await _firestore.collection(_produitsCollection).doc(id).get();
    if (!doc.exists) return null;
    return Produit.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<String> addProduit(Produit p) async {
    final map = p.toMap();
    final docRef = await _firestore.collection(_produitsCollection).add(map);
    return docRef.id;
  }

  Future<void> updateProduit(Produit p) async {
    final map = p.toMap();
    await _firestore.collection(_produitsCollection).doc(p.id).update(map);
  }

  Future<void> deleteProduit(String id) async {
    await _firestore.collection(_produitsCollection).doc(id).delete();
  }

  Future<void> updateProduitStock(String id, int newQuantite) async {
    await _firestore.collection(_produitsCollection).doc(id).update({
      'quantiteStock': newQuantite,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProduitVariantes(String id, List<VarianteStock> variantes) async {
    await _firestore.collection(_produitsCollection).doc(id).update({
      'variantes': variantes.map((v) => v.toMap()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ——— Mouvements ———

  /// Évite l'index composite Firestore: on trie par date côté serveur, puis on filtre par type en mémoire si besoin.
  Stream<List<Mouvement>> watchMouvements({String? type}) {
    return _firestore
        .collection(_mouvementsCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      var list = snap.docs
          .map((d) => Mouvement.fromMap({...d.data(), 'id': d.id}))
          .toList();
      if (type != null) {
        list = list.where((m) => m.type == type).toList();
      }
      return list;
    });
  }

  Stream<List<Mouvement>> watchEntrees() => watchMouvements(type: 'entree');
  Stream<List<Mouvement>> watchSorties() => watchMouvements(type: 'sortie');

  Future<String> addMouvement(Mouvement m) async {
    final map = m.toMap();
    final docRef = await _firestore.collection(_mouvementsCollection).add(map);
    return docRef.id;
  }

  Future<void> deleteMouvement(String id) async {
    await _firestore.collection(_mouvementsCollection).doc(id).delete();
  }

  // ——— Catégories ———

  Stream<List<Categorie>> watchCategories() {
    return _firestore
        .collection(_categoriesCollection)
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Categorie.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<String> addCategorie(Categorie c) async {
    final map = c.toMap();
    final docRef = await _firestore.collection(_categoriesCollection).add(map);
    return docRef.id;
  }

  Future<void> deleteCategorie(String id) async {
    await _firestore.collection(_categoriesCollection).doc(id).delete();
  }

  // ——— Stats ———

  Future<int> getTotalProduitsCount() async {
    final snap = await _firestore.collection(_produitsCollection).get();
    return snap.docs.length;
  }

  Future<int> getTotalStockCount() async {
    final snap = await _firestore.collection(_produitsCollection).get();
    int total = 0;
    for (final doc in snap.docs) {
      final p = Produit.fromMap({...doc.data(), 'id': doc.id});
      total += p.total;
    }
    return total;
  }
}
