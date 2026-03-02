import 'package:flutter/material.dart';
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

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}