enum UserRole { directeur, chefEquipe }

class AppUser {
  final String id;
  final String nom;
  final String username;
  final String password;
  final UserRole role;
  final String? equipeId; // فقط لـ Chef Équipe

  AppUser({
    required this.id,
    required this.nom,
    required this.username,
    required this.password,
    required this.role,
    this.equipeId,
  });
}

// Users de test
final List<AppUser> appUsers = [
  AppUser(
    id: 'u1',
    nom: 'Directeur DIPS',
    username: 'admin',
    password: '1234',
    role: UserRole.directeur,
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