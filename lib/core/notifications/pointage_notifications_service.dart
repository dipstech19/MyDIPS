import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/app_permissions.dart';
import '../auth/auth_model.dart';
import 'local_notifications_service.dart';
import '../../modules/employees/models/equipe_model.dart';
import '../../modules/pointage/pointage_hours_config.dart';
import '../../modules/shifts/data/shifts_repository.dart';
import '../../modules/shifts/models/shift_models.dart';

/// Rappels et alertes pointage (hors app + dans l'app via barre système).
class PointageNotificationsService {
  PointageNotificationsService._();
  static final PointageNotificationsService instance = PointageNotificationsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ShiftsRepository _shiftsRepo = ShiftsRepository();

  Timer? _supervisorTimer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  final Set<String> _notifiedEventKeys = <String>{};
  final Set<String> _missedNotifiedKeys = <String>{};
  final Map<String, bool> _chefSubmittedToday = <String, bool>{};

  static const int _idArrivalBase = 10000;
  static const int _idDepartureBase = 20000;
  static const int _idMissedBase = 30000;

  Future<void> bindUser(AppUser? user) async {
    await _stopAll();
    if (user == null) return;

    switch (user.role) {
      case UserRole.chefEquipe:
      case UserRole.chauffeur:
        final eq = user.equipeId?.trim();
        if (eq != null && eq.isNotEmpty) {
          await _scheduleEquipeReminders(eq, user.role);
        }
        break;
      case UserRole.distributionResponsable:
        final ids = user.distributionGroupIds;
        if (ids.isEmpty) {
          final one = user.distributionGroupId?.trim();
          if (one != null && one.isNotEmpty) {
            await _scheduleEquipeReminders('distribution:$one', user.role);
          }
        } else {
          for (final gid in ids) {
            await _scheduleEquipeReminders('distribution:$gid', user.role);
          }
        }
        break;
      case UserRole.directeur:
        await _startSupervisorMode(user);
        break;
      case UserRole.groupeResponsable:
        break;
    }
  }

  /// Appelé après envoi réussi du rapport chef.
  Future<void> onChefReportSubmitted({
    required String equipeId,
    required String equipeName,
    required String chefName,
  }) async {
    final day = DateTime.now();
    _chefSubmittedToday[equipeId] = true;
    await _cancelMissedForEquipe(equipeId);

    try {
      await _firestore.collection('pointage_events').add({
        'type': 'chef_report_submitted',
        'equipeId': equipeId,
        'equipeName': equipeName,
        'chefName': chefName,
        'date': DateTime(day.year, day.month, day.day).toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('pointage_events write: $e');
    }
  }

  Future<void> _scheduleEquipeReminders(String equipeId, UserRole role) async {
    final config = await _loadHoursConfig(equipeId);
    if (config == null || config.isRestDay) return;

    final now = DateTime.now();
    final logicalDay = getPointageDateForConfig(config, now);
    final equipeName = await _equipeDisplayName(equipeId);

    final arrivalStart = config.arrivalWindowStartOn(logicalDay);
    final departureStart = config.departureWindowStartOn(logicalDay);
    final departureEnd = config.departureWindowEndOn(logicalDay);

    final suffix = _idSuffix(equipeId);
    final isChef = role == UserRole.chefEquipe || role == UserRole.distributionResponsable;

    if (isChef) {
      await LocalNotificationsService.instance.schedule(
        id: _idArrivalBase + suffix,
        when: arrivalStart,
        title: 'Pointage — entrée',
        body: 'Fenêtre d\'entrée ouverte pour $equipeName (${config.arrivalWindowFormatted(now)}).',
      );
      await LocalNotificationsService.instance.schedule(
        id: _idDepartureBase + suffix,
        when: departureStart,
        title: 'Pointage — sortie',
        body: 'Confirmez le départ / envoyez le rapport pour $equipeName.',
      );
      await LocalNotificationsService.instance.schedule(
        id: _idMissedBase + suffix,
        when: departureEnd,
        title: 'Pointage non confirmé',
        body: 'La fenêtre de sortie est terminée. Confirmez le pointage pour $equipeName.',
        channelId: LocalNotificationsService.channelAlertsId,
      );
    } else {
      await LocalNotificationsService.instance.schedule(
        id: _idArrivalBase + suffix,
        when: arrivalStart,
        title: 'Pointage chauffeur',
        body: 'Marquez la présence de votre équipe ($equipeName).',
      );
      await LocalNotificationsService.instance.schedule(
        id: _idDepartureBase + suffix,
        when: departureStart,
        title: 'Rapport chauffeur',
        body: 'Envoyez le rapport de fin de shift pour $equipeName.',
      );
    }
  }

  Future<void> _startSupervisorMode(AppUser user) async {
    final adminRole = (user.adminRole ?? '').toLowerCase();
    final isZone = adminRole.contains('zone');
    final canPointage = user.permissions.contains(AppPermissions.all) ||
        user.permissions.contains(AppPermissions.pointageView);

    if (!canPointage && !isZone) return;

    _supervisorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_checkSupervisorAlerts(user));
    });
    unawaited(_checkSupervisorAlerts(user));

