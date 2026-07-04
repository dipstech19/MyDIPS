import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_models.dart';

class ShiftsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _configDoc = 'shifts_config';
  static const String _overridesCollection = 'shifts_overrides';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// جلب إعداد الورديات من Firestore
  Future<RotationConfig?> getConfig() async {
    try {
      final doc = await _firestore.collection('app_config').doc(_configDoc).get();
      if (doc.data() == null) return null;
      final data = doc.data()!;
      final startStamp = data['startDate'];
      DateTime startDate = DateTime.now();
      if (startStamp != null) {
        if (startStamp is Timestamp) {
          startDate = startStamp.toDate();
        } else if (startStamp is String) {
          startDate = DateTime.tryParse(startStamp) ?? startDate;
        }
      }
      final ids = data['equipeIds'];
      List<String> equipeIds = [];
      if (ids is List) {
        equipeIds = ids.map((e) => e?.toString() ?? '').toList();
      }
      return RotationConfig(startDate: startDate, equipeIds: equipeIds);
    } catch (e) {
      return null;
    }
  }

  /// حفظ إعداد الورديات في Firestore
  Future<void> setConfig(RotationConfig config) async {
    await _firestore.collection('app_config').doc(_configDoc).set({
      'startDate': config.startDay.toIso8601String(),
      'equipeIds': config.equipeIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// جلب كل التعديلات اليدوية (overrides) للورديات
  Future<Map<String, Map<String, ShiftType>>> getOverrides() async {
    final result = <String, Map<String, ShiftType>>{};
    try {
      final snap = await _firestore.collection('app_config').doc(_configDoc).collection(_overridesCollection).get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final dateKey = doc.id;
        final perEquipe = data['overrides'] as Map<String, dynamic>?;
        if (perEquipe != null) {
          result[dateKey] = {};
          perEquipe.forEach((equipeId, shiftName) {
            if (shiftName is String) {
              try {
                final st = ShiftType.values.firstWhere((e) => e.name == shiftName);
                result[dateKey]![equipeId] = st;
              } catch (_) {}
            }
          });
        }
      }
    } catch (_) {}
    return result;
  }

  /// حفظ تعديل يدوي ليوم وفريق معيّن
  Future<void> setShiftOverride(DateTime date, String equipeId, ShiftType shift) async {
    final key = _dateKey(date);
    final ref = _firestore.collection('app_config').doc(_configDoc).collection(_overridesCollection).doc(key);
    final doc = await ref.get();
    final Map<String, String> overrides = {};
    if (doc.data() != null && doc.data()!['overrides'] != null) {
      (doc.data()!['overrides'] as Map).forEach((k, v) {
        if (v is String) overrides[k.toString()] = v;
      });
    }
    overrides[equipeId] = shift.name;
    await ref.set({'overrides': overrides, 'date': key});
  }

  // ─── Jours ×2 (jours fériés / travail doublé) ────────────────────────────

  static const String _doubleDaysCollection = 'double_days';

  /// Charger tous les jours ×2 depuis Firestore.
  Future<List<DoubleDay>> getDoubleDays() async {
    try {
      final snap = await _firestore
          .collection('app_config')
          .doc(_configDoc)
          .collection(_doubleDaysCollection)
          .get();
      return snap.docs.map((d) => DoubleDay.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /// Ajouter ou mettre à jour un jour ×2.
  Future<void> setDoubleDay(DoubleDay day) async {
    final ref = _firestore
        .collection('app_config')
        .doc(_configDoc)
        .collection(_doubleDaysCollection)
        .doc(day.dateKey);
    await ref.set(day.toMap());
  }

  /// Supprimer un jour ×2.
  Future<void> removeDoubleDay(DateTime date) async {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('app_config')
        .doc(_configDoc)
        .collection(_doubleDaysCollection)
        .doc(key)
        .delete();
  }

  // ─── Jours fériés (JF — Hors équipe / export OCP) ───────────────────────

  static const String _publicHolidaysCollection = 'public_holidays';

  Future<List<PublicHoliday>> getPublicHolidays() async {
    try {
      final snap = await _firestore
          .collection('app_config')
          .doc(_configDoc)
          .collection(_publicHolidaysCollection)
          .get();
      return snap.docs.map((d) => PublicHoliday.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setPublicHoliday(PublicHoliday day) async {
    final ref = _firestore
        .collection('app_config')
        .doc(_configDoc)
        .collection(_publicHolidaysCollection)
        .doc(day.dateKey);
    await ref.set(day.toMap());
  }

  Future<void> removePublicHoliday(DateTime date) async {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _firestore
        .collection('app_config')
        .doc(_configDoc)
        .collection(_publicHolidaysCollection)
        .doc(key)
        .delete();
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// تحميل الإعداد + كل الـ overrides + أيام ×2 (للاستدعاء عند بدء التطبيق)
  Future<
      ({
        RotationConfig? config,
        Map<String, Map<String, ShiftType>> overrides,
        List<DoubleDay> doubleDays,
        List<PublicHoliday> publicHolidays,
      })> loadAll() async {
    final config = await getConfig();
    final overrides = await getOverrides();
    final doubleDays = await getDoubleDays();
    final publicHolidays = await getPublicHolidays();
    return (
      config: config,
      overrides: overrides,
      doubleDays: doubleDays,
      publicHolidays: publicHolidays,
    );
  }
}
