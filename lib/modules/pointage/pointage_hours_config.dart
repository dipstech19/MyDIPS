import '../employees/models/equipe_model.dart';
import '../shifts/models/shift_models.dart';

/// فتح النافذة قبل بداية الشيفت / نهايته بـ 30 دقيقة؛ الإغلاق بعد ساعتين من البداية / النهاية.
const Duration kPointageWindowOpenBefore = Duration(minutes: 30);
/// مدة نافذة تأكيد الدخول بعد بداية الشيفت، ونافذة تأكيد الخروج بعد نهايته.
const Duration kPointageArrivalWindow = Duration(hours: 2);
const Duration kPointageDepartureWindow = Duration(hours: 2);

/// إعداد ساعات البوانتاج (دخول/خروج) — من الشيفت أو مخصص للفريق
class PointageHoursConfig {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int departureEarliestHour;
  final int departureEarliestMinute;
  final int departureLatestHour;
  final int departureLatestMinute;
  /// يوم راحة (rotation) — لا بوانتاج
  final bool isRestDay;

  const PointageHoursConfig({
    this.startHour = 6,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    this.departureEarliestHour = 14,
    this.departureEarliestMinute = 0,
    this.departureLatestHour = 23,
    this.departureLatestMinute = 59,
    this.isRestDay = false,
  });

  int get _startMinutes => startHour * 60 + startMinute;
  int get _endMinutes => endHour * 60 + endMinute;
  /// نافذة الوصول: من بداية العمل حتى بداية العمل + 1 ساعة
  int get _arrivalEndMinutes => _startMinutes + 60;
  /// نافذة الخروج: من نهاية العمل حتى نهاية العمل + 1 ساعة
  int get _departureStartMinutes => _endMinutes;
  int get _departureEndMinutes => _endMinutes + 60;

  /// وردية ليلية (نفس اليوم → اليوم التالي)
  bool get isNightShift => _isOvernight(this);

  bool _inWindow(DateTime now, DateTime windowStart, DateTime windowEnd,
      {Duration graceBefore = Duration.zero, Duration graceAfter = Duration.zero}) {
    final a = windowStart.subtract(graceBefore);
    final b = windowEnd.add(graceAfter);
    return !now.isBefore(a) && now.isBefore(b);
  }

  /// نافذة الدخول: من (بداية الشيفت − 30 د) حتى بداية الشيفت + ساعتان.
  bool canMarkArrivalNow(DateTime now,
      {Duration graceBefore = Duration.zero,
      Duration graceAfter = Duration.zero}) {
    if (isRestDay) return false;
    final day = getPointageDateForConfig(this, now);
    final start = _shiftStartDateTime(this, day);
    final end = start.add(kPointageArrivalWindow);
    return _inWindow(now, start, end,
        graceBefore: graceBefore + kPointageWindowOpenBefore, graceAfter: graceAfter);
  }

  /// نافذة الخروج: من (نهاية الشيفت − 30 د) حتى نهاية الشيفت + ساعتان.
  bool canMarkDepartureNow(DateTime now,
      {Duration graceBefore = Duration.zero,
      Duration graceAfter = Duration.zero}) {
    if (isRestDay) return false;
    final day = getPointageDateForConfig(this, now);
    final shiftEnd = _shiftEndDateTime(this, day);
    final end = shiftEnd.add(kPointageDepartureWindow);
    return _inWindow(now, shiftEnd, end,
        graceBefore: graceBefore + kPointageWindowOpenBefore, graceAfter: graceAfter);
  }

  /// Instant de fin de shift pour un [logicalDay] affiché (admin / rapports).
  DateTime shiftEndMomentOn(DateTime logicalDay) {
    if (isRestDay) {
      return DateTime(logicalDay.year, logicalDay.month, logicalDay.day);
    }
    return _shiftEndDateTime(this, logicalDay);
  }

