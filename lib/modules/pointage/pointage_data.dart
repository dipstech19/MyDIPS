import '../employees/models/employe_model.dart';
import '../employees/models/equipe_model.dart';
import 'models/pointage_model.dart';

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

/// Workers for one equipe considering temp assignments (renfort) for the date.
/// [shouldShowRenfortInTarget]: when set, renforts appear in this (target) team only when true (e.g. after their original shift ended).
/// [shouldShowMemberInOriginal]: when set, a base member who is renfort elsewhere stays visible here only when true (e.g. before their shift ended).
List<Employe> getWorkersForEquipeConsideringTemp(
  List<Equipe> equipes,
  List<Employe> employes,
  String? equipeId,
  Map<String, PointageRecord> recordByEmployeIdForDate, {
  bool Function(PointageRecord rec)? shouldShowRenfortInTarget,
  bool Function(PointageRecord rec)? shouldShowMemberInOriginal,
}) {
  if (equipeId == null || equipeId.isEmpty) return [];
  final eqList = equipes.where((e) => e.id == equipeId).toList();
  if (eqList.isEmpty) return [];
  final eq = eqList.first;
  final baseIds = {...eq.membreIds, if (eq.chefId.isNotEmpty) eq.chefId};
  final workerIds = <String>{};
  for (final id in baseIds) {
    final rec = recordByEmployeIdForDate[id];
    if (rec == null) {
      workerIds.add(id);
      continue;
    }
    if (!rec.tempAssigned) {
      workerIds.add(id);
      continue;
    }
    if (rec.originalEquipeId != eq.id) continue;
    if (shouldShowMemberInOriginal == null || shouldShowMemberInOriginal(rec)) workerIds.add(id);
  }
  for (final rec in recordByEmployeIdForDate.values) {
    if (!rec.tempAssigned || rec.equipeId != equipeId) continue;
    if (shouldShowRenfortInTarget == null || shouldShowRenfortInTarget(rec)) workerIds.add(rec.employeId);
  }
  return employes.where((e) => workerIds.contains(e.id)).toList();
}

/// All teams with workers considering temp assignments for the date.
/// Optional callbacks: same semantics as [getWorkersForEquipeConsideringTemp].
List<({String equipeId, String equipeName, String chefName, List<Employe> workers})>
getAllTeamsWithWorkersConsideringTemp(
  List<Equipe> equipes,
  List<Employe> employes,
  Map<String, PointageRecord> recordByEmployeIdForDate, {
  bool Function(PointageRecord rec)? shouldShowRenfortInTarget,
  bool Function(PointageRecord rec)? shouldShowMemberInOriginal,
}) {
  final list = <({String equipeId, String equipeName, String chefName, List<Employe> workers})>[];
  for (final eq in equipes) {
    final workers = getWorkersForEquipeConsideringTemp(
      equipes,
      employes,
      eq.id,
      recordByEmployeIdForDate,
      shouldShowRenfortInTarget: shouldShowRenfortInTarget,
      shouldShowMemberInOriginal: shouldShowMemberInOriginal,
    );
    final chefName = getChefName(employes, eq.chefId);
    list.add((equipeId: eq.id, equipeName: eq.nom, chefName: chefName, workers: workers));
  }
  return list;
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

/// كل الفرق مع اسم الفريق واسم الشاف وقائمة العمال (لشاشة قائمة اليوم)
List<({String equipeId, String equipeName, String chefName, List<Employe> workers})>
getAllTeamsWithWorkers(List<Equipe> equipes, List<Employe> employes) {
  final list = <({String equipeId, String equipeName, String chefName, List<Employe> workers})>[];
  for (final eq in equipes) {
    final chefName = getChefName(employes, eq.chefId);
    final workers = employes
        .where((e) => eq.membreIds.contains(e.id) || e.id == eq.chefId)
        .toList();
    list.add((equipeId: eq.id, equipeName: eq.nom, chefName: chefName, workers: workers));
  }
  return list;
}
