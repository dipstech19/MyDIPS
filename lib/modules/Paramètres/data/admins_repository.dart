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
  List<String> siteIds;
  String password;
  /// Groupes Distribution gérés par ce compte (ex. Chef de zone) — même clé que `admins.distributionGroupIds`.
  List<String> distributionGroupIds;

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
    this.siteIds = const ['all'],
    this.password = '',
    this.distributionGroupIds = const [],
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
      'siteIds': siteIds,
      'password': password,
      'dateCreation': Timestamp.fromDate(dateCreation),
      'distributionGroupIds': distributionGroupIds,
    };
  }

  static AdminUser fromMap(Map<String, dynamic> map) {
    final dc = map['dateCreation'];
    DateTime dateCreation = DateTime.now();
    if (dc is Timestamp) dateCreation = dc.toDate();
    final perms = map['permissions'];
    final sIds = map['siteIds'];
    final rawDist = map['distributionGroupIds'];
    final distIds = rawDist is List<dynamic>
        ? rawDist.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : <String>[];
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
      siteIds: sIds is List<dynamic>
          ? sIds.map((e) => e.toString()).toList()
          : ['all'],
      password: map['password'] as String? ?? '',
      distributionGroupIds: distIds,
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
