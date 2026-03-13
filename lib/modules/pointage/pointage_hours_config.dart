import '../employees/models/equipe_model.dart';

/// إعداد ساعات البوانتاج (دخول/خروج) — إما افتراضي أو مخصص للفريق
class PointageHoursConfig {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int departureEarliestHour;
  final int departureEarliestMinute;
  final int departureLatestHour;
  final int departureLatestMinute;

  const PointageHoursConfig({
    this.startHour = 6,
    this.startMinute = 0,
    this.endHour = 22,
    this.endMinute = 0,
    this.departureEarliestHour = 14,
    this.departureEarliestMinute = 0,
    this.departureLatestHour = 23,
    this.departureLatestMinute = 0,
  });

  static const PointageHoursConfig instance = PointageHoursConfig();

  /// يمكن تسجيل الدخول الآن؟
  bool canMarkArrivalNow(DateTime now) {
    final t = now.hour * 60 + now.minute;
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return t >= start && t <= end;
  }

  /// يمكن تسجيل الخروج الآن؟
  bool canMarkDepartureNow(DateTime now) {
    final t = now.hour * 60 + now.minute;
    final earliest = departureEarliestHour * 60 + departureEarliestMinute;
    final latest = departureLatestHour * 60 + departureLatestMinute;
    return t >= earliest && t <= latest;
  }

  /// هل الوقت الحالي ضمن نافذة الدخول (وليس نافذة الخروج فقط)؟
  bool isWithinArrivalWindow(DateTime now) => canMarkArrivalNow(now);

  /// وردية ليلية (بداية الوردية بعد 22:00 تقريباً)
  bool get isNightShift => startHour >= 22;

  /// وقت البداية منسّق (مثلاً "06:00")
  String startTimeFormatted() {
    return '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  }

  /// وقت النهاية منسّق (مثلاً "22:00")
  String endTimeFormatted() {
    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  /// نافذة الخروج منسّقة (مثلاً "14:00 - 23:00")
  String departureWindowFormatted() {
    final earliest = '${departureEarliestHour.toString().padLeft(2, '0')}:${departureEarliestMinute.toString().padLeft(2, '0')}';
    final latest = '${departureLatestHour.toString().padLeft(2, '0')}:${departureLatestMinute.toString().padLeft(2, '0')}';
    return '$earliest - $latest';
  }

  /// نافذة الدخول منسّقة للنص (مثلاً "06:00 - 22:00")
  String arrivalWindowFormatted() {
    final start = '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
    final end = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}

/// حالة نافذة البوانتاج: مفتوحة | لم تُفتح بعد | مغلقة
enum PointageHoursStatus { open, notYetOpen, closed }

/// تاريخ البوانتاج الفعلي (قد يكون اليوم أو اليوم السابق لوردية ليلية)
DateTime getPointageDateForConfig(PointageHoursConfig config, DateTime now) {
  final t = now.hour * 60 + now.minute;
  final start = config.startHour * 60 + config.startMinute;
  // إذا كان قبل منتصف الليل وبعد منتصف الليل نعتبره اليوم السابق للوردية الليلية
  if (t < 12 && start >= 22) {
    return DateTime(now.year, now.month, now.day - 1);
  }
  return DateTime(now.year, now.month, now.day);
}

PointageHoursStatus getPointageHoursStatus(DateTime now, PointageHoursConfig config) {
  if (config.canMarkArrivalNow(now) || config.canMarkDepartureNow(now)) return PointageHoursStatus.open;
  final t = now.hour * 60 + now.minute;
  final start = config.startHour * 60 + config.startMinute;
  if (t < start) return PointageHoursStatus.notYetOpen;
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
      departureEarliestHour: (equipe.pointageStartHour! + 8).clamp(0, 23),
      departureEarliestMinute: equipe.pointageStartMinute ?? 0,
      departureLatestHour: 23,
      departureLatestMinute: 59,
    );
  }
  return PointageHoursConfig.instance;
}
