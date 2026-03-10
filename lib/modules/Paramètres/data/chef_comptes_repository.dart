import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chef_compte_model.dart';

/// مستودع حسابات الشافات من Firestore
class ChefComptesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chef_comptes';

  Stream<List<ChefCompte>> watchChefComptes() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => ChefCompte.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addChefCompte(ChefCompte c) async {
    if (c.id.isEmpty) {
      await _firestore.collection(_collection).add(c.toMap());
      return;
    }
    await _firestore.collection(_collection).doc(c.id).set(c.toMap());
  }

  Future<void> updateChefCompte(ChefCompte c) async {
    await _firestore.collection(_collection).doc(c.id).update(c.toMap());
  }

  Future<void> deleteChefCompte(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<ChefCompte?> getChefCompteByEmail(String email) async {
    final snap = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return ChefCompte.fromMap({...doc.data(), 'id': doc.id});
  }
}
