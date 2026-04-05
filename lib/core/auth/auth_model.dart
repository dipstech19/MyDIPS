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

  bool get isSuperAdmin =>
      siteIds != null && (siteIds!.contains('all') || siteIds!.isEmpty);
  List<String>? get allowedSiteIds => siteIds;
}

/// المستخدمون الثابتون (Admin و Chefs)
final List<AppUser> appUsers = [
  AppUser(
    id: 'u1',
    nom: 'Directeur DIPS',
    username: 'dips@dips.ma',
    password: '1234',
    role: UserRole.directeur,
    siteIds: ['all'],
  ),

];