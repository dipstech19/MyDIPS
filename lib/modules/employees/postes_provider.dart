import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/postes_repository.dart';

/// مزود المناصب (وظائف) — من Firestore فقط
class PostesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  PostesRepository? _repo;
  StreamSubscription? _sub;

  List<Poste> _list = [];
  bool _loading = true;
  String? _error;

  List<Poste> get postes => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  PostesProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = PostesRepository();
    _sub = _repo!.watchPostes().listen(
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

  Future<void> addPoste(Poste p) async {
    if (_repo == null) return;
    await _repo!.addPoste(p);
  }

  Future<void> updatePoste(Poste p) async {
    if (_repo == null) return;
    await _repo!.updatePoste(p);
  }

  Future<void> deletePoste(String id) async {
    if (_repo == null) return;
    await _repo!.deletePoste(id);
  }
}
