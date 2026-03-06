import 'package:flutter/material.dart';

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

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
