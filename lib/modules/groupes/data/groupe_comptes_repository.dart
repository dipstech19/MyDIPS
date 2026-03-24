import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/groupe_compte_model.dart';

class GroupeComptesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'groupe_comptes';

  Stream<List<GroupeCompte>> watchGroupeComptes() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs.map((d) => GroupeCompte.fromMap({...d.data(), 'id': d.id})).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addGroupeCompte(GroupeCompte c) async {
    if (c.id.isEmpty) {
      await _firestore.collection(_collection).add(c.toMap());
      return;
    }
    await _firestore.collection(_collection).doc(c.id).set(c.toMap());
  }

  Future<void> updateGroupeCompte(GroupeCompte c) async {
    await _firestore.collection(_collection).doc(c.id).update(c.toMap());
  }

  Future<void> deleteGroupeCompte(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<GroupeCompte?> getByEmail(String email) async {
    final snap = await _firestore
        .collection(_collection)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return GroupeCompte.fromMap({...doc.data(), 'id': doc.id});
  }
}

