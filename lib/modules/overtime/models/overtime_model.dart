import 'package:cloud_firestore/cloud_firestore.dart';

enum OvertimeAttendanceStatus { unset, present, absent }

class OvertimeAssignment {
  final String id;
  final String employeId;
  final String employeNom;
  final String originEquipeId;
  final String originEquipeName;
  final String targetEquipeId;
  final String targetEquipeName;
  final DateTime date;
  final DateTime createdAt;
  final String createdByAdminId;
  final OvertimeAttendanceStatus attendanceStatus;
  final bool finished;
  final int overtimeMinutes;
  final bool locked;
  final DateTime? lockedAt;
  final String? lockedByChefId;
  /// Heure à laquelle le chef a confirmé l'arrivée de l'employé.
  final DateTime? arrivalConfirmedAt;
  /// Heure à laquelle le chef a confirmé le départ de l'employé (= fin de la journée d'HS).
  final DateTime? departureConfirmedAt;

  const OvertimeAssignment({
    required this.id,
    required this.employeId,
    required this.employeNom,
    required this.originEquipeId,
    required this.originEquipeName,
    required this.targetEquipeId,
    required this.targetEquipeName,
    required this.date,
    required this.createdAt,
    required this.createdByAdminId,
    this.attendanceStatus = OvertimeAttendanceStatus.unset,
    this.finished = false,
    this.overtimeMinutes = 0,
    this.locked = false,
    this.lockedAt,
    this.lockedByChefId,
    this.arrivalConfirmedAt,
    this.departureConfirmedAt,
  });

  OvertimeAssignment copyWith({
    String? id,
    String? employeId,
    String? employeNom,
    String? originEquipeId,
    String? originEquipeName,
    String? targetEquipeId,
    String? targetEquipeName,
    DateTime? date,
    DateTime? createdAt,
    String? createdByAdminId,
    OvertimeAttendanceStatus? attendanceStatus,
    bool? finished,
    int? overtimeMinutes,
    bool? locked,
    DateTime? lockedAt,
    String? lockedByChefId,
    DateTime? arrivalConfirmedAt,
    DateTime? departureConfirmedAt,
  }) {
    return OvertimeAssignment(
      id: id ?? this.id,
      employeId: employeId ?? this.employeId,
      employeNom: employeNom ?? this.employeNom,
      originEquipeId: originEquipeId ?? this.originEquipeId,
      originEquipeName: originEquipeName ?? this.originEquipeName,
      targetEquipeId: targetEquipeId ?? this.targetEquipeId,
      targetEquipeName: targetEquipeName ?? this.targetEquipeName,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      finished: finished ?? this.finished,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      locked: locked ?? this.locked,
      lockedAt: lockedAt ?? this.lockedAt,
      lockedByChefId: lockedByChefId ?? this.lockedByChefId,
      arrivalConfirmedAt: arrivalConfirmedAt ?? this.arrivalConfirmedAt,
      departureConfirmedAt: departureConfirmedAt ?? this.departureConfirmedAt,
    );
  }

  /// YYYY-MM-DD string key for simple equality Firestore queries (no composite index).
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'employeId': employeId,
        'employeNom': employeNom,
        'originEquipeId': originEquipeId,
        'originEquipeName': originEquipeName,
        'targetEquipeId': targetEquipeId,
        'targetEquipeName': targetEquipeName,
        'date': Timestamp.fromDate(date),
        'dateKey': dateKey,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdByAdminId': createdByAdminId,
        'attendanceStatus': attendanceStatus.name,
        'finished': finished,
        'overtimeMinutes': overtimeMinutes,
        'locked': locked,
        'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
        'lockedByChefId': lockedByChefId,
        'arrivalConfirmedAt': arrivalConfirmedAt != null ? Timestamp.fromDate(arrivalConfirmedAt!) : null,
        'departureConfirmedAt': departureConfirmedAt != null ? Timestamp.fromDate(departureConfirmedAt!) : null,
      };

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return fallback;
  }

  static DateTime? _parseDateNullable(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory OvertimeAssignment.fromMap(String id, Map<String, dynamic> map) =>
      OvertimeAssignment(
        id: id,
        employeId: map['employeId'] as String? ?? '',
        employeNom: map['employeNom'] as String? ?? '',
        originEquipeId: map['originEquipeId'] as String? ?? '',
        originEquipeName: map['originEquipeName'] as String? ?? '',
        targetEquipeId: map['targetEquipeId'] as String? ?? '',
        targetEquipeName: map['targetEquipeName'] as String? ?? '',
        date: _parseDate(map['date'], DateTime.now()),
        createdAt: _parseDate(map['createdAt'], DateTime.now()),
        createdByAdminId: map['createdByAdminId'] as String? ?? '',
        attendanceStatus: OvertimeAttendanceStatus.values.firstWhere(
          (e) => e.name == (map['attendanceStatus'] as String?),
          orElse: () => OvertimeAttendanceStatus.unset,
        ),
        finished: map['finished'] as bool? ?? false,
        overtimeMinutes: map['overtimeMinutes'] as int? ?? 0,
        locked: map['locked'] as bool? ?? false,
        lockedAt: _parseDateNullable(map['lockedAt']),
        lockedByChefId: map['lockedByChefId'] as String?,
        arrivalConfirmedAt: _parseDateNullable(map['arrivalConfirmedAt']),
        departureConfirmedAt: _parseDateNullable(map['departureConfirmedAt']),
      );
}
