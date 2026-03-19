enum UserRole { directeur, chefEquipe, chauffeur }

class AppUser {
  final String id;
  final String nom;
  final String username;
  final String password;
  final UserRole role;
  final String? equipeId;
  final String? photoUrl;
  /// للمشرفين: null أو ["all"] = أدمن عام (كل المواقع)، ["jadida"] أو ["safi"] = مشرف موقع واحد
  final List<String>? siteIds;

  AppUser({
    required this.id,
    required this.nom,
    required this.username,
    required this.password,
    required this.role,
    this.equipeId,
    this.photoUrl,
    this.siteIds,
  });

  /// أدمن عام يرى كل المواقع ويمكنه الفلترة
  bool get isSuperAdmin =>
      role == UserRole.directeur && (siteIds == null || siteIds!.isEmpty || siteIds!.contains('all'));

  /// المواقع المسموح بها للمشرف (null = الكل، غير null = قائمة المواقع فقط)
  List<String>? get allowedSiteIds =>
      (siteIds == null || siteIds!.isEmpty || siteIds!.contains('all')) ? null : siteIds;
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