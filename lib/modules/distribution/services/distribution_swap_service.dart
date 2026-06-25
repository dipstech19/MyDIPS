import '../../employees/models/employe_model.dart';
import '../../employees/models/equipe_model.dart';
import '../../pointage/data/pointage_repository.dart';
import '../../pointage/models/pointage_model.dart';
import '../../shifts/models/shift_models.dart';
import '../data/distribution_swaps_repository.dart';
import '../distribution_shifts_provider.dart';
import '../models/distribution_group_model.dart';
import '../models/distribution_swap_model.dart';

/// Logique métier des échanges Distribution (renfort + arrangement « E »).
class DistributionSwapService {
  static const int arrangementMinutes = 480;

  /// Retourne l'equipeId utilisé dans les records de pointage pour ce groupe.
  /// Distribution : préfixe 'distribution:groupId'
  /// Dessalement  : l'ID de l'équipe lui-même (pas de préfixe)
  static String equipeIdForGroup(String groupId, [String sectionType = 'distribution']) {
    if (sectionType == 'dessalement') return groupId;
    return 'distribution:$groupId';
  }

  static String sectionLabel(String sectionType) =>
      sectionType == 'dessalement' ? 'Dessalement' : 'Distribution';

  /// Doc Firestore standard : `{employeId}_{yyyy-MM-dd}`.
  static String standardDayDocId(String employeId, DateTime day) {
    final d = DistributionSwap.dayOnly(day);
    final dk =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${employeId}_$dk';
  }

  static String? groupIdFromEquipe(String equipeId) {
    if (!equipeId.startsWith('distribution:')) return null;
    return equipeId.substring('distribution:'.length);
  }

  static bool canManageSwaps({
    required bool isDistributionResponsable,
    required bool isChefZoneAdmin,
  }) =>
      isDistributionResponsable || isChefZoneAdmin;

  /// Groupe en service ce jour-là (planning Distribution).
  static bool isGroupOnDutyOnDate({
    required String groupId,
    required DateTime date,
    required DistributionShiftsProvider shiftsProv,
  }) {
    if (!shiftsProv.hasRotationSlotForGroup(groupId)) return true;
    return shiftsProv.getShiftForGroup(groupId, date) != ShiftType.rest;
  }

  static List<DistributionGroup> groupsOnDutyOnDate({
    required List<DistributionGroup> groups,
    required DateTime date,
    required DistributionShiftsProvider shiftsProv,
  }) =>
      groups
          .where((g) =>
              g.membreIds.isNotEmpty &&
              isGroupOnDutyOnDate(groupId: g.id, date: date, shiftsProv: shiftsProv))
          .toList();

  static String shiftLabelForGroup({
    required String groupId,
    required DateTime date,
    required DistributionShiftsProvider shiftsProv,
  }) {
    if (!shiftsProv.hasRotationSlotForGroup(groupId)) return '';
    final s = shiftsProv.getShiftForGroup(groupId, date);
    if (s == ShiftType.rest) return ' (Repos)';
    return switch (s) {
      ShiftType.morning => ' (P1)',
      ShiftType.evening => ' (P2)',
      ShiftType.night => ' (P3)',
      ShiftType.rest => ' (Repos)',
    };
  }

