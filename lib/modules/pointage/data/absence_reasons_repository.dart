import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/absence_reason_config.dart';

class AbsenceReasonsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'absence_reasons';

  Stream<List<AbsenceReasonConfig>> watchReasons() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      return snap.docs
          .map((d) => AbsenceReasonConfig.fromMap({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> add(AbsenceReasonConfig reason) async {
    await _firestore.collection(_collection).add(reason.toMap());
  }

  Future<void> update(AbsenceReasonConfig reason) async {
    if (reason.id.isEmpty) return;
    await _firestore.collection(_collection).doc(reason.id).update(reason.toMap());
  }

  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
