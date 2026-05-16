/// Échange / manœuvre entre deux membres de groupes Distribution (même mois).
enum DistributionSwapStatus {
  /// Date de travail du 1er employé fixée ; en attente de la date de retour.
  awaitingReturnDate,
  /// Les deux dates sont fixées ; pointage renfort + arrangement créés.
  scheduled,
  /// Les deux journées de manœuvre sont terminées et les « E » confirmés.
  completed,
  cancelled,
}

class DistributionSwap {
  final String id;
  final String employeAId;
  final String employeBId;
  final String groupAId;
  final String groupBId;
  final DateTime dateAInGroupB;
  final DateTime? dateBInGroupA;
  final String monthKey;
  final DistributionSwapStatus status;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;

  const DistributionSwap({
    required this.id,
    required this.employeAId,
    required this.employeBId,
    required this.groupAId,
    required this.groupBId,
    required this.dateAInGroupB,
    this.dateBInGroupA,
    required this.monthKey,
    required this.status,
    this.createdById = '',
    this.createdByName = '',
    required this.createdAt,
  });

  static String monthKeyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get isSameMonthPair =>
      dateBInGroupA != null && monthKeyFor(dateAInGroupB) == monthKeyFor(dateBInGroupA!);

  Map<String, dynamic> toMap() => {
        'employeAId': employeAId,
        'employeBId': employeBId,
        'groupAId': groupAId,
        'groupBId': groupBId,
        'dateAInGroupB': dayOnly(dateAInGroupB).toIso8601String(),
        'dateBInGroupA': dateBInGroupA != null ? dayOnly(dateBInGroupA!).toIso8601String() : null,
        'monthKey': monthKey,
        'status': status.name,
        'createdById': createdById,
        'createdByName': createdByName,
        'createdAt': createdAt.toIso8601String(),
      };

  static DistributionSwap fromMap(Map<String, dynamic> map) {
    final statusRaw = map['status'] as String? ?? '';
    final status = DistributionSwapStatus.values.firstWhere(
      (e) => e.name == statusRaw,
      orElse: () => DistributionSwapStatus.awaitingReturnDate,
    );
    final dateA = DateTime.tryParse(map['dateAInGroupB'] as String? ?? '') ?? DateTime.now();
    final dateBRaw = map['dateBInGroupA'] as String?;
    final dateB = dateBRaw != null && dateBRaw.isNotEmpty ? DateTime.tryParse(dateBRaw) : null;
    return DistributionSwap(
      id: map['id'] as String? ?? '',
      employeAId: map['employeAId'] as String? ?? '',
      employeBId: map['employeBId'] as String? ?? '',
      groupAId: map['groupAId'] as String? ?? '',
      groupBId: map['groupBId'] as String? ?? '',
      dateAInGroupB: dayOnly(dateA),
      dateBInGroupA: dateB != null ? dayOnly(dateB) : null,
      monthKey: map['monthKey'] as String? ?? monthKeyFor(dateA),
      status: status,
      createdById: map['createdById'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  DistributionSwap copyWith({
    DateTime? dateBInGroupA,
    DistributionSwapStatus? status,
  }) =>
      DistributionSwap(
        id: id,
        employeAId: employeAId,
        employeBId: employeBId,
        groupAId: groupAId,
        groupBId: groupBId,
        dateAInGroupB: dateAInGroupB,
        dateBInGroupA: dateBInGroupA ?? this.dateBInGroupA,
        monthKey: monthKey,
        status: status ?? this.status,
        createdById: createdById,
        createdByName: createdByName,
        createdAt: createdAt,
      );
}
