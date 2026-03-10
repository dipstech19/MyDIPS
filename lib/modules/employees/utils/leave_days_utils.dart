/// حساب أيام الإجازة المستحقة من تاريخ البدء (Date début).
/// القاعدة الحالية: كل شهر كامل = 1.5 يوم إجازة.

/// يحوّل نص التاريخ إلى [DateTime] إن أمكن.
/// يدعم: yyyy-MM-dd و dd/MM/yyyy و dd-MM-yyyy
DateTime? parseDateDebut(String dateDebut) {
  if (dateDebut.trim().isEmpty) return null;
  final s = dateDebut.trim();
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final parts = s.split(RegExp(r'[/\-.]'));
  if (parts.length == 3) {
    int? day, month, year;
    if (parts[0].length == 4) {
      year = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      day = int.tryParse(parts[2]);
    } else {
      day = int.tryParse(parts[0]);
      month = int.tryParse(parts[1]);
      year = int.tryParse(parts[2]);
    }
    if (year != null && month != null && day != null &&
        month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day);
    }
  }
  return null;
}

/// عدد الأشهر الكاملة بين [start] و [end] (من بداية يوم start إلى نهاية يوم end).
/// مثال: من 15 جانفي إلى 14 فيفري = شهر واحد.
int fullMonthsBetween(DateTime start, DateTime end) {
  final d = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  if (d.isAfter(e)) return 0;
  int months = (e.year - d.year) * 12 + (e.month - d.month);
  if (e.day < d.day) months--;
  return months < 0 ? 0 : months;
}

/// أيام الإجازة المستحقة حتى اليوم، انطلاقاً من [dateDebut].
/// القاعدة: 1.5 يوم لكل شهر كامل منذ تاريخ البدء.
double leaveDaysAcquired(String dateDebut) {
  final start = parseDateDebut(dateDebut);
  if (start == null) return 0;
  final now = DateTime.now();
  final months = fullMonthsBetween(start, now);
  return months * 1.5;
}
