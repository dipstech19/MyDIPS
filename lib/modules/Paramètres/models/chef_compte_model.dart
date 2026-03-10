/// حساب تسجيل دخول للشاف (Chef d'équipe) — بريد إلكتروني + كلمة مرور + ربط بفريق
class ChefCompte {
  final String id;
  final String nom;
  final String email;
  final String password;
  final String equipeId;
  final String? employeId;
  final bool actif;
  final DateTime dateCreation;

  ChefCompte({
    required this.id,
    required this.nom,
    required this.email,
    required this.password,
    required this.equipeId,
    this.employeId,
    this.actif = true,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'email': email,
      'password': password,
      'equipeId': equipeId,
      'employeId': employeId ?? '',
      'actif': actif,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  static ChefCompte fromMap(Map<String, dynamic> map) {
    return ChefCompte(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      employeId: map['employeId'] as String?,
      actif: map['actif'] as bool? ?? true,
      dateCreation: map['dateCreation'] != null
          ? DateTime.tryParse(map['dateCreation'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ChefCompte copyWith({
    String? id,
    String? nom,
    String? email,
    String? password,
    String? equipeId,
    String? employeId,
    bool? actif,
    DateTime? dateCreation,
  }) {
    return ChefCompte(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      password: password ?? this.password,
      equipeId: equipeId ?? this.equipeId,
      employeId: employeId ?? this.employeId,
      actif: actif ?? this.actif,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}
