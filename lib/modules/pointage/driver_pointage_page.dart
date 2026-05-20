import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/smart_avatar.dart';
import '../../modules/employees/models/employe_model.dart';
import '../../modules/employees/employees_provider.dart';
import 'pointage_data.dart';
import 'pointage_provider.dart';
import 'pointage_hours_config.dart';
import '../shifts/shifts_provider.dart';
import '../shifts/models/shift_models.dart';
import 'models/pointage_model.dart';
import 'services/pointage_export_service.dart';

/// Pointage chauffeur: حاضر | غائب | في المركبة (سيارة/دراجة). بعد الإرسال لا يمكن التعديل.
class DriverPointagePage extends StatefulWidget {
  const DriverPointagePage({super.key});

  @override
  State<DriverPointagePage> createState() => _DriverPointagePageState();
}

class _DriverPointagePageState extends State<DriverPointagePage> {
  String? _selectedEquipeId;
  bool _nonWorkingLoadRequested = false;
  bool _wasDriverSyncPending = false;
  Timer? _clockRefreshTimer;
  final Set<String> _driverArrivalReportLocks = <String>{};
  final Set<String> _driverDepartureReportLocks = <String>{};
  final Map<String, DriverPointageStatus> _driverDraftStatus = <String, DriverPointageStatus>{};
  final Map<String, DepartureStatus> _driverDraftDeparture = <String, DepartureStatus>{};
  final Map<String, int?> _driverDraftOvertimeMinutes = <String, int?>{};
  final Map<String, int?> _driverDraftWorkedMinutes = <String, int?>{};
  final Map<String, String?> _driverDraftIncompleteReason = <String, String?>{};

  @override
  void initState() {
    super.initState();
    _clockRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockRefreshTimer?.cancel();
    super.dispose();
  }