  /// Après planification des deux dates : crée renfort + arrangement en attente.
  static Future<void> applyScheduledSwap({
    required DistributionSwap swap,
    required PointageRepository pointageRepo,
    required Map<String, Employe> employesById,
    Map<String, DistributionGroup> groupsById = const {},
    Map<String, Equipe> equipesById = const {},
  }) async {
    final dateA = DistributionSwap.dayOnly(swap.dateAInGroupB);
    final dateB = DistributionSwap.dayOnly(swap.dateBInGroupA!);
    final empA = employesById[swap.employeAId];
    final empB = employesById[swap.employeBId];
    if (empA == null || empB == null) return;

    final eqA = equipeIdForGroup(swap.groupAId, swap.sectionType);
    final eqB = equipeIdForGroup(swap.groupBId, swap.sectionType);
    final String nameA, nameB;
    final String chefName;

    if (swap.sectionType == 'dessalement') {
      final gA = equipesById[swap.groupAId];
      final gB = equipesById[swap.groupBId];
      if (gA == null || gB == null) return;
      nameA = 'Dessalement: ${gA.nom}';
      nameB = 'Dessalement: ${gB.nom}';
      chefName = 'Responsable Dessalement';
    } else {
      final gA = groupsById[swap.groupAId];
      final gB = groupsById[swap.groupBId];
      if (gA == null || gB == null) return;
      nameA = 'Distribution: ${gA.nom}';
      nameB = 'Distribution: ${gB.nom}';
      chefName = 'Responsable Distribution';
    }

    await pointageRepo.createOrUpdateRenfortRecord(
      employeId: empA.id,
      employeNom: empA.nom,
      employeCin: empA.cin,
      targetEquipeId: eqB,
      targetEquipeName: nameB,
      targetChefName: chefName,
      originalEquipeId: eqA,
      day: dateA,
      defaultOvertimeMinutes: arrangementMinutes,
    );

    await pointageRepo.createOrUpdateRenfortRecord(
      employeId: empB.id,
      employeNom: empB.nom,
      employeCin: empB.cin,
      targetEquipeId: eqA,
      targetEquipeName: nameA,
      targetChefName: chefName,
      originalEquipeId: eqB,
      day: dateB,
      defaultOvertimeMinutes: arrangementMinutes,
    );

    // B : arrangement sur dateA (chez lui) — confirmé quand B termine sa manœuvre (dateB).
    await pointageRepo.createOrUpdateDistSwapArrangement(
      employeId: empB.id,
      employeNom: empB.nom,
      employeCin: empB.cin,
      homeEquipeId: eqB,
      homeEquipeName: nameB,
      day: dateA,
      swapId: swap.id,
      unlockWhenEmployeId: empB.id,
      unlockWhenWorkDate: dateB,
      pending: true,
    );

    // A : arrangement sur dateB (chez lui) — confirmé quand A termine sa manœuvre (dateA).
    await pointageRepo.createOrUpdateDistSwapArrangement(
      employeId: empA.id,
      employeNom: empA.nom,
      employeCin: empA.cin,
      homeEquipeId: eqA,
      homeEquipeName: nameA,
      day: dateB,
      swapId: swap.id,
      unlockWhenEmployeId: empA.id,
      unlockWhenWorkDate: dateA,
      pending: true,
    );

  }

  /// Crée immédiatement le renfort pour empA chez GroupB sur dateA dès la création
  /// de l'échange (statut awaitingReturnDate), avant même que dateB soit connue.
  static Future<void> applyInitialSwap({
    required DistributionSwap swap,
    required PointageRepository pointageRepo,
    required Map<String, Employe> employesById,
    Map<String, DistributionGroup> groupsById = const {},
    Map<String, Equipe> equipesById = const {},
  }) async {
    final dateA = DistributionSwap.dayOnly(swap.dateAInGroupB);
    final empA = employesById[swap.employeAId];
    if (empA == null) return;

    final String targetName;
    if (swap.sectionType == 'dessalement') {
      final gB = equipesById[swap.groupBId];
      if (gB == null) return;
      targetName = 'Dessalement: ${gB.nom}';
    } else {
      final gA = groupsById[swap.groupAId];
      final gB = groupsById[swap.groupBId];
      if (gA == null || gB == null) return;
      targetName = 'Distribution: ${gB.nom}';
    }

    await pointageRepo.createOrUpdateRenfortRecord(
      employeId: empA.id,
      employeNom: empA.nom,
      employeCin: empA.cin,
      targetEquipeId: equipeIdForGroup(swap.groupBId, swap.sectionType),
      targetEquipeName: targetName,
      targetChefName: 'Responsable ${sectionLabel(swap.sectionType)}',
      originalEquipeId: equipeIdForGroup(swap.groupAId, swap.sectionType),
      day: dateA,
      defaultOvertimeMinutes: arrangementMinutes,
    );
  }

  /// Journée de manœuvre (renfort) terminée → débloque l'« E » de l'autre.
  static Future<void> tryConfirmArrangementsAfterWorkDay({
    required PointageRecord completedRecord,
    required PointageRepository pointageRepo,
    required DistributionSwapsRepository swapsRepo,
    required List<DistributionSwap> swaps,
  }) async {
    if (!completedRecord.tempAssigned) return;
    final eqId = completedRecord.equipeId;
    final isDistribution = eqId.startsWith('distribution:');
    if (!isDistribution) {
      // Vérifie si ce renfort correspond à un échange Dessalement actif
      final isDessalement = swaps.any((s) =>
          s.sectionType == 'dessalement' &&
          s.status != DistributionSwapStatus.cancelled &&
          (s.groupAId == eqId || s.groupBId == eqId));
      if (!isDessalement) return;
    }
    if (completedRecord.chefStatus != ChefPointageStatus.present) return;
    if (completedRecord.departureStatus != DepartureStatus.finished) return;

    final workDay = DistributionSwap.dayOnly(completedRecord.date);
    final workerId = completedRecord.employeId;

    for (final swap in swaps) {
      if (swap.status != DistributionSwapStatus.scheduled) continue;

      // A a terminé sa manœuvre (dateA dans groupe B) → confirmer E de B sur dateA.
      if (swap.employeAId == workerId &&
          DistributionSwap.dayOnly(swap.dateAInGroupB) == workDay) {
        await pointageRepo.confirmDistSwapArrangement(
          employeId: swap.employeBId,
          day: workDay,
          homeEquipeId: equipeIdForGroup(swap.groupBId, swap.sectionType),
        );
      }

      // B a terminé sa manœuvre (dateB dans groupe A) → confirmer E de A sur dateB.
      if (swap.dateBInGroupA != null &&
          swap.employeBId == workerId &&
          DistributionSwap.dayOnly(swap.dateBInGroupA!) == workDay) {
        await pointageRepo.confirmDistSwapArrangement(
          employeId: swap.employeAId,
          day: workDay,
          homeEquipeId: equipeIdForGroup(swap.groupAId, swap.sectionType),
        );
      }

      await _maybeMarkSwapCompleted(swap, swapsRepo, pointageRepo);
    }
  }

