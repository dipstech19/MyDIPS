import '../employees/models/equipe_model.dart';
import '../shifts/models/shift_models.dart';

/// أوقات فتح وإقفال البوانتاج: لا يمكن التسجيل خارج هذا النافذة.
/// بعد وقت الإقفال يُعتبر من لم يسجّل غائباً.
class PointageHoursConfig {
  PointageHoursConfig({
    this.startHour = 6,
    this.startMinute = 0,
    this.endHour = 10,
    this.endMinute = 0,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  static PointageHoursConfig get instance => _instance ??= PointageHoursConfig();
  static PointageHoursConfig? _instance;

  int get _startMinutes => startHour * 60 + startMinute;
  int get _endMinutes => endHour * 60 + endMinute;
  /// نافذة الوصول: من بداية العمل حتى بداية العمل + 1 ساعة
  int get _arrivalEndMinutes => _startMinutes + 60;
  /// نافذة الخروج: من نهاية العمل حتى نهاية العمل + 1 ساعة
  int get _departureStartMinutes => _endMinutes;
  int get _departureEndMinutes => _endMinutes + 60;

  static int _minutesOfDay(DateTime d) => d.hour * 60 + d.minute;

  /// نافذة نقطاج الوصول (من بداية العمل إلى بداية + 1 ساعة)
  bool isWithinArrivalWindow(DateTime now) {
    final m = _minutesOfDay(now);
    return m >= _startMinutes && m < _arrivalEndMinutes;
  }

  /// نافذة نقطاج الخروج (من نهاية العمل إلى نهاية + 1 ساعة)
  bool isWithinDepartureWindow(DateTime now) {
    final m = _minutesOfDay(now);
    return m >= _departureStartMinutes && m < _departureEndMinutes;
  }

  /// هل يمكن تسجيل الحضور (وصل) الآن؟
  bool canMarkArrivalNow(DateTime now) => isWithinArrivalWindow(now);

  /// هل يمكن تسجيل الخروج (لا يزال يعمل / انتهى) الآن؟
  bool canMarkDepartureNow(DateTime now) => isWithinDepartureWindow(now);

  /// هل الوقت الحالي ضمن أي نافذة (وصل أو خروج)؟
  bool isWithinHours(DateTime now) =>
      isWithinArrivalWindow(now) || isWithinDepartureWindow(now);

  bool isBeforeOpening(DateTime now) =>
      _minutesOfDay(now) < _startMinutes && _minutesOfDay(now) < _departureStartMinutes;

  bool isAfterCutoff(DateTime now) =>
      _minutesOfDay(now) >= _departureEndMinutes ||
      (_minutesOfDay(now) >= _arrivalEndMinutes && _minutesOfDay(now) < _departureStartMinutes);

  bool canMarkOrSubmitNow(DateTime now) => isWithinHours(now);

  String startTimeFormatted() => '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String endTimeFormatted() => '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  String arrivalWindowFormatted() => '${startTimeFormatted()} — ${((_arrivalEndMinutes ~/ 60) % 24).toString().padLeft(2, '0')}:${(_arrivalEndMinutes % 60).toString().padLeft(2, '0')}';
  String departureWindowFormatted() => '${endTimeFormatted()} — ${((_departureEndMinutes ~/ 60) % 24).toString().padLeft(2, '0')}:${(_departureEndMinutes % 60).toString().padLeft(2, '0')}';

  /// وردية ليلية (22→06): التقرير يُربط بيوم الدخول وليس يوم الخروج.
  bool get isNightShift => startHour == 22 && endHour == 6;
}

/// تاريخ البوانتاج لاستخدامه في الحفظ والتقارير: لوردية الليل قبل 07:00 = يوم الدخول (أمس).
DateTime getPointageDateForConfig(PointageHoursConfig config, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (config.isNightShift && now.hour < 7) {
    return today.subtract(const Duration(days: 1));
  }
  return today;
}

/// إرجاع إعداد الساعات لفريق: إن وُجدت ساعات مخصّصة للفريق تُستخدم، وإلا الإعداد العام.
PointageHoursConfig getConfigForEquipe(Equipe? equipe) {
  if (equipe == null) return PointageHoursConfig.instance;
  final sh = equipe.pointageStartHour;
  final sm = equipe.pointageStartMinute;
  final eh = equipe.pointageEndHour;
  final em = equipe.pointageEndMinute;
  if (sh != null && eh != null) {
    return PointageHoursConfig(
      startHour: sh,
      startMinute: sm ?? 0,
      endHour: eh,
      endMinute: em ?? 0,
    );
  }
  return PointageHoursConfig.instance;
}

/// إرجاع إعداد الساعات لفريق في تاريخ معيّن: إن وُجدت وردية (صباحية/مسائية/ليلية) تُستخدم أوقاتها الفعلية، وإلا إعداد الفريق أو العام.
PointageHoursConfig getConfigForEquipeAndDate(Equipe? equipe, DateTime date, ShiftType? shift) {
  if (shift == ShiftType.morning) {
    return PointageHoursConfig(startHour: 6, startMinute: 0, endHour: 14, endMinute: 0);
  }
  if (shift == ShiftType.evening) {
    return PointageHoursConfig(startHour: 14, startMinute: 0, endHour: 22, endMinute: 0);
  }
  if (shift == ShiftType.night) {
    return PointageHoursConfig(startHour: 22, startMinute: 0, endHour: 6, endMinute: 0);
  }
  return getConfigForEquipe(equipe);
}

enum PointageHoursStatus {
  open,
  notYetOpen,
  closed,
}

PointageHoursStatus getPointageHoursStatus(DateTime now, [PointageHoursConfig? config]) {
  final c = config ?? PointageHoursConfig.instance;
  if (c.isWithinArrivalWindow(now) || c.isWithinDepartureWindow(now)) return PointageHoursStatus.open;
  if (c.isAfterCutoff(now)) return PointageHoursStatus.closed;
  return PointageHoursStatus.notYetOpen;
}
