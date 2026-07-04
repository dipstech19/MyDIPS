import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../employees/models/employe_model.dart';
import 'models/pointage_model.dart';
import 'data/pointage_repository.dart';
import 'data/daily_snapshot_repository.dart';
import 'data/daily_confirmation_repository.dart';
import '../distribution/data/distribution_swaps_repository.dart';
import '../distribution/services/distribution_swap_service.dart';
import '../distribution/models/distribution_swap_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pointage_hours_config.dart';
import 'services/pointage_export_service.dart';
import '../../core/notifications/pointage_notifications_service.dart';

/// Ù†Ø§ÙØ°Ø© ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø´Ø§Ù: Ø§Ù„Ø¯Ø®ÙˆÙ„ (âˆ’30 Ø¯ â†’ Ø¨Ø¯Ø§ÙŠØ© + 2h) Ø£Ùˆ Ø§Ù„Ø®Ø±ÙˆØ¬ (âˆ’30 Ø¯ â†’ Ù†Ù‡Ø§ÙŠØ© + 2h) â€” Ù„Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„ØªÙ‚Ø±ÙŠØ± ÙŠÙÙƒÙ…Ù‘Ù„ Ø§Ù„ØºÙŠØ§Ø¨ ÙÙŠ Ù†Ø§ÙØ°Ø© Ø§Ù„Ø®Ø±ÙˆØ¬.
bool _isChefMarkingWindow(PointageHoursConfig config, DateTime now, Duration grace) {
  return config.canMarkArrivalNow(now, graceBefore: grace, graceAfter: grace) ||
      config.canMarkDepartureNow(now, graceBefore: grace, graceAfter: grace);
}

class _ChefReportPendingPayload {
  final List<Employe> workersDisplay;
  final Set<String> overtimeWorkerIds;
  final String equipeId;
  final String equipeName;
  final String chefName;
  final String? chefId;
  final PointageHoursConfig configOverride;
  final bool bypassTimeWindows;
  final int totalEmployees;
  final int presentCount;
  final int absentCount;
  final bool syncBypassTimeWindows;
  /// employeId → texte (shift nuit uniquement, optionnel)
  final Map<String, String>? nightShiftSupervisorNotes;

  const _ChefReportPendingPayload({
    required this.workersDisplay,
    required this.overtimeWorkerIds,
    required this.equipeId,
    required this.equipeName,
    required this.chefName,
    required this.chefId,
    required this.configOverride,
    required this.bypassTimeWindows,
    required this.totalEmployees,
    required this.presentCount,
    required this.absentCount,
    this.syncBypassTimeWindows = true,
    this.nightShiftSupervisorNotes,
  });
}

class _DriverReportPendingPayload {
  final String equipeId;
  final PointageHoursConfig configOverride;
  final bool bypassTimeWindows;
  final bool syncBypassTimeWindows;

  const _DriverReportPendingPayload({
    required this.equipeId,
    required this.configOverride,
    required this.bypassTimeWindows,
    this.syncBypassTimeWindows = true,
  });
}

class PointageProvider extends ChangeNotifier {
  final bool _firebaseAvailable = Firebase.apps.isNotEmpty;
  PointageRepository? _repo;
  final DailySnapshotRepository _dailySnapshotRepo = DailySnapshotRepository();
  final DailyConfirmationRepository _dailyConfirmationRepo = DailyConfirmationRepository();
  /// Clé i18n [AppTranslations] — consommée par l’UI (SnackBar) après invalidation export.
  String? _exportReconfirmHintKey;

  /// Retourne et efface le message à afficher à l’utilisateur (réconfirmation pointage / Excel).
  String? takeExportReconfirmHint() {
    final k = _exportReconfirmHintKey;
    _exportReconfirmHintKey = null;
    return k;
  }

