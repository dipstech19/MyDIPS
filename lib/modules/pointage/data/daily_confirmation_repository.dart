import 'package:cloud_firestore/cloud_firestore.dart';

/// تأكيد يومي لفريق واحد من الأدمن
class DailyEquipeConfirmation {
  final String id;
  final String equipeId;
  final String equipeName;
  final String confirmedById;
  final String confirmedByName;
  final DateTime date;
  final DateTime confirmedAt;
  final int presentCount;
  final int absentCount;

  const DailyEquipeConfirmation({
    required this.id,
    required this.equipeId,
    required this.equipeName,
    required this.confirmedById,
    required this.confirmedByName,
    required this.date,
    required this.confirmedAt,
    required this.presentCount,
    required this.absentCount,
  });

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate().toLocal();
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? fallback;
    return fallback;
  }

  factory DailyEquipeConfirmation.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return DailyEquipeConfirmation(
      id: id,
      equipeId: map['equipeId'] as String? ?? '',
      equipeName: map['equipeName'] as String? ?? '',
      confirmedById: map['confirmedById'] as String? ?? '',
      confirmedByName: map['confirmedByName'] as String? ?? '',
      date: _parseDate(map['date'], now),
      confirmedAt: _parseDate(map['confirmedAt'], now),
      presentCount: (map['presentCount'] as num?)?.toInt() ?? 0,
      absentCount: (map['absentCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyConfirmationRepository {
  static const _collection = 'pointage_daily_confirmations';
  final _db = FirebaseFirestore.instance;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// doc-id ثابت لكل (equipeId + date) — يمنع التكرار
  String _docId(String equipeId, DateTime date) =>
      '${equipeId}_${_dateKey(date)}';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  /// تأكيد فريق ليوم معين (يُنشئ أو يُحدِّث)
  Future<void> confirmEquipe({
    required String equipeId,
    required String equipeName,
    required String confirmedById,
    required String confirmedByName,
    required DateTime date,
    required int presentCount,
    required int absentCount,
  }) async {
    final docId = _docId(equipeId, date);
    final dateTs = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    await _ref.doc(docId).set({
      'equipeId': equipeId,
      'equipeName': equipeName,
      'confirmedById': confirmedById,
      'confirmedByName': confirmedByName,
      'date': dateTs,
      'confirmedAt': FieldValue.serverTimestamp(),
      'presentCount': presentCount,
      'absentCount': absentCount,
    });
  }

  /// إلغاء تأكيد فريق ليوم معين
  Future<void> unconfirmEquipe(String equipeId, DateTime date) async {
    await _ref.doc(_docId(equipeId, date)).delete();
  }

  /// جلب كل التأكيدات ليوم معين
  Future<List<DailyEquipeConfirmation>> getConfirmationsForDate(DateTime date) async {
    final dateTs = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final snap = await _ref.where('date', isEqualTo: dateTs).get();
    return snap.docs
        .map((d) => DailyEquipeConfirmation.fromMap(d.id, d.data()))
        .toList();
  }

  /// Stream لتأكيدات يوم معين (real-time)
  Stream<List<DailyEquipeConfirmation>> watchConfirmationsForDate(DateTime date) {
    final dateTs = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    return _ref
        .where('date', isEqualTo: dateTs)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DailyEquipeConfirmation.fromMap(d.id, d.data()))
            .toList());
  }

  /// هل هذا الفريق مؤكَّد ليوم معين؟
  Future<bool> isConfirmed(String equipeId, DateTime date) async {
    final doc = await _ref.doc(_docId(equipeId, date)).get();
    return doc.exists;
  }
}
