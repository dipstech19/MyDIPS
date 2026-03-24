import 'absence_reason_config.dart';

/// حالة من السائق: حاضر | غائب | في المركبة (سيارة/دراجة)
enum DriverPointageStatus { present, absent, enVehicule, unset }

/// حالة من الشاف: حاضر | غائب فقط
enum ChefPointageStatus { present, absent, unset }

/// سبب الغياب (يُختار عند تسجيل غياب من الشاف أو الأدمن فقط)
enum AbsenceReason {
  maladie,
  paternite,
  mariage,
  deces,
  autorisee,
  absenceInjustifiee,
}

extension AbsenceReasonExt on AbsenceReason {
  String get label {
    switch (this) {
      case AbsenceReason.maladie:
        return 'Maladie';
      case AbsenceReason.paternite:
        return 'Paternité';
      case AbsenceReason.mariage:
        return 'Mariage';
      case AbsenceReason.deces:
        return 'Décès';
      case AbsenceReason.autorisee:
        return 'Autorisée';
      case AbsenceReason.absenceInjustifiee:
        return 'Absence injustifiée';
    }
  }
}

/// تسمية سبب الغياب من القيمة المخزنة (للتقارير و Excel).
/// إذا وُجدت [configs] تُستخدم أولاً (مطابقة id)، وإلا التعداد الثابت.
String getAbsenceReasonLabel(String? reason, [List<AbsenceReasonConfig>? configs]) {
  if (reason == null || reason.isEmpty) return '';
  if (configs != null) {
    final found = configs.where((c) => c.id == reason).toList();
    if (found.isNotEmpty) return found.first.label;
  }
  try {
    return AbsenceReason.values.firstWhere((e) => e.name == reason).label;
  } catch (_) {
    return reason;
  }
}

/// هل هذا السبب يقتضي خصمًا من الراتب؟ تُستخدم في Excel (ألوان).
bool isAbsenceReasonDeductFromSalary(String? reason, [List<AbsenceReasonConfig>? configs]) {
  if (reason == null || reason.isEmpty) return true;
  if (configs != null) {
    final found = configs.where((c) => c.id == reason).toList();
    if (found.isNotEmpty) return found.first.deductFromSalary;
  }
  try {
    final e = AbsenceReason.values.firstWhere((e) => e.name == reason);
    return e == AbsenceReason.maladie || e == AbsenceReason.absenceInjustifiee;
  } catch (_) {
    return true;
  }
}

/// نتيجة المندقية: مؤكد حاضر | مؤكد غائب | خلل | في الانتظار
enum ReconciledStatus { confirmedPresent, confirmedAbsent, discrepancy, pending }

/// للتوافق مع الكود القديم — training = في دورة تكوينية (حاضر لكن لا يظهر للشاف/السائق)
enum AttendanceStatus { present, absent, notInVehicle, unmarked, training }

/// حالة الخروج: لم يُسجّل | لا يزال يعمل | انتهى من العمل
enum DepartureStatus { unset, stillWorking, finished }

class PointageRecord {
  final String id;
  final String employeId;
  final String employeNom;
  final String employeCin;
  final String equipeId;
  final String equipeName;
  final String chefName;
  /// الحالة الموحدة القديمة (تُستخدم عند عدم وجود driver/chef)
  final AttendanceStatus status;
  final DateTime date;
  final DateTime createdAt;
  final String? markedById;
  final String? markedByName;

