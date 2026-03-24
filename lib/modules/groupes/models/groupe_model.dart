class Groupe {
  final String id;
  final String nom;
  final List<String> membreIds;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  Groupe({
    required this.id,
    required this.nom,
    this.membreIds = const [],
    this.startHour = 8,
    this.startMinute = 0,
    this.endHour = 16,
    this.endMinute = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'membreIds': membreIds,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  static Groupe fromMap(Map<String, dynamic> map) {
    final membreIds = map['membreIds'];
    return Groupe(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      membreIds: membreIds is List ? membreIds.map((e) => e.toString()).toList() : const [],
      startHour: (map['startHour'] as num?)?.toInt() ?? 8,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 16,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
    );
  }

  Groupe copyWith({
    String? id,
    String? nom,
    List<String>? membreIds,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return Groupe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      membreIds: membreIds ?? this.membreIds,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }
}