  /// Confirmation admin (Directeur / Chef d'atelier) : **uniquement après** la fin du shift
  /// pour le jour [logicalDay] — pas pendant la fenêtre « départ » (−30 min) réservée au pointage.
  /// Après cette heure, la confirmation reste possible sans limite supérieure (réglage côté appel pour le « jour J »).
  bool canAdminConfirmAfterShiftEnd(DateTime now, DateTime logicalDay) {
    if (isRestDay) return false;
    final end = shiftEndMomentOn(logicalDay);
    return !now.isBefore(end);
  }

  /// Libellé court pour l'heure de fin de shift (ex. pour message admin).
  String shiftEndFormattedOn(DateTime logicalDay) {
    if (isRestDay) return '—';
    final end = shiftEndMomentOn(logicalDay);
    return _fmt(end);
  }

  /// إرسال التقرير (شاف / سائق): نفس [نافذة تأكيد الخروج] — من نهاية الشيفت حتى نهاية الشيفت + ساعتان، ثم يُقفل.
  bool canSubmitReportNow(DateTime now,
      {Duration graceBefore = Duration.zero,
      Duration graceAfter = Duration.zero}) {
    return canMarkDepartureNow(now, graceBefore: graceBefore, graceAfter: graceAfter);
  }

  /// ساعات إضافية / renfort: نافذة الدخول أو نافذة الخروج فقط.
  bool canMarkOvertimeRelatedNow(DateTime now,
      {Duration graceBefore = Duration.zero,
      Duration graceAfter = Duration.zero}) {
    return canMarkDepartureNow(now, graceBefore: graceBefore, graceAfter: graceAfter) ||
        canMarkArrivalNow(now, graceBefore: graceBefore, graceAfter: graceAfter);
  }

  bool isWithinArrivalWindow(DateTime now) => canMarkArrivalNow(now);

