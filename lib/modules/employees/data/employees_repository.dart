import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employe_model.dart';
import '../models/equipe_model.dart';

/// مستودع بيانات العمال والفرق من Firestore — تخزين ديناميكي من القاعدة الفعلية
class EmployeesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _employesCollection = 'employes';
  static const String _equipesCollection = 'equipes';

  // ——— Employes ———

  Stream<List<Employe>> watchEmployes() {
    return _firestore.collection(_employesCollection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Employe.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addEmploye(Employe e) async {
    final map = e.toMap();
    map.remove('id');
    await _firestore.collection(_employesCollection).doc(e.id).set(map);
  }

  Future<void> updateEmploye(Employe e) async {
    final map = e.toMap();
    map.remove('id');
    await _firestore.collection(_employesCollection).doc(e.id).update(map);
  }

  Future<void> deleteEmploye(String id) async {
    await _firestore.collection(_employesCollection).doc(id).delete();
  }

  Future<void> updateEmployeStatut(String id, EmployeStatut statut) async {
    await _firestore
        .collection(_employesCollection)
        .doc(id)
        .update({'statut': statut.name});
  }

  // ——— Equipes ———

  Stream<List<Equipe>> watchEquipes() {
    return _firestore.collection(_equipesCollection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Equipe.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addEquipe(Equipe eq) async {
    final map = eq.toMap();
    map.remove('id');
    await _firestore.collection(_equipesCollection).doc(eq.id).set(map);
  }

  Future<void> updateEquipe(Equipe eq) async {
    final map = eq.toMap();
    map.remove('id');
    await _firestore.collection(_equipesCollection).doc(eq.id).update(map);
  }

  Future<void> deleteEquipe(String id) async {
    await _firestore.collection(_equipesCollection).doc(id).delete();
  }
}
