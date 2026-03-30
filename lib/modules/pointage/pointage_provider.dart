import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/pointage_model.dart';
import 'data/pointage_repository.dart';
import 'pointage_hours_config.dart';
import 'services/pointage_export_service.dart';

/// نافذة تسجيل الشاف: الدخول (بداية الشيفت + 2h) أو الخروج (نهاية الشيفت + 2h) — لإرسال التقرير يُكمّل الغياب في نافذة الخروج.
bool _isChefMarkingWindow(PointageHoursConfig config, DateTime now, Duration grace) {
  return config.canMarkArrivalNow(now, graceBefore: grace, graceAfter: grace) ||
      config.canMarkDepartureNow(now, graceBefore: grace, graceAfter: grace);
}

class PointageProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  PointageRepository? _repo;

  List<PointageRecord> _todayPointage = [];
  List<PointageRecord> _pointageByDate = [];
  DateTime? _selectedReportDate;
  List<String> _nonWorkingEquipeIds = [];
  List<DailyReport> _reports = [];
  int _todayPresentCount = 0;
  int _monthlyReportsCount = 0;
  bool _loading = true;
  String? _error;

  List<PointageRecord> get todayPointage => List.unmodifiable(_todayPointage);
  List<PointageRecord> get pointageByDate => List.unmodifiable(_pointageByDate);
  DateTime? get selectedReportDate => _selectedReportDate;
  List<String> get nonWorkingEquipeIds => List.unmodifiable(_nonWorkingEquipeIds);
  List<DailyReport> get reports => List.unmodifiable(_reports);
  int get todayPresentCount => _todayPresentCount;
  int get monthlyReportsCount => _monthlyReportsCount;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  bool _ignoreTimeWindowsForTest = false;
  bool get ignoreTimeWindowsForTest => _ignoreTimeWindowsForTest;
  void setIgnoreTimeWindowsForTest(bool value) {
    if (_ignoreTimeWindowsForTest == value) return;
    _ignoreTimeWindowsForTest = value;
    notifyListeners();
  }

  StreamSubscription? _subPointage;
  StreamSubscription? _subReports;
  StreamSubscription? _subByDate;

  PointageProvider() {
    if (!_firebaseAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }
    _repo = PointageRepository();
    _subscribe();
  }

  void _subscribe() {
    _loading = true;
    _error = null;
    notifyListeners();

    _subPointage?.cancel();
    _subReports?.cancel();
    _subByDate?.cancel();

    final repo = _repo!;

    _subPointage = repo.watchTodayPointage().listen(
      (list) {
        _todayPointage = list;
        _todayPresentCount = list.where((p) => p.isFinalPresent).length;
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

    _subReports = repo.watchReports().listen(
      (list) {
        _reports = list;
        final now = DateTime.now();
        _monthlyReportsCount = list.where((r) =>
            r.submittedAt.year == now.year && r.submittedAt.month == now.month).length;
        notifyListeners();
      },
      onError: (e) {
        _error = _error ?? e.toString();
        notifyListeners();
      },
    );
  }

  DateTime? _lastNonWorkingDate;

  void selectReportDate(DateTime? date) {
    _selectedReportDate = date;
    if (date == null || _repo == null) {
      _pointageByDate = [];
      _nonWorkingEquipeIds = [];
      _lastNonWorkingDate = null;
      notifyListeners();
      return;
    }
    _loadNonWorkingForDate(date);
    _subByDate?.cancel();
    _subByDate = _repo!.watchPointageByDate(date).listen(
      (list) {
        _pointageByDate = list;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> _loadNonWorkingForDate(DateTime date) async {
    if (_repo == null) return;
    try {
      _nonWorkingEquipeIds = await _repo!.getNonWorkingEquipeIds(date);
      _lastNonWorkingDate = DateTime(date.year, date.month, date.day);
      notifyListeners();
    } catch (_) {
      _nonWorkingEquipeIds = [];
      _lastNonWorkingDate = DateTime(date.year, date.month, date.day);
      notifyListeners();
    }
  }

  /// Pour l'admin: charger la liste des équipes « ne travaillent pas » pour la date affichée (ex. aujourd'hui si pas de date choisie).
  Future<void> ensureNonWorkingLoadedForDate(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    if (_lastNonWorkingDate == d) return;
    await _loadNonWorkingForDate(date);
  }

  Future<void> setEquipeNonWorkingForDate(DateTime date, String equipeId, bool nonWorking) async {
    if (!_firebaseAvailable || _repo == null) return;
    await _repo!.setEquipeNonWorkingForDate(date, equipeId, nonWorking);
    await _loadNonWorkingForDate(date);
  }

  bool isEquipeNonWorking(String equipeId) => _nonWorkingEquipeIds.contains(equipeId);

  PointageRecord? getRecordForEmployee(String employeId) {
    // Prefer the non-renfort (original) record when multiple exist.
    final list = _todayPointage.where((p) => p.employeId == employeId).toList();
    if (list.isEmpty) return null;
    final nonRenfort = list.where((r) => !r.tempAssigned).toList();
    return nonRenfort.isNotEmpty ? nonRenfort.first : list.first;
  }

  /// Returns the record for a specific employee in a specific team.
  /// For Renfort workers, this returns the independent Renfort record for the target team,
  /// not the original team's record.
  PointageRecord? getRecordForEmployeeInEquipe(String employeId, String equipeId) {
    final list = _todayPointage.where((p) => p.employeId == employeId).toList();
    if (list.isEmpty) return null;
    // First try exact equipeId match.
    final exact = list.where((r) => r.equipeId == equipeId).toList();
    if (exact.isNotEmpty) return exact.first;
    // Fallback: return the non-renfort record.
    final nonRenfort = list.where((r) => !r.tempAssigned).toList();
    return nonRenfort.isNotEmpty ? nonRenfort.first : list.first;
  }

  /// جلب سجلات يوم معيّن (للسائق عندما الفريق في وردية ليلية قبل 07:00).
  Future<List<PointageRecord>> getPointageRecordsForDate(DateTime date) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageForDate(date);
  }

  /// جلب كل سجلات البوانتاج لنطاق تاريخ (من start إلى end شامل) — للإحصائيات متعددة الأيام.
  Future<List<PointageRecord>> getPointageForDateRange(DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageForDateRange(start, end);
  }

  /// سجل نقطاج لموظف في تاريخ معيّن (للتحقق من «في تكويني» في الحوار)
  Future<PointageRecord?> getRecordForEmployeeForDate(String employeId, DateTime date) async {
    if (!_firebaseAvailable || _repo == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return getRecordForEmployee(employeId);
    return _repo!.getByEmployeAndDate(employeId, day);
  }

  /// للحصول على الحالة المعروضة حسب الدور (للتوافق مع الواجهة الحالية)
  AttendanceStatus getStatusForEmployee(String employeId) {
    final record = getRecordForEmployee(employeId);
    if (record == null) return AttendanceStatus.absent;
    if (record.adminFinalStatus != null) {
      return record.adminFinalStatus!;
    }
    // Chef overrides driver.
    if (record.chefStatus != ChefPointageStatus.unset) {
      return record.chefStatus == ChefPointageStatus.present
          ? AttendanceStatus.present
          : AttendanceStatus.absent;
    }
    switch (record.reconciledStatus) {
      case ReconciledStatus.confirmedPresent:
        return AttendanceStatus.present;
      case ReconciledStatus.confirmedAbsent:
        return AttendanceStatus.absent;
      case ReconciledStatus.discrepancy:
        return AttendanceStatus.absent;
      case ReconciledStatus.pending:
        break;
    }
    if (record.driverStatus != DriverPointageStatus.unset) {
      switch (record.driverStatus) {
        case DriverPointageStatus.present:
          return AttendanceStatus.present;
        case DriverPointageStatus.absent:
          return AttendanceStatus.absent;
        case DriverPointageStatus.enVehicule:
          // Legacy value (driver "in vehicle") treated as present.
          return AttendanceStatus.present;
        case DriverPointageStatus.unset:
          break;
      }
    }
    return AttendanceStatus.unmarked;
  }

  /// حالة السائق للموظف (حاضر | غائب | في المركبة)
  DriverPointageStatus getDriverStatusForEmployee(String employeId) {
    final r = getRecordForEmployee(employeId);
    return r?.driverStatus ?? DriverPointageStatus.unset;
  }

  /// حالة الشاف للموظف (حاضر | غائب)
  ChefPointageStatus getChefStatusForEmployee(String employeId) {
    final r = getRecordForEmployee(employeId);
    return r?.chefStatus ?? ChefPointageStatus.unset;
  }

  bool isDriverLockedForEmployee(String employeId) {
    if (_ignoreTimeWindowsForTest) return false;
    return getRecordForEmployee(employeId)?.driverLocked ?? false;
  }

  bool isChefLockedForEmployee(String employeId) {
    if (_ignoreTimeWindowsForTest) return false;
    return getRecordForEmployee(employeId)?.chefLocked ?? false;
  }

  /// عدد أيام الحضور المؤكدة لموظف بين تاريخين (من نقطاج).
  Future<int> getPresentDaysCountForEmployee(String employeId, DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return 0;
    final list = await _repo!.getPointageForEmployeeRange(employeId, start, end);
    return list.where((r) => r.isFinalPresent).length;
  }

  /// جميع سجلات الحضور في نطاق تواريخ (لتصدير Excel).
  /// [knownEmployeIds] — تمرير معرفات الموظفين المراد تصديرهم لضمان جلب
  /// سجلاتهم حتى لو لم تظهر في الاستعلام الأولي.
  Future<List<PointageRecord>> getPointageInDateRange(
    DateTime start,
    DateTime end, {
    Set<String>? knownEmployeIds,
  }) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageInDateRange(start, end, knownEmployeIds: knownEmployeIds);
  }

  Future<void> markAttendance({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required AttendanceStatus status,
    String? markedById,
    String? markedByName,
  }) async {
    if (!_firebaseAvailable) return;
    final record = PointageRecord(
      id: '',
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      status: status,
      date: DateTime.now(),
      createdAt: DateTime.now(),
      markedById: markedById,
      markedByName: markedByName,
    );
    await _repo!.markAttendance(record);
  }

  /// يُرجع true إذا تم التسجيل، false إذا كان خارج وقت البوانتاج.
  /// [configOverride] إن وُجد يُستخدم للتحقق من الوقت؛ وإلا الإعداد العام.
  Future<bool> markDriverAttendance({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required DriverPointageStatus driverStatus,
    String? driverId,
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!config.canMarkArrivalNow(now, graceBefore: grace, graceAfter: grace)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    final record = PointageRecord(
      id: '',
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      status: AttendanceStatus.unmarked,
      date: pointageDate,
      createdAt: now,
      driverStatus: driverStatus,
    );
    await _repo!.setDriverStatus(
      record,
      driverStatus,
      driverId,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// يُرجع true إذا تم التسجيل، false إذا كان خارج وقت البوانتاج.
  /// [configOverride] إن وُجد يُستخدم للتحقق من الوقت؛ وإلا الإعداد العام.
  Future<bool> markChefAttendance({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required ChefPointageStatus chefStatus,
    String? chefId,
    String? absenceReason,
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!_isChefMarkingWindow(config, now, grace)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    final record = PointageRecord(
      id: '',
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      status: AttendanceStatus.unmarked,
      date: pointageDate,
      createdAt: now,
      chefStatus: chefStatus,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
    );
    await _repo!.setChefStatus(
      record,
      chefStatus,
      chefId,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// تسجيل حضور عامل renfort (محوَّل مؤقتاً) باستخدام سجله المستقل في الفريق الثاني.
  /// يستخدم record.id للكتابة على الـ docId الصحيح وليس السجل الأصلي.
  Future<bool> markRenfortChefAttendance({
    required PointageRecord renfortRecord,
    required ChefPointageStatus chefStatus,
    String? chefId,
    String? absenceReason,
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!_isChefMarkingWindow(config, now, grace)) return false;
    await _repo!.setChefStatus(
      renfortRecord,
      chefStatus,
      chefId,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// تأكيد الساعات الإضافية (للشيفت الموالي) على نفس record (نفس date/docId).
  Future<bool> markOvertimeChefAttendance({
    required PointageRecord record,
    required ChefPointageStatus overtimeChefStatus,
    String? chefId,
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!config.canMarkOvertimeRelatedNow(now, graceBefore: grace, graceAfter: grace)) return false;
    await _repo!.setOvertimeChefStatus(
      record,
      overtimeChefStatus,
      chefId,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// يُرجع true إذا تم الإرسال، false إذا كان خارج وقت البوانتاج.
  /// [configOverride] إن وُجد يُستخدم للتحقق من الوقت؛ وإلا الإعداد العام.
  Future<bool> submitDriverReport({PointageHoursConfig? configOverride}) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!config.canSubmitReportNow(now, graceBefore: grace, graceAfter: grace)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    await _repo!.submitDriverReport(pointageDate);
    return true;
  }

  /// يُرجع true إذا تم الإرسال، false إذا كان خارج وقت البوانتاج.
  /// [configOverride] إن وُجد يُستخدم للتحقق من الوقت؛ وإلا الإعداد العام.
  Future<bool> submitChefReport(String equipeId, {PointageHoursConfig? configOverride}) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!config.canSubmitReportNow(now, graceBefore: grace, graceAfter: grace)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    await _repo!.submitChefReport(equipeId, pointageDate);
    return true;
  }

  /// تسجيل حالة الخروج: لا يزال يعمل | انتهى (مع اختياري ساعات إضافية).
  /// يُرجع true إذا تم التسجيل، false إذا كان خارج نافذة الخروج.
  Future<bool> setDepartureStatus({
    required PointageRecord record,
    required DepartureStatus status,
    int? overtimeMinutes,
    String? incompleteShiftReason,
    int? workedMinutesBeforeStop,
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    final grace = _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;
    if (!config.canMarkDepartureNow(now, graceBefore: grace, graceAfter: grace)) return false;
    int? resolvedOvertime = overtimeMinutes;
    if (status == DepartureStatus.finished) {
      if (record.tempAssigned) {
        // Renfort (heures sup):
        // - If the worker is present (chef/driver marked present) in the target team => count overtime.
        // - Otherwise overtime is 0.
        final defaultOtMinutes = (PointageExportService.hoursPerDay * 60).toInt();
        final isPresentInTarget = record.isFinalPresent;
        if (!isPresentInTarget) {
          resolvedOvertime = 0;
        } else if (record.workedMinutesBeforeStop != null && record.workedMinutesBeforeStop! > 0) {
          // If the worker previously didn't complete the shift (N'a pas terminé) and provided worked minutes,
          // convert those worked minutes directly to overtime minutes in the target team.
          resolvedOvertime = record.workedMinutesBeforeStop;
        } else if (record.overtimeChefStatus == ChefPointageStatus.present) {
          // Use overtimeArrivalMarkedAt when available; otherwise default to 8h.
          final otArrival = record.overtimeArrivalMarkedAt;
          if (otArrival != null) {
            final mins = now.difference(otArrival).inMinutes;
            resolvedOvertime = mins < 0 ? 0 : mins;
          } else {
            resolvedOvertime = defaultOtMinutes;
          }
          // Ensure at least one full shift is counted as overtime.
          if (resolvedOvertime < defaultOtMinutes) resolvedOvertime = defaultOtMinutes;
        } else {
          // Fallback: if overtimeChefStatus isn't explicitly set, still count default 8h when present.
          resolvedOvertime = defaultOtMinutes;
        }
      } else {
        // Normal worker (not Renfort): "Fin du travail" = 8 natural hours, no overtime by default.
        // overtimeMinutes stays as passed in (could be null/0 unless explicitly entered by user).
        resolvedOvertime = overtimeMinutes ?? 0;
      }
    }
    await _repo!.setDepartureStatus(
      record,
      status,
      overtimeMinutes: resolvedOvertime,
      incompleteShiftReason: incompleteShiftReason,
      workedMinutesBeforeStop: workedMinutesBeforeStop,
    );
    return true;
  }

  Future<void> setAdminOverride(
    String pointageDocId,
    AttendanceStatus? status, {
    String? absenceReason,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
  }) async {
    if (!_firebaseAvailable) return;
    await _repo!.setAdminOverride(
      pointageDocId,
      status,
      absenceReason: status == AttendanceStatus.absent ? absenceReason : null,
      trainingStartAt: status == AttendanceStatus.training ? trainingStartAt : null,
      trainingEndAt: status == AttendanceStatus.training ? trainingEndAt : null,
    );
  }

  /// تعيين الحضور النهائي من الأدمن (يُنشئ سجلاً إن لم يكن موجوداً). يدعم أي تاريخ [viewDate].
  Future<void> setAdminOverrideForEmployee({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required AttendanceStatus status,
    String? absenceReason,
    DateTime? viewDate,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
  }) async {
    if (!_firebaseAvailable) return;
    final date = viewDate ?? DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    PointageRecord? existing;
    if (viewDate == null) {
      existing = getRecordForEmployee(employeId);
    } else {
      existing = await _repo!.getByEmployeAndDate(employeId, day);
    }
    if (existing != null) {
      await _repo!.setAdminOverride(
        existing.id,
        status,
        absenceReason: status == AttendanceStatus.absent ? absenceReason : null,
        trainingStartAt: status == AttendanceStatus.training ? trainingStartAt : null,
        trainingEndAt: status == AttendanceStatus.training ? trainingEndAt : null,
      );
    } else {
      final now = DateTime.now();
      final confirmDeparture = status == AttendanceStatus.present ||
          status == AttendanceStatus.training ||
          status == AttendanceStatus.leave;
      final record = PointageRecord(
        id: '',
        employeId: employeId,
        employeNom: employeNom,
        employeCin: employeCin,
        equipeId: equipeId,
        equipeName: equipeName,
        chefName: chefName,
        status: status,
        date: day,
        createdAt: now,
        adminFinalStatus: status,
        absenceReason: status == AttendanceStatus.absent ? absenceReason : null,
        arrivalMarkedAt: confirmDeparture ? now : null,
        departureStatus: confirmDeparture ? DepartureStatus.finished : DepartureStatus.unset,
        departureMarkedAt: confirmDeparture ? now : null,
        trainingStartAt: status == AttendanceStatus.training ? trainingStartAt : null,
        trainingEndAt: status == AttendanceStatus.training ? trainingEndAt : null,
      );
      await _repo!.createRecordWithAdminOverride(record);
    }
  }

  /// Affectation temporaire d'un employé vers une autre équipe pour une journée (renfort).
  /// Crée un sجل SÉPARÉ (docId différent) pour le fريق cible afin que les pointages
  /// des deux équipes soient totalement indépendants.
  Future<void> assignEmployeeTemp({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String targetEquipeId,
    required String targetEquipeName,
    required String targetChefName,
    required String originalEquipeId,
    required DateTime day,
    String? shiftOverride,
    int defaultOvertimeMinutes = 480,
  }) async {
    if (!_firebaseAvailable || _repo == null) return;
    final d = DateTime(day.year, day.month, day.day);
    // Clean the original record if it was wrongly marked as tempAssigned by the old system.
    await _repo!.cleanOriginalRecordFromRenfort(employeId, d);
    // Create an INDEPENDENT record for the target team.
    // The original team's record is untouched so its chef/driver statuses remain separate.
    await _repo!.createOrUpdateRenfortRecord(
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      targetEquipeId: targetEquipeId,
      targetEquipeName: targetEquipeName,
      targetChefName: targetChefName,
      originalEquipeId: originalEquipeId,
      day: d,
      shiftOverride: shiftOverride,
      defaultOvertimeMinutes: defaultOvertimeMinutes,
    );
  }

  Future<void> submitDailyReport({
    required String equipeId,
    required String equipeName,
    required String chefId,
    required String chefName,
    required int totalEmployees,
    required int presentCount,
    required int absentCount,
    required int notInVehicleCount,
    String? notes,
  }) async {
    if (!_firebaseAvailable) return;
    final report = DailyReport(
      id: '',
      date: DateTime.now(),
      equipeId: equipeId,
      equipeName: equipeName,
      chefId: chefId,
      chefName: chefName,
      totalEmployees: totalEmployees,
      presentCount: presentCount,
      absentCount: absentCount,
      notInVehicleCount: notInVehicleCount,
      submittedAt: DateTime.now(),
      notes: notes,
    );
    await _repo!.submitReport(report);
  }

  /// Réinitialise les données pointage (pointages + rapports) sur une plage.
  Future<void> clearPointageAndReportsInDateRange(DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return;
    await _repo!.clearPointageAndReportsInDateRange(start, end);
    if (_selectedReportDate != null) {
      selectReportDate(_selectedReportDate);
    }
  }

  /// تنظيف كل السجلات الملوثة من النظام القديم (tempAssigned في السجل الأصلي).
  /// يُستخدم مرة واحدة لإصلاح البيانات الموجودة في Firestore.
  Future<void> fixLegacyRenfortRecords() async {
    if (!_firebaseAvailable || _repo == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Get all today's records that are tempAssigned but use the OLD docId format (no _renfort_ in id).
    final records = _todayPointage.where((r) {
      return r.tempAssigned && !r.id.contains('_renfort_');
    }).toList();
    for (final r in records) {
      // Fix: remove tempAssigned from the original record.
      await _repo!.updatePointageFields(r.id, {
        'tempAssigned': false,
        'originalEquipeId': null,
        // Restore equipeId to the original if we can (using originalEquipeId stored in the record).
        if ((r.originalEquipeId ?? '').isNotEmpty) 'equipeId': r.originalEquipeId,
        if ((r.originalEquipeId ?? '').isNotEmpty) 'equipeName': r.equipeName,
      });
    }
    // Reload.
    selectReportDate(today);
  }

  @override
  void dispose() {
    _subPointage?.cancel();
    _subReports?.cancel();
    _subByDate?.cancel();
    super.dispose();
  }
}
