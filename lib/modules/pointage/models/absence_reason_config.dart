/// سبب غياب قابل للتعديل من طرف الأدمن — يُخزّن في Firestore.
class AbsenceReasonConfig {
  final String id;
  final String label;
  /// إن كان true يُخصم من الراتب/ساعات العمل؛ إن كان false يُحتسب كغياب مأذون (مدفوع).
  final bool deductFromSalary;
  final int order;

  const AbsenceReasonConfig({
    required this.id,
    required this.label,
    required this.deductFromSalary,
    this.order = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'deductFromSalary': deductFromSalary,
      'order': order,
    };
  }

  static AbsenceReasonConfig? fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) return null;
    return AbsenceReasonConfig(
      id: id,
      label: map['label'] as String? ?? '',
      deductFromSalary: map['deductFromSalary'] as bool? ?? true,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

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
}
