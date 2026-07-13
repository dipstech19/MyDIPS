import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pointage_model.dart';
import '../../shifts/models/shift_models.dart';

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

  /// Journée « E » (échange Distribution) dans le groupe d'origine.
  String _distArrangementDocId(String employeId, DateTime date, String homeEquipeId) =>
      '${employeId}_${_dateKey(date)}_dist_arr_$homeEquipeId';

  String _dayStart(String dateKey) => '${dateKey}T00:00:00.000';
  String _dayEnd(String dateKey) => '${dateKey}T23:59:59.999';

  /// [logicalDate] هو تاريخ البوانتاج المنطقي (قد يكون اليوم أو اليوم السابق لشيفت ليلي).
  /// إذا لم يُمرَّر يُستخدم تاريخ اليوم الفعلي.
  Stream<List<PointageRecord>> watchTodayPointage({DateTime? logicalDate}) {
    final today = _dateKey(logicalDate ?? DateTime.now());
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

  /// Récupère un enregistrement par id Firestore (ex. renfort, docId personnalisé).
  Future<PointageRecord?> getByDocId(String docId) async {
    if (docId.isEmpty) return null;
    final doc = await _firestore.collection(_pointageCollection).doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
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
    final to = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));
    return _getPointageRangeMixedDate(from, to);
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

  /// Distribution: تسجيل الشاف يدوياً على تاريخ محدد (عادةً الأمس)
  /// مع إمكانية تحديد وقت الدخول والخروج يدوياً.
  Future<void> setDistributionChefStatusManual(
    PointageRecord record,
    ChefPointageStatus status,
    String? chefId, {
    String? absenceReason,
    DateTime? arrivalAt,
    DateTime? departureAt,
  }) async {
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    final isPresent = status == ChefPointageStatus.present;
    final updates = <String, dynamic>{
      'chefStatus': status.name,
      'markedByChefId': chefId,
      'equipeId': record.equipeId,
      'equipeName': record.equipeName,
      'chefName': record.chefName,
      'employeNom': record.employeNom,
      'employeCin': record.employeCin,
      'absenceReason': isPresent ? null : absenceReason,
      'arrivalMarkedAt': isPresent ? (arrivalAt ?? existing?.arrivalMarkedAt ?? DateTime.now()).toIso8601String() : null,
      'departureStatus': isPresent
          ? (departureAt != null ? DepartureStatus.finished.name : (existing?.departureStatus.name ?? DepartureStatus.unset.name))
          : DepartureStatus.unset.name,
      'departureMarkedAt': isPresent
          ? (departureAt != null
              ? departureAt.toIso8601String()
              : existing?.departureMarkedAt?.toIso8601String())
          : null,
    };
    if (existing != null) {
      await _firestore.collection(_pointageCollection).doc(docId).update(updates);
    } else {
      final map = record.copyWith(
        chefStatus: status,
        markedByChefId: chefId,
        absenceReason: isPresent ? null : absenceReason,
        arrivalMarkedAt: isPresent ? (arrivalAt ?? DateTime.now()) : null,
        departureStatus: isPresent
            ? (departureAt != null ? DepartureStatus.finished : DepartureStatus.unset)
            : DepartureStatus.unset,
        departureMarkedAt: isPresent ? departureAt : null,
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
    DateTime? departureAt,
  }) async {
    final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
    final existing = record.id.isNotEmpty
        ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
            (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
        : await getByEmployeAndDate(record.employeId, record.date);
    final now = departureAt ?? DateTime.now();
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

  /// قفل تقرير السائق لفرقته واليوم: تعيين submittedByDriverAt للسجلات التي لها driverStatus
  /// المُصنَّفة تحت [equipeId] فقط (دفعات WriteBatch لتقليل الطلبات على الشبكة الضعيفة).
  /// [equipeId] مطلوب لتقييد القفل بالفرقة الصحيحة وعدم المساس بفرق أخرى.
  Future<void> submitDriverReport(DateTime date, {required String equipeId}) async {
    assert(equipeId.isNotEmpty, 'equipeId must not be empty for driver report submit');
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _firestore
        .collection(_pointageCollection)
        .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('date', isLessThan: end.toIso8601String())
        .get();
    final now = DateTime.now().toIso8601String();
    final refs = <DocumentReference>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['equipeId'] as String? ?? '') != equipeId) continue;
      final driverStatus = data['driverStatus'] as String?;
      if (driverStatus != null && driverStatus != 'unset') {
        refs.add(doc.reference);
      }
    }
    await _commitBatchedFieldUpdates(refs, {'submittedByDriverAt': now});
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
    final refs = <DocumentReference>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['equipeId'] as String? ?? '') != equipeId) continue;
      refs.add(doc.reference);
    }
    await _commitBatchedFieldUpdates(refs, {'submittedByChefAt': now});
  }

  static const int _maxBatchOps = 450;

  /// Remarques chef d'équipe pour shift de nuit (22h→6h), par employé et jour logique de pointage.
  Future<void> updateNightShiftSupervisorNotes({
    required Map<String, String> employeIdToNote,
    required DateTime date,
  }) async {
    if (employeIdToNote.isEmpty) return;
    final day = DateTime(date.year, date.month, date.day);
    final noteAt = DateTime.now().toIso8601String();
    final refs = <DocumentReference>[];
    final payloads = <Map<String, dynamic>>[];
    for (final e in employeIdToNote.entries) {
      final text = e.value.trim();
      if (text.isEmpty) continue;
      final docId = _docId(e.key, day);
      refs.add(_firestore.collection(_pointageCollection).doc(docId));
      payloads.add({
        'nightShiftSupervisorNote': text,
        'nightShiftSupervisorNoteAt': noteAt,
      });
    }
    for (var i = 0; i < refs.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      final end = (i + _maxBatchOps < refs.length) ? i + _maxBatchOps : refs.length;
      for (var j = i; j < end; j++) {
        batch.update(refs[j], payloads[j]);
      }
      await batch.commit();
    }
  }

  Future<void> _commitBatchedFieldUpdates(
    List<DocumentReference> refs,
    Map<String, dynamic> updates,
  ) async {
    for (var i = 0; i < refs.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      final end = (i + _maxBatchOps < refs.length) ? i + _maxBatchOps : refs.length;
      for (var j = i; j < end; j++) {
        batch.update(refs[j], updates);
      }
      await batch.commit();
    }
  }

  /// Avant [submitChefReport] : marquer tous les non-marqués comme absents en une ou quelques écritures batch.
  Future<void> batchMarkUnmarkedAbsentBeforeChefSubmit({
    required List<PointageRecord> regularTemplates,
    required List<PointageRecord> overtimeRecords,
    required String? chefId,
    bool ignoreLock = false,
  }) async {
    if (regularTemplates.isEmpty && overtimeRecords.isEmpty) return;

    final regularPrepared = await Future.wait(regularTemplates.map((record) async {
      final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
      final existing = record.id.isNotEmpty
          ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
              (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
          : await getByEmployeAndDate(record.employeId, record.date);
      return (record: record, docId: docId, existing: existing);
    }));

    final overtimePrepared = await Future.wait(overtimeRecords.map((record) async {
      final docId = record.id.isNotEmpty ? record.id : _docId(record.employeId, record.date);
      final existing = record.id.isNotEmpty
          ? await _firestore.collection(_pointageCollection).doc(docId).get().then(
              (d) => d.exists ? PointageRecord.fromMap({...d.data()!, 'id': d.id}) : null)
          : await getByEmployeAndDate(record.employeId, record.date);
      return (record: record, docId: docId, existing: existing);
    }));

    final status = ChefPointageStatus.absent;
    final ops = <({DocumentReference ref, bool isSet, Map<String, dynamic> data})>[];

    for (final p in regularPrepared) {
      if (p.existing != null && p.existing!.chefLocked && !ignoreLock) continue;
      final ref = _firestore.collection(_pointageCollection).doc(p.docId);
      if (p.existing != null) {
        ops.add((
          ref: ref,
          isSet: false,
          data: {
            'chefStatus': status.name,
            'markedByChefId': chefId,
            'absenceReason': null,
          },
        ));
      } else {
        final map = p.record
            .copyWith(
              chefStatus: status,
              markedByChefId: chefId,
              absenceReason: null,
            )
            .toMap();
        ops.add((ref: ref, isSet: true, data: map));
      }
    }

    for (final p in overtimePrepared) {
      if (p.existing != null && p.existing!.chefLocked && !ignoreLock) continue;
      final ref = _firestore.collection(_pointageCollection).doc(p.docId);
      if (p.existing != null) {
        ops.add((
          ref: ref,
          isSet: false,
          data: {
            'overtimeChefStatus': status.name,
            'overtimeMarkedByChefId': chefId,
            'overtimeMinutes': 0,
          },
        ));
      } else {
        final map = p.record
            .copyWith(
              overtimeChefStatus: status,
              overtimeMarkedByChefId: chefId,
              overtimeArrivalMarkedAt: null,
              overtimeMinutes: 0,
            )
            .toMap();
        ops.add((ref: ref, isSet: true, data: map));
      }
    }

    for (var i = 0; i < ops.length; i += _maxBatchOps) {
      final batch = _firestore.batch();
      final end = (i + _maxBatchOps < ops.length) ? i + _maxBatchOps : ops.length;
      for (var j = i; j < end; j++) {
        final op = ops[j];
        if (op.isSet) {
          batch.set(op.ref, op.data);
        } else {
          batch.update(op.ref, op.data);
        }
      }
      await batch.commit();
    }
  }

  /// إلغاء تأكيد الخروج: إعادة departureStatus إلى unset وحذف وقت الخروج والساعات الإضافية.
  Future<void> resetDepartureStatus(String docId) async {
    final ref = _firestore.collection(_pointageCollection).doc(docId);
    await ref.update({
      'departureStatus': DepartureStatus.unset.name,
      'departureMarkedAt': null,
      'overtimeMinutes': 0,
      'incompleteShiftReason': null,
      'workedMinutesBeforeStop': null,
    });
  }

  /// تعديل الأدمن النهائي (يمكن تغيير التقرير بعد إرسال الشاف والسائق).
  /// [absenceReason] يُسجّل عند تعيين status = absent.
  Future<void> setAdminOverride(
    String docId,
    AttendanceStatus? status, {
    String? absenceReason,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
    ShiftType? shiftType,
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

    // For admin validation, set the arrival timestamp so "Statistiques" can show times.
    if (status == AttendanceStatus.present ||
        status == AttendanceStatus.training ||
        status == AttendanceStatus.leave) {
      final hasArrival = (data['arrivalMarkedAt'] as String?)?.isNotEmpty == true;
      if (!hasArrival) updates['arrivalMarkedAt'] = nowIso;

      // Poste 1/2 : la sortie doit être confirmée par le chef lui-même, pas automatiquement.
      // Poste 3 (nuit) : la sortie reste automatique. Congé/formation : pas de "sortie" à attendre.
      final confirmDeparture = status == AttendanceStatus.training ||
          status == AttendanceStatus.leave ||
          (status == AttendanceStatus.present && shiftType == ShiftType.night);
      if (confirmDeparture) {
        updates['departureStatus'] = DepartureStatus.finished.name;
        final hasDeparture = (data['departureMarkedAt'] as String?)?.isNotEmpty == true;
        if (!hasDeparture) updates['departureMarkedAt'] = nowIso;
      }
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

  Future<void> createOrUpdateDistSwapArrangement({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String homeEquipeId,
    required String homeEquipeName,
    required DateTime day,
    required String swapId,
    required String unlockWhenEmployeId,
    required DateTime unlockWhenWorkDate,
    required bool pending,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final docId = _distArrangementDocId(employeId, d, homeEquipeId);
    final ref = _firestore.collection(_pointageCollection).doc(docId);
    final snap = await ref.get();
    final base = {
      'employeId': employeId,
      'employeNom': employeNom,
      'employeCin': employeCin,
      'equipeId': homeEquipeId,
      'equipeName': homeEquipeName,
      'chefName': 'Échange Distribution',
      'date': d.toIso8601String(),
      'distSwapArrangement': true,
      'distSwapArrangementPending': pending,
      'distSwapId': swapId,
      'distSwapUnlockEmployeId': unlockWhenEmployeId,
      'distSwapUnlockWorkDate': DateTime(
        unlockWhenWorkDate.year,
        unlockWhenWorkDate.month,
        unlockWhenWorkDate.day,
      ).toIso8601String(),
      'tempAssigned': false,
    };
    if (snap.exists) {
      await ref.update(base);
      return;
    }
    final record = PointageRecord(
      id: docId,
      employeId: employeId,
      employeNom: employeNom,
      employeCin: employeCin,
      equipeId: homeEquipeId,
      equipeName: homeEquipeName,
      chefName: 'Échange Distribution',
      status: AttendanceStatus.present,
      date: d,
      createdAt: DateTime.now(),
      chefStatus: ChefPointageStatus.present,
      departureStatus: pending ? DepartureStatus.unset : DepartureStatus.finished,
      departureMarkedAt: pending ? null : DateTime.now(),
      overtimeMinutes: pending ? null : 480,
      distSwapArrangement: true,
      distSwapArrangementPending: pending,
      distSwapId: swapId,
    );
    await ref.set({...record.toMap(), ...base});
  }

  Future<void> confirmDistSwapArrangement({
    required String employeId,
    required DateTime day,
    required String homeEquipeId,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final docId = _distArrangementDocId(employeId, d, homeEquipeId);
    final ref = _firestore.collection(_pointageCollection).doc(docId);
    final snap = await ref.get();
    if (!snap.exists) return;
    await ref.update({
      'distSwapArrangementPending': false,
      'chefStatus': ChefPointageStatus.present.name,
      'departureStatus': DepartureStatus.finished.name,
      'arrivalMarkedAt': null,
      'departureMarkedAt': null,
      'overtimeMinutes': 480,
      'status': AttendanceStatus.present.name,
    });
  }

  Future<PointageRecord?> getDistSwapArrangement({
    required String employeId,
    required DateTime day,
    required String homeEquipeId,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final docId = _distArrangementDocId(employeId, d, homeEquipeId);
    final snap = await _firestore.collection(_pointageCollection).doc(docId).get();
    if (!snap.exists) return null;
    return PointageRecord.fromMap({...snap.data()!, 'id': snap.id});
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

  /// Supprime les pointages/rapports d'un seul jour, avec option de scope par equipe.
  /// - [equipeId] null/empty => tout le jour.
  /// - [equipeId] renseigné => seulement ce scope.
  Future<void> clearPointageAndReportsForDay(
    DateTime day, {
    String? equipeId,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final scopedEquipeId = (equipeId ?? '').trim();

    Future<void> deleteWithOptionalScope(Query<Map<String, dynamic>> query) async {
      final snap = await query.get();
      if (snap.docs.isEmpty) return;
      final docs = scopedEquipeId.isEmpty
          ? snap.docs
          : snap.docs.where((d) => (d.data()['equipeId'] as String? ?? '') == scopedEquipeId).toList();
      if (docs.isEmpty) return;
      WriteBatch batch = _firestore.batch();
      int ops = 0;
      for (final doc in docs) {
        batch.delete(doc.reference);
        ops++;
        if (ops >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    }

    await deleteWithOptionalScope(
      _firestore
          .collection(_pointageCollection)
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThan: end.toIso8601String()),
    );

    await deleteWithOptionalScope(
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
  /// [knownEmployeIds] — إذا مُرِّرت، يتم البحث عن سجلات هؤلاء الموظفين
  /// مباشرة بالـ doc-id حتى لو لم تظهر في نتائج الاستعلام الأولي (مثلاً
  /// موظفون لم يُسجَّل لهم أي بوانتاج لكنهم موجودون في قائمة الموظفين).
  Future<List<PointageRecord>> getPointageInDateRange(
    DateTime startInclusive,
    DateTime endInclusive, {
    Set<String>? knownEmployeIds,
  }) async {
    final start = DateTime(startInclusive.year, startInclusive.month, startInclusive.day);
    final end = DateTime(endInclusive.year, endInclusive.month, endInclusive.day)
        .add(const Duration(days: 1));
    return _getPointageRangeMixedDate(start, end, knownEmployeIds: knownEmployeIds);
  }

  /// Récupère les pointages dans un intervalle [start, endExclusive[.
  ///
  /// Stratégie en 2 étapes :
  ///   1. Query Firestore avec 3 formats de date (ISO local, ISO UTC, Timestamp)
  ///      → couvre tous les formats de stockage historiques.
  ///   2. Génère les doc-ids attendus ({employeId}_{dateKey}) pour chaque jour
  ///      et fait un getAll() pour récupérer les éventuels documents manqués
  ///      (ex: Renfort docs, ou docs dont le champ 'date' diffère légèrement).
  ///
  /// Les résultats sont fusionnés par doc-id pour éliminer les doublons.
  Future<List<PointageRecord>> _getPointageRangeMixedDate(
    DateTime start,
    DateTime endExclusive, {
    Set<String>? knownEmployeIds,
  }) async {
    final startLocal = DateTime(start.year, start.month, start.day);
    final endLocal   = DateTime(endExclusive.year, endExclusive.month, endExclusive.day);
    final startUtc   = DateTime.utc(start.year, start.month, start.day);
    final endUtc     = DateTime.utc(endExclusive.year, endExclusive.month, endExclusive.day);

    final byId = <String, PointageRecord>{};

    // ── Étape 1 : récupération directe par doc-id (stratégie principale) ──
    // doc-id = {employeId}_{YYYY-MM-DD} — déterministe et indépendant du
    // format de stockage du champ 'date' dans Firestore.
    if (knownEmployeIds != null && knownEmployeIds.isNotEmpty) {
      final days = <DateTime>[];
      for (var d = startLocal; d.isBefore(endLocal); d = d.add(const Duration(days: 1))) {
        days.add(d);
      }
      final allRefs = <DocumentReference>[];
      for (final empId in knownEmployeIds) {
        for (final day in days) {
          allRefs.add(_firestore.collection(_pointageCollection).doc(_docId(empId, day)));
        }
      }
      const getChunk = 20;
      final fetchErrors = <String>[];
      for (int i = 0; i < allRefs.length; i += getChunk) {
        final chunk = allRefs.skip(i).take(getChunk).toList();
        try {
          final snaps = await Future.wait(chunk.map((ref) => ref.get()));
          for (final ds in snaps) {
            final data = ds.data();
            if (ds.exists && data != null) {
              final map = data as Map<String, dynamic>;
              byId[ds.id] = PointageRecord.fromMap({...map, 'id': ds.id});
            }
          }
        } catch (e) {
          fetchErrors.add(e.toString());
        }
      }
      if (fetchErrors.isNotEmpty) {
        throw Exception('Erreur lors de la récupération des pointages (${fetchErrors.length} chunk(s) échoué(s)): ${fetchErrors.first}');
      }
    }

    // ── Étape 2 : query globale par 'date' pour capturer les Renfort docs ─
    // Les Renfort ont un doc-id différent ({empId}_{date}_renfort_{equipeId}),
    // donc non couverts par l'étape 1. On les récupère via query sur 'date'.
    Future<void> runQuery(dynamic from, dynamic to) async {
      try {
        final snap = await _firestore
            .collection(_pointageCollection)
            .where('date', isGreaterThanOrEqualTo: from)
            .where('date', isLessThan: to)
            .get();
        for (final d in snap.docs) {
          byId.putIfAbsent(d.id, () => PointageRecord.fromMap({...d.data(), 'id': d.id}));
        }
      } catch (e) {
        // Query auxiliaire échouée — on continue sans interrompre (Renfort non-critique).
        debugPrint('[PointageRepository] runQuery error: $e');
      }
    }

    await runQuery(startLocal.toIso8601String(), endLocal.toIso8601String());
    await runQuery(startUtc.toIso8601String(), endUtc.toIso8601String());
    await runQuery(Timestamp.fromDate(startUtc), Timestamp.fromDate(endUtc));

    // ── Étape 3 : compléter les employés trouvés dans les queries ─────────
    // Si des employés apparaissent dans les résultats de l'étape 2 mais
    // n'étaient pas dans knownEmployeIds, on cherche leurs docs manquants.
    final extraIds = byId.values
        .map((r) => r.employeId)
        .toSet()
        .difference(knownEmployeIds ?? {});
    if (extraIds.isNotEmpty) {
      final days = <DateTime>[];
      for (var d = startLocal; d.isBefore(endLocal); d = d.add(const Duration(days: 1))) {
        days.add(d);
      }
      final missingRefs = <DocumentReference>[];
      for (final empId in extraIds) {
        for (final day in days) {
          final docId = _docId(empId, day);
          if (!byId.containsKey(docId)) {
            missingRefs.add(_firestore.collection(_pointageCollection).doc(docId));
          }
        }
      }
      const getChunk = 20;
      for (int i = 0; i < missingRefs.length; i += getChunk) {
        final chunk = missingRefs.skip(i).take(getChunk).toList();
        try {
          final snaps = await Future.wait(chunk.map((ref) => ref.get()));
          for (final ds in snaps) {
            final data = ds.data();
            if (ds.exists && data != null) {
              final map = data as Map<String, dynamic>;
              byId.putIfAbsent(ds.id, () => PointageRecord.fromMap({...map, 'id': ds.id}));
            }
          }
        } catch (e) {
          debugPrint('[PointageRepository] étape 3 fetch error: $e');
        }
      }
    }

    return byId.values.toList();
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
