import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/distribution_swap_model.dart';

class DistributionSwapsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'distribution_swaps';

  Stream<List<DistributionSwap>> watchSwaps() {
    return _firestore.collection(_collection).orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((d) => DistributionSwap.fromMap({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  Future<String> createSwap(DistributionSwap swap) async {
    final ref = await _firestore.collection(_collection).add(swap.toMap());
    return ref.id;
  }

  Future<void> updateSwap(String id, Map<String, dynamic> updates) async {
    await _firestore.collection(_collection).doc(id).update(updates);
  }

  Future<void> deleteSwap(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