  static Future<void> _maybeMarkSwapCompleted(
    DistributionSwap swap,
    DistributionSwapsRepository swapsRepo,
    PointageRepository pointageRepo,
  ) async {
    if (swap.dateBInGroupA == null) return;
    final dateA = DistributionSwap.dayOnly(swap.dateAInGroupB);
    final dateB = DistributionSwap.dayOnly(swap.dateBInGroupA!);

    final bArr = await pointageRepo.getDistSwapArrangement(
      employeId: swap.employeBId,
      day: dateA,
      homeEquipeId: equipeIdForGroup(swap.groupBId, swap.sectionType),
    );
    final aArr = await pointageRepo.getDistSwapArrangement(
      employeId: swap.employeAId,
      day: dateB,
      homeEquipeId: equipeIdForGroup(swap.groupAId, swap.sectionType),
    );
    if (bArr != null &&
        !bArr.distSwapArrangementPending &&
        aArr != null &&
        !aArr.distSwapArrangementPending) {
      await swapsRepo.updateSwap(swap.id, {'status': DistributionSwapStatus.completed.name});
    }
  }

  /// Membres affichés pour le pointage d'un groupe à une date.
  static List<({Employe employe, PointageRecord? record, bool isGuest, bool isArrangement, bool arrangementPending, bool isAwayOnRenfort})>
      membersForPointage({
    required DistributionGroup group,
    required List<Employe> allEmployes,
    required List<PointageRecord> dayRecords,
    required List<DistributionSwap> swaps,
    required DateTime day,
  }) {
    final eqId = equipeIdForGroup(group.id);
    final d = DistributionSwap.dayOnly(day);
    final byId = {for (final e in allEmployes) e.id: e};
    final result = <({
      Employe employe,
      PointageRecord? record,
      bool isGuest,
      bool isArrangement,
      bool arrangementPending,
      bool isAwayOnRenfort,
    })>[];
    final added = <String>{};

    void add(
      Employe e,
      PointageRecord? rec, {
      bool guest = false,
      bool arrangement = false,
      bool pending = false,
      bool away = false,
    }) {
      if (added.contains(e.id) && !guest && !arrangement && !away) return;
      if (guest || arrangement || away || !added.contains(e.id)) {
        result.add((
          employe: e,
          record: rec,
          isGuest: guest,
          isArrangement: arrangement,
          arrangementPending: pending,
          isAwayOnRenfort: away,
        ));
        added.add(e.id);
      }
    }

    PointageRecord? pickRecord(String employeId, String forEquipeId) {
      final matches = dayRecords
          .where((r) =>
              r.employeId == employeId &&
              r.equipeId == forEquipeId &&
              !r.distSwapArrangement)
          .toList();
      if (matches.isNotEmpty) {
        final home = matches.where((r) => !r.tempAssigned).toList();
        return home.isNotEmpty ? home.first : matches.first;
      }
      final stdId = standardDayDocId(employeId, d);
      try {
        return dayRecords.firstWhere(
          (r) => r.id == stdId && !r.tempAssigned && !r.distSwapArrangement,
        );
      } catch (_) {
        return null;
      }
    }

    for (final id in group.membreIds) {
      final e = byId[id];
      if (e == null || e.statut != EmployeStatut.enService) continue;
      // Renfort away prend la priorité sur l'arrangement (cas échange même jour).
      final renfortAway = dayRecords.any((r) =>
          r.employeId == id &&
          r.tempAssigned &&
          r.originalEquipeId == eqId &&
          DistributionSwap.dayOnly(r.date) == d);
      if (renfortAway) {
        // Passe le record arrangement si disponible (affichage statut E dans le pointage).
        final arrRecords = dayRecords.where((r) =>
            r.employeId == id &&
            r.equipeId == eqId &&
            r.distSwapArrangement &&
            DistributionSwap.dayOnly(r.date) == d);
        add(e, arrRecords.isNotEmpty ? arrRecords.first : null, away: true);
      } else {
        final arr = dayRecords.where((r) =>
            r.employeId == id &&
            r.equipeId == eqId &&
            r.distSwapArrangement &&
            DistributionSwap.dayOnly(r.date) == d);
        if (arr.isNotEmpty) {
          final r = arr.first;
          add(e, r, arrangement: true, pending: r.distSwapArrangementPending);
        } else {
          add(e, pickRecord(id, eqId));
        }
      }
    }

    for (final r in dayRecords) {
      if (!r.tempAssigned || r.equipeId != eqId) continue;
      if (DistributionSwap.dayOnly(r.date) != d) continue;
      final e = byId[r.employeId];
      if (e == null) continue;
      add(e, r, guest: true);
    }

    // ─── Fallback swap : couvre les échanges sans enregistrement pointage encore créé ───
    // Utile pour les swaps au statut awaitingReturnDate (records pas encore générés)
    // et comme filet de sécurité si les records Firestore n'ont pas encore été lus.
    for (final swap in swaps) {
      if (swap.status == DistributionSwapStatus.cancelled) continue;
      final dayA = DistributionSwap.dayOnly(swap.dateAInGroupB);
      final dayB = swap.dateBInGroupA != null
          ? DistributionSwap.dayOnly(swap.dateBInGroupA!)
          : null;

      // dateA : empA part chez GroupB → absent de GroupA, invité dans GroupB
      if (dayA == d) {
        if (swap.groupAId == group.id) {
          final empA = byId[swap.employeAId];
          if (empA != null && empA.statut == EmployeStatut.enService) {
            // Remplace l'entrée normale par "absent (renfort)" si elle n'est pas déjà correcte
            final idx = result.indexWhere((r) =>
                r.employe.id == empA.id &&
                !r.isAwayOnRenfort &&
                !r.isArrangement &&
                !r.isGuest);
            if (idx >= 0) {
              result[idx] = (
                employe: empA,
                record: null,
                isGuest: false,
                isArrangement: false,
                arrangementPending: false,
                isAwayOnRenfort: true,
              );
            }
          }
        }
        if (swap.groupBId == group.id) {
          final empA = byId[swap.employeAId];
          if (empA != null &&
              empA.statut == EmployeStatut.enService &&
              !group.membreIds.contains(empA.id)) {
            final alreadyShown = result
                .any((r) => r.employe.id == empA.id && (r.isGuest || r.isArrangement));
            if (!alreadyShown && !added.contains(empA.id)) {
              add(empA, null, guest: true);
            }
          }
        }
      }

      // dateB : empB part chez GroupA → absent de GroupB, invité dans GroupA
      if (dayB != null && dayB == d) {
        if (swap.groupBId == group.id) {
          final empB = byId[swap.employeBId];
          if (empB != null && empB.statut == EmployeStatut.enService) {
            final idx = result.indexWhere((r) =>
                r.employe.id == empB.id &&
                !r.isAwayOnRenfort &&
                !r.isArrangement &&
                !r.isGuest);
            if (idx >= 0) {
              result[idx] = (
                employe: empB,
                record: null,
                isGuest: false,
                isArrangement: false,
                arrangementPending: false,
                isAwayOnRenfort: true,
              );
            }
          }
        }
        if (swap.groupAId == group.id) {
          final empB = byId[swap.employeBId];
          if (empB != null &&
              empB.statut == EmployeStatut.enService &&
              !group.membreIds.contains(empB.id)) {
            final alreadyShown = result
                .any((r) => r.employe.id == empB.id && (r.isGuest || r.isArrangement));
            if (!alreadyShown && !added.contains(empB.id)) {
              add(empB, null, guest: true);
            }
          }
        }
      }
    }

    result.sort((a, b) => a.employe.nom.compareTo(b.employe.nom));
    return result;
  }

  static String? validateReturnDate({
    required DateTime dateA,
    required DateTime dateB,
  }) {
    if (DistributionSwap.monthKeyFor(dateA) != DistributionSwap.monthKeyFor(dateB)) {
      return 'Les deux dates doivent être dans le même mois.';
    }
    if (DistributionSwap.dayOnly(dateB).isBefore(DistributionSwap.dayOnly(dateA))) {
      return 'La date de retour doit être après ou égale à la première date.';
    }
    return null;
  }
}
