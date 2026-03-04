import 'package:cloud_firestore/cloud_firestore.dart';

/// مستخدم أدمن — من Firestore
class AdminUser {
  final String id;
  String nom;
  String prenom;
  String email;
  String telephone;
  String role;
  bool actif;
  List<String> permissions;
  DateTime dateCreation;

  AdminUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.role,
    required this.actif,
    required this.permissions,
    required this.dateCreation,
  });

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'role': role,
      'actif': actif,
      'permissions': permissions,
      'dateCreation': Timestamp.fromDate(dateCreation),
    };
  }

  static AdminUser fromMap(Map<String, dynamic> map) {
    final dc = map['dateCreation'];
    DateTime dateCreation = DateTime.now();
    if (dc is Timestamp) dateCreation = dc.toDate();
    final perms = map['permissions'];
    return AdminUser(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      prenom: map['prenom'] as String? ?? '',
      email: map['email'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      role: map['role'] as String? ?? '',
      actif: map['actif'] as bool? ?? true,
      permissions: perms is List<dynamic>
          ? perms.map((e) => e.toString()).toList()
          : [],
      dateCreation: dateCreation,
    );
  }
}

class AdminsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'admins';

  Stream<List<AdminUser>> watchAdmins() {
    return _firestore.collection(_collection).snapshots().map((snap) {
      return snap.docs
          .map((d) => AdminUser.fromMap({...d.data(), 'id': d.id}))
          .toList();
    });
  }

  Future<void> addAdmin(AdminUser a) async {
    final map = a.toMap();
    await _firestore.collection(_collection).add(map);
  }

  Future<void> updateAdmin(AdminUser a) async {
    final map = a.toMap();
    await _firestore.collection(_collection).doc(a.id).update(map);
  }

  Future<void> deleteAdmin(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }
}
