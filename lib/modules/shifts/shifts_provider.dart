import 'package:flutter/material.dart';
import 'models/shift_models.dart';

class ShiftsProvider extends ChangeNotifier {
  RotationConfig? _config;
  final Map<String, Map<String, ShiftType>> _overrides = {};

  bool get loading => false;
  String? get error => null;

  bool get hasConfig => _config != null && _config!.equipeIds.any((id) => id.isNotEmpty);

  RotationConfig? get config => _config;

  /// يوم في الدورة (0–3) حسب تاريخ البداية
  int dayInCycle(DateTime day) {
    if (_config == null) return 0;
    final start = _config!.startDay;
    final d = DateTime(day.year, day.month, day.day);
    final diff = d.difference(start).inDays;
    return diff >= 0 ? diff % 4 : 0;
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
    notifyListeners();
  }

  Future<void> setConfig(RotationConfig c) async {
    _config = c;
    notifyListeners();
  }
}
