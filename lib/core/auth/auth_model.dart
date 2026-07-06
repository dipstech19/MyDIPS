enum UserRole { directeur, chefEquipe, chauffeur, groupeResponsable, distributionResponsable }

class AppUser {
  final String id;
  final String nom;
  final String username;
  final String password;
  final UserRole role;
  final String? equipeId;
  final String? groupeId;
  final String? distributionGroupId;
  final List<String> distributionGroupIds;
  final String? photoUrl;
  /// للمشرفين: null أو ["all"] = أدمن عام (كل المواقع)، ["jadida"] أو ["safi"] = مشرف موقع واحد
  final List<String>? siteIds;
  final List<String> permissions;
  final String? adminRole;
  /// Lien optionnel employé pour comptes `chef_comptes` (poste ex. chef d’atelier).
  final String? chefEmployeId;

  AppUser({
    required this.id,
    required this.nom,
    required this.username,
    required this.password,
    required this.role,
    this.equipeId,
    this.groupeId,
    this.distributionGroupId,
    this.distributionGroupIds = const [],
    this.photoUrl,
    this.siteIds,
    this.permissions = const [],
    this.adminRole,
    this.chefEmployeId,
  });

  /// أدمن عام يرى كل المواقع ويمكنه الفلترة
  bool get isSuperAdmin =>
      role == UserRole.directeur && (siteIds == null || siteIds!.isEmpty || siteIds!.contains('all'));

  /// المواقع المسموح بها للمشرف (null = الكل، غير null = قائمة المواقع فقط)
  List<String>? get allowedSiteIds =>
      (siteIds == null || siteIds!.isEmpty || siteIds!.contains('all')) ? null : siteIds;
}

/// Aucun compte statique — authentification uniquement via Firebase.
final List<AppUser> appUsers = [];