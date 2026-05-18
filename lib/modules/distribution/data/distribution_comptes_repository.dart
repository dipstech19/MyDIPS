import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/distribution_compte_model.dart';

class DistributionComptesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'distribution_comptes';

  Stream<List<DistributionCompte>> watchComptes() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => DistributionCompte.fromMap({...d.data(), 'id': d.id})).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addCompte(DistributionCompte c) async {
    if (c.id.isEmpty) {
      await _firestore.collection(_collection).add(c.toMap());
      return;
    }
    await _firestore.collection(_collection).doc(c.id).set(c.toMap());
  }

  Future<void> updateCompte(DistributionCompte c) async {
    await _firestore.collection(_collection).doc(c.id).update(c.toMap());
  }

  Future<void> deleteCompte(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}

