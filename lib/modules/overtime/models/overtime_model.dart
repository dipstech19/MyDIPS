/// حالة حضور الموظف في الساعات الإضافية (يُسجلها شاف الفريق المستقبِل)
enum OvertimeAttendanceStatus { unset, present, absent }

extension OvertimeAttendanceStatusExt on OvertimeAttendanceStatus {
  String get label {
    switch (this) {
      case OvertimeAttendanceStatus.present:
        return 'Présent';
      case OvertimeAttendanceStatus.absent:
        return 'Absent';
      case OvertimeAttendanceStatus.unset:
        return '—';
    }
  }

  static OvertimeAttendanceStatus fromString(String? s) {
    switch (s) {
      case 'present':
        return OvertimeAttendanceStatus.present;
      case 'absent':
        return OvertimeAttendanceStatus.absent;
      default:
        return OvertimeAttendanceStatus.unset;
    }
  }
}

/// سجل تكليف موظف بساعات إضافية في فريق آخر ليوم معيّن.
/// يُخزَّن في collection [overtime_assignments] بمعرف مستقل.
class OvertimeAssignment {
  final String id;

  /// بيانات الموظف
  final String employeId;
  final String employeNom;
  final String employeCin;

  /// الفريق الأصلي للموظف
  final String originalEquipeId;
  final String originalEquipeName;

  /// الفريق المستقبِل (الذي سيعمل فيه ساعات إضافية)
  final String targetEquipeId;
  final String targetEquipeName;
  final String targetChefName;

  /// تاريخ الساعات الإضافية
  final DateTime date;

  /// حالة الحضور في الشيفت الإضافي (يُسجلها شاف الفريق المستقبِل)
  final OvertimeAttendanceStatus attendanceStatus;

  /// عدد دقائق الساعات الإضافية المؤكدة (0 = غير محدد بعد، 480 = 8 ساعات افتراضي)
  final int overtimeMinutes;

  /// هل أنهى الموظف الشيفت الإضافي؟
  final bool finished;

  /// من سجّل الحضور (شاف الفريق المستقبِل)
  final String? markedByChefId;

  /// تاريخ الإنشاء
  final DateTime createdAt;

  /// من أنشأ هذا التكليف (الأدمن)
  final String? createdByAdminId;

  /// هل أُقفل هذا السجل بعد إرسال التقرير؟ (لا يمكن التعديل إلا للأدمن)
  final bool locked;

  /// تاريخ الإقفال
  final DateTime? lockedAt;

  /// من أقفل السجل (شاف الفريق)
  final String? lockedByChefId;

  const OvertimeAssignment({
    required this.id,
    required this.employeId,
    required this.employeNom,
    required this.employeCin,
    required this.originalEquipeId,
    required this.originalEquipeName,
    required this.targetEquipeId,
    required this.targetEquipeName,
    required this.targetChefName,
    required this.date,
    this.attendanceStatus = OvertimeAttendanceStatus.unset,
    this.overtimeMinutes = 480,
    this.finished = false,
    this.markedByChefId,
    required this.createdAt,
    this.createdByAdminId,
    this.locked = false,
    this.lockedAt,
    this.lockedByChefId,
  });

  bool get isPresent => attendanceStatus == OvertimeAttendanceStatus.present;
  bool get isAbsent => attendanceStatus == OvertimeAttendanceStatus.absent;
  bool get isPending => attendanceStatus == OvertimeAttendanceStatus.unset;

  Map<String, dynamic> toMap() => {
        'employeId': employeId,
        'employeNom': employeNom,
        'employeCin': employeCin,
        'originalEquipeId': originalEquipeId,
        'originalEquipeName': originalEquipeName,
        'targetEquipeId': targetEquipeId,
        'targetEquipeName': targetEquipeName,
        'targetChefName': targetChefName,
        'date': date.toIso8601String().substring(0, 10),
        'attendanceStatus': attendanceStatus.name,
        'overtimeMinutes': overtimeMinutes,
        'finished': finished,
        'markedByChefId': markedByChefId,
        'createdAt': createdAt.toIso8601String(),
        'createdByAdminId': createdByAdminId,
        'locked': locked,
        'lockedAt': lockedAt?.toIso8601String(),
        'lockedByChefId': lockedByChefId,
      };

  factory OvertimeAssignment.fromMap(Map<String, dynamic> map, String docId) {
    return OvertimeAssignment(
      id: docId,
      employeId: map['employeId'] as String? ?? '',
      employeNom: map['employeNom'] as String? ?? '',
      employeCin: map['employeCin'] as String? ?? '',
      originalEquipeId: map['originalEquipeId'] as String? ?? '',
      originalEquipeName: map['originalEquipeName'] as String? ?? '',
      targetEquipeId: map['targetEquipeId'] as String? ?? '',
      targetEquipeName: map['targetEquipeName'] as String? ?? '',
      targetChefName: map['targetChefName'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      attendanceStatus: OvertimeAttendanceStatusExt.fromString(map['attendanceStatus'] as String?),
      overtimeMinutes: (map['overtimeMinutes'] as num?)?.toInt() ?? 480,
      finished: map['finished'] as bool? ?? false,
      markedByChefId: map['markedByChefId'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdByAdminId: map['createdByAdminId'] as String?,
      locked: map['locked'] as bool? ?? false,
      lockedAt: map['lockedAt'] != null
          ? DateTime.tryParse(map['lockedAt'] as String)
          : null,
      lockedByChefId: map['lockedByChefId'] as String?,
    );
  }

  OvertimeAssignment copyWith({
    String? id,
    String? employeId,
    String? employeNom,
    String? employeCin,
    String? originalEquipeId,
    String? originalEquipeName,
    String? targetEquipeId,
    String? targetEquipeName,
    String? targetChefName,
    DateTime? date,
    OvertimeAttendanceStatus? attendanceStatus,
    int? overtimeMinutes,
    bool? finished,
    String? markedByChefId,
    DateTime? createdAt,
    String? createdByAdminId,
    bool? locked,
    DateTime? lockedAt,
    String? lockedByChefId,
  }) =>
      OvertimeAssignment(
        id: id ?? this.id,
        employeId: employeId ?? this.employeId,
        employeNom: employeNom ?? this.employeNom,
        employeCin: employeCin ?? this.employeCin,
        originalEquipeId: originalEquipeId ?? this.originalEquipeId,
        originalEquipeName: originalEquipeName ?? this.originalEquipeName,
        targetEquipeId: targetEquipeId ?? this.targetEquipeId,
        targetEquipeName: targetEquipeName ?? this.targetEquipeName,
        targetChefName: targetChefName ?? this.targetChefName,
        date: date ?? this.date,
        attendanceStatus: attendanceStatus ?? this.attendanceStatus,
        overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
        finished: finished ?? this.finished,
        markedByChefId: markedByChefId ?? this.markedByChefId,
        createdAt: createdAt ?? this.createdAt,
        createdByAdminId: createdByAdminId ?? this.createdByAdminId,
        locked: locked ?? this.locked,
        lockedAt: lockedAt ?? this.lockedAt,
        lockedByChefId: lockedByChefId ?? this.lockedByChefId,
      );
}
