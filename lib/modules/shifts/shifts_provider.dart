import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/shift_models.dart';
import 'data/shifts_repository.dart';

class ShiftsProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  ShiftsRepository? _repo;
  StreamSubscription<RotationConfig?>? _sub;

  RotationConfig? _config;
  bool _loading = true;
  String? _error;

  RotationConfig? get config => _config;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasConfig => _config != null && _config!.equipeIds.every((id) => id.isNotEmpty);

  ShiftsProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = ShiftsRepository();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();
    _repo!.watchConfig().listen(
      (c) {
        _config = c;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> setConfig(RotationConfig config) async {
    if (!_firebaseAvailable || _repo == null) return;
    _error = null;
    notifyListeners();
    try {
      await _repo!.setConfig(config);
      _config = config;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// وردية فريق في تاريخ معيّن
  ShiftType? getShiftForEquipe(String equipeId, DateTime date) {
    final c = _config;
    if (c == null) return null;
    return ShiftRotationLogic.shiftForEquipe(c, equipeId, date);
  }

  /// يوم في الدورة 0..7 لتاريخ معيّن
  int dayInCycle(DateTime date) {
    final c = _config;
    if (c == null) return 0;
    return ShiftRotationLogic.dayInCycle(c.startDay, date);
  }

  /// جدول أيام قادمة: قائمة (تاريخ, قائمة (equipeId, shift))
  List<({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})> getScheduleForDays(DateTime from, int dayCount) {
    final c = _config;
    if (c == null || c.equipeIds.every((id) => id.isEmpty)) return [];
    final list = <({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})>[];
    for (var i = 0; i < dayCount; i++) {
      final d = from.add(Duration(days: i));
      final day = DateTime(d.year, d.month, d.day);
      final cycle = ShiftRotationLogic.dayInCycle(c.startDay, day);
      final perEquipe = <({String equipeId, ShiftType shift})>[];
      for (var pos = 0; pos < 4; pos++) {
        final eid = c.equipeIds[pos];
        if (eid.isEmpty) continue;
        perEquipe.add((equipeId: eid, shift: ShiftRotationLogic.shiftForPosition(pos, cycle)));
      }
      list.add((date: day, perEquipe: perEquipe));
    }
    return list;
  }
}
