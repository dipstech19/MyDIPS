import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/departements_repository.dart';

/// مزود الأقسام (Départements) — من Firestore فقط
class DepartementsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  DepartementsRepository? _repo;
  StreamSubscription? _sub;

  List<Departement> _list = [];
  bool _loading = true;
  String? _error;

  List<Departement> get departements => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  DepartementsProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = DepartementsRepository();
    _sub = _repo!.watchDepartements().listen(
      (list) {
        _list = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> addDepartement(Departement d) async {
    if (_repo == null) return;
    await _repo!.addDepartement(d);
  }

  Future<void> updateDepartement(Departement d) async {
    if (_repo == null) return;
    await _repo!.updateDepartement(d);
  }

  Future<void> deleteDepartement(String id) async {
    if (_repo == null) return;
    await _repo!.deleteDepartement(id);
  }
}

