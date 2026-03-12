import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_models.dart';

class ShiftsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'shift_rotation_config';
  static const String _docId = 'default';

  Future<RotationConfig?> getConfig() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();
      return RotationConfig.fromMap(doc.data());
    } catch (_) {
      return null;
    }
  }

  Stream<RotationConfig?> watchConfig() {
    return _firestore.collection(_collection).doc(_docId).snapshots().map((doc) => RotationConfig.fromMap(doc.data()));
  }

  Future<void> setConfig(RotationConfig config) async {
    await _firestore.collection(_collection).doc(_docId).set(config.toMap());
  }
}