  bool isWithinDepartureWindow(DateTime now) => canMarkDepartureNow(now);

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// وقت البداية منسّق (مثلاً "06:00")
  String startTimeFormatted() {
    return '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  }

  /// وقت النهاية منسّق (مثلاً "14:00")
  String endTimeFormatted() {
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  /// نافذة تأكيد الدخول (−30 د من البداية → +2 س من البداية)
  String arrivalWindowFormatted([DateTime? referenceNow]) {
    if (isRestDay) return '—';
    final now = referenceNow ?? DateTime.now();
    final day = getPointageDateForConfig(this, now);
    final start = _shiftStartDateTime(this, day);
    final winStart = start.subtract(kPointageWindowOpenBefore);
    final winEnd = start.add(kPointageArrivalWindow);
    return '${_fmt(winStart)} – ${_fmt(winEnd)}';
  }

  /// نافذة تأكيد الخروج (−30 د من النهاية → +2 س من النهاية)
  String departureWindowFormatted([DateTime? referenceNow]) {
    if (isRestDay) return '—';
    final now = referenceNow ?? DateTime.now();
    final day = getPointageDateForConfig(this, now);
    final shiftEnd = _shiftEndDateTime(this, day);
    final winStart = shiftEnd.subtract(kPointageWindowOpenBefore);
    final winEnd = shiftEnd.add(kPointageDepartureWindow);
    return '${_fmt(winStart)} – ${_fmt(winEnd)}';
  }

  DateTime arrivalWindowStartOn(DateTime logicalDay) {
    return _shiftStartDateTime(this, logicalDay).subtract(kPointageWindowOpenBefore);
  }

  DateTime departureWindowStartOn(DateTime logicalDay) {
    return shiftEndMomentOn(logicalDay).subtract(kPointageWindowOpenBefore);
  }

  DateTime departureWindowEndOn(DateTime logicalDay) {
    return shiftEndMomentOn(logicalDay).add(kPointageDepartureWindow);
  }
}

bool _isOvernight(PointageHoursConfig c) {
  final s = c.startHour * 60 + c.startMinute;
  final e = c.endHour * 60 + c.endMinute;
  return s >= e;
}

DateTime _shiftStartDateTime(PointageHoursConfig c, DateTime logicalDay) {
  return DateTime(logicalDay.year, logicalDay.month, logicalDay.day, c.startHour, c.startMinute);
}

DateTime _shiftEndDateTime(PointageHoursConfig c, DateTime logicalDay) {
  if (_isOvernight(c)) {
    return DateTime(logicalDay.year, logicalDay.month, logicalDay.day + 1, c.endHour, c.endMinute);
  }
  return DateTime(logicalDay.year, logicalDay.month, logicalDay.day, c.endHour, c.endMinute);
}

/// تاريخ البوانتاج لاستخدامه في الحفظ والتقارير: لوردية الليل قبل 07:00 = يوم الدخول (أمس).
DateTime getPointageDateForConfig(PointageHoursConfig config, DateTime now) {
  final startM = config.startHour * 60 + config.startMinute;
  final endM = config.endHour * 60 + config.endMinute;
  final overnight = startM >= endM;
  if (!overnight) {
    return DateTime(now.year, now.month, now.day);
  }
  final t = now.hour * 60 + now.minute;
  if (t < 12 * 60) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

PointageHoursStatus getPointageHoursStatus(DateTime now, PointageHoursConfig config) {
  if (config.isRestDay) return PointageHoursStatus.closed;
  if (config.canMarkArrivalNow(now) || config.canMarkDepartureNow(now)) {
    return PointageHoursStatus.open;
  }
  final day = getPointageDateForConfig(config, now);
  final shiftStart = _shiftStartDateTime(config, day);
  if (now.isBefore(shiftStart)) return PointageHoursStatus.notYetOpen;
  return PointageHoursStatus.closed;
}

/// يُرجع إعداد الساعات للفريق والتاريخ والوردية (إن وُجدت)
PointageHoursConfig getConfigForEquipeAndDate(Equipe? equipe, DateTime date, dynamic shiftForEquipe) {
  if (equipe != null && equipe.pointageStartHour != null && equipe.pointageEndHour != null) {
    return PointageHoursConfig(
      startHour: equipe.pointageStartHour!,
      startMinute: equipe.pointageStartMinute ?? 0,
      endHour: equipe.pointageEndHour!,
      endMinute: equipe.pointageEndMinute ?? 0,
      departureEarliestHour: equipe.pointageEndHour!.clamp(0, 23),
      departureEarliestMinute: equipe.pointageEndMinute ?? 0,
      departureLatestHour: (equipe.pointageEndHour! + 2).clamp(0, 23),
      departureLatestMinute: equipe.pointageEndMinute ?? 0,
    );
  }
  if (shiftForEquipe is ShiftType) {
    switch (shiftForEquipe) {
      case ShiftType.rest:
        return const PointageHoursConfig(
          startHour: 0,
          startMinute: 0,
          endHour: 0,
          endMinute: 0,
          departureEarliestHour: 0,
          departureEarliestMinute: 0,
          departureLatestHour: 0,
          departureLatestMinute: 0,
          isRestDay: true,
        );
      case ShiftType.morning:
        return const PointageHoursConfig(
          startHour: 6,
          startMinute: 0,
          endHour: 14,
          endMinute: 0,
          departureEarliestHour: 14,
          departureEarliestMinute: 0,
          departureLatestHour: 16,
          departureLatestMinute: 0,
        );
      case ShiftType.evening:
        return const PointageHoursConfig(
          startHour: 14,
          startMinute: 0,
          endHour: 22,
          endMinute: 0,
          departureEarliestHour: 22,
          departureEarliestMinute: 0,
          departureLatestHour: 23,
          departureLatestMinute: 59,
        );
      case ShiftType.night:
        return const PointageHoursConfig(
          startHour: 22,
          startMinute: 0,
          endHour: 6,
          endMinute: 0,
          departureEarliestHour: 6,
          departureEarliestMinute: 0,
          departureLatestHour: 8,
          departureLatestMinute: 0,
        );
    }
  }
  return const PointageHoursConfig();
}

enum PointageHoursStatus {
  open,
  notYetOpen,
  closed,
}

