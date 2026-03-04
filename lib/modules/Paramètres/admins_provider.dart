import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/admins_repository.dart';

class AdminsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  AdminsRepository? _repo;
  StreamSubscription? _sub;

  List<AdminUser> _list = [];
  bool _loading = true;
  String? _error;

  List<AdminUser> get admins => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  AdminsProvider() {
    if (!_firebaseAvailable) {
      _list = [];
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = AdminsRepository();
    _sub = _repo!.watchAdmins().listen(
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

  Future<void> addAdmin(AdminUser a) async {
    if (_repo == null) return;
    await _repo!.addAdmin(a);
  }

  Future<void> updateAdmin(AdminUser a) async {
    if (_repo == null) return;
    await _repo!.updateAdmin(a);
  }

  Future<void> deleteAdmin(String id) async {
    if (_repo == null) return;
    await _repo!.deleteAdmin(id);
  }
}
