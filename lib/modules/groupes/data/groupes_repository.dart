import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/groupe_model.dart';

class GroupesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'groupes';

  Stream<List<Groupe>> watchGroupes() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs.map((d) => Groupe.fromMap({...d.data(), 'id': d.id})).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addGroupe(Groupe g) async {
    if (g.id.isEmpty) {
      await _firestore.collection(_collection).add(g.toMap());
      return;
    }
    await _firestore.collection(_collection).doc(g.id).set(g.toMap());
  }

  Future<void> updateGroupe(Groupe g) async {
    await _firestore.collection(_collection).doc(g.id).update(g.toMap());
  }

  Future<void> deleteGroupe(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<Groupe?> getById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return Groupe.fromMap({...data, 'id': doc.id});
  }
}

