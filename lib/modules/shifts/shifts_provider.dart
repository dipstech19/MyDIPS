import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/shifts_repository.dart';
import 'models/shift_models.dart';

class ShiftsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  ShiftsRepository? _repo;
  RotationConfig? _config;
  Map<String, Map<String, ShiftType>> _overrides = {};
  /// Map dateKey → DoubleDay pour accès rapide.
  Map<String, DoubleDay> _doubleDays = {};
  bool _loading = false;
  String? _error;

  ShiftsProvider() {
    if (_firebaseAvailable) {
      _repo = ShiftsRepository();
      _loadAll();
    }
    // If Firebase not available, loading stays false, no config shown.
  }

  bool get loading => _loading;
  String? get error => _error;
  bool get hasConfig => _config != null && _config!.equipeIds.any((id) => id.isNotEmpty);
  RotationConfig? get config => _config;

  /// Liste triée des jours ×2.
  List<DoubleDay> get doubleDays {
    final list = _doubleDays.values.toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Retourne true si la date est un jour ×2 (travail doublé).
  bool isDoubleDay(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _doubleDays.containsKey(key);
  }

  /// Retourne le label du jour ×2 ou null.
  String? doubleDayLabel(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _doubleDays[key]?.label;
  }

  Future<void> _loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _repo!.loadAll().timeout(
        const Duration(seconds: 15),
        onTimeout: () => (config: null, overrides: <String, Map<String, ShiftType>>{}, doubleDays: <DoubleDay>[]),
      );
      _config = data.config;
      _overrides = data.overrides;
      _doubleDays = {for (final d in data.doubleDays) d.dateKey: d};
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  /// إعادة تحميل الإعداد من Firestore (مثلاً بعد زر التحديث)
  Future<void> refresh() async {
    if (_repo == null) return;
    await _loadAll();
  }

  /// يوم في الدورة (0–7) حسب تاريخ البداية — دورة 8 أيام (يومان راحة)
  int dayInCycle(DateTime day) {
    if (_config == null) return 0;
    final start = _config!.startDay;
    final d = DateTime(day.year, day.month, day.day);
    final diff = d.difference(start).inDays;
    return diff >= 0 ? diff % ShiftRotationLogic.cycleDays : 0;
  }

  ShiftType getShiftForEquipe(String equipeId, DateTime date) {
    if (_config == null) return ShiftType.rest;
    final pos = _config!.equipeIds.indexOf(equipeId);
    if (pos < 0) return ShiftType.rest;
    final key = '${date.year}-${date.month}-${date.day}';
    if (_overrides[key] != null && _overrides[key]![equipeId] != null) {
      return _overrides[key]![equipeId]!;
    }
    return ShiftRotationLogic.shiftForPosition(pos, dayInCycle(date));
  }

  /// جدول الأيام: لكل يوم قائمة (equipeId, shift)
  List<({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})> getScheduleForDays(DateTime startDay, int dayCount) {
    final list = <({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})>[];
    for (var i = 0; i < dayCount; i++) {
      final date = startDay.add(Duration(days: i));
      final perEquipe = <({String equipeId, ShiftType shift})>[];
      if (_config != null) {
        for (var j = 0; j < _config!.equipeIds.length; j++) {
          final eid = _config!.equipeIds[j];
          perEquipe.add((equipeId: eid, shift: getShiftForEquipe(eid, date)));
        }
      }
      list.add((date: date, perEquipe: perEquipe));
    }
    return list;
  }

  Future<void> setShiftOverride(DateTime date, String equipeId, ShiftType shift) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _overrides[key] ??= {};
    _overrides[key]![equipeId] = shift;
    if (_repo != null) {
      try {
        await _repo!.setShiftOverride(date, equipeId, shift);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setConfig(RotationConfig c) async {
    _config = c;
    if (_repo != null) {
      try {
        await _repo!.setConfig(c);
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Ajouter ou mettre à jour un jour ×2.
  Future<void> setDoubleDay(DateTime date, {String? label}) async {
    final day = DoubleDay(date: DateTime(date.year, date.month, date.day), label: label?.trim().isEmpty == true ? null : label?.trim());
    _doubleDays[day.dateKey] = day;
    notifyListeners();
    if (_repo != null) {
      try {
        await _repo!.setDoubleDay(day);
      } catch (_) {}
    }
  }

  /// Supprimer un jour ×2.
  Future<void> removeDoubleDay(DateTime date) async {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    _doubleDays.remove(key);
    notifyListeners();
    if (_repo != null) {
      try {
        await _repo!.removeDoubleDay(date);
      } catch (_) {}
    }
  }
}
