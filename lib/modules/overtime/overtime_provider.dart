import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/overtime_model.dart';
import 'data/overtime_repository.dart';

class OvertimeProvider extends ChangeNotifier {
  final _repo = OvertimeRepository();

  /// All assignments for the current equipe (admin history stream).
  List<OvertimeAssignment> _assignments = [];
  List<OvertimeAssignment> get assignments => List.unmodifiable(_assignments);

  /// Today's assignments for a given target equipe (chef pointage view).
  List<OvertimeAssignment> _todayAssignments = [];
  List<OvertimeAssignment> get todayAssignments =>
      List.unmodifiable(_todayAssignments);

  String? _todayStreamError;
  String? get todayStreamError => _todayStreamError;

  bool _loading = false;
  bool get loading => _loading;

  StreamSubscription<List<OvertimeAssignment>>? _equipeSub;
  StreamSubscription<List<OvertimeAssignment>>? _todaySub;
  StreamSubscription<List<OvertimeAssignment>>? _dateSub;

  /// Assignments filtered by a specific date (admin view).
  List<OvertimeAssignment> _dateAssignments = [];
  List<OvertimeAssignment> get dateAssignments =>
      List.unmodifiable(_dateAssignments);

  /// Listen to all assignments for this equipe (history).
  void listenForEquipe(String equipeId) {
    _equipeSub?.cancel();
    _equipeSub = _repo.streamForEquipe(equipeId).listen((list) {
      _assignments = list;
      notifyListeners();
    });
  }

  /// Listen to TODAY's overtime assignments for a target equipe (used by chef pointage).
  void listenTodayForEquipe(String equipeId) {
    _todaySub?.cancel();
    _todayStreamError = null;
    _todayAssignments = [];
    notifyListeners();

    _todaySub = _repo.streamTodayForEquipe(equipeId).listen(
      (list) {
        _todayAssignments = list;
        _todayStreamError = null;
        notifyListeners();
      },
      onError: (e) {
        _todayStreamError = e.toString();
        _todayAssignments = [];
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  /// Listen to assignments for a specific date (admin view — real-time).
  void listenForDate(DateTime date) {
    _dateSub?.cancel();
    _dateAssignments = [];
    notifyListeners();
    _dateSub = _repo.streamForDate(date).listen(
      (list) {
        _dateAssignments = list;
        notifyListeners();
      },
      onError: (_) {
        _dateAssignments = [];
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _equipeSub?.cancel();
    _todaySub?.cancel();
    _dateSub?.cancel();
    super.dispose();
  }

  Future<void> assignOvertime({
    required String employeId,
    required String employeNom,
    required String originEquipeId,
    required String originEquipeName,
    required String targetEquipeId,
    required String targetEquipeName,
    required DateTime date,
    required String adminId,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final a = OvertimeAssignment(
        id: '',
        employeId: employeId,
        employeNom: employeNom,
        originEquipeId: originEquipeId,
        originEquipeName: originEquipeName,
        targetEquipeId: targetEquipeId,
        targetEquipeName: targetEquipeName,
        date: date,
        createdAt: DateTime.now(),
        createdByAdminId: adminId,
      );
      await _repo.add(a);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Chef confirms employee ARRIVED for overtime shift.
  Future<void> confirmOvertimeArrival(String id) async {
    await _repo.confirmArrival(id, DateTime.now());
    _refreshLocal(id,
        (a) => a.copyWith(
            attendanceStatus: OvertimeAttendanceStatus.present,
            arrivalConfirmedAt: DateTime.now()));
  }

  /// Chef confirms employee DEPARTED (end of overtime shift) — records 8 hours.
  Future<void> confirmOvertimeDeparture(String id) async {
    await _repo.confirmDeparture(id, DateTime.now());
    _refreshLocal(id,
        (a) => a.copyWith(
            departureConfirmedAt: DateTime.now(),
            overtimeMinutes: 480,
            finished: true));
  }

  /// Chef marks employee as ABSENT for overtime shift.
  Future<void> markOvertimeAbsent(String id) async {
    await _repo.markAbsent(id);
    _refreshLocal(id,
        (a) => a.copyWith(
            attendanceStatus: OvertimeAttendanceStatus.absent,
            overtimeMinutes: 0,
            finished: false));
  }

  void _refreshLocal(
      String id, OvertimeAssignment Function(OvertimeAssignment) transform) {
    // Update in _assignments list.
    final idx = _assignments.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _assignments = List.from(_assignments)..[idx] = transform(_assignments[idx]);
    }
    // Update in _todayAssignments list.
    final tidx = _todayAssignments.indexWhere((a) => a.id == id);
    if (tidx != -1) {
      _todayAssignments = List.from(_todayAssignments)
        ..[tidx] = transform(_todayAssignments[tidx]);
    }
    notifyListeners();
  }

  Future<void> markAttendance(
      String id, OvertimeAttendanceStatus status) async {
    final idx = _assignments.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final updated = _assignments[idx].copyWith(attendanceStatus: status);
    await _repo.update(updated);
    _assignments = List.from(_assignments)..[idx] = updated;
    notifyListeners();
  }

  Future<void> submitAndLock(String id, String chefId) async {
    final now = DateTime.now();
    await _repo.lock(id, chefId, now);
    _refreshLocal(id,
        (a) => a.copyWith(locked: true, lockedAt: now, lockedByChefId: chefId));
  }

  Future<void> adminUnlock(String id) async {
    await _repo.unlock(id);
    _refreshLocal(id, (a) => a.copyWith(locked: false));
    // Also update _dateAssignments
    final didx = _dateAssignments.indexWhere((a) => a.id == id);
    if (didx != -1) {
      _dateAssignments = List.from(_dateAssignments)
        ..[didx] = _dateAssignments[didx].copyWith(locked: false);
      notifyListeners();
    }
  }

  Future<List<OvertimeAssignment>> getForDateRange(
          DateTime start, DateTime end) =>
      _repo.getForDateRange(start, end);

  Future<void> deleteAssignment(String id) async {
    await _repo.delete(id);
    _assignments = _assignments.where((a) => a.id != id).toList();
    _todayAssignments = _todayAssignments.where((a) => a.id != id).toList();
    notifyListeners();
  }
}
