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
    await _ref.add({
      'createdAt': FieldValue.serverTimestamp(),
      'createdById': createdById,
      'createdByName': createdByName,
      'startDate': Timestamp.fromDate(
          DateTime(startDate.year, startDate.month, startDate.day)),
      'endDate':
          Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)),
      'scope': scope,
      'equipeId': equipeId,
      'validated': validated,
      'filePath': filePath,
    });
  }

  Future<List<ExcelValidationRecord>> getRecentValidated({
    int limit = 50,
  }) async {
    final snap = await _ref
        .orderBy('createdAt', descending: true)
        .limit(limit * 3)
        .get();
    return snap.docs
        .map((d) => ExcelValidationRecord.fromMap(d.id, d.data()))
        .where((r) => r.validated)
        .take(limit)
        .toList();
  }
}