  /// من السائق: حاضر | غائب | في المركبة
  final DriverPointageStatus driverStatus;
  /// من الشاف: حاضر | غائب
  final ChefPointageStatus chefStatus;
  /// وقت إرسال تقرير السائق (بعدها لا يستطيع التعديل)
  final DateTime? submittedByDriverAt;
  /// وقت إرسال تقرير الشاف (بعدها لا يستطيع التعديل)
  final DateTime? submittedByChefAt;
  /// تعديل الأدمن النهائي (يُعتمد عند الحضور النهائي)
  final AttendanceStatus? adminFinalStatus;
  final String? markedByDriverId;
  final String? markedByChefId;
  /// تأكيد الحضور/الغياب الخاص بالساعات الإضافية (للشيفت الموالي).
  final ChefPointageStatus overtimeChefStatus;
  final String? overtimeMarkedByChefId;
  final DateTime? overtimeArrivalMarkedAt;
  /// وقت تسجيل الدخول الفعلي (أول مرة يُسجّل فيها حاضر)
  final DateTime? arrivalMarkedAt;
  /// حالة الخروج: لا يزال يعمل | انتهى
  final DepartureStatus departureStatus;
  final DateTime? departureMarkedAt;
  /// ساعات إضافية (دقائق) عند "انتهى من العمل"
  final int? overtimeMinutes;
  /// عند "لا يزال يعمل": الوردية/الفريق الذي سيعمل فيه ساعات إضافية
  final String? overtimeTargetEquipeId;
  final String? overtimeTargetEquipeName;
  /// If shift is not completed, optional reason and worked minutes.
  final String? incompleteShiftReason;
  final int? workedMinutesBeforeStop;
  /// سبب الغياب (من الشاف أو الأدمن عند تسجيل غائب)
  final String? absenceReason;
  /// Employe temporarily assigned to another team for this day.
  final bool tempAssigned;
  /// Original team id before temporary assignment.
  final String? originalEquipeId;
  /// Optional shift override code for temporary assignment.
  final String? shiftOverride;
  /// Optional training window start datetime (when admin marks formation).
  final DateTime? trainingStartAt;
  /// Optional training window end datetime (when admin marks formation).
  final DateTime? trainingEndAt;

  PointageRecord({
    required this.id,
    required this.employeId,
    required this.employeNom,
    required this.employeCin,
    required this.equipeId,
    required this.equipeName,
    required this.chefName,
    required this.status,
    required this.date,
    required this.createdAt,
    this.markedById,
    this.markedByName,
    this.driverStatus = DriverPointageStatus.unset,
    this.chefStatus = ChefPointageStatus.unset,
    this.submittedByDriverAt,
    this.submittedByChefAt,
    this.adminFinalStatus,
    this.markedByDriverId,
    this.markedByChefId,
    this.overtimeChefStatus = ChefPointageStatus.unset,
    this.overtimeMarkedByChefId,
    this.overtimeArrivalMarkedAt,
    this.arrivalMarkedAt,
    this.departureStatus = DepartureStatus.unset,
    this.departureMarkedAt,
    this.overtimeMinutes,
    this.overtimeTargetEquipeId,
    this.overtimeTargetEquipeName,
    this.incompleteShiftReason,
    this.workedMinutesBeforeStop,
    this.absenceReason,
    this.tempAssigned = false,
    this.originalEquipeId,
    this.shiftOverride,
    this.trainingStartAt,
    this.trainingEndAt,
  });

  /// السائق لا يستطيع التعديل بعد الإرسال
  bool get driverLocked => submittedByDriverAt != null;
  /// الشاف لا يستطيع التعديل بعد الإرسال
  bool get chefLocked => submittedByChefAt != null;

  /// نتيجة المندقية حسب القواعد. training = في تكويني يُعتبر حاضر.
  ReconciledStatus get reconciledStatus {
    if (adminFinalStatus != null) {
      return (adminFinalStatus == AttendanceStatus.present || adminFinalStatus == AttendanceStatus.training)
          ? ReconciledStatus.confirmedPresent
          : ReconciledStatus.confirmedAbsent;
    }
    // Groupes: validation is done by responsable/admin only (no driver reconciliation).
    final isGroupe = equipeId.startsWith('groupe:');
    final d = driverStatus;
    final c = chefStatus;
    if (isGroupe) {
      if (c == ChefPointageStatus.present) return ReconciledStatus.confirmedPresent;
      if (c == ChefPointageStatus.absent) return ReconciledStatus.confirmedAbsent;
      return ReconciledStatus.pending;
    }
    // Chef decision overrides driver decision (no discrepancy state for chef-vs-driver).
    if (c == ChefPointageStatus.present) return ReconciledStatus.confirmedPresent;
    if (c == ChefPointageStatus.absent) return ReconciledStatus.confirmedAbsent;
    if (d == DriverPointageStatus.unset && c == ChefPointageStatus.unset) {
      return ReconciledStatus.pending;
    }
    if (d == DriverPointageStatus.present && c == ChefPointageStatus.present) {
      return ReconciledStatus.confirmedPresent;
    }
    if (d == DriverPointageStatus.absent && c == ChefPointageStatus.absent) {
      return ReconciledStatus.confirmedAbsent;
    }
    if ((d == DriverPointageStatus.present && c == ChefPointageStatus.absent) ||
        (d == DriverPointageStatus.absent && c == ChefPointageStatus.present)) {
      return ReconciledStatus.discrepancy;
    }
    return ReconciledStatus.pending;
  }

