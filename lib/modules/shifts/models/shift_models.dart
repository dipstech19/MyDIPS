import 'package:flutter/material.dart';

enum ShiftType { morning, evening, night, rest }

extension ShiftTypeExt on ShiftType {
  String get timeRange {
    switch (this) {
      case ShiftType.morning:
        return '06:00–14:00';
      case ShiftType.evening:
        return '14:00–22:00';
      case ShiftType.night:
        return '22:00–06:00';
      case ShiftType.rest:
        return '—';
    }
  }
}

class RotationConfig {
  final DateTime startDate;
  final List<String> equipeIds;

  RotationConfig({required this.startDate, required this.equipeIds});

  DateTime get startDay => DateTime(startDate.year, startDate.month, startDate.day);
}

class ShiftRotationLogic {
  /// دورة 4 أيام: صباحي، مسائي، ليلي، راحة. الموضع 0 = أول فريق، إلخ.
  static ShiftType shiftForPosition(int position, int dayInCycle) {
    final cycle = dayInCycle % 4;
    final order = [ShiftType.morning, ShiftType.evening, ShiftType.night, ShiftType.rest];
    final idx = (position + cycle) % 4;
    return order[idx];
  }
}
