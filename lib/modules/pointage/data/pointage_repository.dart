import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pointage_model.dart';

class PointageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _pointageCollection = 'pointage';
  static const String _reportsCollection = 'daily_reports';
  static const String _nonWorkingCollection = 'pointage_non_working';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// معرف مستند ثابت لتجنب الحاجة إلى فهرس مركب (employeId + date)
  String _docId(String employeId, DateTime date) => '${employeId}_${_dateKey(date)}';

  /// معرف مستند مخصص للسجل Renfort (سجل مستقل لكل فريق هدف).
  String _renfortDocId(String employeId, DateTime date, String targetEquipeId) =>
      '${employeId}_${_dateKey(date)}_renfort_$targetEquipeId';

  String _dayStart(String dateKey) => '${dateKey}T00:00:00.000';
  String _dayEnd(String dateKey) => '${dateKey}T23:59:59.999';

  Stream<List<PointageRecord>> watchTodayPointage() {
    final today = _dateKey(DateTime.now());
    return _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: _dayStart(today))
        .where('date', isLessThan: _dayEnd(today))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<PointageRecord>> watchPointageByDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: dayStart.toIso8601String())
        .where('date', isLessThan: DateTime(date.year, date.month, date.day + 1).toIso8601String())
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<PointageRecord>> watchPointageByEquipe(String equipeId) {
    final today = _dateKey(DateTime.now());
    return _firestore
        .collection(_pointageCollection)
        .where('equipeId', isEqualTo: equipeId)
        .where('date', isGreaterThanOrEqualTo: _dayStart(today))
        .where('date', isLessThan: _dayEnd(today))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<PointageRecord?> getByEmployeAndDate(String employeId, DateTime date) async {
    final docId = _docId(employeId, date);
    final doc = await _firestore.collection(_pointageCollection).doc(docId).get();
    if (doc.data() == null) return null;
    return PointageRecord.fromMap({...doc.data()!, 'id': doc.id});
  }

  /// جلب كل سجلات البوانتاج ليوم معيّن (للسائق في وردية ليلية قبل 07:00).
  Future<List<PointageRecord>> getPointageForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: day.toIso8601String())
        .where('date', isLessThan: day.add(const Duration(days: 1)).toIso8601String())
        .get();
    return snap.docs.map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id})).toList();
  }

  /// جلب سجلات البوانتاج لنطاق تاريخ (من start إلى end شامل).
  Future<List<PointageRecord>> getPointageForDateRange(DateTime start, DateTime end) async {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day + 1);
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('date', isLessThan: to.toIso8601String())
        .get();
    return snap.docs.map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id})).toList();
  }

  /// إنشاء أو تحديث سجل نقطاج (للتوافق القديم وللأدمن عند الحاجة)
  Future<void> markAttendance(PointageRecord record) async {
    final docId = _docId(record.employeId, record.date);
    final existing = await getByEmployeAndDate(record.employeId, record.date);
    final Map<String, dynamic> toWrite = record.toMap();
    if (existing != null) {
      toWrite['driverStatus'] = existing.driverStatus.name;
      toWrite['chefStatus'] = existing.chefStatus.name;
      toWrite['submittedByDriverAt'] = existing.submittedByDriverAt?.toIso8601String();
      toWrite['submittedByChefAt'] = existing.submittedByChefAt?.toIso8601String();
      toWrite['adminFinalStatus'] = record.adminFinalStatus?.name ?? existing.adminFinalStatus?.name;
      toWrite['markedByDriverId'] = existing.markedByDriverId;
      toWrite['markedByChefId'] = existing.markedByChefId;
      toWrite['arrivalMarkedAt'] = existing.arrivalMarkedAt?.toIso8601String();
      toWrite['departureStatus'] = existing.departureStatus.name;
      toWrite['departureMarkedAt'] = existing.departureMarkedAt?.toIso8601String();
      toWrite['overtimeMinutes'] = existing.overtimeMinutes;
      await _firestore.collection(_pointageCollection).doc(docId).set(toWrite);
    } else {
      await _firestore.collection(_pointageCollection).doc(docId).set(toWrite);
    }
  }

  /// تحديث حالة السائق فقط (إن لم يكن التقرير مُرسلاً). يُسجّل وقت الدخول عند أول حضور.
  Future<void> setDriverStatus(
    PointageRecord record,
    DriverPointageStatus status,
    String? driverId, {
    bool ignoreLock = false,
  }) async {
    // Use record.id directly to support Renfort records (different docId).
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    if (existing != null && existing.driverLocked && !ignoreLock) return;
    final now = DateTime.now().toIso8601String();
    final isPresent = status == DriverPointageStatus.present;
    final setArrival = isPresent && (existing?.arrivalMarkedAt == null);
    if (existing != null) {
      final updates = <String, dynamic>{
        'driverStatus': status.name,
        'markedByDriverId': driverId,
      };
      if (setArrival) updates['arrivalMarkedAt'] = now;
      await _firestore.collection(_pointageCollection).doc(docId).update(updates);
    } else {
      final map = record.copyWith(
        driverStatus: status,
        markedByDriverId: driverId,
        arrivalMarkedAt: setArrival ? DateTime.now() : null,
      ).toMap();
      await _firestore.collection(_pointageCollection).doc(docId).set(map);
    }
  }

  /// تحديث حالة الشاف فقط (إن لم يكن التقرير مُرسلاً). يُسجّل وقت الدخول عند أول حضور.
  /// [absenceReason] مطلوب عند الغياب (من الشاف أو الأدمن).
  Future<void> setChefStatus(
    PointageRecord record,
    ChefPointageStatus status,
    String? chefId, {
    String? absenceReason,
    bool ignoreLock = false,
  }) async {
    // Use record.id directly to support Renfort records (different docId).
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    if (existing != null && existing.chefLocked && !ignoreLock) return;
    final now = DateTime.now().toIso8601String();
    final isPresent = status == ChefPointageStatus.present;
    final setArrival = isPresent && (existing?.arrivalMarkedAt == null);
    if (existing != null) {
      final updates = <String, dynamic>{
        'chefStatus': status.name,
        'markedByChefId': chefId,
        'absenceReason': status == ChefPointageStatus.absent ? absenceReason : null,
      };
      if (setArrival) updates['arrivalMarkedAt'] = now;
      await _firestore.collection(_pointageCollection).doc(docId).update(updates);
    } else {
      final map = record.copyWith(
        chefStatus: status,
        markedByChefId: chefId,
        arrivalMarkedAt: setArrival ? DateTime.now() : null,
        absenceReason: status == ChefPointageStatus.absent ? absenceReason : null,
      ).toMap();
      await _firestore.collection(_pointageCollection).doc(docId).set(map);
    }
  }

  /// تحديث تأكيد الساعات الإضافية (للشيفت الموالي) بدون لمس chefStatus الأصلي.
  Future<void> setOvertimeChefStatus(
    PointageRecord record,
    ChefPointageStatus status,
    String? chefId, {
    bool ignoreLock = false,
  }) async {
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    if (existing != null && existing.chefLocked && !ignoreLock) return;
    final now = DateTime.now().toIso8601String();
    final isPresent = status == ChefPointageStatus.present;
    final setArrival = isPresent && (existing?.overtimeArrivalMarkedAt == null);
    if (existing != null) {
      final updates = <String, dynamic>{
        'overtimeChefStatus': status.name,
        'overtimeMarkedByChefId': chefId,
        // When overtime is confirmed present, set at least one full shift (8h) as overtime.
        // When absent/unset, clear overtime minutes.
        'overtimeMinutes': status == ChefPointageStatus.present ? 480 : 0,
      };
      if (setArrival) updates['overtimeArrivalMarkedAt'] = now;
      await _firestore.collection(_pointageCollection).doc(docId).update(updates);
    } else {
      final map = record.copyWith(
        overtimeChefStatus: status,
        overtimeMarkedByChefId: chefId,
        overtimeArrivalMarkedAt: setArrival ? DateTime.now() : null,
        overtimeMinutes: status == ChefPointageStatus.present ? 480 : 0,
      ).toMap();
      await _firestore.collection(_pointageCollection).doc(docId).set(map);
    }
  }

  /// تحديث حالة الخروج (لا يزال يعمل / انتهى) مع اختياري ساعات إضافية
  Future<void> setDepartureStatus(
    PointageRecord record,
    DepartureStatus status, {
    int? overtimeMinutes,
    String? incompleteShiftReason,
    int? workedMinutesBeforeStop,
  }) async {
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'departureStatus': status.name,
      'departureMarkedAt': now.toIso8601String(),
      if (overtimeMinutes != null) 'overtimeMinutes': overtimeMinutes,
      if (status == DepartureStatus.stillWorking) 'incompleteShiftReason': incompleteShiftReason,
      if (status == DepartureStatus.stillWorking) 'workedMinutesBeforeStop': workedMinutesBeforeStop,
      if (status != DepartureStatus.stillWorking) 'incompleteShiftReason': null,
      if (status != DepartureStatus.stillWorking) 'workedMinutesBeforeStop': null,
    };
    if (existing != null) {
      await _firestore.collection(_pointageCollection).doc(docId).update(updates);
    } else {
      final map = record.copyWith(
        departureStatus: status,
        departureMarkedAt: now,
        overtimeMinutes: overtimeMinutes ?? record.overtimeMinutes,
        incompleteShiftReason: status == DepartureStatus.stillWorking ? incompleteShiftReason : null,
        workedMinutesBeforeStop: status == DepartureStatus.stillWorking ? workedMinutesBeforeStop : null,
      ).toMap();
      await _firestore.collection(_pointageCollection).doc(docId).set(map);
    }
  }

  /// قفل تقرير السائق لليوم: تعيين submittedByDriverAt لجميع السجلات التي لها driverStatus
  Future<void> submitDriverReport(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    final now = DateTime.now().toIso8601String();
    for (final doc in snap.docs) {
      final data = doc.data();
      final driverStatus = data['driverStatus'] as String?;
      if (driverStatus != null && driverStatus != 'unset') {
        await doc.reference.update({'submittedByDriverAt': now});
      }
    }
  }

  /// قفل تقرير الشاف للفريق واليوم (استعلام بالتاريخ فقط ثم تصفية بالفريق لتجنب فهرس مركب)
  Future<void> submitChefReport(String equipeId, DateTime date) async {
    if (equipeId.isEmpty) return;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    final now = DateTime.now().toIso8601String();
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['equipeId'] as String? ?? '') != equipeId) continue;
      await doc.reference.update({'submittedByChefAt': now});
    }
  }

  /// تعديل الأدمن النهائي (يمكن تغيير التقرير بعد إرسال الشاف والسائق).
  /// [absenceReason] يُسجّل عند تعيين status = absent.
  Future<void> setAdminOverride(
    String docId,
    AttendanceStatus? status, {
    String? absenceReason,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
  }) async {
    final ref = _firestore.collection(_pointageCollection).doc(docId);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final nowIso = DateTime.now().toIso8601String();

    final updates = <String, dynamic>{
      'adminFinalStatus': status?.name,
      if (status == AttendanceStatus.absent) 'absenceReason': absenceReason,
      if (status != AttendanceStatus.absent) 'absenceReason': null,
      if (status == AttendanceStatus.training) 'trainingStartAt': trainingStartAt?.toIso8601String(),
      if (status == AttendanceStatus.training) 'trainingEndAt': trainingEndAt?.toIso8601String(),
      if (status != AttendanceStatus.training) 'trainingStartAt': null,
      if (status != AttendanceStatus.training) 'trainingEndAt': null,
    };

    // For admin validation, set arrival/departure timestamps so "Statistiques" can show times.
    if (status == AttendanceStatus.present || status == AttendanceStatus.training) {
      final hasArrival = (data['arrivalMarkedAt'] as String?)?.isNotEmpty == true;
      if (!hasArrival) updates['arrivalMarkedAt'] = nowIso;
      updates['departureStatus'] = DepartureStatus.finished.name;
      final hasDeparture = (data['departureMarkedAt'] as String?)?.isNotEmpty == true;
      if (!hasDeparture) updates['departureMarkedAt'] = nowIso;
    }

    await ref.update(updates);
  }

  Future<void> updatePointageFields(String docId, Map<String, dynamic> updates) async {
    await _firestore.collection(_pointageCollection).doc(docId).update(updates);
  }

  /// تنظيف السجل الأصلي من tempAssigned إذا كان ملوثًا من نظام قديم.
  /// يُستدعى قبل إنشاء سجل Renfort مستقل لضمان أن السجل الأصلي يبقى نظيفًا.
  Future<void> cleanOriginalRecordFromRenfort(String employeId, DateTime day) async {
    final d = DateTime(day.year, day.month, day.day);
    final docId = _docId(employeId, d);
    final doc = await _firestore.collection(_pointageCollection).doc(docId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final isTempAssigned = data['tempAssigned'] == true;
    if (!isTempAssigned) return;
    // The original record was wrongly marked as tempAssigned by the old system. Clean it.
    await _firestore.collection(_pointageCollection).doc(docId).update({
      'tempAssigned': false,
      'originalEquipeId': null,
    });
  }

  /// إنشاء أو تحديث سجل Renfort المستقل (docId مختلف عن السجل الأصلي).
  /// السجل الجديد لا يحمل أي chefStatus/driverStatus من الفريق الأصلي.
  Future<String> createOrUpdateRenfortRecord({
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
    final d = DateTime(day.year, day.month, day.day);
    final docId = _renfortDocId(employeId, d, targetEquipeId);
    final ref = _firestore.collection(_pointageCollection).doc(docId);
    final snap = await ref.get();
    if (snap.exists) {
      // Already exists: just ensure the fields are correct, don't reset statuses.
      await ref.update({
        'equipeId': targetEquipeId,
        'equipeName': targetEquipeName,
        'chefName': targetChefName,
        'tempAssigned': true,
        'originalEquipeId': originalEquipeId,
        if (shiftOverride != null) 'shiftOverride': shiftOverride,
      });
    } else {
      final record = PointageRecord(
        id: docId,
        employeId: employeId,
        employeNom: employeNom,
        employeCin: employeCin,
        equipeId: targetEquipeId,
        equipeName: targetEquipeName,
        chefName: targetChefName,
        status: AttendanceStatus.unmarked,
        date: d,
        createdAt: DateTime.now(),
        tempAssigned: true,
        originalEquipeId: originalEquipeId,
        shiftOverride: shiftOverride,
        overtimeMinutes: defaultOvertimeMinutes,
        // chefStatus and driverStatus intentionally left as unset (default).
      );
      await ref.set(record.toMap());
    }
    return docId;
  }

  /// إنشاء سجل نقطاج بتعديل أدمن فقط (عند عدم وجود سجل)
  Future<void> createRecordWithAdminOverride(PointageRecord record) async {
    final docId = _docId(record.employeId, record.date);
    await _firestore.collection(_pointageCollection).doc(docId).set(record.toMap());
  }

  Future<void> deletePointage(String id) async {
    await _firestore.collection(_pointageCollection).doc(id).delete();
  }

  Stream<List<DailyReport>> watchReports() {
    return _firestore
        .collection(_reportsCollection)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DailyReport.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<void> submitReport(DailyReport report) async {
    await _firestore.collection(_reportsCollection).add(report.toMap());
  }

  /// Supprime les pointages et rapports dans une plage de dates (inclusif).
  Future<void> clearPointageAndReportsInDateRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final start = DateTime(startInclusive.year, startInclusive.month, startInclusive.day);
    final endDay = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
    final end = endDay.add(const Duration(days: 1));

    Future<void> deleteQueryDocs(Query<Map<String, dynamic>> query) async {
      final snap = await query.get();
      if (snap.docs.isEmpty) return;
      final batch = _firestore.batch();
      int ops = 0;
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops++;
        if (ops >= 400) {
          await batch.commit();
          ops = 0;
        }
      }
      if (ops > 0) {
        await batch.commit();
      }
    }

    await deleteQueryDocs(
      _firestore
          .collection(_pointageCollection)
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThan: end.toIso8601String()),
    );

    await deleteQueryDocs(
      _firestore
          .collection(_reportsCollection)
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThan: end.toIso8601String()),
    );
  }

  Future<int> getTodayPresentCount() async {
    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    int count = 0;
    for (final doc in snap.docs) {
      final r = PointageRecord.fromMap({...doc.data(), 'id': doc.id});
      if (r.isFinalPresent) count++;
    }
    return count;
  }

  /// سجلات الحضور لموظف واحد في نطاق تواريخ (لحساب أيام الحضور).
  /// يتطلب فهرساً مركباً على (employeId, date) في Firestore.
  Future<List<PointageRecord>> getPointageForEmployeeRange(
    String employeId,
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final start = DateTime(startInclusive.year, startInclusive.month, startInclusive.day);
    final endDay = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
    final end = endDay.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('employeId', isEqualTo: employeId)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    return snap.docs
        .map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  /// جميع سجلات الحضور في نطاق تواريخ (لتصدير Excel).
  Future<List<PointageRecord>> getPointageInDateRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final start = DateTime(startInclusive.year, startInclusive.month, startInclusive.day);
    final endDay = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
    final end = endDay.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    return snap.docs
        .map((d) => PointageRecord.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  // ——— Équipes ne travaillant pas (ce jour) ———

  Future<List<String>> getNonWorkingEquipeIds(DateTime date) async {
    final key = _dateKey(date);
    final doc = await _firestore.collection(_nonWorkingCollection).doc(key).get();
    if (doc.data() == null) return [];
    final list = doc.data()!['equipeIds'];
    if (list is! List) return [];
    return list.map((e) => e.toString()).toList();
  }

  Future<void> setEquipeNonWorkingForDate(DateTime date, String equipeId, bool nonWorking) async {
    final key = _dateKey(date);
    final ref = _firestore.collection(_nonWorkingCollection).doc(key);
    final current = await getNonWorkingEquipeIds(date);
    final set = current.toSet();
    if (nonWorking) {
      set.add(equipeId);
    } else {
      set.remove(equipeId);
    }
    final list = set.toList();
    if (list.isEmpty) {
      await ref.delete();
    } else {
      await ref.set({'equipeIds': list, 'date': key});
    }
  }
}
