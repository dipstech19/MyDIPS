import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/overtime_model.dart';
import 'data/overtime_repository.dart';

class OvertimeProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  OvertimeRepository? _repo;

  /// تكاليف اليوم (لجميع الفرق — تُستخدم من الأدمن)
  List<OvertimeAssignment> _todayAssignments = [];

  /// تكاليف الفريق المحدد في اليوم المحدد (تُستخدم من الشاف)
  List<OvertimeAssignment> _equipeAssignments = [];

  String? _watchedEquipeId;
  DateTime? _watchedDate;

  bool _loading = true;
  String? _error;

  List<OvertimeAssignment> get todayAssignments =>
      List.unmodifiable(_todayAssignments);
  List<OvertimeAssignment> get equipeAssignments =>
      List.unmodifiable(_equipeAssignments);
  bool get loading => _loading;
  String? get error => _error;

  StreamSubscription? _subToday;
  StreamSubscription? _subEquipe;

  OvertimeProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      return;
    }
    _repo = OvertimeRepository();
    _subscribeToday();
  }

  void _subscribeToday() {
    _subToday?.cancel();
    _subToday = _repo!.watchForDate(DateTime.now()).listen(
      (list) {
        _todayAssignments = list;
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

  /// الشاف يستدعي هذا لمراقبة تكاليف فريقه.
  void watchForEquipe(String equipeId) {
    if (_watchedEquipeId == equipeId &&
        _watchedDate != null &&
        _isSameDay(_watchedDate!, DateTime.now())) return;
    _watchedEquipeId = equipeId;
    _watchedDate = DateTime.now();
    _subEquipe?.cancel();
    _subEquipe = _repo!
        .watchForEquipeAndDate(equipeId, DateTime.now())
        .listen(
          (list) {
            _equipeAssignments = list;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// تكاليف الفريق المستقبِل في اليوم الحالي (من todayAssignments).
  List<OvertimeAssignment> getAssignmentsForEquipe(String equipeId) =>
      _todayAssignments
          .where((a) => a.targetEquipeId == equipeId)
          .toList();

  /// سجل ساعات إضافية لموظف في فريق معيّن اليوم.
  OvertimeAssignment? getForEmployee(String employeId, String targetEquipeId) {
    final matches = _todayAssignments.where(
        (a) => a.employeId == employeId && a.targetEquipeId == targetEquipeId);
    return matches.isEmpty ? null : matches.first;
  }

  // ── Admin actions ──────────────────────────────────────────────────────────

  /// الأدمن يُكلّف موظفاً بساعات إضافية في فريق آخر.
  Future<bool> assignOvertime({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String originalEquipeId,
    required String originalEquipeName,
    required String targetEquipeId,
    required String targetEquipeName,
    required String targetChefName,
    required DateTime date,
    String? adminId,
    int overtimeMinutes = 480,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    try {
      await _repo!.createOrUpdate(
        employeId: employeId,
        employeNom: employeNom,
        employeCin: employeCin,
        originalEquipeId: originalEquipeId,
        originalEquipeName: originalEquipeName,
        targetEquipeId: targetEquipeId,
        targetEquipeName: targetEquipeName,
        targetChefName: targetChefName,
        date: date,
        createdByAdminId: adminId,
        overtimeMinutes: overtimeMinutes,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// الأدمن يحذف تكليف ساعات إضافية.
  Future<bool> deleteAssignment(String docId) async {
    if (!_firebaseAvailable || _repo == null) return false;
    try {
      await _repo!.delete(docId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Chef actions ───────────────────────────────────────────────────────────

  /// شاف الفريق المستقبِل يُسجّل حضور/غياب الموظف في الشيفت الإضافي.
  Future<bool> markAttendance({
    required OvertimeAssignment assignment,
    required OvertimeAttendanceStatus status,
    String? chefId,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    try {
      await _repo!.markAttendance(
        docId: assignment.id,
        status: status,
        markedByChefId: chefId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// شاف الفريق يؤكد إنهاء الشيفت الإضافي.
  Future<bool> markFinished({
    required OvertimeAssignment assignment,
    required int overtimeMinutes,
    String? chefId,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    try {
      await _repo!.markFinished(
        docId: assignment.id,
        overtimeMinutes: overtimeMinutes,
        markedByChefId: chefId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// شاف الفريق يُرسل التقرير ويُقفل السجل — لا يمكن التعديل بعدها.
  Future<bool> submitAndLock({
    required OvertimeAssignment assignment,
    required String chefId,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    // يجب أن تكون الحالة محددة قبل الإقفال
    if (assignment.attendanceStatus == OvertimeAttendanceStatus.unset) return false;
    try {
      await _repo!.lockAssignment(
        docId: assignment.id,
        lockedByChefId: chefId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// الأدمن يفتح القفل لتعديل حالة الساعات الإضافية.
  Future<bool> adminUnlock(String docId) async {
    if (!_firebaseAvailable || _repo == null) return false;
    try {
      await _repo!.unlockAssignment(docId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// جلب تكاليف نطاق تاريخ (للـ Excel Export).
  Future<List<OvertimeAssignment>> getForDateRange(
      DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getForDateRange(start, end);
  }

  @override
  void dispose() {
    _subToday?.cancel();
    _subEquipe?.cancel();
    super.dispose();
  }
}
