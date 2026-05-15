import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CongesProvider extends ChangeNotifier {
  final Map<String, double> _daysTaken = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _employesCollection = 'employes';

  double? getCachedDaysTaken(String employeId) => _daysTaken[employeId];

  Future<bool> _employeeExists(String employeId) async {
    final doc = await _firestore.collection(_employesCollection).doc(employeId).get();
    return doc.exists;
  }

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
    if (!await _employeeExists(employeId)) {
      _daysTaken.remove(employeId);
      notifyListeners();
      return;
    }
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

  Future<Map<String, double>> loadDaysTakenForEmployees(List<String> employeIds, {bool forceRefresh = false}) async {
    if (employeIds.isEmpty) return const {};
    final uniqueIds = employeIds.toSet().toList();
    final missing = uniqueIds
        .where((id) => forceRefresh || !_daysTaken.containsKey(id))
        .toList();

    if (missing.isNotEmpty) {
      final chunks = <List<String>>[];
      for (var i = 0; i < missing.length; i += 10) {
        final end = (i + 10 < missing.length) ? i + 10 : missing.length;
        chunks.add(missing.sublist(i, end));
      }
      for (final chunk in chunks) {
        final snap = await _firestore
            .collection(_employesCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final raw = doc.data()['leaveDaysTaken'];
          _daysTaken[doc.id] = raw is num ? raw.toDouble() : 0.0;
        }
        for (final id in chunk) {
          _daysTaken.putIfAbsent(id, () => 0.0);
        }
      }
      notifyListeners();
    }

    return {for (final id in uniqueIds) id: _daysTaken[id] ?? 0.0};
  }

  Future<void> setDaysTaken(String employeId, double days) async {
    final safe = days.clamp(0.0, double.infinity).toDouble();
    if (!await _employeeExists(employeId)) {
      _daysTaken.remove(employeId);
      notifyListeners();
      return;
    }
    _daysTaken[employeId] = safe;
    await _firestore.collection(_employesCollection).doc(employeId).set({
      'leaveDaysTaken': safe,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    notifyListeners();
  }

  /// Remet à zéro le cache local pour un employé (après reset global).
  void resetCachedDaysTaken(String employeId) {
    _daysTaken[employeId] = 0.0;
  }

  /// Remet à zéro tout le cache local (après reset global de tous les employés).
  void resetAllCachedDaysTaken() {
    for (final key in _daysTaken.keys) {
      _daysTaken[key] = 0.0;
    }
    notifyListeners();
  }
}
