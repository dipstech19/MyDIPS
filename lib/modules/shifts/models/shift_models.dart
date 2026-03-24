import 'package:flutter/material.dart';

enum ShiftType { morning, evening, night, rest }

extension ShiftTypeExt on ShiftType {
  String get shortLabel {
    switch (this) {
      case ShiftType.morning:
        return 'P1';
      case ShiftType.evening:
        return 'P2';
      case ShiftType.night:
        return 'P3';
      case ShiftType.rest:
        return 'RH';
    }
  }

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

  DateTime getShiftEnd(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    switch (this) {
      case ShiftType.morning:
        return DateTime(d.year, d.month, d.day, 14, 0);
      case ShiftType.evening:
        return DateTime(d.year, d.month, d.day, 22, 0);
      case ShiftType.night:
        return DateTime(d.year, d.month, d.day + 1, 6, 0);
      case ShiftType.rest:
        return DateTime(d.year, d.month, d.day, 23, 59, 59);
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
