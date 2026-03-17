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
  /// دورة 8 أيام: يومان صباحي، يومان مسائي، يومان ليلي، يومان راحة (كما كان سابقاً).
  /// الموضع 0 = أول فريق، إلخ. كل فريق يحصل على يومين متتاليين من كل نوع.
  static const int cycleDays = 8;
  static const List<ShiftType> _baseOrder = [
    ShiftType.morning,
    ShiftType.morning,
    ShiftType.evening,
    ShiftType.evening,
    ShiftType.night,
    ShiftType.night,
    ShiftType.rest,
    ShiftType.rest,
  ];

  static ShiftType shiftForPosition(int position, int dayInCycle) {
    final d = dayInCycle % cycleDays;
    final idx = (d + position * 2) % cycleDays;
    return _baseOrder[idx];
  }
}
