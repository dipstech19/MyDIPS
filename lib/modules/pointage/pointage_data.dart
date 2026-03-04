import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';

/// عمال فريق واحد (بيانات من القاعدة عبر القوائم المُمرَّرة)
List<Employe> getWorkersForEquipe(
  List<Equipe> equipes,
  List<Employe> employes,
  String? equipeId,
) {
  if (equipeId == null || equipeId.isEmpty) return [];
  final eqList = equipes.where((e) => e.id == equipeId).toList();
  if (eqList.isEmpty) return [];
  final eq = eqList.first;
  final ids = [...eq.membreIds, eq.chefId];
  return employes.where((e) => ids.contains(e.id)).toList();
}

/// اسم الشاف من id الموظف
String getChefName(List<Employe> employes, String chefId) {
  final list = employes.where((emp) => emp.id == chefId).toList();
  return list.isEmpty ? chefId : list.first.nom;
}

/// عمال الفرق الأخرى فقط (لشاشة إضافة عامل)
List<({Employe e, String chefName})> getOtherTeamsWorkers(
  List<Equipe> equipes,
  List<Employe> employes,
  String? myEquipeId,
) {
  if (myEquipeId == null || myEquipeId.isEmpty) return [];
  final otherEquipes = equipes.where((eq) => eq.id != myEquipeId);
  final list = <({Employe e, String chefName})>[];
  for (final eq in otherEquipes) {
    final chefName = getChefName(employes, eq.chefId);
    for (final id in eq.membreIds) {
      final empList = employes.where((e) => e.id == id).toList();
      if (empList.isNotEmpty) list.add((e: empList.first, chefName: chefName));
    }
  }
  return list;
}

/// قائمة الشافات (لاختيار مرسل التقرير)
List<({String chefId, String chefName})> getChefsForReport(
  List<Equipe> equipes,
  List<Employe> employes,
) {
  final seen = <String>{};
  final list = <({String chefId, String chefName})>[];
  for (final eq in equipes) {
    if (seen.contains(eq.chefId)) continue;
    seen.add(eq.chefId);
    list.add((chefId: eq.chefId, chefName: getChefName(employes, eq.chefId)));
  }
  return list;
}

/// كل الفرق مع اسم الشاف وقائمة العمال (لشاشة قائمة اليوم)
List<({String equipeId, String chefName, List<Employe> workers})>
getAllTeamsWithWorkers(List<Equipe> equipes, List<Employe> employes) {
  final list = <({String equipeId, String chefName, List<Employe> workers})>[];
  for (final eq in equipes) {
    final chefName = getChefName(employes, eq.chefId);
    final workers = employes
        .where((e) => eq.membreIds.contains(e.id) || e.id == eq.chefId)
        .toList();
    list.add((equipeId: eq.id, chefName: chefName, workers: workers));
  }
  return list;
}
