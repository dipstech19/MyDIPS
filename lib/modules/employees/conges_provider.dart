import 'package:flutter/material.dart';

class CongesProvider extends ChangeNotifier {
  final Map<String, double> _daysTaken = {};

  double? getCachedDaysTaken(String employeId) => _daysTaken[employeId];

  void loadDaysTaken(String employeId) {
    // TODO: load from Firebase/local; for now keep cache only
    if (!_daysTaken.containsKey(employeId)) {
      _daysTaken[employeId] = 0.0;
      notifyListeners();
    }
  }

  Future<void> addDaysTaken(String employeId, double days) async {
    _daysTaken[employeId] = (_daysTaken[employeId] ?? 0.0) + days;
    notifyListeners();
  }
}
