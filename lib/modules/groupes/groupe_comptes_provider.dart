import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'data/groupe_comptes_repository.dart';
import 'models/groupe_compte_model.dart';

class GroupeComptesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  GroupeComptesRepository? _repo;
  StreamSubscription? _sub;

  List<GroupeCompte> _list = [];
  bool _loading = true;
  String? _error;

  List<GroupeCompte> get comptes => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  GroupeComptesProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = GroupeComptesRepository();
    _sub = _repo!.watchGroupeComptes().listen(
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

  Future<void> addCompte(GroupeCompte c) async {
    if (_repo == null) return;
    await _repo!.addGroupeCompte(c);
  }

  Future<void> updateCompte(GroupeCompte c) async {
    if (_repo == null) return;
    await _repo!.updateGroupeCompte(c);
  }

  Future<void> deleteCompte(String id) async {
    if (_repo == null) return;
    await _repo!.deleteGroupeCompte(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