  /// الحضور النهائي المعروض (أدمن > منديقية). training يُعتبر حاضر.
  bool get isFinalPresent {
    if (adminFinalStatus != null) return adminFinalStatus == AttendanceStatus.present || adminFinalStatus == AttendanceStatus.training;
    switch (reconciledStatus) {
      case ReconciledStatus.confirmedPresent:
        return true;
      case ReconciledStatus.confirmedAbsent:
      case ReconciledStatus.discrepancy:
      case ReconciledStatus.pending:
        return false;
    }
  }

  Map<String, dynamic> toMap() => {
    'employeId': employeId,
    'employeNom': employeNom,
    'employeCin': employeCin,
    'equipeId': equipeId,
    'equipeName': equipeName,
    'chefName': chefName,
    'status': status.name,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'markedById': markedById,
    'markedByName': markedByName,
    'driverStatus': driverStatus.name,
    'chefStatus': chefStatus.name,
    'submittedByDriverAt': submittedByDriverAt?.toIso8601String(),
    'submittedByChefAt': submittedByChefAt?.toIso8601String(),
    'adminFinalStatus': adminFinalStatus?.name,
    'markedByDriverId': markedByDriverId,
    'markedByChefId': markedByChefId,
    'overtimeChefStatus': overtimeChefStatus.name,
    'overtimeMarkedByChefId': overtimeMarkedByChefId,
    'overtimeArrivalMarkedAt': overtimeArrivalMarkedAt?.toIso8601String(),
    'arrivalMarkedAt': arrivalMarkedAt?.toIso8601String(),
    'departureStatus': departureStatus.name,
    'departureMarkedAt': departureMarkedAt?.toIso8601String(),
    'overtimeMinutes': overtimeMinutes,
    'overtimeTargetEquipeId': overtimeTargetEquipeId,
    'overtimeTargetEquipeName': overtimeTargetEquipeName,
    'incompleteShiftReason': incompleteShiftReason,
    'workedMinutesBeforeStop': workedMinutesBeforeStop,
    'absenceReason': absenceReason,
    'tempAssigned': tempAssigned,
    'originalEquipeId': originalEquipeId,
    'shiftOverride': shiftOverride,
    'trainingStartAt': trainingStartAt?.toIso8601String(),
    'trainingEndAt': trainingEndAt?.toIso8601String(),
  };

