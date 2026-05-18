class DistributionCompte {
  final String id;
  final String nom;
  final String email;
  final String password;
  final String? employeId;
  final List<String> distributionGroupIds;
  final bool actif;
  final DateTime dateCreation;

  DistributionCompte({
    required this.id,
    required this.nom,
    required this.email,
    required this.password,
    this.employeId,
    this.distributionGroupIds = const [],
    this.actif = true,
    DateTime? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'email': email,
        'password': password,
        'employeId': employeId ?? '',
        'distributionGroupIds': distributionGroupIds,
        'distributionGroupId': distributionGroupIds.isNotEmpty ? distributionGroupIds.first : '',
        'actif': actif,
        'dateCreation': dateCreation.toIso8601String(),
      };

  static DistributionCompte fromMap(Map<String, dynamic> map) {
    final raw = map['distributionGroupIds'];
    final ids = raw is List<dynamic> ? raw.map((e) => e.toString()).toList() : <String>[];
    final one = map['distributionGroupId'] as String? ?? '';
    return DistributionCompte(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      email: map['email'] as String? ?? '',
      password: map['password'] as String? ?? '',
      employeId: (map['employeId'] as String?)?.trim().isEmpty == true ? null : map['employeId'] as String?,
      distributionGroupIds: ids.isNotEmpty ? ids : (one.isNotEmpty ? <String>[one] : const <String>[]),
      actif: map['actif'] as bool? ?? true,
      dateCreation: map['dateCreation'] != null
          ? DateTime.tryParse(map['dateCreation'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

