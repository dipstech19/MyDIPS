class GroupeCompte {
  final String id;
  final String nom;
  final String email;
  final String password;
  final String groupeId;
  final bool actif;
  final DateTime dateCreation;

  GroupeCompte({
    required this.id,
    required this.nom,
    required this.email,
    required this.password,
    required this.groupeId,
    this.actif = true,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'email': email,
      'password': password,
      'groupeId': groupeId,
      'actif': actif,
      'dateCreation': dateCreation.toIso8601String(),
    };
  }

  static GroupeCompte fromMap(Map<String, dynamic> map) {
    return GroupeCompte(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      groupeId: map['groupeId'] as String? ?? '',
      actif: map['actif'] as bool? ?? true,
      dateCreation: map['dateCreation'] != null
          ? DateTime.tryParse(map['dateCreation'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  GroupeCompte copyWith({
    String? id,
    String? nom,
    String? email,
    String? password,
    String? groupeId,
    bool? actif,
    DateTime? dateCreation,
  }) {
    return GroupeCompte(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      password: password ?? this.password,
      groupeId: groupeId ?? this.groupeId,
      actif: actif ?? this.actif,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }
}

