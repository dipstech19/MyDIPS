import 'package:flutter/material.dart';

enum ShiftType { morning, evening, night, rest }

/// Représente un jour de travail doublé (×2) — jour férié travaillé ou jour exceptionnel.
class DoubleDay {
  final DateTime date;
  final String? label; // e.g. "Fête du travail", "Aïd", etc.

  DoubleDay({required this.date, this.label});

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'label': label ?? '',
      };

  static DoubleDay fromMap(Map<String, dynamic> map) {
    final raw = map['date'] as String? ?? '';
    final parts = raw.split('-');
    final dt = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1)
        : DateTime.now();
    return DoubleDay(date: DateTime(dt.year, dt.month, dt.day), label: map['label'] as String?);
  }
}

/// Jour férié (sans travail) — export Excel OCP « Hors équipe » : marqueur **JF**.
class PublicHoliday {
  final DateTime date;
  final String? label;

  PublicHoliday({required this.date, this.label});

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'label': label ?? '',
      };

  static PublicHoliday fromMap(Map<String, dynamic> map) {
    final raw = map['date'] as String? ?? '';
    final parts = raw.split('-');
    final dt = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1)
        : DateTime.now();
    return PublicHoliday(date: DateTime(dt.year, dt.month, dt.day), label: map['label'] as String?);
  }
}

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
