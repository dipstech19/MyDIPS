import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/absence_reasons_repository.dart';
import 'models/absence_reason_config.dart';

class AbsenceReasonsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  AbsenceReasonsRepository? _repo;
  StreamSubscription<List<AbsenceReasonConfig>>? _sub;

  List<AbsenceReasonConfig> _list = [];
  bool _loading = true;
  String? _error;

  List<AbsenceReasonConfig> get reasons => List.unmodifiable(_list);
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  AbsenceReasonsProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = AbsenceReasonsRepository();
    _sub = _repo!.watchReasons().listen(
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

  Future<void> add(AbsenceReasonConfig reason) async {
    if (_repo == null) return;
    await _repo!.add(reason);
  }

  Future<void> update(AbsenceReasonConfig reason) async {
    if (_repo == null) return;
    await _repo!.update(reason);
  }

  Future<void> delete(String id) async {
    if (_repo == null) return;
    await _repo!.delete(id);
  }
}
