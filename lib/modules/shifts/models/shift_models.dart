/// نوع الوردية: صباحية | مسائية | ليلية | راحة
enum ShiftType {
  morning,   // 06→14
  evening,   // 14→22
  night,     // 22→06
  rest,
}

/// إعداد التناوب: تاريخ البداية + ربط 4 فرق بمواقع التناوب (1..4)
class RotationConfig {
  final DateTime startDate;
  /// ترتيب معرفات الفرق: [فريق الموضع 1, فريق الموضع 2, فريق الموضع 3, فريق الموضع 4]
  final List<String> equipeIds;

  const RotationConfig({
    required this.startDate,
    required this.equipeIds,
  }) : assert(equipeIds.length == 4, 'يجب أن يكون هناك 4 فرق بالضبط');

  DateTime get startDay => DateTime(startDate.year, startDate.month, startDate.day);

  Map<String, dynamic> toMap() => {
    'startDate': startDay.toIso8601String(),
    'equipeIds': equipeIds,
  };

  static RotationConfig? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final start = map['startDate'];
    final ids = map['equipeIds'];
    if (start == null || ids is! List || ids.length != 4) return null;
    final startDate = DateTime.tryParse(start.toString());
    if (startDate == null) return null;
    final equipeIds = ids.map((e) => e.toString()).toList();
    return RotationConfig(startDate: startDate, equipeIds: equipeIds);
  }
}

/// منطق الدورة: كل 8 أيام، كل يومين كتلة. المواقع 0..3 = الفرق 1..4.
class ShiftRotationLogic {
  /// يوم في الدورة 0..7 من تاريخ البداية
  static int dayInCycle(DateTime startDay, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDay.year, startDay.month, startDay.day);
    final diff = d.difference(s).inDays;
    if (diff < 0) return 0;
    return diff % 8;
  }

  /// الكتلة 0..3 حسب اليوم في الدورة (0,1→0 ; 2,3→1 ; 4,5→2 ; 6,7→3)
  static int blockIndex(int dayInCycle) => dayInCycle ~/ 2;

  /// الوردية للموضع position (0=فريق1, 1=فريق2, 2=فريق3, 3=فريق4) في يوم الدورة dayInCycle (0..7)
  /// الدورة: يوم1-2: صباحية،مسائية،ليلية،راحة | يوم3-4: راحة،صباحية،مسائية،ليلية | يوم5-6: ليلية،راحة،صباحية،مسائية | يوم7-8: مسائية،ليلية،راحة،صباحية
  static ShiftType shiftForPosition(int position, int dayInCycle) {
    const blockShifts = [
      [ShiftType.morning, ShiftType.evening, ShiftType.night, ShiftType.rest],   // days 0,1
      [ShiftType.rest, ShiftType.morning, ShiftType.evening, ShiftType.night],   // days 2,3
      [ShiftType.night, ShiftType.rest, ShiftType.morning, ShiftType.evening],   // days 4,5
      [ShiftType.evening, ShiftType.night, ShiftType.rest, ShiftType.morning],   // days 6,7
    ];
    final block = blockIndex(dayInCycle).clamp(0, 3);
    return blockShifts[block][position.clamp(0, 3)];
  }

  /// وردية فريق معيّن في تاريخ معيّن (مع إعداد التناوب). يُرجع null إذا الفريق غير موجود في الإعداد.
  static ShiftType? shiftForEquipe(RotationConfig config, String equipeId, DateTime date) {
    final day = dayInCycle(config.startDay, date);
    final idx = config.equipeIds.indexOf(equipeId);
    if (idx < 0) return null;
    return shiftForPosition(idx, day);
  }
}

/// تسميات ووقت كل وردية (للعرض)
extension ShiftTypeDisplay on ShiftType {
  String get timeRange {
    switch (this) {
      case ShiftType.morning: return '06:00 → 14:00';
      case ShiftType.evening: return '14:00 → 22:00';
      case ShiftType.night: return '22:00 → 06:00';
      case ShiftType.rest: return '—';
    }
  }

  String get shortLabel {
    switch (this) {
      case ShiftType.morning: return '06→14';
      case ShiftType.evening: return '14→22';
      case ShiftType.night: return '22→06';
      case ShiftType.rest: return 'راحة';
    }
  }
}
