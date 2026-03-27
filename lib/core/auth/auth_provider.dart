import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_permissions.dart';
import 'auth_model.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isDirecteur => _currentUser?.role == UserRole.directeur;
  bool get isChefEquipe => _currentUser?.role == UserRole.chefEquipe;
  bool get isChauffeur => _currentUser?.role == UserRole.chauffeur;
  bool get isGroupeResponsable => _currentUser?.role == UserRole.groupeResponsable;
  String? get equipeId => _currentUser?.equipeId;
  String? get groupeId => _currentUser?.groupeId;
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;
  List<String> get permissions => _currentUser?.permissions ?? const [];

  bool hasPermission(String permission) {
    if (!isDirecteur) return false;
    if (permissions.contains(AppPermissions.all)) return true;
    if (isSuperAdmin && permissions.isEmpty) return true; // legacy full admin
    if (permissions.contains(permission)) return true;

    // Legacy compatibility with old broad permissions.
    if (permissions.contains('Paramètres') && permission.startsWith('settings.')) return true;
    if (permissions.contains('Employés') &&
        (permission.startsWith('employees.') || permission == AppPermissions.teamsManage)) {
      return true;
    }
    if (permissions.contains('Pointage') &&
        (permission.startsWith('pointage.') ||
            permission == AppPermissions.overtimeView ||
            permission == AppPermissions.shiftsView ||
            permission == AppPermissions.trainingManage)) {
      return true;
    }
    if (permissions.contains('Gestion Magasin') && permission == AppPermissions.stockView) return true;
    if (permissions.contains('Rapports') && permission == AppPermissions.reportsView) return true;
    return false;
  }

  bool hasAnyPermission(List<String> required) {
    for (final p in required) {
      if (hasPermission(p)) return true;
    }
    return false;
  }

  /// تسجيل الدخول — ثابت ثم سائقين ثم شافات (بالايميل)
  Future<bool> login(String usernameOrEmail, String password) async {
    final input = usernameOrEmail.trim();
    final pwd = password;

    // 1. المستخدمون الثابتون (Admin / Chef test) — أدمن عام بدون موقع
    final staticUser = appUsers.where(
          (u) => u.username == input && u.password == pwd,
    ).toList();
    if (staticUser.isNotEmpty) {
      _currentUser = AppUser(
        id: staticUser.first.id,
        nom: staticUser.first.nom,
        username: staticUser.first.username,
        password: staticUser.first.password,
        role: staticUser.first.role,
        equipeId: staticUser.first.equipeId,
        photoUrl: staticUser.first.photoUrl,
        siteIds: ['all'],
        permissions: const [AppPermissions.all],
      );
      notifyListeners();
      return true;
    }

    if (Firebase.apps.isEmpty) return false;

    // 1b. أدمن من Firestore (email + mot de passe) — قد يكون أدمن عام أو مشرف موقع
    try {
      final email = input.contains('@') ? input.trim().toLowerCase() : null;
      if (email != null) {
        final adminSnap = await FirebaseFirestore.instance
            .collection('admins')
            .where('email', isEqualTo: email)
            .where('actif', isEqualTo: true)
            .limit(1)
            .get();
        if (adminSnap.docs.isNotEmpty) {
          final data = adminSnap.docs.first.data();
          final storedPwd = data['password'] as String? ?? '';
          if (storedPwd == pwd) {
            final perms = data['siteIds'];
            List<String> siteIds = ['all'];
            if (perms is List<dynamic> && perms.isNotEmpty) {
              siteIds = perms.map((e) => e.toString()).toList();
            }
            final rawPermissions = data['permissions'];
            final adminPermissions = rawPermissions is List<dynamic>
                ? rawPermissions.map((e) => e.toString()).toList()
                : <String>[];
            _currentUser = AppUser(
              id: adminSnap.docs.first.id,
              nom: '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim(),
              username: data['email'] as String? ?? email,
              password: pwd,
              role: UserRole.directeur,
              siteIds: siteIds,
              permissions: adminPermissions,
            );
            notifyListeners();
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('AuthProvider: Error admin login: $e');
    }

    // 2. السائقون من Firebase (identifiant + mot de passe)
    try {
      final chauffeurDoc = await FirebaseFirestore.instance
          .collection('chauffeurs')
          .where('username', isEqualTo: input)
          .where('password', isEqualTo: pwd)
          .where('actif', isEqualTo: true)
          .limit(1)
          .get();

      if (chauffeurDoc.docs.isNotEmpty) {
        final data = chauffeurDoc.docs.first.data();
        final id = chauffeurDoc.docs.first.id;
        _currentUser = AppUser(
          id: id,
          nom: data['nom'] as String? ?? 'Chauffeur',
          username: data['username'] as String? ?? '',
          password: data['password'] as String? ?? '',
          role: UserRole.chauffeur,
          equipeId: data['equipeId'] as String?,
          photoUrl: data['photoUrl'] as String?,
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('AuthProvider: Error chauffeur login: $e');
    }

    // 3. الشافون من Firebase (email + mot de passe) — يظهر لكل شاف فريقه فقط
    try {
      final email = input.toLowerCase();
      final chefDoc = await FirebaseFirestore.instance
          .collection('chef_comptes')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (chefDoc.docs.isNotEmpty) {
        final data = chefDoc.docs.first.data();
        if ((data['password'] as String? ?? '') == pwd && (data['actif'] as bool? ?? false)) {
          final id = chefDoc.docs.first.id;
          final equipeId = data['equipeId'] as String? ?? '';
          _currentUser = AppUser(
            id: id,
            nom: data['nom'] as String? ?? 'Chef',
            username: data['email'] as String? ?? email,
            password: data['password'] as String? ?? '',
            role: UserRole.chefEquipe,
            equipeId: equipeId.isNotEmpty ? equipeId : null,
          );
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('AuthProvider: Error chef login: $e');
    }

    // 4. مسؤول مجموعة (Groupe) من Firebase (email + mot de passe) — يظهر له groupe فقط
    try {
      final email = input.toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collection('groupe_comptes')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        if ((data['password'] as String? ?? '') == pwd && (data['actif'] as bool? ?? false)) {
          final id = snap.docs.first.id;
          final gid = data['groupeId'] as String? ?? '';
          _currentUser = AppUser(
            id: id,
            nom: data['nom'] as String? ?? 'Responsable',
            username: data['email'] as String? ?? email,
            password: data['password'] as String? ?? '',
            role: UserRole.groupeResponsable,
            groupeId: gid.isNotEmpty ? gid : null,
          );
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('AuthProvider: Error groupe login: $e');
    }

    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}