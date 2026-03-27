import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CongesProvider extends ChangeNotifier {
  final Map<String, double> _daysTaken = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _employesCollection = 'employes';

  double? getCachedDaysTaken(String employeId) => _daysTaken[employeId];

  Future<double> loadDaysTaken(String employeId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _daysTaken.containsKey(employeId)) {
      return _daysTaken[employeId]!;
    }
    try {
      final doc = await _firestore.collection(_employesCollection).doc(employeId).get();
      final map = doc.data();
      final raw = map == null ? null : map['leaveDaysTaken'];
      final taken = raw is num ? raw.toDouble() : 0.0;
      _daysTaken[employeId] = taken;
      notifyListeners();
      return taken;
    } catch (_) {
      final fallback = _daysTaken[employeId] ?? 0.0;
      _daysTaken[employeId] = fallback;
      notifyListeners();
      return fallback;
    }
  }

  Future<void> addDaysTaken(String employeId, double days) async {
    final current = await loadDaysTaken(employeId);
    final next = (current + days).clamp(0.0, double.infinity).toDouble();
    _daysTaken[employeId] = next;
    await _firestore.collection(_employesCollection).doc(employeId).set({
      'leaveDaysTaken': next,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    notifyListeners();
  }

  Future<double> getDaysTaken(String employeId, {bool refresh = false}) async {
    return loadDaysTaken(employeId, forceRefresh: refresh);
  }

  Future<void> setDaysTaken(String employeId, double days) async {
    final safe = days.clamp(0.0, double.infinity).toDouble();
    _daysTaken[employeId] = safe;
    await _firestore.collection(_employesCollection).doc(employeId).set({
      'leaveDaysTaken': safe,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    notifyListeners();
  }
}