  static DriverPointageStatus _driverFromMap(dynamic v) {
    if (v == null) return DriverPointageStatus.unset;
    return DriverPointageStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => DriverPointageStatus.unset,
    );
  }

  static ChefPointageStatus _chefFromMap(dynamic v) {
    if (v == null) return ChefPointageStatus.unset;
    return ChefPointageStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => ChefPointageStatus.unset,
    );
  }

  static DepartureStatus _departureFromMap(dynamic v) {
    if (v == null) return DepartureStatus.unset;
    return DepartureStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => DepartureStatus.unset,
    );
  }

  factory PointageRecord.fromMap(Map<String, dynamic> map) => PointageRecord(
    id: map['id'] ?? '',
    employeId: map['employeId'] ?? '',
    employeNom: map['employeNom'] ?? '',
    employeCin: map['employeCin'] ?? '',
    equipeId: map['equipeId'] ?? '',
    equipeName: map['equipeName'] ?? '',
    chefName: map['chefName'] ?? '',
    status: AttendanceStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => AttendanceStatus.unmarked,
    ),
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    markedById: map['markedById'],
    markedByName: map['markedByName'],
    driverStatus: _driverFromMap(map['driverStatus']),
    chefStatus: _chefFromMap(map['chefStatus']),
    submittedByDriverAt: map['submittedByDriverAt'] != null ? DateTime.tryParse(map['submittedByDriverAt']) : null,
    submittedByChefAt: map['submittedByChefAt'] != null ? DateTime.tryParse(map['submittedByChefAt']) : null,
    adminFinalStatus: map['adminFinalStatus'] != null
        ? AttendanceStatus.values.firstWhere(
            (e) => e.name == map['adminFinalStatus'],
            orElse: () => AttendanceStatus.unmarked,
          )
        : null,
    markedByDriverId: map['markedByDriverId'],
    markedByChefId: map['markedByChefId'],
    overtimeChefStatus: _chefFromMap(map['overtimeChefStatus']),
    overtimeMarkedByChefId: map['overtimeMarkedByChefId'],
    overtimeArrivalMarkedAt: map['overtimeArrivalMarkedAt'] != null ? DateTime.tryParse(map['overtimeArrivalMarkedAt']) : null,
    arrivalMarkedAt: map['arrivalMarkedAt'] != null ? DateTime.tryParse(map['arrivalMarkedAt']) : null,
    departureStatus: _departureFromMap(map['departureStatus']),
    departureMarkedAt: map['departureMarkedAt'] != null ? DateTime.tryParse(map['departureMarkedAt']) : null,
    overtimeMinutes: map['overtimeMinutes'] is int ? map['overtimeMinutes'] as int : null,
    overtimeTargetEquipeId: map['overtimeTargetEquipeId'] as String?,
    overtimeTargetEquipeName: map['overtimeTargetEquipeName'] as String?,
    incompleteShiftReason: map['incompleteShiftReason'] as String?,
    workedMinutesBeforeStop: map['workedMinutesBeforeStop'] is int ? map['workedMinutesBeforeStop'] as int : null,
    absenceReason: map['absenceReason'] as String?,
    tempAssigned: map['tempAssigned'] as bool? ?? false,
    originalEquipeId: map['originalEquipeId'] as String?,
    shiftOverride: map['shiftOverride'] as String?,
    trainingStartAt: map['trainingStartAt'] != null ? DateTime.tryParse(map['trainingStartAt']) : null,
    trainingEndAt: map['trainingEndAt'] != null ? DateTime.tryParse(map['trainingEndAt']) : null,
  );

  PointageRecord copyWith({
    String? id,
    String? employeId,
    String? employeNom,
    String? employeCin,
    String? equipeId,
    String? equipeName,
    String? chefName,
    AttendanceStatus? status,
    DateTime? date,
    DateTime? createdAt,
    String? markedById,
    String? markedByName,
    DriverPointageStatus? driverStatus,
    ChefPointageStatus? chefStatus,
    DateTime? submittedByDriverAt,
    DateTime? submittedByChefAt,
    AttendanceStatus? adminFinalStatus,
    String? markedByDriverId,
    String? markedByChefId,
    ChefPointageStatus? overtimeChefStatus,
    String? overtimeMarkedByChefId,
    DateTime? overtimeArrivalMarkedAt,
    DateTime? arrivalMarkedAt,
    DepartureStatus? departureStatus,
    DateTime? departureMarkedAt,
    int? overtimeMinutes,
    String? overtimeTargetEquipeId,
    String? overtimeTargetEquipeName,
    String? incompleteShiftReason,
    int? workedMinutesBeforeStop,
    String? absenceReason,
    bool? tempAssigned,
    String? originalEquipeId,
    String? shiftOverride,
    DateTime? trainingStartAt,
    DateTime? trainingEndAt,
  }) => PointageRecord(
    id: id ?? this.id,
    employeId: employeId ?? this.employeId,
    employeNom: employeNom ?? this.employeNom,
    employeCin: employeCin ?? this.employeCin,
    equipeId: equipeId ?? this.equipeId,
    equipeName: equipeName ?? this.equipeName,
    chefName: chefName ?? this.chefName,
    status: status ?? this.status,
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
    markedById: markedById ?? this.markedById,
    markedByName: markedByName ?? this.markedByName,
    driverStatus: driverStatus ?? this.driverStatus,
    chefStatus: chefStatus ?? this.chefStatus,
    submittedByDriverAt: submittedByDriverAt ?? this.submittedByDriverAt,
    submittedByChefAt: submittedByChefAt ?? this.submittedByChefAt,
    adminFinalStatus: adminFinalStatus ?? this.adminFinalStatus,
    markedByDriverId: markedByDriverId ?? this.markedByDriverId,
    markedByChefId: markedByChefId ?? this.markedByChefId,
    overtimeChefStatus: overtimeChefStatus ?? this.overtimeChefStatus,
    overtimeMarkedByChefId: overtimeMarkedByChefId ?? this.overtimeMarkedByChefId,
    overtimeArrivalMarkedAt: overtimeArrivalMarkedAt ?? this.overtimeArrivalMarkedAt,
    arrivalMarkedAt: arrivalMarkedAt ?? this.arrivalMarkedAt,
    departureStatus: departureStatus ?? this.departureStatus,
    departureMarkedAt: departureMarkedAt ?? this.departureMarkedAt,
    overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
    overtimeTargetEquipeId: overtimeTargetEquipeId ?? this.overtimeTargetEquipeId,
    overtimeTargetEquipeName: overtimeTargetEquipeName ?? this.overtimeTargetEquipeName,
    incompleteShiftReason: incompleteShiftReason ?? this.incompleteShiftReason,
    workedMinutesBeforeStop: workedMinutesBeforeStop ?? this.workedMinutesBeforeStop,
    absenceReason: absenceReason ?? this.absenceReason,
    tempAssigned: tempAssigned ?? this.tempAssigned,
    originalEquipeId: originalEquipeId ?? this.originalEquipeId,
    shiftOverride: shiftOverride ?? this.shiftOverride,
    trainingStartAt: trainingStartAt ?? this.trainingStartAt,
    trainingEndAt: trainingEndAt ?? this.trainingEndAt,
  );
}

