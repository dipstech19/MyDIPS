enum ShiftType { morning, evening, night, rest }

/// Représente un jour de travail doublé (×2) — jour férié travaillé ou jour exceptionnel.
class DoubleDay {
  final DateTime date;
  final String? label; // e.g. "Fête du travail", "Aïd", etc.

  DoubleDay({required this.date, this.label});

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'label': label ?? '',
      };

  static DoubleDay fromMap(Map<String, dynamic> map) {
    final raw = map['date'] as String? ?? '';
    final parts = raw.split('-');
    final dt = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1)
        : DateTime.now();
    return DoubleDay(date: DateTime(dt.year, dt.month, dt.day), label: map['label'] as String?);
  }
}

/// Jour férié (sans travail) — export Excel OCP « Hors équipe » : marqueur **JF**.
class PublicHoliday {
  final DateTime date;
  final String? label;

  PublicHoliday({required this.date, this.label});

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'date': dateKey,
        'label': label ?? '',
      };

  static PublicHoliday fromMap(Map<String, dynamic> map) {
    final raw = map['date'] as String? ?? '';
    final parts = raw.split('-');
    final dt = parts.length == 3
        ? DateTime(int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1)
        : DateTime.now();
    return PublicHoliday(date: DateTime(dt.year, dt.month, dt.day), label: map['label'] as String?);
  }
}

extension ShiftTypeExt on ShiftType {
  String get shortLabel {
    switch (this) {
      case ShiftType.morning:
        return 'P1';
      case ShiftType.evening:
        return 'P2';
      case ShiftType.night:
        return 'P3';
      case ShiftType.rest:
        return 'P4';
    }
  }

  String get timeRange {
    switch (this) {
      case ShiftType.morning:
        return '06:00–14:00';
      case ShiftType.evening:
        return '14:00–22:00';
      case ShiftType.night:
        return '22:00–06:00';
      case ShiftType.rest:
        return '—';
    }
  }

}

class RotationConfig {
  final DateTime startDate;
  final List<String> equipeIds;

  /// Journée du poste au [startDate] : 1 = premier jour du poste, 2 = deuxième jour.
  /// Chaque poste dure deux jours de suite : si la rotation démarre le 2e jour,
  /// le cycle est décalé d'un jour.
  final int startJournee;

  RotationConfig({
    required this.startDate,
    required this.equipeIds,
    int startJournee = 1,
  }) : startJournee = startJournee == 2 ? 2 : 1;

  DateTime get startDay => DateTime(startDate.year, startDate.month, startDate.day);

  /// Décalage à ajouter au nombre de jours écoulés depuis [startDay].
  int get cycleOffset => startJournee == 2 ? 1 : 0;

  RotationConfig copyWith({DateTime? startDate, List<String>? equipeIds, int? startJournee}) =>
      RotationConfig(
        startDate: startDate ?? this.startDate,
        equipeIds: equipeIds ?? this.equipeIds,
        startJournee: startJournee ?? this.startJournee,
      );
}

class ShiftRotationLogic {
  /// دورة 8 أيام: يومان صباحي، يومان مسائي، يومان ليلي، يومان راحة (كما كان سابقاً).
  /// الموضع 0 = أول فريق، إلخ. كل فريق يحصل على يومين متتاليين من كل نوع.
  static const int cycleDays = 8;
  static const List<ShiftType> _baseOrder = [
    ShiftType.morning,
    ShiftType.morning,
    ShiftType.evening,
    ShiftType.evening,
    ShiftType.night,
    ShiftType.night,
    ShiftType.rest,
    ShiftType.rest,
  ];

  /// Ordre d'affichage des colonnes du planning : les équipes se suivent
  /// (EQUIPE 1, EQUIPE 2, EQUIPE 3, EQUIPE 4) au lieu des postes P1…P4.
  /// [equipeNames] est indexé par position de rotation ; le résultat contient
  /// ces positions triées par numéro d'équipe. Les équipes sans numéro (ou non
  /// renseignées) restent à la fin, dans l'ordre de la rotation.
  static List<int> equipeDisplayOrder(List<String> equipeNames) {
    final positions = List<int>.generate(equipeNames.length, (i) => i);
    int? numberOf(int pos) {
      final match = RegExp(r'\d+').firstMatch(equipeNames[pos]);
      return match == null ? null : int.tryParse(match.group(0)!);
    }

    positions.sort((a, b) {
      final na = numberOf(a);
      final nb = numberOf(b);
      if (na == null && nb == null) return a.compareTo(b);
      if (na == null) return 1;
      if (nb == null) return -1;
      if (na != nb) return na.compareTo(nb);
      return a.compareTo(b);
    });
    return positions;
  }

  static ShiftType shiftForPosition(int position, int dayInCycle) {
    final d = dayInCycle % cycleDays;
    final idx = (d + position * 2) % cycleDays;
    return _baseOrder[idx];
  }

  /// Journée 1 ou 2 du poste en cours (chaque poste dure deux jours de suite).
  /// Retourne 0 si repos / poste inconnu.
  /// [previousDay] = shift de la veille pour la même équipe.
  static int journeeDansPoste({
    required ShiftType today,
    required ShiftType previousDay,
  }) {
    if (today == ShiftType.rest) return 0;
    return previousDay == today ? 2 : 1;
  }
}
