import 'package:cloud_firestore/cloud_firestore.dart';

/// Département (قسم إداري) — مخزَّن في Firestore
class Departement {
  final String id;
  final String nom;
  final int ordre;

  Departement({
    required this.id,
    required this.nom,
    this.ordre = 0,
  });

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'ordre': ordre,
      };

  static Departement fromMap(Map<String, dynamic> map) {
    return Departement(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      ordre: map['ordre'] as int? ?? 0,
    );
  }
}

/// Repository Départements (Firestore)
class DepartementsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'departements';

  Stream<List<Departement>> watchDepartements() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Departement.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.ordre != b.ordre
          ? a.ordre.compareTo(b.ordre)
          : a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addDepartement(Departement d) async {
    await _firestore.collection(_collection).add(d.toMap());
  }

  Future<void> updateDepartement(Departement d) async {
    await _firestore.collection(_collection).doc(d.id).update(d.toMap());
  }

  Future<void> deleteDepartement(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
