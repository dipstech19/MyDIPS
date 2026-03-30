import 'package:cloud_firestore/cloud_firestore.dart';

/// حالة موظف واحد ليوم واحد — مخزّنة عند تأكيد الفريق من الأدمن.
/// هذا هو المصدر الموثوق للتصدير Excel بدلاً من محاولة جلب وتفسير سجلات Firestore.
class DailyEmployeeSnapshot {
  final String id;           // {employeId}_{YYYY-MM-DD}
  final String employeId;
  final String employeNom;
  final String employeCin;
  final String equipeId;
  final String equipeName;
  final DateTime date;
  /// present | absent | leave | formation | rest | paid_absence
  final String status;
  /// سبب الغياب إن وُجد
  final String? absenceReason;
  /// هل يوم راحة
  final bool isRestDay;
  /// وقت التخزين
  final DateTime snapshotAt;
  /// معرف من أكّد
  final String confirmedById;

  const DailyEmployeeSnapshot({
    required this.id,
    required this.employeId,
    required this.employeNom,
    required this.employeCin,
    required this.equipeId,
    required this.equipeName,
    required this.date,
    required this.status,
    this.absenceReason,
    required this.isRestDay,
    required this.snapshotAt,
    required this.confirmedById,
  });

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate().toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? fallback;
    return fallback;
  }

  factory DailyEmployeeSnapshot.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return DailyEmployeeSnapshot(
      id: id,
      employeId: map['employeId'] as String? ?? '',
      employeNom: map['employeNom'] as String? ?? '',
      employeCin: map['employeCin'] as String? ?? '',
      equipeId: map['equipeId'] as String? ?? '',
      equipeName: map['equipeName'] as String? ?? '',
      date: _parseDate(map['date'], now),
      status: map['status'] as String? ?? 'absent',
      absenceReason: map['absenceReason'] as String?,
      isRestDay: map['isRestDay'] as bool? ?? false,
      snapshotAt: _parseDate(map['snapshotAt'], now),
      confirmedById: map['confirmedById'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'employeId': employeId,
    'employeNom': employeNom,
    'employeCin': employeCin,
    'equipeId': equipeId,
    'equipeName': equipeName,
    'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    'status': status,
    'absenceReason': absenceReason,
    'isRestDay': isRestDay,
    'snapshotAt': FieldValue.serverTimestamp(),
    'confirmedById': confirmedById,
  };
}

class DailySnapshotRepository {
  static const _collection = 'pointage_daily_snapshots';
  final _db = FirebaseFirestore.instance;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// doc-id ثابت: {employeId}_{YYYY-MM-DD}
  String _docId(String employeId, DateTime date) =>
      '${employeId}_${_dateKey(date)}';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  /// تخزين snapshots لكل موظفي فريق ليوم معين (batch write)
  Future<void> saveEquipeSnapshot({
    required String equipeId,
    required String equipeName,
    required DateTime date,
    required String confirmedById,
    required List<({
      String employeId,
      String employeNom,
      String employeCin,
      String status,
      String? absenceReason,
      bool isRestDay,
    })> employees,
  }) async {
    if (employees.isEmpty) return;

    // كتابة batch (max 500 per batch)
    const chunkSize = 400;
    for (int i = 0; i < employees.length; i += chunkSize) {
      final chunk = employees.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final emp in chunk) {
        final docId = _docId(emp.employeId, date);
        final snap = DailyEmployeeSnapshot(
          id: docId,
          employeId: emp.employeId,
          employeNom: emp.employeNom,
          employeCin: emp.employeCin,
          equipeId: equipeId,
          equipeName: equipeName,
          date: date,
          status: emp.status,
          absenceReason: emp.absenceReason,
          isRestDay: emp.isRestDay,
          snapshotAt: DateTime.now(),
          confirmedById: confirmedById,
        );
        batch.set(_ref.doc(docId), snap.toMap());
      }
      await batch.commit();
    }
  }

  /// جلب كل snapshots لنطاق تواريخ (للتصدير Excel)
  Future<List<DailyEmployeeSnapshot>> getSnapshotsForRange(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final startTs = Timestamp.fromDate(
        DateTime(startInclusive.year, startInclusive.month, startInclusive.day));
    final endTs = Timestamp.fromDate(
        DateTime(endInclusive.year, endInclusive.month, endInclusive.day));

    final snap = await _ref
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThanOrEqualTo: endTs)
        .get();

    return snap.docs
        .map((d) => DailyEmployeeSnapshot.fromMap(d.id, d.data()))
        .toList();
  }

  /// جلب snapshots ليوم واحد وفريق واحد
  Future<List<DailyEmployeeSnapshot>> getSnapshotsForEquipeAndDate(
    String equipeId,
    DateTime date,
  ) async {
    final dateTs = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final snap = await _ref
        .where('equipeId', isEqualTo: equipeId)
        .where('date', isEqualTo: dateTs)
        .get();
    return snap.docs
        .map((d) => DailyEmployeeSnapshot.fromMap(d.id, d.data()))
        .toList();
  }

  /// حذف snapshots فريق ليوم معين (عند إلغاء التأكيد)
  Future<void> deleteEquipeSnapshot(String equipeId, DateTime date) async {
    final dateTs = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final snap = await _ref
        .where('equipeId', isEqualTo: equipeId)
        .where('date', isEqualTo: dateTs)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }
}
