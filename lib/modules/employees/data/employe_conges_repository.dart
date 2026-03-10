import 'package:cloud_firestore/cloud_firestore.dart';

/// تخزين أيام الإجازة المستخدمة لكل موظف (يُخصم من المستحق).
class EmployeCongesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'employe_conges';

  Future<double> getDaysTaken(String employeId) async {
    if (employeId.isEmpty) return 0;
    final doc = await _firestore.collection(_collection).doc(employeId).get();
    if (doc.data() == null) return 0;
    final v = doc.data()!['daysTaken'];
    if (v == null) return 0;
    return (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
  }

  /// إضافة أيام مُستخدَمة (خصم من الرصيد).
  Future<void> addDaysTaken(String employeId, double days) async {
    if (employeId.isEmpty) return;
    final ref = _firestore.collection(_collection).doc(employeId);
    final current = await getDaysTaken(employeId);
    await ref.set({
      'daysTaken': current + days,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// تعيين القيمة يدوياً (لتصحيح).
  Future<void> setDaysTaken(String employeId, double value) async {
    if (employeId.isEmpty) return;
    await _firestore.collection(_collection).doc(employeId).set({
      'daysTaken': value < 0 ? 0 : value,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
