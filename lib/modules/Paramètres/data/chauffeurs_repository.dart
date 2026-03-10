import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chauffeur_model.dart';

/// مستودع بيانات السائقين من Firestore
class ChauffeursRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'chauffeurs';

  Stream<List<Chauffeur>> watchChauffeurs() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Chauffeur.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addChauffeur(Chauffeur c) async {
    final map = c.toMap();
    await _firestore.collection(_collection).doc(c.id).set(map);
  }

  Future<void> updateChauffeur(Chauffeur c) async {
    final map = c.toMap();
    await _firestore.collection(_collection).doc(c.id).update(map);
  }

  Future<void> deleteChauffeur(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<Chauffeur?> getChauffeurByUsername(String username) async {
    final snap = await _firestore
        .collection(_collection)
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Chauffeur.fromMap({...doc.data(), 'id': doc.id});
  }
}