  bool _isProtectedHigherPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef de zone') ||
        p.contains('chef d\'atelier') ||
        p.contains('rh') ||
        p.contains('admin') ||
        p.contains('directeur');
  }

  bool _isHiddenForDriver(Employe e, PointageProvider pointageProvider) {
    final r = pointageProvider.getRecordForEmployee(e.id);
    final isLeaveOrTrainingInRecord =
        r?.adminFinalStatus == AttendanceStatus.training ||
            r?.adminFinalStatus == AttendanceStatus.leave ||
            r?.status == AttendanceStatus.training ||
            r?.status == AttendanceStatus.leave;
    final isEmployeeOnLeave = e.statut == EmployeStatut.enConge;
    return isLeaveOrTrainingInRecord || isEmployeeOnLeave;
  }

  String? _departureStatusLabel(BuildContext context, PointageRecord record) {
    if (record.departureStatus == DepartureStatus.finished) {
      final t = record.departureMarkedAt;
      if (t != null) {
        final hh = t.hour.toString().padLeft(2, '0');
        final mm = t.minute.toString().padLeft(2, '0');
        return 'Terminé ($hh:$mm)';
      }
      return tr(context, 'departure_finished');
    }
    if (record.departureStatus == DepartureStatus.stillWorking) {
      return 'En cours';
    }
    return null;
  }

  static AttendanceState _driverStatusToState(DriverPointageStatus s) {
    switch (s) {
      case DriverPointageStatus.present:
        return AttendanceState.present;
      case DriverPointageStatus.absent:
        return AttendanceState.absent;
      case DriverPointageStatus.enVehicule:
        // Legacy value treated as present.
        return AttendanceState.present;
      case DriverPointageStatus.unset:
        return AttendanceState.unmarked;
    }
  }

  static DriverPointageStatus _stateToDriverStatus(AttendanceState s) {
    switch (s) {
      case AttendanceState.present:
        return DriverPointageStatus.present;
      case AttendanceState.absent:
        return DriverPointageStatus.absent;
      case AttendanceState.unmarked:
        return DriverPointageStatus.unset;
      case AttendanceState.notInVehicle:
        // Driver no longer uses "vient seul" (not in vehicle). Treat as unset.
        return DriverPointageStatus.unset;
    }
  }

  Future<void> _offerMobileShare(
    BuildContext context,
    String filePath, {
    String? text,
  }) async {
    if (!isMobile(context)) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fichier généré',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 6),
              Text(
                filePath,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await launchUrl(
                    Uri.file(filePath),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Impossible d\'ouvrir le fichier automatiquement.'),
                        behavior: SnackBarBehavior.fixed,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Ouvrir le fichier'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: <XFile>[XFile(filePath)],
                      text: text ?? 'Partager le fichier',
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Partager / WhatsApp'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendReport(
    PointageHoursConfig? pointageConfig, {
    required String equipeId,
    required bool departurePhase,
    required String departureLockKey,
  }) async {
    final pointageProvider = context.read<PointageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'pointage_confirm_send_title')),
        content: Text(tr(ctx, 'pointage_confirm_send_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(ctx, 'report_send')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    // Immediate lock in UI (no wait for network).
    if (departurePhase) {
      setState(() => _driverDepartureReportLocks.add(departureLockKey));
    } else {
      setState(() => _driverArrivalReportLocks.add(departureLockKey));
    }
    pointageProvider.applyOptimisticDriverReportLock();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trOf(context, 'pointage_report_locked_pending_sync')),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 4),
      ),
    );

    // Flush local draft before final submit.
    final emp = context.read<EmployeesProvider>();
    final auth = context.read<AuthProvider>();
    final team = getAllTeamsWithWorkers(emp.equipes, emp.employes)
        .where((t) => t.equipeId == equipeId)
        .toList();
    if (team.isNotEmpty) {
      final t = team.first;
      for (final w in t.workers) {
        final s = _driverDraftStatus[w.id];
        if (s != null) {
          await pointageProvider.markDriverAttendance(
            employeId: w.id,
            employeNom: w.nom,
            employeCin: w.cin ?? '',
            equipeId: t.equipeId,
            equipeName: t.equipeName,
            chefName: t.chefName,
            driverStatus: s,
            driverId: auth.currentUser?.id,
            configOverride: pointageConfig ?? const PointageHoursConfig(),
            bypassTimeWindows: true,
          );
        }
        final dep = _driverDraftDeparture[w.id];
        if (dep != null && dep != DepartureStatus.unset) {
          final record = pointageProvider.getRecordForEmployee(w.id);
          if (record != null) {
            await pointageProvider.setDepartureStatus(
              record: record,
              status: dep,
              overtimeMinutes: _driverDraftOvertimeMinutes[w.id],
              workedMinutesBeforeStop: _driverDraftWorkedMinutes[w.id],
              incompleteShiftReason: _driverDraftIncompleteReason[w.id],
              configOverride: pointageConfig ?? const PointageHoursConfig(),
              bypassTimeWindows: true,
            );
          }
        }
      }
      _driverDraftStatus.clear();
      _driverDraftDeparture.clear();
      _driverDraftOvertimeMinutes.clear();
      _driverDraftWorkedMinutes.clear();
      _driverDraftIncompleteReason.clear();
    }

    unawaited(() async {
      final accepted = await pointageProvider.submitDriverReportWithRetry(
        equipeId: equipeId,
        configOverride: pointageConfig ?? const PointageHoursConfig(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accepted
                ? trOf(context, 'report_sent')
                : trOf(context, 'pointage_hours_cannot_mark'),
          ),
          backgroundColor: accepted ? AppColors.green : Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }());
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final pointageProvider = context.watch<PointageProvider>();
    final auth = context.watch<AuthProvider>();
    final isRtl = locale.isArabic;
    final mobile = isMobile(context);
    if (!_nonWorkingLoadRequested) {
      _nonWorkingLoadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pointageProvider.ensureNonWorkingLoadedForDate(DateTime.now());
      });
    }
    final allTeams = getAllTeamsWithWorkers(emp.equipes, emp.employes);
    var teams = allTeams.where((t) => !pointageProvider.isEquipeNonWorking(t.equipeId)).toList();
    final shiftsProvider = context.watch<ShiftsProvider>();
    final today = DateTime.now();
    if (shiftsProvider.hasConfig) {
      final logicalToday = DateTime(today.year, today.month, today.day);
      final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
      teams = teams.where((t) {
        final shiftToday = shiftsProvider.getShiftForEquipe(t.equipeId, logicalToday);
        final shiftYesterday = shiftsProvider.getShiftForEquipe(t.equipeId, logicalYesterday);
        final useYesterdayNight = today.hour < 7 && shiftYesterday == ShiftType.night;
        final effectiveShift = useYesterdayNight ? shiftYesterday : shiftToday;
        return effectiveShift != ShiftType.rest;
      }).toList();
    }
    if (_selectedEquipeId != null && !teams.any((t) => t.equipeId == _selectedEquipeId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedEquipeId = null);
      });
    }
    final selectedTeam = teams.where((t) => t.equipeId == _selectedEquipeId).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    // Ne pas afficher les travailleurs en formation ou en congé approuvé
    // (ils sont considérés présents automatiquement dans les rapports)
    final workersDisplay = workers
        .where((e) => !_isHiddenForDriver(e, pointageProvider))
        .where((e) => !_isProtectedHigherPoste(e.poste))
        .toList();
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);
    final selectedEquipeList = emp.equipes.where((e) => e.id == _selectedEquipeId).toList();
    final selectedEquipe = selectedEquipeList.isEmpty ? null : selectedEquipeList.first;
    final now = DateTime.now();
    final logicalToday = DateTime(today.year, today.month, today.day);
    final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
    final shiftToday = selectedEquipe != null ? shiftsProvider.getShiftForEquipe(selectedEquipe.id, logicalToday) : null;
    final shiftYesterday = selectedEquipe != null ? shiftsProvider.getShiftForEquipe(selectedEquipe.id, logicalYesterday) : null;
    final useYesterdayNight = now.hour < 7 && shiftYesterday == ShiftType.night;
    final shiftForEquipe = useYesterdayNight ? shiftYesterday : shiftToday;
    final configDay = useYesterdayNight ? logicalYesterday : logicalToday;
    final config = getConfigForEquipeAndDate(selectedEquipe, configDay, shiftForEquipe);
    if (pointageProvider.ignoreTimeWindowsForTest && !pointageProvider.hasActiveTestCycle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PointageProvider>().startTestCycle(arrivalMinutes: 5);
      });
    }
    final inTestCycle = pointageProvider.ignoreTimeWindowsForTest && pointageProvider.hasActiveTestCycle;
    final hoursStatus = inTestCycle ? PointageHoursStatus.open : getPointageHoursStatus(now, config);
    final isWithinArrival = inTestCycle ? pointageProvider.isInTestArrivalPhase : config.canMarkArrivalNow(now);
    final isWithinDeparture = inTestCycle ? pointageProvider.isInTestDeparturePhase : config.canMarkDepartureNow(now);
    final lockTeamId = _selectedEquipeId ?? '';
    final dayKey = '${today.year}-${today.month}-${today.day}';
    final departureLockKey = '${lockTeamId}_$dayKey';
    // Verrou arrivée : uniquement après envoi chauffeur (pas après rapport chef).
    final arrivalReportLocked = _driverArrivalReportLocks.contains(departureLockKey);
    final departureReportLocked = _driverDepartureReportLocks.contains(departureLockKey);
    final isNightShiftBefore7 = useYesterdayNight;
    final yesterday = logicalYesterday;

    // canSendReport: tous les travailleurs affichés (hors congé/formation) ont un statut
    DriverPointageStatus effectiveDriverStatusFor(Employe e) {
      final draft = _driverDraftStatus[e.id];
      if (draft != null) return draft;
      final r = pointageProvider.getRecordForEmployee(e.id);
      return r?.driverStatus ?? DriverPointageStatus.unset;
    }
    DepartureStatus effectiveDepartureFor(Employe e) {
      final draft = _driverDraftDeparture[e.id];
      if (draft != null) return draft;
      final r = pointageProvider.getRecordForEmployee(e.id);
      return r?.departureStatus ?? DepartureStatus.unset;
    }
    final canSendReport = workersDisplay.isNotEmpty && workersDisplay.every((e) {
      final r = pointageProvider.getRecordForEmployee(e.id);
      final s = effectiveDriverStatusFor(e);
      if (s == DriverPointageStatus.unset) return false;
      final isPresent = s == DriverPointageStatus.present || s == DriverPointageStatus.enVehicule;
      if (!isPresent) return true; // absent doesn't require departure
      if (!isWithinDeparture) return true; // arrival phase: present is enough
      return (r?.arrivalMarkedAt != null || isWithinDeparture) &&
          effectiveDepartureFor(e) == DepartureStatus.finished;
    });
    final pendingDepartureCount = workersDisplay.where((e) {
      final s = effectiveDriverStatusFor(e);
      final isPresent = s == DriverPointageStatus.present || s == DriverPointageStatus.enVehicule;
      if (!isPresent) return false;
      return effectiveDepartureFor(e) != DepartureStatus.finished;
    }).length;
    final unmarkedCount = workersDisplay.where((e) {
      return effectiveDriverStatusFor(e) == DriverPointageStatus.unset;
    }).length;
    final unmarkedWorkers = workersDisplay.where((e) {
      return effectiveDriverStatusFor(e) == DriverPointageStatus.unset;
    }).toList();
    final lockAfterSend = isWithinDeparture ? departureReportLocked : arrivalReportLocked;
    if (_wasDriverSyncPending && !pointageProvider.driverReportSyncPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trOf(context, 'report_sent')),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      });
    }
    _wasDriverSyncPending = pointageProvider.driverReportSyncPending;

    Widget buildBody(PointageRecord? Function(String)? getRecordOverride) {
      return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'pointage_title'),
              style: TextStyle(fontSize: mobile ? 18 : 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'select_chef'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _PointageHoursBanner(context: context, status: hoursStatus, config: config),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isWithinDeparture ? Colors.orange.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isWithinDeparture ? Colors.orange.shade200 : Colors.green.shade200),
              ),
              child: Text(
                isWithinDeparture ? 'Mode actuel: Confirmation sortie' : 'Mode actuel: Pointage entrée',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isWithinDeparture ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),
            if (pointageProvider.driverReportSyncPending) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(context, 'pointage_sync_pending'),
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (mobile) _buildMobileChefSelector(context, teams),
            if (mobile) const SizedBox(height: 12),
            Expanded(
              child: mobile
                  ? _buildMobileWorkersSection(context, team, workersDisplay, borderColor, pointageProvider, auth, isWithinArrival, isWithinDeparture, config, getRecordOverride, lockAfterSend)
                  : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            tr(context, 'chefs_side_title'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const Divider(height: 1),
                        if (teams.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: teams.length,
                              itemBuilder: (context, i) {
                                final t = teams[i];
                                final isSelected = _selectedEquipeId == t.equipeId;
                                return Material(
                                  color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : null,
                                  child: ListTile(
                                    leading: const Icon(Icons.person, size: 20),
                                    title: Text('${t.equipeName} — ${t.chefName}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)),
                                      child: Text('${t.workers.length}', style: const TextStyle(fontSize: 12)),
                                    ),
                                    onTap: () => setState(() => _selectedEquipeId = t.equipeId),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildMobileWorkersSection(context, team, workersDisplay, borderColor, pointageProvider, auth, isWithinArrival, isWithinDeparture, config, getRecordOverride, lockAfterSend),
                  ),
                ],
              ),
            ),
            if (teams.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final equipes = <({
                    String equipeName,
                    String? chefName,
                    List<String> presentNames,
                    List<String> presentNoDepartureNames,
                    List<String> absentNames,
                    List<String?> absentReasons
                  })>[];
                  for (final t in teams) {
                    final workersForExport = t.workers
                        .where((e) => !_isHiddenForDriver(e, pointageProvider))
                        .toList();

                    final presentNames = <String>[];
                    final presentNoDepartureNames = <String>[];
                    final absentNames = <String>[];
                    final absentReasons = <String?>[];

                    for (final e in workersForExport) {
                      final record = pointageProvider.getRecordForEmployee(e.id);
                      final s = _driverStatusToState(pointageProvider.getDriverStatusForEmployee(e.id));

                      if (s == AttendanceState.present) {
                        // Sortie confirmée = P2 (sinon = seulement P1)
                        if (record?.departureStatus == DepartureStatus.finished) {
                          presentNames.add(e.nom);
                        } else {
                          presentNoDepartureNames.add(e.nom);
                        }
                      } else {
                        absentNames.add(e.nom);
                        absentReasons.add(record?.absenceReason);
                      }
                    }
                    equipes.add((
                      equipeName: t.equipeName,
                      chefName: t.chefName.isNotEmpty ? t.chefName : null,
                      presentNames: presentNames,
                      presentNoDepartureNames: presentNoDepartureNames,
                      absentNames: absentNames,
                      absentReasons: absentReasons,
                    ));
                  }
                  final filePath = await PointageExportService.shareDailyReportPdfForDriver(
                    date: DateTime.now(),
                    title: trOf(context, 'report_presence_title'),
                    signatureLabel: trOf(context, 'pointage_signature_driver'),
                    personName: auth.currentUser?.nom ?? '',
                    equipes: equipes,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${trOf(context, 'pointage_export_ok')}: $filePath'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.fixed,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    await _offerMobileShare(context, filePath, text: 'Rapport pointage chauffeur');
                  }
                },
                icon: const Icon(Icons.download, size: 20),
                label: Text(tr(context, 'pointage_download_report')),
              ),
            SizedBox(height: mobile ? 10 : 16),
            SafeArea(
              child: SizedBox(
                height: mobile ? 40 : 52,
                width: double.infinity,
                child: PrimaryButton(
                  label: tr(context, 'send_report_btn'),
                  onTap: (canSendReport &&
                          !lockAfterSend &&
                          !pointageProvider.driverReportSyncPending)
                      ? () => _sendReport(
                            config,
                            equipeId: _selectedEquipeId ?? '',
                            departurePhase: isWithinDeparture,
                            departureLockKey: departureLockKey,
                          )
                      : () async {
                          if (context.mounted && !canSendReport) {
                            String msg = trOf(context, 'pointage_hours_cannot_mark');
                            if (isWithinDeparture && pendingDepartureCount > 0) {
                              msg = 'Veuillez confirmer la sortie de $pendingDepartureCount personne(s) avant l\'envoi.';
                            } else if (unmarkedCount > 0) {
                              msg = 'Veuillez pointer tous les travailleurs avant l\'envoi ($unmarkedCount non pointé(s)).';
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Travailleurs non pointés'),
                                  content: SizedBox(
                                    width: 420,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$unmarkedCount personne(s) sans pointage:',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 10),
                                        Flexible(
                                          child: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: unmarkedWorkers
                                                  .map((w) => Padding(
                                                        padding: const EdgeInsets.only(bottom: 4),
                                                        child: Text('• ${w.nom}'),
                                                      ))
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Compris'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          } else if (context.mounted && lockAfterSend) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rapport déjà envoyé pour cette phase.'),
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          }
                        },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  if (isNightShiftBefore7) {
    return FutureBuilder<List<PointageRecord>>(
      future: pointageProvider.getPointageRecordsForDate(yesterday),
      builder: (context, snap) {
        final list = snap.data ?? [];
        PointageRecord? getRecord(String id) {
          try { return list.firstWhere((r) => r.employeId == id); } catch (_) { return null; }
        }
        return buildBody(getRecord);
      },
    );
  }
  return buildBody(null);
  }

  Widget _buildMobileChefSelector(BuildContext context, List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams) {
    if (teams.isEmpty) {
      return Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600]));
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = teams[i];
          final isSelected = _selectedEquipeId == t.equipeId;
          return FilterChip(
            label: Text('${t.equipeName} — ${t.chefName}', style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedEquipeId = t.equipeId),
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.25),
          );
        },
      ),
    );
  }

  Widget _buildMobileWorkersSection(
    BuildContext context,
    ({String equipeId, String equipeName, String chefName, List<Employe> workers})? team,
    List<Employe> workers,
    Color borderColor,
    PointageProvider pointageProvider,
    AuthProvider auth,
    bool isWithinArrival,
    bool isWithinDeparture,
    PointageHoursConfig pointageConfig,
    PointageRecord? Function(String)? getRecordOverride,
    bool lockAfterSendForSelectedTeam,
  ) {
    if (team == null) {
      return Center(child: Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    if (workers.isEmpty) {
      return Center(child: Text(tr(context, 'no_workers'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    PointageRecord? getRecord(String id) => getRecordOverride?.call(id) ?? pointageProvider.getRecordForEmployee(id);
    final titleLabel = '${tr(context, 'workers_of')} ${team.equipeName} (${team.chefName})';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(titleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...workers.map((e) {
            final record = getRecord(e.id) ??
                PointageRecord(
                  id: '',
                  employeId: e.id,
                  employeNom: e.nom,
                  employeCin: e.cin ?? '',
                  equipeId: team.equipeId,
                  equipeName: team.equipeName,
                  chefName: team.chefName,
                  status: AttendanceStatus.unmarked,
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                );
            final driverStatus = _driverDraftStatus[e.id] ?? record.driverStatus;
            final state = _driverStatusToState(driverStatus);
            final draftDep = _driverDraftDeparture[e.id];
            final recordForUi = draftDep == null
                ? record
                : record.copyWith(
                    departureStatus: draftDep,
                    overtimeMinutes: _driverDraftOvertimeMinutes[e.id] ?? record.overtimeMinutes,
                    workedMinutesBeforeStop: _driverDraftWorkedMinutes[e.id] ?? record.workedMinutesBeforeStop,
                    incompleteShiftReason: _driverDraftIncompleteReason[e.id] ?? record.incompleteShiftReason,
                  );
            final rawLocked = pointageProvider.isDriverLockedForEmployee(e.id);
            final isDriverPresent = state == AttendanceState.present;
            final locked = lockAfterSendForSelectedTeam
                ? true
                : (isWithinDeparture
                    ? (isDriverPresent ? false : rawLocked)
                    : false);
            // Dans la fenêtre de départ: afficher les chips départ si le travailleur est présent
            // (qu'il ait déjà une valeur ou non — pour permettre l'annulation aussi).
            final showDepartureChips = isWithinDeparture && !locked && isDriverPresent;
            // Dans la fenêtre d'arrivée uniquement (pas encore de départ): afficher Présent/Absent.
            final showArrivalChips = !isWithinDeparture && isWithinArrival && !locked;
            // Fenêtre de départ + travailleur non-marqué (driverStatus = unset): bouton "Non pointé"
            final showUnsetDepartureChip = isWithinDeparture && !locked &&
                driverStatus == DriverPointageStatus.unset;

            Widget chipsWidget;

            if (showDepartureChips) {
              chipsWidget = _DepartureChips(
                record: recordForUi,
                config: pointageConfig,
                onStillWorking: (int? workedMinutesBeforeStop, String? incompleteShiftReason) async {
                  setState(() {
                    _driverDraftDeparture[e.id] = DepartureStatus.stillWorking;
                    _driverDraftWorkedMinutes[e.id] = workedMinutesBeforeStop;
                    _driverDraftIncompleteReason[e.id] = incompleteShiftReason;
                  });
                },
                onFinished: (int? overtimeMinutes) async {
                  setState(() {
                    _driverDraftDeparture[e.id] = DepartureStatus.finished;
                    _driverDraftOvertimeMinutes[e.id] = overtimeMinutes;
                    _driverDraftWorkedMinutes.remove(e.id);
                    _driverDraftIncompleteReason.remove(e.id);
                  });
                },
                onCancel: () async {
                  setState(() {
                    _driverDraftDeparture[e.id] = DepartureStatus.unset;
                    _driverDraftOvertimeMinutes.remove(e.id);
                    _driverDraftWorkedMinutes.remove(e.id);
                    _driverDraftIncompleteReason.remove(e.id);
                  });
                },
                stillLabel: 'N\'a pas terminé',
                finishedLabel: tr(context, 'departure_finished'),
              );
            } else if (showUnsetDepartureChip) {
              // Travailleur non pointé à l'arrivée — dans la fenêtre de départ,
              // le chauffeur peut l'enregistrer absent ou confirmer qu'il n'a pas pointé.
              chipsWidget = _UnsetDepartureChip(
                onMarkAbsent: () async {
                  setState(() => _driverDraftStatus[e.id] = DriverPointageStatus.absent);
                },
              );
            } else if (showArrivalChips) {
              chipsWidget = DriverStatusChips(
                current: state,
                onSelect: (s) async {
                  setState(() => _driverDraftStatus[e.id] = _stateToDriverStatus(s));
                },
                presentLabel: tr(context, 'present'),
                absentLabel: tr(context, 'absent'),
                notInVehicleLabel: tr(context, 'not_in_vehicle'),
              );
            } else {
              chipsWidget = const SizedBox.shrink();
            }
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // < 520: chips (Présent/Absent + départ) passent sous le nom pour éviter RenderFlex overflow.
                    final narrow = constraints.maxWidth < 520;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              SmartAvatar(
                                imageUrl: e.photoUrl,
                                fallbackText: e.nom,
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (_departureStatusLabel(context, recordForUi) != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          _departureStatusLabel(context, recordForUi)!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: recordForUi.departureStatus == DepartureStatus.finished
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (recordForUi.departureStatus != DepartureStatus.unset && recordForUi.overtimeMinutes != null && recordForUi.overtimeMinutes! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '${tr(context, 'pointage_analysis_overtime_h')}: ${(recordForUi.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (locked)
                                Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                            ],
                          ),
                          const SizedBox(height: 10),
                          chipsWidget,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        SmartAvatar(
                          imageUrl: e.photoUrl,
                          fallbackText: e.nom,
                          radius: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (_departureStatusLabel(context, recordForUi) != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _departureStatusLabel(context, recordForUi)!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: recordForUi.departureStatus == DepartureStatus.finished
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (recordForUi.departureStatus != DepartureStatus.unset && recordForUi.overtimeMinutes != null && recordForUi.overtimeMinutes! > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${tr(context, 'pointage_analysis_overtime_h')}: ${(recordForUi.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (locked)
                          Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        chipsWidget,
                      ],
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DepartureChips extends StatelessWidget {
  final PointageRecord record;
  final PointageHoursConfig config;
  final void Function(int? workedMinutesBeforeStop, String? incompleteShiftReason) onStillWorking;
  final void Function(int? overtimeMinutes) onFinished;
  /// Appelé quand l'utilisateur re-appuie sur un bouton déjà sélectionné pour l'annuler.
  final VoidCallback onCancel;
  final String stillLabel;
  final String finishedLabel;

  const _DepartureChips({
    required this.record,
    required this.config,
    required this.onStillWorking,
    required this.onFinished,
    required this.onCancel,
    required this.stillLabel,
    required this.finishedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isStill = record.departureStatus == DepartureStatus.stillWorking;
    final isFinished = record.departureStatus == DepartureStatus.finished;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // ── Bouton "N'a pas terminé" ────────────────────────────────────
        FilterChip(
          label: Text(stillLabel, style: const TextStyle(fontSize: 12)),
          selected: isStill,
          selectedColor: Colors.orange.shade100,
          checkmarkColor: Colors.orange.shade800,
          onSelected: (_) async {
            // Re-appui → annulation
            if (isStill) {
              onCancel();
              return;
            }
            final workedHoursCtrl = TextEditingController();
            final reasonCtrl = TextEditingController();
            final data = await showDialog<({int? workedMinutes, String? reason})>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(stillLabel),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: workedHoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Heures travaillées',
                        hintText: 'Ex: 5.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Raison (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                  ),
                  FilledButton(
                    onPressed: () {
                      final hours = double.tryParse(workedHoursCtrl.text.trim().replaceAll(',', '.'));
                      final workedMinutes = (hours != null && hours >= 0) ? (hours * 60).round() : null;
                      final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
                      Navigator.pop(ctx, (workedMinutes: workedMinutes, reason: reason));
                    },
                    child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                  ),
                ],
              ),
            );
            if (data != null) onStillWorking(data.workedMinutes, data.reason);
          },
        ),
        // ── Bouton "Fin du travail" — confirmation directe sans dialogue ─
        FilterChip(
          label: Text(finishedLabel, style: const TextStyle(fontSize: 12)),
          selected: isFinished,
          selectedColor: Colors.green.shade100,
          checkmarkColor: Colors.green.shade800,
          onSelected: (_) {
            // Re-appui → annulation
            if (isFinished) {
              onCancel();
              return;
            }
            // Confirmation directe, pas de dialogue de saisie
            onFinished(null);
          },
        ),
      ],
    );
  }
}

/// Chip affiché pour un travailleur non pointé pendant la fenêtre de départ.
/// Permet au chauffeur de l'enregistrer comme absent (n'a pas pointé).
class _UnsetDepartureChip extends StatelessWidget {
  final VoidCallback onMarkAbsent;

  const _UnsetDepartureChip({required this.onMarkAbsent});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
      label: Text(
        'Non pointé — Marquer absent',
        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
      ),
      backgroundColor: Colors.orange.shade50,
      side: BorderSide(color: Colors.orange.shade300),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Non pointé'),
            content: const Text(
              'Ce travailleur n\'a pas été pointé à l\'arrivée.\nVoulez-vous le marquer comme absent ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Marquer absent'),
              ),
            ],
          ),
        );
        if (confirmed == true) onMarkAbsent();
      },
    );
  }
}

class _PointageHoursBanner extends StatelessWidget {
  final BuildContext context;
  final PointageHoursStatus status;
  final PointageHoursConfig config;

  const _PointageHoursBanner({required this.context, required this.status, required this.config});

  @override
  Widget build(BuildContext context) {
    final String msg;
    final Color bg;
    final now = DateTime.now();
    if (status == PointageHoursStatus.open) {
      if (config.isWithinArrivalWindow(now)) {
        msg = tr(this.context, 'pointage_arrival_window').replaceFirst('%s', config.arrivalWindowFormatted());
      } else {
        msg = tr(this.context, 'pointage_departure_window').replaceFirst('%s', config.departureWindowFormatted());
      }
      bg = Colors.green.shade50;
    } else if (status == PointageHoursStatus.notYetOpen) {
      msg = tr(this.context, 'pointage_hours_not_yet').replaceFirst('%s', config.startTimeFormatted());
      bg = Colors.orange.shade100;
    } else {
      msg = config.isNightShift
          ? tr(this.context, 'pointage_night_shift_closed')
          : tr(this.context, 'pointage_hours_closed').replaceFirst('%s', config.endTimeFormatted());
      bg = Colors.red.shade50;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status == PointageHoursStatus.open ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(status == PointageHoursStatus.open ? Icons.check_circle : Icons.schedule, size: 20, color: status == PointageHoursStatus.open ? Colors.green.shade700 : Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey[800]))),
        ],
      ),
    );
  }
}
