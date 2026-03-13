class Equipe {
  final String id;
  final String nom;
  final String magasin;
  final String chefId;
  final List<String> membreIds;
  /// ساعات البوانتاج لهذا الفريق (اختياري). إن كانت null يُستخدم الإعداد العام.
  final int? pointageStartHour;
  final int? pointageStartMinute;
  final int? pointageEndHour;
  final int? pointageEndMinute;
  /// موقع الفريق: jadida | safi
  final String siteId;

  Equipe({
    required this.id,
    required this.nom,
    required this.magasin,
    required this.chefId,
    this.membreIds = const [],
    this.siteId = 'jadida',
    this.pointageStartHour,
    this.pointageStartMinute,
    this.pointageEndHour,
    this.pointageEndMinute,
  });

  Equipe copyWith({
    String? nom,
    String? magasin,
    String? chefId,
    List<String>? membreIds,
    int? pointageStartHour,
    int? pointageStartMinute,
    int? pointageEndHour,
    int? pointageEndMinute,
    String? siteId,
  }) {
    return Equipe(
      id: id,
      nom: nom ?? this.nom,
      magasin: magasin ?? this.magasin,
      chefId: chefId ?? this.chefId,
      membreIds: membreIds ?? this.membreIds,
      siteId: siteId ?? this.siteId,
      pointageStartHour: pointageStartHour ?? this.pointageStartHour,
      pointageStartMinute: pointageStartMinute ?? this.pointageStartMinute,
      pointageEndHour: pointageEndHour ?? this.pointageEndHour,
      pointageEndMinute: pointageEndMinute ?? this.pointageEndMinute,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'nom': nom,
      'magasin': magasin,
      'chefId': chefId,
      'membreIds': membreIds,
      'siteId': siteId,
    };
    if (pointageStartHour != null) m['pointageStartHour'] = pointageStartHour;
    if (pointageStartMinute != null) m['pointageStartMinute'] = pointageStartMinute;
    if (pointageEndHour != null) m['pointageEndHour'] = pointageEndHour;
    if (pointageEndMinute != null) m['pointageEndMinute'] = pointageEndMinute;
    return m;
  }

  static Equipe fromMap(Map<String, dynamic> map) {
    final membreIds = map['membreIds'];
    final startH = map['pointageStartHour'];
    final startM = map['pointageStartMinute'];
    final endH = map['pointageEndHour'];
    final endM = map['pointageEndMinute'];
    return Equipe(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      magasin: map['magasin'] as String? ?? '',
      chefId: map['chefId'] as String? ?? '',
      siteId: map['siteId'] as String? ?? 'jadida',
      membreIds: membreIds is List<dynamic>
          ? membreIds.map((e) => e.toString()).toList()
          : const [],
      pointageStartHour: startH is int ? startH : (startH != null ? int.tryParse(startH.toString()) : null),
      pointageStartMinute: startM is int ? startM : (startM != null ? int.tryParse(startM.toString()) : null),
      pointageEndHour: endH is int ? endH : (endH != null ? int.tryParse(endH.toString()) : null),
      pointageEndMinute: endM is int ? endM : (endM != null ? int.tryParse(endM.toString()) : null),
    );
  }
}