enum UserRole { directeur, chefEquipe, chauffeur, groupeResponsable }

class AppUser {
  final String id;
  final String nom;
  final String username;
  final String password;
  final UserRole role;
  final String? equipeId;
  final String? groupeId;
  final String? photoUrl;
  final List<String>? siteIds;

  AppUser({
    required this.id,
    required this.nom,
    required this.username,
    required this.password,
    required this.role,
    this.equipeId,
    this.groupeId,
    this.photoUrl,
    this.siteIds,
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
    username: 'admin',
    password: '1234',
    role: UserRole.directeur,
    siteIds: ['all'],
  ),
  AppUser(
    id: 'u2',
    nom: 'Fatima Zahra',
    username: 'fatima',
    password: '1234',
    role: UserRole.chefEquipe,
    equipeId: 'eq1',
  ),
];