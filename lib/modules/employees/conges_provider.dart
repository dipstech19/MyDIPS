import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/employe_conges_repository.dart';

class CongesProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  final EmployeCongesRepository _repo = EmployeCongesRepository();

  final Map<String, double> _cache = {};

  double? getCachedDaysTaken(String employeId) => _cache[employeId];

  Future<void> loadDaysTaken(String employeId) async {
    if (!_firebaseAvailable) {
      _cache[employeId] = 0;
      notifyListeners();
      return;
    }
    final v = await _repo.getDaysTaken(employeId);
    _cache[employeId] = v;
    notifyListeners();
  }

  Future<void> addDaysTaken(String employeId, double days) async {
    if (!_firebaseAvailable) return;
    await _repo.addDaysTaken(employeId, days);
    _cache[employeId] = (_cache[employeId] ?? 0) + days;
    notifyListeners();
  }

  Future<void> setDaysTaken(String employeId, double value) async {
    if (!_firebaseAvailable) return;
    await _repo.setDaysTaken(employeId, value);
    _cache[employeId] = value < 0 ? 0 : value;
    notifyListeners();
  }
}
