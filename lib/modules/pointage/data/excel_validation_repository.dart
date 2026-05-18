import 'package:cloud_firestore/cloud_firestore.dart';

class ExcelValidationRecord {
  final String id;
  final DateTime createdAt;
  final String createdById;
  final String createdByName;
  final DateTime startDate;
  final DateTime endDate;
  final String scope;
  final String? equipeId;
  final bool validated;
  final String filePath;

  const ExcelValidationRecord({
    required this.id,
    required this.createdAt,
    required this.createdById,
    required this.createdByName,
    required this.startDate,
    required this.endDate,
    required this.scope,
    required this.equipeId,
    required this.validated,
    required this.filePath,
  });

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? fallback;
    return fallback;
  }

  factory ExcelValidationRecord.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final now = DateTime.now();
    return ExcelValidationRecord(
      id: id,
      createdAt: _parseDate(map['createdAt'], now),
      createdById: map['createdById'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      startDate: _parseDate(map['startDate'], now),
      endDate: _parseDate(map['endDate'], now),
      scope: map['scope'] as String? ?? 'all',
      equipeId: map['equipeId'] as String?,
      validated: map['validated'] as bool? ?? false,
      filePath: map['filePath'] as String? ?? '',
    );
  }
}

class ExcelValidationRepository {
  static const _collection = 'pointage_excel_exports';
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  /// تسجيل تصدير Excel — يحذف التقارير السابقة لنفس النطاق والنطاق قبل الإضافة
  /// حتى لا يظهر أكثر من تقرير واحد لنفس الفترة.
  Future<void> logExport({
    required String createdById,
    required String createdByName,
    required DateTime startDate,
    required DateTime endDate,
    required String scope,
    required String? equipeId,
    required bool validated,
    required String filePath,
  }) async {
    final startTs = Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day));
    final endTs   = Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day));

    // حذف كل التقارير السابقة بنفس startDate + endDate + scope + equipeId
    try {
      Query<Map<String, dynamic>> q = _ref
          .where('startDate', isEqualTo: startTs)
          .where('endDate', isEqualTo: endTs)
          .where('scope', isEqualTo: scope);
      if (equipeId != null) {
        q = q.where('equipeId', isEqualTo: equipeId);
      }
      final existing = await q.get();
      final batch = _db.batch();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      if (existing.docs.isNotEmpty) await batch.commit();
    } catch (_) {}

    // إضافة التقرير الجديد
    await _ref.add({
      'createdAt': FieldValue.serverTimestamp(),
      'createdById': createdById,
      'createdByName': createdByName,
      'startDate': startTs,
      'endDate': endTs,
      'scope': scope,
      'equipeId': equipeId,
      'validated': validated,
      'filePath': filePath,
    });
  }

  /// جلب التقارير الأخيرة — يُبقي فقط آخر تقرير لكل مجموعة (startDate+endDate+scope+equipeId)
  Future<List<ExcelValidationRecord>> getRecentValidated({
    int limit = 50,
  }) async {
    final snap = await _ref
        .orderBy('createdAt', descending: true)
        .limit(limit * 5)
        .get();

    final all = snap.docs
        .map((d) => ExcelValidationRecord.fromMap(d.id, d.data()))
        .where((r) => r.validated)
        .toList();

    // إزالة المكررات — الاحتفاظ بآخر تقرير لكل مجموعة فريدة
    final seen = <String>{};
    final unique = <ExcelValidationRecord>[];
    for (final r in all) {
      final key = '${r.startDate.year}-${r.startDate.month}-${r.startDate.day}'
          '_${r.endDate.year}-${r.endDate.month}-${r.endDate.day}'
          '_${r.scope}_${r.equipeId ?? "all"}';
      if (seen.add(key)) unique.add(r);
      if (unique.length >= limit) break;
    }
    return unique;
  }
}