class DailyReport {
  final String id;
  final DateTime date;
  final String equipeId;
  final String equipeName;
  final String chefId;
  final String chefName;
  final int totalEmployees;
  final int presentCount;
  final int absentCount;
  final int notInVehicleCount;
  final DateTime submittedAt;
  final String? notes;

  DailyReport({
    required this.id,
    required this.date,
    required this.equipeId,
    required this.equipeName,
    required this.chefId,
    required this.chefName,
    required this.totalEmployees,
    required this.presentCount,
    required this.absentCount,
    required this.notInVehicleCount,
    required this.submittedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'equipeId': equipeId,
    'equipeName': equipeName,
    'chefId': chefId,
    'chefName': chefName,
    'totalEmployees': totalEmployees,
    'presentCount': presentCount,
    'absentCount': absentCount,
    'notInVehicleCount': notInVehicleCount,
    'submittedAt': submittedAt.toIso8601String(),
    'notes': notes,
  };

  factory DailyReport.fromMap(Map<String, dynamic> map) => DailyReport(
    id: map['id'] ?? '',
    date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    equipeId: map['equipeId'] ?? '',
    equipeName: map['equipeName'] ?? '',
    chefId: map['chefId'] ?? '',
    chefName: map['chefName'] ?? '',
    totalEmployees: map['totalEmployees'] ?? 0,
    presentCount: map['presentCount'] ?? 0,
    absentCount: map['absentCount'] ?? 0,
    notInVehicleCount: map['notInVehicleCount'] ?? 0,
    submittedAt: DateTime.tryParse(map['submittedAt'] ?? '') ?? DateTime.now(),
    notes: map['notes'],
  );
}
