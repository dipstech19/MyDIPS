import 'package:cloud_firestore/cloud_firestore.dart';

/// منصب عمل (وظيفة) — من Firestore
class Poste {
  final String id;
  final String nom;
  final int ordre;

  Poste({required this.id, required this.nom, this.ordre = 0});

  Map<String, dynamic> toMap() => {'nom': nom, 'ordre': ordre};

  static Poste fromMap(Map<String, dynamic> map) {
    return Poste(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      ordre: (map['ordre'] as num?)?.toInt() ?? 0,
    );
  }
}

/// مستودع المناصب من Firestore
class PostesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'postes';

  Stream<List<Poste>> watchPostes() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Poste.fromMap({...d.data(), 'id': d.id}))
          .toList();
      list.sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    });
  }

  Future<void> addPoste(Poste p) async {
    final map = p.toMap();
    await _firestore.collection(_collection).add(map);
  }

  Future<void> updatePoste(Poste p) async {
    final map = p.toMap();
    await _firestore.collection(_collection).doc(p.id).update(map);
  }

  Future<void> deletePoste(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