    _eventsSub = _firestore
        .collection('pointage_events')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .listen((snap) {
      if (!_eventsBootstrapDone) {
        for (final d in snap.docs) {
          _notifiedEventKeys.add(d.id);
        }
        _eventsBootstrapDone = true;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        if (change.doc.id.isNotEmpty && _notifiedEventKeys.contains(change.doc.id)) continue;
        _notifiedEventKeys.add(change.doc.id);
        unawaited(_handlePointageEvent(user, data));
      }
    });
  }

  bool _eventsBootstrapDone = false;

  Future<void> _handlePointageEvent(AppUser user, Map<String, dynamic> data) async {
    final type = (data['type'] as String? ?? '').trim();
    final equipeId = (data['equipeId'] as String? ?? '').trim();
    if (equipeId.isEmpty) return;
    if (!_supervisorWatchesEquipe(user, equipeId)) return;

    final equipeName = (data['equipeName'] as String? ?? equipeId).trim();
    final chefName = (data['chefName'] as String? ?? 'Chef d\'équipe').trim();

    if (type == 'chef_report_submitted') {
      await LocalNotificationsService.instance.show(
        id: 50000 + _idSuffix(equipeId),
        title: 'Pointage confirmé',
        body: '$chefName a confirmé le pointage pour $equipeName.',
        channelId: LocalNotificationsService.channelAlertsId,
      );
    } else if (type == 'chef_report_missed') {
      await LocalNotificationsService.instance.show(
        id: 60000 + _idSuffix(equipeId),
        title: 'Pointage manqué',
        body: 'Aucune confirmation de sortie pour $equipeName avant la fin de la fenêtre.',
        channelId: LocalNotificationsService.channelAlertsId,
      );
    }
  }

  Future<void> _checkSupervisorAlerts(AppUser user) async {
    final equipeIds = await _watchedEquipeIds(user);
    if (equipeIds.isEmpty) return;

    final now = DateTime.now();
    for (final equipeId in equipeIds) {
      final config = await _loadHoursConfig(equipeId);
      if (config == null || config.isRestDay) continue;

      final logicalDay = getPointageDateForConfig(config, now);
      final key = '${equipeId}_${logicalDay.year}-${logicalDay.month}-${logicalDay.day}';

      final submitted = await _hasChefSubmitted(equipeId, logicalDay);
      _chefSubmittedToday[equipeId] = submitted;

      final departureEnd = config.departureWindowEndOn(logicalDay);
      if (now.isBefore(departureEnd)) continue;
      if (submitted) continue;
      if (_missedNotifiedKeys.contains(key)) continue;

      _missedNotifiedKeys.add(key);
      final equipeName = await _equipeDisplayName(equipeId);

      await LocalNotificationsService.instance.show(
        id: 60000 + _idSuffix(equipeId),
        title: 'Pointage manqué',
        body: 'L\'équipe $equipeName n\'a pas confirmé le pointage de sortie.',
        channelId: LocalNotificationsService.channelAlertsId,
      );

      try {
        await _firestore.collection('pointage_events').add({
          'type': 'chef_report_missed',
          'equipeId': equipeId,
          'equipeName': equipeName,
          'date': logicalDay.toIso8601String(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  bool _supervisorWatchesEquipe(AppUser user, String equipeId) {
    if (equipeId.startsWith('distribution:')) {
      final gid = equipeId.substring('distribution:'.length);
      final ids = user.distributionGroupIds;
      if (ids.isEmpty) {
        return user.distributionGroupId == gid;
      }
      return ids.contains(gid);
    }
    final adminRole = (user.adminRole ?? '').toLowerCase();
    if (adminRole.contains('zone')) return false;
    return user.permissions.contains(AppPermissions.all) ||
        user.permissions.contains(AppPermissions.pointageView);
  }

  Future<List<String>> _watchedEquipeIds(AppUser user) async {
    final adminRole = (user.adminRole ?? '').toLowerCase();
    if (adminRole.contains('zone')) {
      final distIds = user.distributionGroupIds.isNotEmpty
          ? user.distributionGroupIds
          : [
              if ((user.distributionGroupId ?? '').isNotEmpty) user.distributionGroupId!,
            ];
      return distIds.map((g) => 'distribution:$g').toList();
    }

    try {
      final snap = await _firestore.collection('equipes').get();
      return snap.docs.map((d) => d.id).where((id) => !id.startsWith('distribution:')).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _hasChefSubmitted(String equipeId, DateTime logicalDay) async {
    if (_chefSubmittedToday[equipeId] == true) return true;
    final start = DateTime(logicalDay.year, logicalDay.month, logicalDay.day);
    final end = start.add(const Duration(days: 1));
    try {
      final snap = await _firestore
          .collection('pointage')
          .where('date', isGreaterThanOrEqualTo: start.toIso8601String())
          .where('date', isLessThan: end.toIso8601String())
          .limit(80)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if ((data['equipeId'] as String? ?? '') != equipeId) continue;
        if (data['submittedByChefAt'] != null) return true;
      }
    } catch (e) {
      debugPrint('hasChefSubmitted: $e');
    }
    return false;
  }

  Future<PointageHoursConfig?> _loadHoursConfig(String equipeId) async {
    Equipe? equipe;
    if (!equipeId.startsWith('distribution:')) {
      try {
        final doc = await _firestore.collection('equipes').doc(equipeId).get();
        if (doc.exists && doc.data() != null) {
          equipe = Equipe.fromMap({...doc.data()!, 'id': doc.id});
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    ShiftType shift = ShiftType.morning;
    if (!equipeId.startsWith('distribution:')) {
      shift = await _shiftForEquipe(equipeId, now);
    } else {
      shift = await _shiftForDistributionGroup(equipeId.substring('distribution:'.length), now);
    }

    final provisional = getConfigForEquipeAndDate(equipe, now, shift);
    final logicalDay = getPointageDateForConfig(provisional, now);
    if (!equipeId.startsWith('distribution:')) {
      shift = await _shiftForEquipe(equipeId, logicalDay);
    } else {
      shift = await _shiftForDistributionGroup(equipeId.substring('distribution:'.length), logicalDay);
    }
    return getConfigForEquipeAndDate(equipe, logicalDay, shift);
  }

  Future<ShiftType> _shiftForEquipe(String equipeId, DateTime date) async {
    final config = await _shiftsRepo.getConfig();
    if (config == null) return ShiftType.rest;
    final pos = config.equipeIds.indexOf(equipeId);
    if (pos < 0) return ShiftType.rest;
    final overrides = await _shiftsRepo.getOverrides();
    final key = '${date.year}-${date.month}-${date.day}';
    final override = overrides[key]?[equipeId];
    if (override != null) return override;
    final start = config.startDay;
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(start).inDays;
    if (diff < 0) return ShiftType.rest;
    return ShiftRotationLogic.shiftForPosition(pos, diff % ShiftRotationLogic.cycleDays);
  }

  Future<ShiftType> _shiftForDistributionGroup(String groupId, DateTime date) async {
    try {
      const configDocId = 'distribution_shifts_config';
      const overridesCollection = 'distribution_shifts_overrides';
      final cfgRef = _firestore.collection('app_config').doc(configDocId);
      final cfgSnap = await cfgRef.get();
      final cfgData = cfgSnap.data();
      if (cfgData == null) return ShiftType.morning;

      final startRaw = cfgData['startDate'] as String?;
      final start = DateTime.tryParse(startRaw ?? '');
      final idsRaw = cfgData['equipeIds'];
      final ids = idsRaw is List ? idsRaw.map((e) => e.toString()).toList() : <String>[];
      if (start == null) return ShiftType.morning;

      final pos = ids.indexOf(groupId);
      if (pos < 0) return ShiftType.rest;

      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final ovSnap = await cfgRef.collection(overridesCollection).doc(key).get();
      final ovRaw = ovSnap.data()?['overrides'];
      if (ovRaw is Map) {
        final shiftName = ovRaw[groupId] as String?;
        if (shiftName != null) {
          return ShiftType.values.firstWhere((e) => e.name == shiftName, orElse: () => ShiftType.morning);
        }
      }

      final d = DateTime(date.year, date.month, date.day);
      final diff = d.difference(DateTime(start.year, start.month, start.day)).inDays;
      if (diff < 0) return ShiftType.rest;
      return ShiftRotationLogic.shiftForPosition(pos, diff % ShiftRotationLogic.cycleDays);
    } catch (_) {}
    return ShiftType.morning;
  }

  Future<String> _equipeDisplayName(String equipeId) async {
    if (equipeId.startsWith('distribution:')) {
      final gid = equipeId.substring('distribution:'.length);
      try {
        final doc = await _firestore.collection('distribution_groups').doc(gid).get();
        final nom = (doc.data()?['nom'] as String? ?? '').trim();
        if (nom.isNotEmpty) return nom;
      } catch (_) {}
      return 'Distribution';
    }
    try {
      final doc = await _firestore.collection('equipes').doc(equipeId).get();
      final nom = (doc.data()?['nom'] as String? ?? '').trim();
      if (nom.isNotEmpty) return nom;
    } catch (_) {}
    return 'Équipe';
  }

  int _idSuffix(String equipeId) => equipeId.hashCode.abs() % 8000;

  Future<void> _cancelMissedForEquipe(String equipeId) async {
    await LocalNotificationsService.instance.cancel(_idMissedBase + _idSuffix(equipeId));
  }

  Future<void> _stopAll() async {
    _supervisorTimer?.cancel();
    _supervisorTimer = null;
    await _eventsSub?.cancel();
    _eventsSub = null;
    _eventsBootstrapDone = false;
    _notifiedEventKeys.clear();
    _missedNotifiedKeys.clear();
    _chefSubmittedToday.clear();
    await LocalNotificationsService.instance.cancelAll();
  }
}
