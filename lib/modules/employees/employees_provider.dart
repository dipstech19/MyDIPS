import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/employe_model.dart';
import 'models/equipe_model.dart';
import 'data/employees_repository.dart';

/// مزود بيانات العمال والفرق — من Firestore فقط (بدون بيانات وهمية)
class EmployeesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  EmployeesRepository? _repo;

  List<Employe> _employes = [];
  List<Equipe> _equipes = [];
  bool _loading = true;
  String? _error;

  List<Employe> get employes => List.unmodifiable(_employes);
  List<Equipe> get equipes => List.unmodifiable(_equipes);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  StreamSubscription? _subEmployes;
  StreamSubscription? _subEquipes;

  EmployeesProvider() {
    debugPrint('EmployeesProvider: Firebase available = $_firebaseAvailable, apps = ${Firebase.apps.length}');
    if (!_firebaseAvailable) {
      _employes = [];
      _equipes = [];
      _loading = false;
      _error = 'Firebase non disponible';
      notifyListeners();
      return;
    }
    _repo = EmployeesRepository();
    _subscribe();
  }

  void _subscribe() {
    _loading = true;
    _error = null;
    notifyListeners();

    _subEmployes?.cancel();
    _subEquipes?.cancel();

    final repo = _repo!;
    _subEmployes = repo.watchEmployes().listen(
      (list) {
        debugPrint('EmployeesProvider: Received ${list.length} employes from Firestore');
        _employes = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('EmployeesProvider: Error watching employes: $e');
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );

    _subEquipes = repo.watchEquipes().listen(
      (list) {
        debugPrint('EmployeesProvider: Received ${list.length} equipes from Firestore');
        _equipes = list;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('EmployeesProvider: Error watching equipes: $e');
        _error = _error ?? e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> addEmploye(Employe e) async {
    if (!_firebaseAvailable) return;
    await _repo!.addEmploye(e);
  }

  Future<void> updateEmploye(Employe e) async {
    if (!_firebaseAvailable) return;
    await _repo!.updateEmploye(e);
  }

  Future<void> deleteEmploye(String id) async {
    if (!_firebaseAvailable) return;
    await _repo!.deleteEmploye(id);
  }

  Future<void> updateEmployeStatut(String id, EmployeStatut statut) async {
    if (!_firebaseAvailable) return;
    await _repo!.updateEmployeStatut(id, statut);
  }

  Future<void> addEquipe(Equipe eq) async {
    if (!_firebaseAvailable) return;
    await _repo!.addEquipe(eq);
  }

  Future<void> updateEquipe(Equipe eq) async {
    if (!_firebaseAvailable) return;
    await _repo!.updateEquipe(eq);
  }

  Future<void> deleteEquipe(String id) async {
    if (!_firebaseAvailable) return;
    await _repo!.deleteEquipe(id);
  }

  /// Force un rechargement complet depuis Firestore (utile après un reset global).
  void forceRefresh() {
    if (!_firebaseAvailable) return;
    _subscribe();
  }

  @override
  void dispose() {
    _subEmployes?.cancel();
    _subEquipes?.cancel();
    super.dispose();
  }
}
