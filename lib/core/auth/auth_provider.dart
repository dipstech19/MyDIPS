import 'package:flutter/material.dart';
<<<<<<< HEAD

class User {
  final String nom;
  final String role;
  User({required this.nom, required this.role});
}

class AuthProvider extends ChangeNotifier {
  User? _currentUser = User(nom: "Utilisateur", role: "directeur");

  User? get currentUser => _currentUser;
  bool get isDirecteur => _currentUser?.role == "directeur";
  bool get isChauffeur => _currentUser?.role == "chauffeur";
  bool get isChefEquipe => _currentUser?.role == "chef_equipe";
=======
import 'auth_model.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isDirecteur => _currentUser?.role == UserRole.directeur;
  bool get isChefEquipe => _currentUser?.role == UserRole.chefEquipe;
  String? get equipeId => _currentUser?.equipeId;

  bool login(String username, String password) {
    final user = appUsers.where(
          (u) => u.username == username && u.password == password,
    ).toList();

    if (user.isNotEmpty) {
      _currentUser = user.first;
      notifyListeners();
      return true;
    }
    return false;
  }
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> d4f0996 (Add auth module, employees module with models and widgets)
