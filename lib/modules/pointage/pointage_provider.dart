import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../employees/models/employe_model.dart';
import 'models/pointage_model.dart';
import 'data/pointage_repository.dart';
import 'pointage_hours_config.dart';
import 'services/pointage_export_service.dart';

/// Ù†Ø§ÙØ°Ø© ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø´Ø§Ù: Ø§Ù„Ø¯Ø®ÙˆÙ„ (âˆ’30 Ø¯ â†’ Ø¨Ø¯Ø§ÙŠØ© + 2h) Ø£Ùˆ Ø§Ù„Ø®Ø±ÙˆØ¬ (âˆ’30 Ø¯ â†’ Ù†Ù‡Ø§ÙŠØ© + 2h) â€” Ù„Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„ØªÙ‚Ø±ÙŠØ± ÙŠÙÙƒÙ…Ù‘Ù„ Ø§Ù„ØºÙŠØ§Ø¨ ÙÙŠ Ù†Ø§ÙØ°Ø© Ø§Ù„Ø®Ø±ÙˆØ¬.
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

  /// Verrouillage immÃ©diat aprÃ¨s confirmation dâ€™envoi (rÃ©seau lent) â€” rÃ©voquÃ© quand Firestore confirme.
  bool _optimisticDriverReportLocked = false;
  final Set<String> _optimisticChefLockedEmployeIds = <String>{};

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

  bool get optimisticDriverReportLocked => _optimisticDriverReportLocked;

  /// Au moins un document du jour porte dÃ©jÃ  un envoi chauffeur (batch global).
  bool get hasDriverReportBeenSubmittedGlobally =>
      _todayPointage.any((p) => p.submittedByDriverAt != null);

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

    final logicalToday = getPointageDateForConfig(PointageHoursConfig.instance, DateTime.now());
    _subPointage = repo.watchTodayPointage(logicalDate: logicalToday).listen(
      (list) {
        _todayPointage = list;
        _reconcileOptimisticLocksWithRemote(list);
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

  void _reconcileOptimisticLocksWithRemote(List<PointageRecord> list) {
    if (_optimisticDriverReportLocked) {
      final driverMarked =
          list.where((p) => p.driverStatus != DriverPointageStatus.unset).toList();
      if (driverMarked.isNotEmpty &&
          driverMarked.every((p) => p.submittedByDriverAt != null)) {
        _optimisticDriverReportLocked = false;
      }
    }
    if (_optimisticChefLockedEmployeIds.isNotEmpty) {
      _optimisticChefLockedEmployeIds.removeWhere(
        (id) => list.any((p) => p.employeId == id && p.submittedByChefAt != null),
      );
    }
  }

  /// AprÃ¨s confirmation utilisateur : bloque tout de suite lâ€™UI chauffeur (mÃªme si la sync tarde).
  void applyOptimisticDriverReportLock() {
    if (_optimisticDriverReportLocked) return;
    _optimisticDriverReportLocked = true;
    notifyListeners();
  }

  /// AprÃ¨s confirmation chef : bloque les fiches des IDs listÃ©s jusquâ€™Ã  rÃ©ception Firestore.
  void applyOptimisticChefReportLock(Set<String> employeIds) {
    _optimisticChefLockedEmployeIds
      ..clear()
      ..addAll(employeIds);
    notifyListeners();
  }

  void rollbackOptimisticChefReportLock() {
    if (_optimisticChefLockedEmployeIds.isNotEmpty) {
      _optimisticChefLockedEmployeIds.clear();
      notifyListeners();
    }
  }

  Duration get _timeGrace => _ignoreTimeWindowsForTest ? const Duration(hours: 8) : Duration.zero;

  bool _arrivalWindowOk(PointageHoursConfig config, DateTime now, {bool bypassTimeWindows = false}) {
    if (bypassTimeWindows) return true;
    final g = _timeGrace;
    return config.canMarkArrivalNow(now, graceBefore: g, graceAfter: g);
  }

  bool _chefMarkingWindowOk(PointageHoursConfig config, DateTime now, {bool bypassTimeWindows = false}) {
    if (bypassTimeWindows) return true;
    return _isChefMarkingWindow(config, now, _timeGrace);
  }

  bool _departureWindowOk(PointageHoursConfig config, DateTime now, {bool bypassTimeWindows = false}) {
    if (bypassTimeWindows) return true;
    final g = _timeGrace;
    return config.canMarkDepartureNow(now, graceBefore: g, graceAfter: g);
  }

  bool _submitReportWindowOk(PointageHoursConfig config, DateTime now, {bool bypassTimeWindows = false}) {
    if (bypassTimeWindows) return true;
    final g = _timeGrace;
    return config.canSubmitReportNow(now, graceBefore: g, graceAfter: g);
  }

  bool _overtimeRelatedWindowOk(PointageHoursConfig config, DateTime now, {bool bypassTimeWindows = false}) {
    if (bypassTimeWindows) return true;
    final g = _timeGrace;
    return config.canMarkOvertimeRelatedNow(now, graceBefore: g, graceAfter: g);
  }

  /// Ã‰crit seulement sur Firestore (fenÃªtre horaire vÃ©rifiÃ©e ici). Utiliser aprÃ¨s verrou optimiste.
  /// [equipeId] obligatoire pour n'affecter que les enregistrements de la bonne Ã©quipe.
  Future<bool> submitDriverReportToFirestore({
    required String equipeId,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    if (equipeId.isEmpty) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_submitReportWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    await _repo!.submitDriverReport(pointageDate, equipeId: equipeId);
    return true;
  }

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

  /// Pour l'admin: charger la liste des Ã©quipes Â« ne travaillent pas Â» pour la date affichÃ©e (ex. aujourd'hui si pas de date choisie).
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

  /// Ø¬Ù„Ø¨ Ø³Ø¬Ù„Ø§Øª ÙŠÙˆÙ… Ù…Ø¹ÙŠÙ‘Ù† (Ù„Ù„Ø³Ø§Ø¦Ù‚ Ø¹Ù†Ø¯Ù…Ø§ Ø§Ù„ÙØ±ÙŠÙ‚ ÙÙŠ ÙˆØ±Ø¯ÙŠØ© Ù„ÙŠÙ„ÙŠØ© Ù‚Ø¨Ù„ 07:00).
  Future<List<PointageRecord>> getPointageRecordsForDate(DateTime date) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageForDate(date);
  }

  /// Ø¬Ù„Ø¨ ÙƒÙ„ Ø³Ø¬Ù„Ø§Øª Ø§Ù„Ø¨ÙˆØ§Ù†ØªØ§Ø¬ Ù„Ù†Ø·Ø§Ù‚ ØªØ§Ø±ÙŠØ® (Ù…Ù† start Ø¥Ù„Ù‰ end Ø´Ø§Ù…Ù„) â€” Ù„Ù„Ø¥Ø­ØµØ§Ø¦ÙŠØ§Øª Ù…ØªØ¹Ø¯Ø¯Ø© Ø§Ù„Ø£ÙŠØ§Ù….
  Future<List<PointageRecord>> getPointageForDateRange(DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return [];
    return _repo!.getPointageForDateRange(start, end);
  }

  /// Ø³Ø¬Ù„ Ù†Ù‚Ø·Ø§Ø¬ Ù„Ù…ÙˆØ¸Ù ÙÙŠ ØªØ§Ø±ÙŠØ® Ù…Ø¹ÙŠÙ‘Ù† (Ù„Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Â«ÙÙŠ ØªÙƒÙˆÙŠÙ†ÙŠÂ» ÙÙŠ Ø§Ù„Ø­ÙˆØ§Ø±)
  Future<PointageRecord?> getRecordForEmployeeForDate(String employeId, DateTime date) async {
    if (!_firebaseAvailable || _repo == null) return null;
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return getRecordForEmployee(employeId);
    return _repo!.getByEmployeAndDate(employeId, day);
  }

  /// Ù„Ù„Ø­ØµÙˆÙ„ Ø¹Ù„Ù‰ Ø§Ù„Ø­Ø§Ù„Ø© Ø§Ù„Ù…Ø¹Ø±ÙˆØ¶Ø© Ø­Ø³Ø¨ Ø§Ù„Ø¯ÙˆØ± (Ù„Ù„ØªÙˆØ§ÙÙ‚ Ù…Ø¹ Ø§Ù„ÙˆØ§Ø¬Ù‡Ø© Ø§Ù„Ø­Ø§Ù„ÙŠØ©)
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

  /// Ø­Ø§Ù„Ø© Ø§Ù„Ø³Ø§Ø¦Ù‚ Ù„Ù„Ù…ÙˆØ¸Ù (Ø­Ø§Ø¶Ø± | ØºØ§Ø¦Ø¨ | ÙÙŠ Ø§Ù„Ù…Ø±ÙƒØ¨Ø©)
  DriverPointageStatus getDriverStatusForEmployee(String employeId) {
    final r = getRecordForEmployee(employeId);
    return r?.driverStatus ?? DriverPointageStatus.unset;
  }

  /// Ø­Ø§Ù„Ø© Ø§Ù„Ø´Ø§Ù Ù„Ù„Ù…ÙˆØ¸Ù (Ø­Ø§Ø¶Ø± | ØºØ§Ø¦Ø¨)
  ChefPointageStatus getChefStatusForEmployee(String employeId) {
    final r = getRecordForEmployee(employeId);
    return r?.chefStatus ?? ChefPointageStatus.unset;
  }

  bool isDriverLockedForEmployee(String employeId) {
    if (_ignoreTimeWindowsForTest) return false;
    if (_optimisticDriverReportLocked) {
      final r = getRecordForEmployee(employeId);
      if (r != null && r.driverStatus != DriverPointageStatus.unset) return true;
    }
    return getRecordForEmployee(employeId)?.driverLocked ?? false;
  }

  bool isChefLockedForEmployee(String employeId) {
    if (_ignoreTimeWindowsForTest) return false;
    if (_optimisticChefLockedEmployeIds.contains(employeId)) return true;
    return getRecordForEmployee(employeId)?.chefLocked ?? false;
  }

  /// Ø¹Ø¯Ø¯ Ø£ÙŠØ§Ù… Ø§Ù„Ø­Ø¶ÙˆØ± Ø§Ù„Ù…Ø¤ÙƒØ¯Ø© Ù„Ù…ÙˆØ¸Ù Ø¨ÙŠÙ† ØªØ§Ø±ÙŠØ®ÙŠÙ† (Ù…Ù† Ù†Ù‚Ø·Ø§Ø¬).
  Future<int> getPresentDaysCountForEmployee(String employeId, DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return 0;
    final list = await _repo!.getPointageForEmployeeRange(employeId, start, end);
    return list.where((r) => r.isFinalPresent).length;
  }

  /// Ø¬Ù…ÙŠØ¹ Ø³Ø¬Ù„Ø§Øª Ø§Ù„Ø­Ø¶ÙˆØ± ÙÙŠ Ù†Ø·Ø§Ù‚ ØªÙˆØ§Ø±ÙŠØ® (Ù„ØªØµØ¯ÙŠØ± Excel).
  /// [knownEmployeIds] â€” ØªÙ…Ø±ÙŠØ± Ù…Ø¹Ø±ÙØ§Øª Ø§Ù„Ù…ÙˆØ¸ÙÙŠÙ† Ø§Ù„Ù…Ø±Ø§Ø¯ ØªØµØ¯ÙŠØ±Ù‡Ù… Ù„Ø¶Ù…Ø§Ù† Ø¬Ù„Ø¨
  /// Ø³Ø¬Ù„Ø§ØªÙ‡Ù… Ø­ØªÙ‰ Ù„Ùˆ Ù„Ù… ØªØ¸Ù‡Ø± ÙÙŠ Ø§Ù„Ø§Ø³ØªØ¹Ù„Ø§Ù… Ø§Ù„Ø£ÙˆÙ„ÙŠ.
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
    PointageHoursConfig? configOverride,
  }) async {
    if (!_firebaseAvailable) return;
    final now = DateTime.now();
    final config = configOverride ?? PointageHoursConfig.instance;
    final pointageDate = getPointageDateForConfig(config, now);
    final record = PointageRecord(
      id: '',
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      status: status,
      date: pointageDate,
      createdAt: now,
      markedById: markedById,
      markedByName: markedByName,
    );
    await _repo!.markAttendance(record);
  }

  /// ÙŠÙØ±Ø¬Ø¹ true Ø¥Ø°Ø§ ØªÙ… Ø§Ù„ØªØ³Ø¬ÙŠÙ„ØŒ false Ø¥Ø°Ø§ ÙƒØ§Ù† Ø®Ø§Ø±Ø¬ ÙˆÙ‚Øª Ø§Ù„Ø¨ÙˆØ§Ù†ØªØ§Ø¬.
  /// [configOverride] Ø¥Ù† ÙˆÙØ¬Ø¯ ÙŠÙØ³ØªØ®Ø¯Ù… Ù„Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„ÙˆÙ‚ØªØ› ÙˆØ¥Ù„Ø§ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ø¹Ø§Ù….
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
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_arrivalWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
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

  /// ÙŠÙØ±Ø¬Ø¹ true Ø¥Ø°Ø§ ØªÙ… Ø§Ù„ØªØ³Ø¬ÙŠÙ„ØŒ false Ø¥Ø°Ø§ ÙƒØ§Ù† Ø®Ø§Ø±Ø¬ ÙˆÙ‚Øª Ø§Ù„Ø¨ÙˆØ§Ù†ØªØ§Ø¬.
  /// [configOverride] Ø¥Ù† ÙˆÙØ¬Ø¯ ÙŠÙØ³ØªØ®Ø¯Ù… Ù„Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„ÙˆÙ‚ØªØ› ÙˆØ¥Ù„Ø§ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ø¹Ø§Ù….
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
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_chefMarkingWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
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

  /// Distribution: pointage ÙŠØ¯ÙˆÙŠ Ø¹Ù„Ù‰ ØªØ§Ø±ÙŠØ® Ù…Ø­Ø¯Ø¯ (Ø¹Ø§Ø¯Ø©Ù‹ Ø§Ù„Ø£Ù…Ø³)
  /// Ø¨Ø¯ÙˆÙ† ØªÙ‚ÙŠÙŠØ¯ Ø¨Ù†Ø§ÙØ°Ø© Ø§Ù„ÙˆÙ‚Øª.
  Future<bool> markDistributionAttendanceForDate({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required ChefPointageStatus chefStatus,
    required DateTime pointageDate,
    String? chefId,
    String? absenceReason,
    DateTime? arrivalAt,
    DateTime? departureAt,
  }) async {
    if (!_firebaseAvailable) return false;
    final now = DateTime.now();
    final record = PointageRecord(
      id: '',
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      status: AttendanceStatus.unmarked,
      date: DateTime(pointageDate.year, pointageDate.month, pointageDate.day),
      createdAt: now,
      chefStatus: chefStatus,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
    );
    await _repo!.setDistributionChefStatusManual(
      record,
      chefStatus,
      chefId,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
      arrivalAt: arrivalAt,
      departureAt: departureAt,
    );
    return true;
  }

  /// ØªØ³Ø¬ÙŠÙ„ Ø­Ø¶ÙˆØ± Ø¹Ø§Ù…Ù„ renfort (Ù…Ø­ÙˆÙŽÙ‘Ù„ Ù…Ø¤Ù‚ØªØ§Ù‹) Ø¨Ø§Ø³ØªØ®Ø¯Ø§Ù… Ø³Ø¬Ù„Ù‡ Ø§Ù„Ù…Ø³ØªÙ‚Ù„ ÙÙŠ Ø§Ù„ÙØ±ÙŠÙ‚ Ø§Ù„Ø«Ø§Ù†ÙŠ.
  /// ÙŠØ³ØªØ®Ø¯Ù… record.id Ù„Ù„ÙƒØªØ§Ø¨Ø© Ø¹Ù„Ù‰ Ø§Ù„Ù€ docId Ø§Ù„ØµØ­ÙŠØ­ ÙˆÙ„ÙŠØ³ Ø§Ù„Ø³Ø¬Ù„ Ø§Ù„Ø£ØµÙ„ÙŠ.
  Future<bool> markRenfortChefAttendance({
    required PointageRecord renfortRecord,
    required ChefPointageStatus chefStatus,
    String? chefId,
    String? absenceReason,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_chefMarkingWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    await _repo!.setChefStatus(
      renfortRecord,
      chefStatus,
      chefId,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// ØªØ£ÙƒÙŠØ¯ Ø§Ù„Ø³Ø§Ø¹Ø§Øª Ø§Ù„Ø¥Ø¶Ø§ÙÙŠØ© (Ù„Ù„Ø´ÙŠÙØª Ø§Ù„Ù…ÙˆØ§Ù„ÙŠ) Ø¹Ù„Ù‰ Ù†ÙØ³ record (Ù†ÙØ³ date/docId).
  Future<bool> markOvertimeChefAttendance({
    required PointageRecord record,
    required ChefPointageStatus overtimeChefStatus,
    String? chefId,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_overtimeRelatedWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    await _repo!.setOvertimeChefStatus(
      record,
      overtimeChefStatus,
      chefId,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    return true;
  }

  /// ÙŠÙØ±Ø¬Ø¹ true Ø¥Ø°Ø§ ØªÙ… Ø§Ù„Ø¥Ø±Ø³Ø§Ù„ØŒ false Ø¥Ø°Ø§ ÙƒØ§Ù† Ø®Ø§Ø±Ø¬ ÙˆÙ‚Øª Ø§Ù„Ø¨ÙˆØ§Ù†ØªØ§Ø¬.
  /// [equipeId] Ù…Ø·Ù„ÙˆØ¨ Ù„ØªÙ‚ÙŠÙŠØ¯ Ø§Ù„Ù‚ÙÙ„ Ø¨Ø§Ù„ÙØ±Ù‚Ø© Ø§Ù„ØµØ­ÙŠØ­Ø©.
  Future<bool> submitDriverReport({
    required String equipeId,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    return submitDriverReportToFirestore(
      equipeId: equipeId,
      configOverride: configOverride,
      bypassTimeWindows: bypassTimeWindows,
    );
  }

  /// ÙŠÙØ±Ø¬Ø¹ true Ø¥Ø°Ø§ ØªÙ… Ø§Ù„Ø¥Ø±Ø³Ø§Ù„ØŒ false Ø¥Ø°Ø§ ÙƒØ§Ù† Ø®Ø§Ø±Ø¬ ÙˆÙ‚Øª Ø§Ù„Ø¨ÙˆØ§Ù†ØªØ§Ø¬.
  /// [configOverride] Ø¥Ù† ÙˆÙØ¬Ø¯ ÙŠÙØ³ØªØ®Ø¯Ù… Ù„Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„ÙˆÙ‚ØªØ› ÙˆØ¥Ù„Ø§ Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ø¹Ø§Ù….
  Future<bool> submitChefReport(
    String equipeId, {
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_submitReportWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    await _repo!.submitChefReport(equipeId, pointageDate);
    return true;
  }

  /// Distribution: ØªØ£ÙƒÙŠØ¯ ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø´Ø§Ù Ù„ØªØ§Ø±ÙŠØ® Ù…Ø­Ø¯Ø¯ Ø¨Ø¯ÙˆÙ† Ù†Ø§ÙØ°Ø© ØªÙˆÙ‚ÙŠØª.
  Future<void> submitChefReportForDateManual(String equipeId, DateTime date) async {
    if (!_firebaseAvailable || _repo == null || equipeId.isEmpty) return;
    final day = DateTime(date.year, date.month, date.day);
    await _repo!.submitChefReport(equipeId, day);
  }

  /// Avant envoi du rapport chef : complÃ©ter les non-marquÃ©s en Â« absent Â» (Firestore batch, moins de requÃªtes).
  Future<void> batchMarkUnmarkedAbsentBeforeChefSubmit({
    required List<Employe> workersDisplay,
    required Set<String> overtimeWorkerIds,
    required String equipeId,
    required String equipeName,
    required String chefName,
    String? chefId,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable || _repo == null) return;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    // Utilise la mÃªme fenÃªtre que submitChefReport (departure) pour cohÃ©rence.
    if (!_submitReportWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return;
    final pointageDate = getPointageDateForConfig(config, now);

    final regularTemplates = <PointageRecord>[];
    final overtimeRecords = <PointageRecord>[];

    for (final w in workersDisplay) {
      final isOvertime = overtimeWorkerIds.contains(w.id);
      final r = getRecordForEmployee(w.id);
      if (r?.adminFinalStatus == AttendanceStatus.leave ||
          r?.adminFinalStatus == AttendanceStatus.training) {
        continue;
      }
      final isUnmarked = isOvertime
          ? (r?.overtimeChefStatus ?? ChefPointageStatus.unset) == ChefPointageStatus.unset
          : (r == null || r.chefStatus == ChefPointageStatus.unset);
      if (!isUnmarked) continue;
      if (isOvertime && r != null) {
        overtimeRecords.add(r);
      } else {
        regularTemplates.add(
          PointageRecord(
            id: '',
            employeId: w.id,
            employeNom: w.nom,
            employeCin: w.cin,
            equipeId: equipeId,
            equipeName: equipeName,
            chefName: chefName,
            status: AttendanceStatus.unmarked,
            date: pointageDate,
            createdAt: now,
            chefStatus: ChefPointageStatus.absent,
          ),
        );
      }
    }

    await _repo!.batchMarkUnmarkedAbsentBeforeChefSubmit(
      regularTemplates: regularTemplates,
      overtimeRecords: overtimeRecords,
      chefId: chefId,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
  }

  /// ØªØ³Ø¬ÙŠÙ„ Ø­Ø§Ù„Ø© Ø§Ù„Ø®Ø±ÙˆØ¬: Ù„Ø§ ÙŠØ²Ø§Ù„ ÙŠØ¹Ù…Ù„ | Ø§Ù†ØªÙ‡Ù‰ (Ù…Ø¹ Ø§Ø®ØªÙŠØ§Ø±ÙŠ Ø³Ø§Ø¹Ø§Øª Ø¥Ø¶Ø§ÙÙŠØ©).
  /// ÙŠÙØ±Ø¬Ø¹ true Ø¥Ø°Ø§ ØªÙ… Ø§Ù„ØªØ³Ø¬ÙŠÙ„ØŒ false Ø¥Ø°Ø§ ÙƒØ§Ù† Ø®Ø§Ø±Ø¬ Ù†Ø§ÙØ°Ø© Ø§Ù„Ø®Ø±ÙˆØ¬.
  Future<bool> setDepartureStatus({
    required PointageRecord record,
    required DepartureStatus status,
    int? overtimeMinutes,
    String? incompleteShiftReason,
    int? workedMinutesBeforeStop,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? PointageHoursConfig.instance;
    final now = DateTime.now();
    if (!_departureWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
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
          // If the worker previously didn't complete the shift (N'a pas terminÃ©) and provided worked minutes,
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

  /// إلغاء تأكيد الخروج لموظف (إعادة departureStatus إلى unset).
  Future<void> resetDepartureStatus(PointageRecord record) async {
    if (!_firebaseAvailable || _repo == null) return;
    final docId = record.id.isNotEmpty ? record.id : '';
    if (docId.isEmpty) return;
    await _repo!.resetDepartureStatus(docId);
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

  /// ØªØ¹ÙŠÙŠÙ† Ø§Ù„Ø­Ø¶ÙˆØ± Ø§Ù„Ù†Ù‡Ø§Ø¦ÙŠ Ù…Ù† Ø§Ù„Ø£Ø¯Ù…Ù† (ÙŠÙÙ†Ø´Ø¦ Ø³Ø¬Ù„Ø§Ù‹ Ø¥Ù† Ù„Ù… ÙŠÙƒÙ† Ù…ÙˆØ¬ÙˆØ¯Ø§Ù‹). ÙŠØ¯Ø¹Ù… Ø£ÙŠ ØªØ§Ø±ÙŠØ® [viewDate].
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

  /// Affectation temporaire d'un employÃ© vers une autre Ã©quipe pour une journÃ©e (renfort).
  /// CrÃ©e un sØ¬Ù„ SÃ‰PARÃ‰ (docId diffÃ©rent) pour le fØ±ÙŠÙ‚ cible afin que les pointages
  /// des deux Ã©quipes soient totalement indÃ©pendants.
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

  /// RÃ©initialise les donnÃ©es pointage (pointages + rapports) sur une plage.
  Future<void> clearPointageAndReportsInDateRange(DateTime start, DateTime end) async {
    if (!_firebaseAvailable || _repo == null) return;
    await _repo!.clearPointageAndReportsInDateRange(start, end);
    if (_selectedReportDate != null) {
      selectReportDate(_selectedReportDate);
    }
  }

  /// ØªÙ†Ø¸ÙŠÙ ÙƒÙ„ Ø§Ù„Ø³Ø¬Ù„Ø§Øª Ø§Ù„Ù…Ù„ÙˆØ«Ø© Ù…Ù† Ø§Ù„Ù†Ø¸Ø§Ù… Ø§Ù„Ù‚Ø¯ÙŠÙ… (tempAssigned ÙÙŠ Ø§Ù„Ø³Ø¬Ù„ Ø§Ù„Ø£ØµÙ„ÙŠ).
  /// ÙŠÙØ³ØªØ®Ø¯Ù… Ù…Ø±Ø© ÙˆØ§Ø­Ø¯Ø© Ù„Ø¥ØµÙ„Ø§Ø­ Ø§Ù„Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…ÙˆØ¬ÙˆØ¯Ø© ÙÙŠ Firestore.
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

