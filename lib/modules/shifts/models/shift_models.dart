/// نوع الوردية: صباحية | مسائية | ليلية | راحة
enum ShiftType {
  morning,   // 06→14
  evening,   // 14→22
  night,     // 22→06
  rest,
}

/// إعداد التناوب: تاريخ البداية + ربط 4 فرق بمواقع التناوب (1..4) + تعديلات يدوية لكل يوم.
class RotationConfig {
  final DateTime startDate;
  /// ترتيب معرفات الفرق: [فريق الموضع 1, فريق الموضع 2, فريق الموضع 3, فريق الموضع 4]
  final List<String> equipeIds;
  /// تعديلات يدوية: [ "yyyy-MM-dd" -> { equipeId -> "morning"|"evening"|"night"|"rest" } ]
  final Map<String, Map<String, String>> overrides;

  const RotationConfig({
    required this.startDate,
    required this.equipeIds,
    this.overrides = const {},
  }) : assert(equipeIds.length == 4, 'يجب أن يكون هناك 4 فرق بالضبط');

  DateTime get startDay => DateTime(startDate.year, startDate.month, startDate.day);

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'startDate': startDay.toIso8601String(),
      'equipeIds': equipeIds,
    };
    if (overrides.isNotEmpty) {
      m['overrides'] = overrides;
    }
    return m;
  }

  static RotationConfig? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final start = map['startDate'];
    final ids = map['equipeIds'];
    if (start == null || ids is! List || ids.length != 4) return null;
    final startDate = DateTime.tryParse(start.toString());
    if (startDate == null) return null;
    final equipeIds = ids.map((e) => e.toString()).toList();
    Map<String, Map<String, String>> overrides = {};
    final ov = map['overrides'];
    if (ov is Map) {
      for (final e in ov.entries) {
        final k = e.key?.toString();
        final v = e.value;
        if (k == null) continue;
        if (v is Map) {
          overrides[k] = v.map((k2, v2) => MapEntry(k2.toString(), v2.toString()));
        }
      }
    }
    return RotationConfig(startDate: startDate, equipeIds: equipeIds, overrides: overrides);
  }

  RotationConfig copyWithOverrides(Map<String, Map<String, String>> newOverrides) {
    return RotationConfig(startDate: startDate, equipeIds: equipeIds, overrides: Map.from(newOverrides));
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
  /// نظام التناوب: الأولى→شيفت ثانية، الثانية→ثالثة، الثالثة→روبور، الرابعة→شيفت أولى (كل يومين).
  /// يوم1-2: م،س،ن،ر | يوم3-4: س،ن،ر،م | يوم5-6: ن،ر،م،س | يوم7-8: ر،م،س،ن
  static ShiftType shiftForPosition(int position, int dayInCycle) {
    const blockShifts = [
      [ShiftType.morning, ShiftType.evening, ShiftType.night, ShiftType.rest],   // days 0,1
      [ShiftType.evening, ShiftType.night, ShiftType.rest, ShiftType.morning],   // days 2,3
      [ShiftType.night, ShiftType.rest, ShiftType.morning, ShiftType.evening],   // days 4,5
      [ShiftType.rest, ShiftType.morning, ShiftType.evening, ShiftType.night],   // days 6,7
    ];
    final block = blockIndex(dayInCycle).clamp(0, 3);
    return blockShifts[block][position.clamp(0, 3)];
  }

  /// وردية فريق معيّن في تاريخ معيّن (مع إعداد التناوب). يُرجع null إذا الفريق غير موجود في الإعداد.
  /// إن وُجدت تعديلات يدوية لهذا اليوم والفريق تُستخدم، وإلا التناوب التلقائي.
  /// إذا كان اليوم أول الشهر والفريق كان في وردية ليلية اليوم السابق، تُحسب الوردية استمراراً (ليلية).
  static ShiftType? shiftForEquipe(RotationConfig config, String equipeId, DateTime date) {
    final dateKey = _dateKey(date);
    final dayOverrides = config.overrides[dateKey];
    if (dayOverrides != null && dayOverrides.containsKey(equipeId)) {
      return _parseShiftType(dayOverrides[equipeId]!);
    }
    final d = DateTime(date.year, date.month, date.day);
    if (d.day == 1) {
      final prev = d.subtract(const Duration(days: 1));
      final prevShift = _shiftForEquipeBase(config, equipeId, prev);
      if (prevShift == ShiftType.night) return ShiftType.night;
    }
    return _shiftForEquipeBase(config, equipeId, date);
  }

  /// وردية الفريق بدون قاعدة "استمرار الليل" (للاستخدام الداخلي).
  static ShiftType? _shiftForEquipeBase(RotationConfig config, String equipeId, DateTime date) {
    final dateKey = _dateKey(date);
    final dayOverrides = config.overrides[dateKey];
    if (dayOverrides != null && dayOverrides.containsKey(equipeId)) {
      return _parseShiftType(dayOverrides[equipeId]!);
    }
    final day = dayInCycle(config.startDay, date);
    final idx = config.equipeIds.indexOf(equipeId);
    if (idx < 0) return null;
    return shiftForPosition(idx, day);
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String shiftToKey(ShiftType s) {
    switch (s) {
      case ShiftType.morning: return 'morning';
      case ShiftType.evening: return 'evening';
      case ShiftType.night: return 'night';
      case ShiftType.rest: return 'rest';
    }
  }

  static ShiftType? _parseShiftType(String key) {
    switch (key) {
      case 'morning': return ShiftType.morning;
      case 'evening': return ShiftType.evening;
      case 'night': return ShiftType.night;
      case 'rest': return ShiftType.rest;
      default: return null;
    }
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

  /// Heure de fin de la shift pour le jour [date]. Nuit: fin à 06:00 le lendemain.
  DateTime? getShiftEnd(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    switch (this) {
      case ShiftType.morning:
        return d.add(const Duration(hours: 14));
      case ShiftType.evening:
        return d.add(const Duration(hours: 22));
      case ShiftType.night:
        return d.add(const Duration(days: 1, hours: 6));
      case ShiftType.rest:
        return null;
    }
  }
}
