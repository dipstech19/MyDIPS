import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/overtime_model.dart';

class OvertimeRepository {
  static const _col = 'overtime_assignments';
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref => _db.collection(_col);

  Stream<List<OvertimeAssignment>> streamForEquipe(String equipeId) {
    return _ref
        .where('targetEquipeId', isEqualTo: equipeId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => OvertimeAssignment.fromMap(d.id, d.data()))
            .toList());
  }

  Future<List<OvertimeAssignment>> getForDateRange(
      DateTime start, DateTime end) async {
    // Single-field range query on 'date' — no composite index needed.
    final s = Timestamp.fromDate(DateTime(start.year, start.month, start.day));
    final e = Timestamp.fromDate(
        DateTime(end.year, end.month, end.day).add(const Duration(days: 1)));
    final snap = await _ref
        .where('date', isGreaterThanOrEqualTo: s)
        .where('date', isLessThan: e)
        .get();
    return snap.docs
        .map((d) => OvertimeAssignment.fromMap(d.id, d.data()))
        .toList();
  }

  /// Stream all assignments for a specific date (admin view).
  /// Uses dateKey string field (single-field query — no composite index needed).
  Stream<List<OvertimeAssignment>> streamForDate(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _ref
        .where('dateKey', isEqualTo: key)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => OvertimeAssignment.fromMap(d.id, d.data()))
            .toList());
  }

  Future<String> add(OvertimeAssignment a) async {
    final doc = await _ref.add(a.toMap());
    return doc.id;
  }

  Future<void> update(OvertimeAssignment a) =>
      _ref.doc(a.id).update(a.toMap());

  Future<void> delete(String id) => _ref.doc(id).delete();

  Future<void> lock(String id, String chefId, DateTime at) =>
      _ref.doc(id).update({
        'locked': true,
        'lockedAt': Timestamp.fromDate(at),
        'lockedByChefId': chefId,
      });

  Future<void> unlock(String id) => _ref.doc(id).update({
        'locked': false,
        'lockedAt': null,
        'lockedByChefId': null,
      });

  /// Confirms employee arrival for overtime shift.
  Future<void> confirmArrival(String id, DateTime at) =>
      _ref.doc(id).update({
        'attendanceStatus': OvertimeAttendanceStatus.present.name,
        'arrivalConfirmedAt': Timestamp.fromDate(at),
      });

  /// Confirms employee departure (end of overtime shift) — sets 8h (480 min).
  Future<void> confirmDeparture(String id, DateTime at) =>
      _ref.doc(id).update({
        'departureConfirmedAt': Timestamp.fromDate(at),
        'overtimeMinutes': 480,
        'finished': true,
      });

  /// Marks employee as absent for the overtime assignment.
  Future<void> markAbsent(String id) =>
      _ref.doc(id).update({
        'attendanceStatus': OvertimeAttendanceStatus.absent.name,
        'arrivalConfirmedAt': null,
        'departureConfirmedAt': null,
        'overtimeMinutes': 0,
        'finished': false,
      });

  /// Stream today's overtime assignments for a given target equipe.
  /// Filters by targetEquipeId only (single-field — no composite index needed),
  /// then filters today client-side.
  Stream<List<OvertimeAssignment>> streamTodayForEquipe(String equipeId) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return _ref
        .where('targetEquipeId', isEqualTo: equipeId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => OvertimeAssignment.fromMap(d.id, d.data()))
            .where((a) {
              final d = DateTime(a.date.year, a.date.month, a.date.day);
              return d == todayKey;
            })
            .toList());
  }
}
