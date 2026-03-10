import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/chef_comptes_repository.dart';
import 'models/chef_compte_model.dart';

/// Provider لحسابات تسجيل دخول الشافات
class ChefComptesProvider extends ChangeNotifier {
  List<ChefCompte> _list = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;
  ChefComptesRepository? _repo;

  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;

  List<ChefCompte> get chefComptes => _list;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  ChefComptesProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      _error = 'Firebase non disponible';
      notifyListeners();
      return;
    }
    _repo = ChefComptesRepository();
    _subscribe();
  }

  void _subscribe() {
    final repo = _repo;
    if (repo == null) return;

    _sub = repo.watchChefComptes().listen(
      (list) {
        _list = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('ChefComptesProvider: Error: $e');
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> addChefCompte(ChefCompte c) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.addChefCompte(c);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateChefCompte(ChefCompte c) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.updateChefCompte(c);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteChefCompte(String id) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.deleteChefCompte(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<ChefCompte?> getChefCompteByEmail(String email) async {
    if (!_firebaseAvailable || _repo == null) return null;
    try {
      return await _repo!.getChefCompteByEmail(email);
    } catch (e) {
      debugPrint('ChefComptesProvider: getByEmail $e');
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