  Future<void> _invalidateDailyConfirmationAfterMutation(String equipeId, DateTime date) async {
    if (!_firebaseAvailable || equipeId.isEmpty) return;
    final day = DateTime(date.year, date.month, date.day);
    try {
      final wasConfirmed = await _dailyConfirmationRepo.isConfirmed(equipeId, day);
      await _dailyConfirmationRepo.unconfirmEquipe(equipeId, day);
      await _dailySnapshotRepo.deleteEquipeSnapshot(equipeId, day);
      if (wasConfirmed) {
        _exportReconfirmHintKey = 'pointage_export_confirmation_reset';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('PointageProvider: invalidate daily confirmation/snapshot: $e');
    }
  }

  PointageRepository? get repository => _repo;

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
  _DriverReportPendingPayload? _pendingDriverReportPayload;
  Timer? _driverReportRetryTimer;
  bool _driverReportSyncPending = false;
  _ChefReportPendingPayload? _pendingChefReportPayload;
  Timer? _chefReportRetryTimer;
  bool _chefReportSyncPending = false;

  List<PointageRecord> get todayPointage => List.unmodifiable(_todayPointage);
  List<PointageRecord> get pointageByDate => List.unmodifiable(_pointageByDate);
  DateTime? get selectedReportDate => _selectedReportDate;
  List<String> get nonWorkingEquipeIds => List.unmodifiable(_nonWorkingEquipeIds);
  List<DailyReport> get reports => List.unmodifiable(_reports);

  /// Rapport quotidien (PDF / RH) déjà enregistré pour l'équipe aujourd'hui — le chef a terminé l'envoi.
  bool hasEquipeDailyReportSubmittedToday(String equipeId) {
    if (equipeId.isEmpty) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return _reports.any(
      (r) =>
          r.equipeId == equipeId &&
          r.date.year == today.year &&
          r.date.month == today.month &&
          r.date.day == today.day,
    );
  }

  int get todayPresentCount => _todayPresentCount;
  int get monthlyReportsCount => _monthlyReportsCount;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;

  bool get optimisticDriverReportLocked => _optimisticDriverReportLocked;
  bool get driverReportSyncPending => _driverReportSyncPending;
  bool get chefReportSyncPending => _chefReportSyncPending;

  /// Au moins un document du jour porte dÃ©jÃ  un envoi chauffeur (batch global).
  bool get hasDriverReportBeenSubmittedGlobally =>
      _todayPointage.any((p) => p.submittedByDriverAt != null);

  bool _ignoreTimeWindowsForTest = false;
  DateTime? _testCycleStartedAt;
  int _testArrivalPhaseMinutes = 5;
  bool get ignoreTimeWindowsForTest => _ignoreTimeWindowsForTest;
  bool get hasActiveTestCycle => _testCycleStartedAt != null;
  int get testArrivalPhaseMinutes => _testArrivalPhaseMinutes;
  void setIgnoreTimeWindowsForTest(bool value) {
    if (_ignoreTimeWindowsForTest == value) return;
    _ignoreTimeWindowsForTest = value;
    if (!value) {
      _testCycleStartedAt = null;
    }
    notifyListeners();
  }

  void startTestCycle({int arrivalMinutes = 5}) {
    _testCycleStartedAt = DateTime.now();
    _testArrivalPhaseMinutes = arrivalMinutes < 1 ? 1 : arrivalMinutes;
    if (!_ignoreTimeWindowsForTest) {
      _ignoreTimeWindowsForTest = true;
    }
    notifyListeners();
  }

  void resetTestCycle() {
    _testCycleStartedAt = null;
    notifyListeners();
  }

  bool get isInTestArrivalPhase {
    if (!_ignoreTimeWindowsForTest || _testCycleStartedAt == null) return false;
    final end = _testCycleStartedAt!.add(Duration(minutes: _testArrivalPhaseMinutes));
    return DateTime.now().isBefore(end);
  }

  bool get isInTestDeparturePhase {
    if (!_ignoreTimeWindowsForTest || _testCycleStartedAt == null) return false;
    final end = _testCycleStartedAt!.add(Duration(minutes: _testArrivalPhaseMinutes));
    return !DateTime.now().isBefore(end);
  }

  StreamSubscription? _subPointage;
  StreamSubscription? _subReports;
  StreamSubscription? _subByDate;

  PointageProvider() {
    unawaited(_restorePendingDriverSyncFromDisk());
    unawaited(_restorePendingChefSyncFromDisk());
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

    final logicalToday = getPointageDateForConfig(const PointageHoursConfig(), DateTime.now());
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

  Future<bool> submitDriverReportWithRetry({
    required String equipeId,
    required PointageHoursConfig configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable || _repo == null || equipeId.isEmpty) return false;
    final payload = _DriverReportPendingPayload(
      equipeId: equipeId,
      configOverride: configOverride,
      bypassTimeWindows: bypassTimeWindows,
      // Once confirmed by user, background sync is allowed even if window closes.
      syncBypassTimeWindows: true,
    );
    _pendingDriverReportPayload = payload;
    await _savePendingDriverSyncToDisk(payload);
    final ok = await _tryFlushPendingDriverReport();
    if (!ok) {
      _driverReportSyncPending = true;
      applyOptimisticDriverReportLock();
      _ensureDriverRetryTimer();
      notifyListeners();
    }
    // Accepted from UI perspective even if awaiting sync.
    return true;
  }

  void _ensureDriverRetryTimer() {
    if (_driverReportRetryTimer != null) return;
    _driverReportRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_tryFlushPendingDriverReport());
    });
  }

  Future<bool> _tryFlushPendingDriverReport() async {
    final p = _pendingDriverReportPayload;
    if (p == null || !_firebaseAvailable || _repo == null || p.equipeId.isEmpty) return false;
    try {
      final ok = await submitDriverReportToFirestore(
        equipeId: p.equipeId,
        configOverride: p.configOverride,
        bypassTimeWindows: p.syncBypassTimeWindows ? true : p.bypassTimeWindows,
      );
      if (!ok) return false;
      _pendingDriverReportPayload = null;
      _driverReportSyncPending = false;
      _driverReportRetryTimer?.cancel();
      _driverReportRetryTimer = null;
      await _clearPendingDriverSyncFromDisk();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
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

  Future<bool> submitChefReportWithRetry({
    required List<Employe> workersDisplay,
    required Set<String> overtimeWorkerIds,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required String? chefId,
    required PointageHoursConfig configOverride,
    required bool bypassTimeWindows,
    required int totalEmployees,
    required int presentCount,
    required int absentCount,
    Map<String, String>? nightShiftSupervisorNotes,
  }) async {
    if (!_firebaseAvailable || _repo == null) return false;
    final payload = _ChefReportPendingPayload(
      workersDisplay: workersDisplay,
      overtimeWorkerIds: overtimeWorkerIds,
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
      chefId: chefId,
      configOverride: configOverride,
      bypassTimeWindows: bypassTimeWindows,
      totalEmployees: totalEmployees,
      presentCount: presentCount,
      absentCount: absentCount,
      // Once user confirms send, sync is allowed even if window closes later.
      syncBypassTimeWindows: true,
      nightShiftSupervisorNotes: nightShiftSupervisorNotes,
    );
    _pendingChefReportPayload = payload;
    await _savePendingChefSyncToDisk(payload);
    final ok = await _tryFlushPendingChefReport();
    if (!ok) {
      _chefReportSyncPending = true;
      applyOptimisticChefReportLock(workersDisplay.map((e) => e.id).toSet());
      _ensureChefRetryTimer();
      notifyListeners();
    }
    // Even on temporary failure, we keep it "accepted" and locked.
    return true;
  }

  void _ensureChefRetryTimer() {
    if (_chefReportRetryTimer != null) return;
    _chefReportRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_tryFlushPendingChefReport());
    });
  }

  Future<bool> _tryFlushPendingChefReport() async {
    final p = _pendingChefReportPayload;
    if (p == null || !_firebaseAvailable || _repo == null) return false;
    try {
      await batchMarkUnmarkedAbsentBeforeChefSubmit(
        workersDisplay: p.workersDisplay,
        overtimeWorkerIds: p.overtimeWorkerIds,
        equipeId: p.equipeId,
        equipeName: p.equipeName,
        chefName: p.chefName,
        chefId: p.chefId,
        configOverride: p.configOverride,
        bypassTimeWindows: p.syncBypassTimeWindows ? true : p.bypassTimeWindows,
      );
      final ok = await submitChefReport(
        p.equipeId,
        configOverride: p.configOverride,
        bypassTimeWindows: p.syncBypassTimeWindows ? true : p.bypassTimeWindows,
      );
      if (!ok) return false;
      await submitDailyReport(
        equipeId: p.equipeId,
        equipeName: p.equipeName,
        chefId: p.chefId ?? '',
        chefName: p.chefName,
        totalEmployees: p.totalEmployees,
        presentCount: p.presentCount,
        absentCount: p.absentCount,
        notInVehicleCount: 0,
      );
      final notes = p.nightShiftSupervisorNotes;
      if (notes != null && notes.isNotEmpty) {
        final cleaned = {
          for (final e in notes.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        };
        if (cleaned.isNotEmpty) {
          final pointageDate = getPointageDateForConfig(p.configOverride, DateTime.now());
          await _repo!.updateNightShiftSupervisorNotes(
            employeIdToNote: cleaned,
            date: pointageDate,
          );
        }
      }
      _pendingChefReportPayload = null;
      _chefReportSyncPending = false;
      _chefReportRetryTimer?.cancel();
      _chefReportRetryTimer = null;
      await _clearPendingChefSyncFromDisk();
      unawaited(PointageNotificationsService.instance.onChefReportSubmitted(
        equipeId: p.equipeId,
        equipeName: p.equipeName,
        chefName: p.chefName,
      ));
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<File> _pendingChefSyncFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}pending_chef_report_sync.json');
  }

  Future<File> _pendingDriverSyncFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}pending_driver_report_sync.json');
  }

  Map<String, dynamic> _configToMap(PointageHoursConfig c) => {
        'startHour': c.startHour,
        'startMinute': c.startMinute,
        'endHour': c.endHour,
        'endMinute': c.endMinute,
        'departureEarliestHour': c.departureEarliestHour,
        'departureEarliestMinute': c.departureEarliestMinute,
        'departureLatestHour': c.departureLatestHour,
        'departureLatestMinute': c.departureLatestMinute,
        'isRestDay': c.isRestDay,
      };

  PointageHoursConfig _configFromMap(Map<String, dynamic> m) => PointageHoursConfig(
        startHour: (m['startHour'] as int?) ?? 6,
        startMinute: (m['startMinute'] as int?) ?? 0,
        endHour: (m['endHour'] as int?) ?? 22,
        endMinute: (m['endMinute'] as int?) ?? 0,
        departureEarliestHour: (m['departureEarliestHour'] as int?) ?? 14,
        departureEarliestMinute: (m['departureEarliestMinute'] as int?) ?? 0,
        departureLatestHour: (m['departureLatestHour'] as int?) ?? 23,
        departureLatestMinute: (m['departureLatestMinute'] as int?) ?? 59,
        isRestDay: (m['isRestDay'] as bool?) ?? false,
      );

  Future<void> _savePendingChefSyncToDisk(_ChefReportPendingPayload p) async {
    try {
      final f = await _pendingChefSyncFile();
      final data = <String, dynamic>{
        'workers': p.workersDisplay
            .map((w) => {'id': w.id, 'nom': w.nom, 'cin': w.cin})
            .toList(),
        'overtimeWorkerIds': p.overtimeWorkerIds.toList(),
        'equipeId': p.equipeId,
        'equipeName': p.equipeName,
        'chefName': p.chefName,
        'chefId': p.chefId,
        'config': _configToMap(p.configOverride),
        'bypassTimeWindows': p.bypassTimeWindows,
        'totalEmployees': p.totalEmployees,
        'presentCount': p.presentCount,
        'absentCount': p.absentCount,
        'syncBypassTimeWindows': p.syncBypassTimeWindows,
        if (p.nightShiftSupervisorNotes != null && p.nightShiftSupervisorNotes!.isNotEmpty)
          'nightShiftSupervisorNotes': p.nightShiftSupervisorNotes,
      };
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {
      // Keep in-memory fallback if disk write fails.
    }
  }

  Future<void> _clearPendingChefSyncFromDisk() async {
    try {
      final f = await _pendingChefSyncFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _savePendingDriverSyncToDisk(_DriverReportPendingPayload p) async {
    try {
      final f = await _pendingDriverSyncFile();
      final data = <String, dynamic>{
        'equipeId': p.equipeId,
        'config': _configToMap(p.configOverride),
        'bypassTimeWindows': p.bypassTimeWindows,
        'syncBypassTimeWindows': p.syncBypassTimeWindows,
      };
      await f.writeAsString(jsonEncode(data), flush: true);
    } catch (_) {}
  }

  Future<void> _clearPendingDriverSyncFromDisk() async {
    try {
      final f = await _pendingDriverSyncFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _restorePendingDriverSyncFromDisk() async {
    try {
      final f = await _pendingDriverSyncFile();
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final equipeId = (m['equipeId'] as String?) ?? '';
      if (equipeId.isEmpty) {
        await _clearPendingDriverSyncFromDisk();
        return;
      }
      _pendingDriverReportPayload = _DriverReportPendingPayload(
        equipeId: equipeId,
        configOverride: _configFromMap(
            (m['config'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? const {}),
        bypassTimeWindows: (m['bypassTimeWindows'] as bool?) ?? false,
        syncBypassTimeWindows: (m['syncBypassTimeWindows'] as bool?) ?? true,
      );
      _driverReportSyncPending = true;
      applyOptimisticDriverReportLock();
      _ensureDriverRetryTimer();
      notifyListeners();
    } catch (_) {
      await _clearPendingDriverSyncFromDisk();
    }
  }

  Future<void> _restorePendingChefSyncFromDisk() async {
    try {
      final f = await _pendingChefSyncFile();
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final workersRaw = (m['workers'] as List?) ?? const [];
      final workers = workersRaw
          .whereType<Map>()
          .map((w) => Employe(
                id: (w['id'] as String?) ?? '',
                nom: (w['nom'] as String?) ?? '',
                cin: (w['cin'] as String?) ?? '',
                telephone: '',
                dateNaissance: '',
                adresse: '',
                email: '',
                poste: '',
                magasin: '',
                departement: '',
                salaireBase: 0,
                typeContrat: '',
                dateDebut: '',
                cnss: '',
                dateCnss: '',
                statut: EmployeStatut.enService,
              ))
          .where((w) => w.id.isNotEmpty)
          .toList();
      if (workers.isEmpty) {
        await _clearPendingChefSyncFromDisk();
        return;
      }
      _pendingChefReportPayload = _ChefReportPendingPayload(
        workersDisplay: workers,
        overtimeWorkerIds:
            ((m['overtimeWorkerIds'] as List?) ?? const []).map((e) => '$e').toSet(),
        equipeId: (m['equipeId'] as String?) ?? '',
        equipeName: (m['equipeName'] as String?) ?? '',
        chefName: (m['chefName'] as String?) ?? '',
        chefId: m['chefId'] as String?,
        configOverride: _configFromMap(
            (m['config'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? const {}),
        bypassTimeWindows: (m['bypassTimeWindows'] as bool?) ?? false,
        totalEmployees: (m['totalEmployees'] as num?)?.toInt() ?? workers.length,
        presentCount: (m['presentCount'] as num?)?.toInt() ?? 0,
        absentCount: (m['absentCount'] as num?)?.toInt() ?? 0,
        syncBypassTimeWindows: (m['syncBypassTimeWindows'] as bool?) ?? true,
        nightShiftSupervisorNotes: (m['nightShiftSupervisorNotes'] as Map?)?.map(
          (k, v) => MapEntry('$k', '$v'),
        ),
      );
      _chefReportSyncPending = true;
      applyOptimisticChefReportLock(workers.map((w) => w.id).toSet());
      _ensureChefRetryTimer();
      notifyListeners();
    } catch (_) {
      await _clearPendingChefSyncFromDisk();
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
    final config = configOverride ?? const PointageHoursConfig();
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
    final config = configOverride ?? const PointageHoursConfig();
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
    await _invalidateDailyConfirmationAfterMutation(equipeId, pointageDate);
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
    final config = configOverride ?? const PointageHoursConfig();
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
    await _invalidateDailyConfirmationAfterMutation(equipeId, pointageDate);
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
    final config = configOverride ?? const PointageHoursConfig();
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
    await _invalidateDailyConfirmationAfterMutation(equipeId, pointageDate);
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
    await _invalidateDailyConfirmationAfterMutation(equipeId, pointageDate);
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
    final config = configOverride ?? const PointageHoursConfig();
    final now = DateTime.now();
    if (!_chefMarkingWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    await _repo!.setChefStatus(
      renfortRecord,
      chefStatus,
      chefId,
      absenceReason: chefStatus == ChefPointageStatus.absent ? absenceReason : null,
      ignoreLock: _ignoreTimeWindowsForTest,
    );
    await _invalidateDailyConfirmationAfterMutation(renfortRecord.equipeId, renfortRecord.date);
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
    final config = configOverride ?? const PointageHoursConfig();
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
    final config = configOverride ?? const PointageHoursConfig();
    final now = DateTime.now();
    if (!_chefMarkingWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return false;
    final pointageDate = getPointageDateForConfig(config, now);
    await _repo!.submitChefReport(equipeId, pointageDate);
    return true;
  }

  /// Distribution: ØªØ£ÙƒÙŠØ¯ ØªÙ‚Ø±ÙŠØ± Ø§Ù„Ø´Ø§Ù Ù„ØªØ§Ø±ÙŠØ® Ù…Ø­Ø¯Ø¯ Ø¨Ø¯ÙˆÙ† Ù†Ø§ÙØ°Ø© ØªÙˆÙ‚ÙŠØª.
  Future<void> submitChefReportForDateManual(
    String equipeId,
    DateTime date, {
    String equipeName = 'Équipe',
    String chefName = 'Chef',
  }) async {
    if (!_firebaseAvailable || _repo == null || equipeId.isEmpty) return;
    final day = DateTime(date.year, date.month, date.day);
    await _repo!.submitChefReport(equipeId, day);
    unawaited(PointageNotificationsService.instance.onChefReportSubmitted(
      equipeId: equipeId,
      equipeName: equipeName,
      chefName: chefName,
    ));
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
    final config = configOverride ?? const PointageHoursConfig();
    final now = DateTime.now();
    if (!_chefMarkingWindowOk(config, now, bypassTimeWindows: bypassTimeWindows)) return;
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
    DateTime? departureAt,
    PointageHoursConfig? configOverride,
    bool bypassTimeWindows = false,
  }) async {
    if (!_firebaseAvailable) return false;
    final config = configOverride ?? const PointageHoursConfig();
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
      departureAt: departureAt,
    );
    await _invalidateDailyConfirmationAfterMutation(record.equipeId, record.date);
    if (status == DepartureStatus.finished) {
      await _tryConfirmDistributionSwapArrangements(record);
    }
    return true;
  }

  Future<void> _tryConfirmDistributionSwapArrangements(PointageRecord record) async {
    if (_repo == null || !_firebaseAvailable) return;
    if (!record.equipeId.startsWith('distribution:')) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('distribution_swaps')
          .where('status', isEqualTo: DistributionSwapStatus.scheduled.name)
          .get();
      final swaps = snap.docs
          .map((d) => DistributionSwap.fromMap({...d.data(), 'id': d.id}))
          .toList();
      final swapsRepo = DistributionSwapsRepository();
      await DistributionSwapService.tryConfirmArrangementsAfterWorkDay(
        completedRecord: record,
        pointageRepo: _repo!,
        swapsRepo: swapsRepo,
        swaps: swaps,
      );
    } catch (e) {
      debugPrint('PointageProvider: distribution swap confirm: $e');
    }
  }

  /// إلغاء تأكيد الخروج لموظف (إعادة departureStatus إلى unset).
  Future<void> resetDepartureStatus(PointageRecord record) async {
    if (!_firebaseAvailable || _repo == null) return;
    final docId = record.id.isNotEmpty ? record.id : '';
    if (docId.isEmpty) return;
    await _repo!.resetDepartureStatus(docId);
    await _invalidateDailyConfirmationAfterMutation(record.equipeId, record.date);
  }

  Future<void> setAdminOverride(
    String pointageDocId,
    AttendanceStatus? status, {
    String? absenceReason,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
  }) async {
    if (!_firebaseAvailable || _repo == null) return;
    await _repo!.setAdminOverride(
      pointageDocId,
      status,
      absenceReason: status == AttendanceStatus.absent ? absenceReason : null,
      trainingStartAt: status == AttendanceStatus.training ? trainingStartAt : null,
      trainingEndAt: status == AttendanceStatus.training ? trainingEndAt : null,
    );
    final rec = await _repo!.getByDocId(pointageDocId);
    if (rec != null) {
      await _invalidateDailyConfirmationAfterMutation(rec.equipeId, rec.date);
    }
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
    await _invalidateDailyConfirmationAfterMutation(equipeId, day);
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
    await _invalidateDailyConfirmationAfterMutation(originalEquipeId, d);
    await _invalidateDailyConfirmationAfterMutation(targetEquipeId, d);
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

  Future<void> clearPointageAndReportsForDay(DateTime day, {String? equipeId}) async {
    if (!_firebaseAvailable || _repo == null) return;
    await _repo!.clearPointageAndReportsForDay(day, equipeId: equipeId);
    if (equipeId != null && equipeId.isNotEmpty) {
      await _invalidateDailyConfirmationAfterMutation(equipeId, day);
    }
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
    _driverReportRetryTimer?.cancel();
    _chefReportRetryTimer?.cancel();
    _subPointage?.cancel();
    _subReports?.cancel();
    _subByDate?.cancel();
    super.dispose();
  }
}

