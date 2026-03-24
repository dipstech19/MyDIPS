import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/groupes_repository.dart';
import 'models/groupe_model.dart';

class GroupesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  GroupesRepository? _repo;
  StreamSubscription? _sub;

  List<Groupe> _list = [];
  bool _loading = true;
  String? _error;

  List<Groupe> get groupes => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  GroupesProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = GroupesRepository();
    _sub = _repo!.watchGroupes().listen(
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

  Future<void> addGroupe(Groupe g) async {
    if (_repo == null) return;
    await _repo!.addGroupe(g);
  }

  Future<void> updateGroupe(Groupe g) async {
    if (_repo == null) return;
    await _repo!.updateGroupe(g);
  }

  Future<void> deleteGroupe(String id) async {
    if (_repo == null) return;
    await _repo!.deleteGroupe(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

