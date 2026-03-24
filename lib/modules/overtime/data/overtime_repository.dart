import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/overtime_model.dart';

class OvertimeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'overtime_assignments';

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _docId(String employeId, DateTime date, String targetEquipeId) =>
      '${employeId}_${_dateKey(date)}_ot_$targetEquipeId';

  // ── Streams ────────────────────────────────────────────────────────────────

  /// جميع تكاليف الساعات الإضافية لتاريخ معيّن (اليوم).
  Stream<List<OvertimeAssignment>> watchForDate(DateTime date) {
    final key = _dateKey(date);
    return _firestore
        .collection(_collection)
        .where('date', isEqualTo: key)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeAssignment.fromMap(d.data(), d.id))
            .toList());
  }

  /// تكاليف الساعات الإضافية للفريق المستقبِل في تاريخ معيّن (ما يراه شاف الفريق).
  Stream<List<OvertimeAssignment>> watchForEquipeAndDate(
      String equipeId, DateTime date) {
    final key = _dateKey(date);
    return _firestore
        .collection(_collection)
        .where('date', isEqualTo: key)
        .where('targetEquipeId', isEqualTo: equipeId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeAssignment.fromMap(d.data(), d.id))
            .toList());
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<List<OvertimeAssignment>> getForDateRange(
      DateTime start, DateTime end) async {
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);
    final snap = await _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: startKey)
        .where('date', isLessThanOrEqualTo: endKey)
        .get();
    return snap.docs
        .map((d) => OvertimeAssignment.fromMap(d.data(), d.id))
        .toList();
  }

  Future<OvertimeAssignment?> getForEmployeeAndDate(
      String employeId, DateTime date, String targetEquipeId) async {
    final docId = _docId(employeId, date, targetEquipeId);
    final doc = await _firestore.collection(_collection).doc(docId).get();
    if (!doc.exists) return null;
    return OvertimeAssignment.fromMap(doc.data()!, doc.id);
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// إنشاء أو تحديث تكليف ساعات إضافية (يستدعيه الأدمن).
  Future<String> createOrUpdate({
    required String employeId,
    required String employeNom,
    required String employeCin,
    required String originalEquipeId,
    required String originalEquipeName,
    required String targetEquipeId,
    required String targetEquipeName,
    required String targetChefName,
    required DateTime date,
    String? createdByAdminId,
    int overtimeMinutes = 480,
  }) async {
    final docId = _docId(employeId, date, targetEquipeId);
    final ref = _firestore.collection(_collection).doc(docId);
    final snap = await ref.get();
    if (snap.exists) {
      // تحديث بيانات الفريق فقط، لا نمسح حالة الحضور
      await ref.update({
        'targetEquipeName': targetEquipeName,
        'targetChefName': targetChefName,
        'originalEquipeName': originalEquipeName,
      });
    } else {
      final assignment = OvertimeAssignment(
        id: docId,
        employeId: employeId,
        employeNom: employeNom,
        employeCin: employeCin,
        originalEquipeId: originalEquipeId,
        originalEquipeName: originalEquipeName,
        targetEquipeId: targetEquipeId,
        targetEquipeName: targetEquipeName,
        targetChefName: targetChefName,
        date: DateTime(date.year, date.month, date.day),
        overtimeMinutes: overtimeMinutes,
        createdAt: DateTime.now(),
        createdByAdminId: createdByAdminId,
      );
      await ref.set(assignment.toMap());
    }
    return docId;
  }

  /// تسجيل حضور/غياب الموظف في الشيفت الإضافي (يستدعيه شاف الفريق المستقبِل).
  Future<void> markAttendance({
    required String docId,
    required OvertimeAttendanceStatus status,
    String? markedByChefId,
  }) async {
    await _firestore.collection(_collection).doc(docId).update({
      'attendanceStatus': status.name,
      'markedByChefId': markedByChefId,
    });
  }

  /// تأكيد إنهاء الشيفت الإضافي وتحديد عدد الساعات الفعلية.
  Future<void> markFinished({
    required String docId,
    required int overtimeMinutes,
    String? markedByChefId,
  }) async {
    await _firestore.collection(_collection).doc(docId).update({
      'finished': true,
      'overtimeMinutes': overtimeMinutes,
      'attendanceStatus': OvertimeAttendanceStatus.present.name,
      'markedByChefId': markedByChefId,
    });
  }

  /// إقفال السجل بعد إرسال التقرير — لا يمكن للشاف التعديل بعدها.
  Future<void> lockAssignment({
    required String docId,
    required String lockedByChefId,
  }) async {
    await _firestore.collection(_collection).doc(docId).update({
      'locked': true,
      'lockedAt': DateTime.now().toIso8601String(),
      'lockedByChefId': lockedByChefId,
    });
  }

  /// فتح القفل (الأدمن فقط) لتعديل الحالة.
  Future<void> unlockAssignment(String docId) async {
    await _firestore.collection(_collection).doc(docId).update({
      'locked': false,
      'lockedAt': null,
      'lockedByChefId': null,
    });
  }

  /// حذف تكليف (يستدعيه الأدمن فقط).
  Future<void> delete(String docId) async {
    await _firestore.collection(_collection).doc(docId).delete();
  }
}
