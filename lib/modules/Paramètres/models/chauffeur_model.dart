/// نموذج السائق - يمثل مستخدم بصلاحيات سائق
class Chauffeur {
  final String id;
  final String nom;
  final String username;
  final String password;
  final String? equipeId;
  final String? employeId; // ربط بموظف موجود
  final String photoUrl;
  final bool actif;
  final DateTime dateCreation;

  Chauffeur({
    required this.id,
    required this.nom,
    required this.username,
    required this.password,
    this.equipeId,
    this.employeId,
    this.photoUrl = '',
    this.actif = true,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'username': username,
      'password': password,
      'equipeId': equipeId ?? '',
      'employeId': employeId ?? '',
      'photoUrl': photoUrl,
      'actif': actif,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  static Chauffeur fromMap(Map<String, dynamic> map) {
    return Chauffeur(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      equipeId: map['equipeId'] as String?,
      employeId: map['employeId'] as String?,
      photoUrl: map['photoUrl'] as String? ?? '',
      actif: map['actif'] as bool? ?? true,
      dateCreation: map['dateCreation'] != null
          ? DateTime.tryParse(map['dateCreation'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Chauffeur copyWith({
    String? id,
    String? nom,
    String? username,
    String? password,
    String? equipeId,
    String? employeId,
    String? photoUrl,
    bool? actif,
    DateTime? dateCreation,
  }) {
    return Chauffeur(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      username: username ?? this.username,
      password: password ?? this.password,
      equipeId: equipeId ?? this.equipeId,
      employeId: employeId ?? this.employeId,
      photoUrl: photoUrl ?? this.photoUrl,
      actif: actif ?? this.actif,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}
