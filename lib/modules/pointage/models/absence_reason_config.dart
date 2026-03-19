/// سبب غياب قابل للتخصيص (من الإعدادات / Firestore)
class AbsenceReasonConfig {
  final String id;
  final String label;
  final bool deductFromSalary;
  final int order;

  AbsenceReasonConfig({
    required this.id,
    required this.label,
    this.deductFromSalary = true,
    this.order = 0,
  });

  AbsenceReasonConfig copyWith({
    String? id,
    String? label,
    bool? deductFromSalary,
    int? order,
  }) {
    return AbsenceReasonConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      deductFromSalary: deductFromSalary ?? this.deductFromSalary,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'deductFromSalary': deductFromSalary,
        'order': order,
      };

  static AbsenceReasonConfig fromMap(Map<String, dynamic> map) {
    return AbsenceReasonConfig(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      deductFromSalary: map['deductFromSalary'] as bool? ?? true,
      order: map['order'] as int? ?? 0,
    );
  }
}
