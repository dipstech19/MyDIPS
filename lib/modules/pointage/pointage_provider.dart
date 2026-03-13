import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'models/pointage_model.dart';
import 'data/pointage_repository.dart';
import 'pointage_hours_config.dart';

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
    final list = _todayPointage.where((p) => p.employeId == employeId).toList();
    return list.isEmpty ? null : list.first;
  }

  /// جلب سجلات يوم معيّن (للسائق عندما الفريق في وردية ليلية قبل 07:00).
  Future<List<PointageRecord>> getPointageRecordsForDate(DateTime date) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageForDate(date);
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
    if (record == null) return AttendanceStatus.unmarked;
    if (record.adminFinalStatus != null) {
      return record.adminFinalStatus!;
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
          return AttendanceStatus.notInVehicle;
        case DriverPointageStatus.unset:
          break;
      }
    }
    if (record.chefStatus != ChefPointageStatus.unset) {
      return record.chefStatus == ChefPointageStatus.present
          ? AttendanceStatus.present
          : AttendanceStatus.absent;
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
    return getRecordForEmployee(employeId)?.driverLocked ?? false;
  }

  bool isChefLockedForEmployee(String employeId) {
    return getRecordForEmployee(employeId)?.chefLocked ?? false;
  }

  /// عدد أيام الحضور المؤكدة لموظف بين تاريخين (من نقطاج).
  Future<int> getPresentDaysCountForEmployee(String employeId, DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return 0;
    final list = await _repo!.getPointageForEmployeeRange(employeId, start, end);
    return list.where((r) => r.isFinalPresent).length;
  }

  /// جميع سجلات الحضور في نطاق تواريخ (لتصدير Excel).
  Future<List<PointageRecord>> getPointageInDateRange(DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageInDateRange(start, end);
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
    if (!config.canMarkArrivalNow(now)) return false;
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
    await _repo!.setDriverStatus(record, driverStatus, driverId);
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
    if (!config.canMarkArrivalNow(now)) return false;
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
    await _repo!.setChefStatus(record, chefStatus, chefId, absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null);
    return true;
  }

  /// يُرجع true إذا تم الإرسال، false إذا كان خارج وقت البوانتاج.
  /// [configOverride] إن وُجد يُستخدم للتحقق من الوقت؛ وإلا الإعداد العام.
  Future<bool> submitDriverReport({PointageHoursConfig? configOverride}) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!config.canMarkArrivalNow(now)) return false;
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
    if (!config.canMarkArrivalNow(now)) return false;
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
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    if (!config.canMarkDepartureNow(DateTime.now())) return false;
    await _repo!.setDepartureStatus(record, status, overtimeMinutes: overtimeMinutes);
    return true;
  }

  Future<void> setAdminOverride(String pointageDocId, AttendanceStatus? status, {String? absenceReason}) async {
    if (!_firebaseAvailable) return;
    await _repo!.setAdminOverride(pointageDocId, status, absenceReason: status == AttendanceStatus.absent ? absenceReason : null);
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
      await _repo!.setAdminOverride(existing.id, status, absenceReason: status == AttendanceStatus.absent ? absenceReason : null);
    } else {
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
        createdAt: DateTime.now(),
        adminFinalStatus: status,
        absenceReason: status == AttendanceStatus.absent ? absenceReason : null,
      );
      await _repo!.createRecordWithAdminOverride(record);
    }
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

  @override
  void dispose() {
    _subPointage?.cancel();
    _subReports?.cancel();
    _subByDate?.cancel();
    super.dispose();
  }
}
