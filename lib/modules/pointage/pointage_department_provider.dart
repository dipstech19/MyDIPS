import 'package:flutter/material.dart';

/// Sélection Dessalement / Distribution pour la page Pointage (directeur/admin).
class PointageDepartmentProvider extends ChangeNotifier {
  static const dessalement = 'dessalement';
  static const distribution = 'distribution';

  String _selected = dessalement;

  String get selected => _selected;

  void setSelected(String value) {
    if (_selected == value) return;
    _selected = value;
    notifyListeners();
  }
}
