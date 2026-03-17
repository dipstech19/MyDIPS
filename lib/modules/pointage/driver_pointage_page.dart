import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  static AttendanceState _driverStatusToState(DriverPointageStatus s) {
    switch (s) {
      case DriverPointageStatus.present:
        return AttendanceState.present;
      case DriverPointageStatus.absent:
        return AttendanceState.absent;
      case DriverPointageStatus.enVehicule:
        return AttendanceState.notInVehicle;
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
      case AttendanceState.notInVehicle:
        return DriverPointageStatus.enVehicule;
      case AttendanceState.unmarked:
        return DriverPointageStatus.unset;
    }
  }

  Future<void> _sendReport(PointageHoursConfig? pointageConfig) async {
    final pointageProvider = context.read<PointageProvider>();
    final ok = await pointageProvider.submitDriverReport(configOverride: pointageConfig);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trOf(context, 'report_sent')),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trOf(context, 'pointage_hours_cannot_mark')),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
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
      teams = teams.where((t) => shiftsProvider.getShiftForEquipe(t.equipeId, today) != ShiftType.rest).toList();
    }
    // Hide ROBO/Repos teams entirely (no pointage on those days)
    teams = teams.where((t) {
      final name = t.equipeName.trim().toLowerCase();
      return !(name.contains('robo') || name.contains('repos') || name.contains('repo'));
    }).toList();
    if (_selectedEquipeId != null && !teams.any((t) => t.equipeId == _selectedEquipeId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedEquipeId = null);
      });
    }
    final selectedTeam = teams.where((t) => t.equipeId == _selectedEquipeId).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    // Ne pas afficher les travailleurs en formation (ils sont considérés présents dans les rapports)
    final workersDisplay = workers.where((e) {
      final r = pointageProvider.getRecordForEmployee(e.id);
      return r?.adminFinalStatus != AttendanceStatus.training;
    }).toList();
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);
    final selectedEquipeList = emp.equipes.where((e) => e.id == _selectedEquipeId).toList();
    final selectedEquipe = selectedEquipeList.isEmpty ? null : selectedEquipeList.first;
    final shiftForEquipe = selectedEquipe != null ? shiftsProvider.getShiftForEquipe(selectedEquipe.id, today) : null;
    final config = getConfigForEquipeAndDate(selectedEquipe, today, shiftForEquipe);
    final now = DateTime.now();
    final hoursStatus = getPointageHoursStatus(now, config);
    final ignoreTime = pointageProvider.ignoreTimeWindowsForTest;
    final isWithinArrival = ignoreTime || config.canMarkArrivalNow(now);
    final isWithinDeparture = ignoreTime || config.canMarkDepartureNow(now);
    final isNightShiftBefore7 = shiftForEquipe == ShiftType.night && now.hour < 7;
    final yesterday = today.subtract(const Duration(days: 1));

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
            const SizedBox(height: 12),
            if (mobile) _buildMobileChefSelector(context, teams),
            if (mobile) const SizedBox(height: 12),
            Expanded(
              child: mobile
                  ? _buildMobileWorkersSection(context, team, workersDisplay, borderColor, pointageProvider, auth, isWithinArrival, isWithinDeparture, config, getRecordOverride)
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
                    child: _buildMobileWorkersSection(context, team, workersDisplay, borderColor, pointageProvider, auth, isWithinArrival, isWithinDeparture, config, getRecordOverride),
                  ),
                ],
              ),
            ),
            if (teams.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  final equipes = <({String equipeName, List<String> presentNames, List<String> absentNames, List<String?> absentReasons})>[];
                  for (final t in teams) {
                    final workersForExport = t.workers.where((e) => pointageProvider.getRecordForEmployee(e.id)?.adminFinalStatus != AttendanceStatus.training).toList();
                    final presentNames = workersForExport.where((e) {
                      final s = _driverStatusToState(pointageProvider.getDriverStatusForEmployee(e.id));
                      return s == AttendanceState.present || s == AttendanceState.notInVehicle;
                    }).map((e) => e.nom).toList();
                    final absentWorkers = workersForExport.where((e) {
                      final s = _driverStatusToState(pointageProvider.getDriverStatusForEmployee(e.id));
                      return s != AttendanceState.present && s != AttendanceState.notInVehicle;
                    }).toList();
                    final absentNames = absentWorkers.map((e) => e.nom).toList();
                    final absentReasons = absentWorkers.map((e) => pointageProvider.getRecordForEmployee(e.id)?.absenceReason).toList();
                    equipes.add((
                      equipeName: t.equipeName,
                      presentNames: presentNames,
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
                  onTap: isWithinArrival ? () => _sendReport(config) : null,
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
            final driverStatus = record.driverStatus;
            final state = _driverStatusToState(driverStatus);
            final locked = record.driverLocked;
            Widget chipsWidget;
            if (isWithinArrival) {
              chipsWidget = DriverStatusChips(
                current: state,
                onSelect: (locked || !isWithinArrival) ? (_) {} : (s) async {
                  final ok = await pointageProvider.markDriverAttendance(
                    employeId: e.id,
                    employeNom: e.nom,
                    employeCin: e.cin ?? '',
                    equipeId: team.equipeId,
                    equipeName: team.equipeName,
                    chefName: team.chefName,
                    driverStatus: _stateToDriverStatus(s),
                    driverId: auth.currentUser?.id,
                    configOverride: pointageConfig,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                    );
                  }
                },
                presentLabel: tr(context, 'present'),
                absentLabel: tr(context, 'absent'),
                notInVehicleLabel: tr(context, 'not_in_vehicle'),
              );
            } else if (isWithinDeparture) {
              chipsWidget = _DepartureChips(
                record: record,
                config: pointageConfig,
                onStillWorking: () async {
                  final ok = await pointageProvider.setDepartureStatus(
                    record: record,
                    status: DepartureStatus.stillWorking,
                    configOverride: pointageConfig,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                    );
                  }
                },
                onFinished: (int? overtimeMinutes) async {
                  final ok = await pointageProvider.setDepartureStatus(
                    record: record,
                    status: DepartureStatus.finished,
                    overtimeMinutes: overtimeMinutes,
                    configOverride: pointageConfig,
                  );
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                    );
                  }
                },
                stillLabel: tr(context, 'departure_still_working'),
                finishedLabel: tr(context, 'departure_finished'),
                overtimeLabel: tr(context, 'overtime_minutes'),
                overtimeHint: tr(context, 'overtime_minutes_hint'),
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
                    final narrow = constraints.maxWidth < 380;
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
                                    if (record.departureStatus != DepartureStatus.unset && record.overtimeMinutes != null && record.overtimeMinutes! > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '${tr(context, 'pointage_analysis_overtime_h')}: ${(record.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
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
                              if (record.departureStatus != DepartureStatus.unset && record.overtimeMinutes != null && record.overtimeMinutes! > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '${tr(context, 'pointage_analysis_overtime_h')}: ${(record.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
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
  final VoidCallback onStillWorking;
  final void Function(int? overtimeMinutes) onFinished;
  final String stillLabel;
  final String finishedLabel;
  final String overtimeLabel;
  final String overtimeHint;

  const _DepartureChips({
    required this.record,
    required this.config,
    required this.onStillWorking,
    required this.onFinished,
    required this.stillLabel,
    required this.finishedLabel,
    required this.overtimeLabel,
    required this.overtimeHint,
  });

  @override
  Widget build(BuildContext context) {
    final isStill = record.departureStatus == DepartureStatus.stillWorking;
    final isFinished = record.departureStatus == DepartureStatus.finished;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        FilterChip(
          label: Text(stillLabel, style: const TextStyle(fontSize: 12)),
          selected: isStill,
          onSelected: (_) => onStillWorking(),
        ),
        FilterChip(
          label: Text(finishedLabel, style: const TextStyle(fontSize: 12)),
          selected: isFinished,
          onSelected: (_) => onFinished(0),
        ),
      ],
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
