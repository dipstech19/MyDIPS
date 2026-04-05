import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/distribution_group_model.dart';

class DistributionGroupsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'distribution_groups';

  Stream<List<DistributionGroup>> watchGroups() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => DistributionGroup.fromMap({...d.data(), 'id': d.id})).toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addGroup(DistributionGroup g) async {
    if (g.id.isEmpty) {
      await _firestore.collection(_collection).add(g.toMap());
      return;
    }
    await _firestore.collection(_collection).doc(g.id).set(g.toMap());
  }

  Future<void> updateGroup(DistributionGroup g) async {
    await _firestore.collection(_collection).doc(g.id).update(g.toMap());
  }

  Future<void> deleteGroup(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}

