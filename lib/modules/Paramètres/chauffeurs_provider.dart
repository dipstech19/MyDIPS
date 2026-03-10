import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/chauffeurs_repository.dart';
import 'models/chauffeur_model.dart';

/// Provider لإدارة بيانات السائقين
class ChauffeursProvider extends ChangeNotifier {
  List<Chauffeur> _chauffeurs = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;
  ChauffeursRepository? _repo;

  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;

  List<Chauffeur> get chauffeurs => _chauffeurs;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  ChauffeursProvider() {
    if (!_firebaseAvailable) {
      _chauffeurs = [];
      _loading = false;
      _error = 'Firebase non disponible';
      notifyListeners();
      return;
    }
    _repo = ChauffeursRepository();
    _subscribe();
  }

  void _subscribe() {
    final repo = _repo;
    if (repo == null) return;

    _sub = repo.watchChauffeurs().listen(
      (list) {
        _chauffeurs = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('ChauffeursProvider: Error watching chauffeurs: $e');
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> addChauffeur(Chauffeur c) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.addChauffeur(c);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateChauffeur(Chauffeur c) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.updateChauffeur(c);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteChauffeur(String id) async {
    if (!_firebaseAvailable || _repo == null) return;
    try {
      await _repo!.deleteChauffeur(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Chauffeur?> getChauffeurByUsername(String username) async {
    if (!_firebaseAvailable || _repo == null) return null;
    try {
      return await _repo!.getChauffeurByUsername(username);
    } catch (e) {
      debugPrint('ChauffeursProvider: Error getting chauffeur: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
