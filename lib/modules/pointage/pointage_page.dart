import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/smart_avatar.dart';
import '../../features/chef/screens/chef_home_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../modules/employees/models/employe_model.dart';
import '../../modules/employees/models/equipe_model.dart';
import '../../modules/employees/employees_provider.dart';
import 'pointage_data.dart';
import 'pointage_provider.dart';
import 'absence_reasons_provider.dart';
import 'pointage_hours_config.dart';
import '../shifts/shifts_provider.dart';
import '../shifts/models/shift_models.dart';
import 'models/pointage_model.dart';
import 'services/pointage_export_service.dart';

/// Badge صغير لحالة السائق أو الشاف
class _DriverChefBadge extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool isDriver;

  const _DriverChefBadge({required this.label, this.value, required this.isDriver});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    if (isDriver) {
      final s = value as DriverPointageStatus?;
      if (s == null || s == DriverPointageStatus.unset) {
        text = '—';
        color = Colors.grey;
      } else {
        text = s == DriverPointageStatus.present ? 'P' : s == DriverPointageStatus.absent ? 'A' : 'V';
        color = s == DriverPointageStatus.present ? Colors.green : s == DriverPointageStatus.absent ? Colors.red : Colors.orange;
      }
    } else {
      final s = value as ChefPointageStatus?;
      if (s == null || s == ChefPointageStatus.unset) {
        text = '—';
        color = Colors.grey;
      } else {
        text = s == ChefPointageStatus.present ? 'P' : 'A';
        color = s == ChefPointageStatus.present ? Colors.green : Colors.red;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text('$label:$text', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ReconciledChip extends StatelessWidget {
  final ReconciledStatus status;

  const _ReconciledChip({required this.status});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    switch (status) {
      case ReconciledStatus.confirmedPresent:
        text = '✓ Présent';
        color = Colors.green;
        break;
      case ReconciledStatus.confirmedAbsent:
        text = '✓ Absent';
        color = Colors.red;
        break;
      case ReconciledStatus.discrepancy:
        text = '⚠ Désaccord';
        color = Colors.orange;
        break;
      case ReconciledStatus.pending:
        text = '…';
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Pointage: للشاف — عماله مباشرة. للأدمن — نفس تنظيم السائق + تقرير الحضور أسفل.
class PointagePage extends StatefulWidget {
  const PointagePage({super.key});

  @override
  State<PointagePage> createState() => _PointagePageState();
}

enum _AdminPointageView { workers, report, analysis }

class _PointagePageState extends State<PointagePage> {
  String? _selectedEquipeIdAdmin;
  DateTime? _reportViewDate;
  _AdminPointageView _adminContentView = _AdminPointageView.workers;

  AttendanceState _convertStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AttendanceState.present;
      case AttendanceStatus.absent:
        return AttendanceState.absent;
      case AttendanceStatus.notInVehicle:
        return AttendanceState.notInVehicle;
      case AttendanceStatus.unmarked:
        return AttendanceState.unmarked;
      case AttendanceStatus.training:
        return AttendanceState.present; // en formation = considéré présent pour l'affichage
    }
  }

  AttendanceStatus _convertState(AttendanceState state) {
    switch (state) {
      case AttendanceState.present:
        return AttendanceStatus.present;
      case AttendanceState.absent:
        return AttendanceStatus.absent;
      case AttendanceState.notInVehicle:
        return AttendanceStatus.notInVehicle;
      case AttendanceState.unmarked:
        return AttendanceStatus.unmarked;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final pointageProvider = context.watch<PointageProvider>();
    final isDirecteur = auth.isDirecteur;
    final isChefEquipe = auth.isChefEquipe;
    final isRtl = locale.isArabic;

    final showDriverList = isDirecteur;
    final isChefOnly = isChefEquipe && !isDirecteur;
    final site = context.watch<SiteProvider>();
    final filteredEquipes = SiteId.filterBySite(
      emp.equipes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );
    final filteredEmployes = SiteId.filterBySite(
      emp.employes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );
    if (isChefOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pointageProvider.ensureNonWorkingLoadedForDate(DateTime.now());
      });
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: isChefOnly
          ? _buildChefContent(context, auth, filteredEquipes, filteredEmployes, pointageProvider)
          : isDirecteur
              ? _buildAdminContent(context, filteredEquipes, filteredEmployes, pointageProvider)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[700], size: 28),
                          const SizedBox(width: 12),
                          Text(
                            tr(context, 'pointage_title'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'pointage_subtitle_admin'),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      _PointageCard(
                        icon: Icons.people,
                        title: tr(context, 'my_team'),
                        subtitle: tr(context, 'my_team_subtitle'),
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Theme(
                              data: appTheme,
                              child: Directionality(
                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                child: const ChefHomeScreen(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (showDriverList) const SizedBox(height: 12),
                      if (showDriverList)
                        _PointageCard(
                          icon: Icons.list_alt,
                          title: tr(context, 'today_list'),
                          subtitle: tr(context, 'today_list_subtitle'),
                          color: const Color(0xFF10B981),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Theme(
                                data: appTheme,
                                child: Directionality(
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                  child: const DriverHomeScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAdminContent(
    BuildContext context,
    List<Equipe> equipes,
    List<Employe> employes,
    PointageProvider pointageProvider,
  ) {
    final mobile = isMobile(context);
    final now = DateTime.now();
    final viewDate = _reportViewDate ?? now;
    final isViewingToday = _reportViewDate == null ||
        (_reportViewDate!.year == now.year && _reportViewDate!.month == now.month && _reportViewDate!.day == now.day);
    final recordsForDate = isViewingToday ? pointageProvider.todayPointage : pointageProvider.pointageByDate;
    final recordByEmployeId = <String, PointageRecord>{};
    for (final r in recordsForDate) recordByEmployeId[r.employeId] = r;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      pointageProvider.ensureNonWorkingLoadedForDate(viewDate);
    });
    final nonWorkingIds = pointageProvider.nonWorkingEquipeIds;
    final shiftsProvider = context.watch<ShiftsProvider>();
    final effectiveNonWorkingIds = <String>{...nonWorkingIds};
    if (shiftsProvider.hasConfig) {
      for (final eid in shiftsProvider.config!.equipeIds) {
        if (eid.isEmpty) continue;
        if (shiftsProvider.getShiftForEquipe(eid, viewDate) == ShiftType.rest) {
          effectiveNonWorkingIds.add(eid);
        }
      }
    }
    bool isRoboEquipe(Equipe eq) {
      final name = eq.nom.trim().toLowerCase();
      if (name.contains('robo') || name.contains('repos') || name.contains('repo')) return true;
      final shift = shiftsProvider.getShiftForEquipe(eq.id, viewDate);
      return shift == ShiftType.rest;
    }
    final workingEquipes = equipes
        .where((e) => e.chefId.isNotEmpty && !effectiveNonWorkingIds.contains(e.id) && !isRoboEquipe(e))
        .toList();
    final teams = getAllTeamsWithWorkersConsideringTemp(workingEquipes, employes, recordByEmployeId);
    // Groupe spécial: employés "hors équipe" (pointage admin uniquement)
    bool isChefEquipePoste(String poste) {
      final p = poste.trim().toLowerCase();
      return p == "chef d'équipe" || p == "chef d’equipe" || p == "chef d'equipe" || p == "chef d equipe";
    }

    // Tous les membres de toutes les équipes (y compris repos/ROBO) ne sont pas "hors équipe"
    final usedIdsInAnyEquipe = <String>{
      for (final eq in equipes) ...[
        if (eq.chefId.isNotEmpty) eq.chefId,
        ...eq.membreIds,
      ]
    };
    var horsEquipeWorkers = employes
        .where((e) => e.statut == EmployeStatut.enService && !usedIdsInAnyEquipe.contains(e.id) && !isChefEquipePoste(e.poste))
        .toList();
    horsEquipeWorkers = horsEquipeWorkers
        .where((e) {
          final rec = recordByEmployeId[e.id];
          if (rec == null || !rec.tempAssigned) return true;
          return rec.originalEquipeId != 'hors_equipe';
        })
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    final allTeams = [
      if (horsEquipeWorkers.isNotEmpty)
        (equipeId: 'hors_equipe', equipeName: 'Hors équipe', chefName: 'Admin', workers: horsEquipeWorkers),
      ...teams,
    ];

    if (_selectedEquipeIdAdmin == null ||
        (allTeams.isNotEmpty && !allTeams.any((t) => t.equipeId == _selectedEquipeIdAdmin))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedEquipeIdAdmin = allTeams.isEmpty ? null : allTeams.first.equipeId);
      });
    }

    final selectedTeam = allTeams.where((t) => t.equipeId == _selectedEquipeIdAdmin).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);

    final nonWorkingIdsEffective = effectiveNonWorkingIds.toList();

    PointageRecord? getRecord(String employeId) {
      if (isViewingToday) return pointageProvider.getRecordForEmployee(employeId);
      final list = pointageProvider.pointageByDate;
      final l = list.where((p) => p.employeId == employeId).toList();
      return l.isEmpty ? null : l.first;
    }

    final presentByChef = <String, List<Employe>>{};
    final absentByChef = <String, List<Employe>>{};
    final notInVehicleByChef = <String, List<Employe>>{};
    final notWorkingByChef = <String, List<Employe>>{};
    String teamChefKey(String equipeName, String chefName) => '$equipeName — $chefName';
    for (final t in allTeams) {
      final key = teamChefKey(t.equipeName, t.chefName);
      final isNonWorking = nonWorkingIdsEffective.contains(t.equipeId);
      for (final e in t.workers) {
        if (isNonWorking) {
          notWorkingByChef.putIfAbsent(key, () => []).add(e);
          continue;
        }
        final record = getRecord(e.id);
        final isPresent = record?.isFinalPresent ?? false;
        if (isPresent) {
          presentByChef.putIfAbsent(key, () => []).add(e);
        } else {
          absentByChef.putIfAbsent(key, () => []).add(e);
        }
      }
    }

    final reportSentMsg = tr(context, 'report_sent');
    void sendReport() async {
      int totalPresent = 0;
      int totalAbsent = 0;
      int totalEmployees = 0;

      for (final t in allTeams) {
        if (nonWorkingIdsEffective.contains(t.equipeId)) continue;
        for (final e in t.workers) {
          totalEmployees++;
          final record = getRecord(e.id);
          if (record?.isFinalPresent ?? false) {
            totalPresent++;
          } else {
            totalAbsent++;
          }
        }
      }

      await pointageProvider.submitDailyReport(
        equipeId: 'admin',
        equipeName: 'Admin Report',
        chefId: 'admin',
        chefName: 'Admin',
        totalEmployees: totalEmployees,
        presentCount: totalPresent,
        absentCount: totalAbsent,
        notInVehicleCount: 0,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reportSentMsg), backgroundColor: Colors.green, behavior: SnackBarBehavior.fixed),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'pointage_title'), style: TextStyle(fontSize: mobile ? 16 : 20, fontWeight: FontWeight.bold)),
                    if (!mobile) ...[
                      const SizedBox(height: 4),
                      Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _reportViewDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: now.add(const Duration(days: 1)),
                  );
                  if (picked != null && mounted) {
                    setState(() => _reportViewDate = picked);
                    pointageProvider.selectReportDate(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(isViewingToday ? 'Aujourd\'hui' : '${_reportViewDate!.day}/${_reportViewDate!.month}/${_reportViewDate!.year}'),
              ),
              if (!isViewingToday)
                TextButton(
                  onPressed: () {
                    setState(() => _reportViewDate = null);
                    pointageProvider.selectReportDate(null);
                  },
                  child: const Text('Aujourd\'hui'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showFormationDialog(
                  context,
                  pointageProvider: pointageProvider,
                  teams: allTeams,
                  initialDate: _reportViewDate ?? now,
                  onSuccess: () => setState(() {}),
                ),
                icon: const Icon(Icons.school, size: 18),
                label: Text(tr(context, 'pointage_formation_btn')),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text('Test créneaux', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  const SizedBox(width: 4),
                  Switch(
                    value: pointageProvider.ignoreTimeWindowsForTest,
                    onChanged: (v) {
                      pointageProvider.setIgnoreTimeWindowsForTest(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (mobile) _buildAdminMobileChefSelector(context, allTeams),
          if (mobile) const SizedBox(height: 12),
          Expanded(
            flex: mobile ? 8 : 5,
            child: mobile
                ? _buildAdminMainContent(
                    context,
                    team: team,
                    workers: workers,
                    borderColor: borderColor,
                    pointageProvider: pointageProvider,
                    getRecord: getRecord,
                    teams: allTeams,
                    nonWorkingIds: nonWorkingIdsEffective,
                    viewDate: viewDate,
                    presentByChef: presentByChef,
                    absentByChef: absentByChef,
                    notInVehicleByChef: notInVehicleByChef,
                    notWorkingByChef: notWorkingByChef,
                  )
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
                              child: Text(tr(context, 'chefs_side_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const Divider(height: 1),
                            if (allTeams.isEmpty)
                              Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600])))
                            else
                              Expanded(
                                child: ListView.builder(
                                  itemCount: allTeams.length,
                                  itemBuilder: (context, i) {
                                    final t = allTeams[i];
                                    final isSelected = _selectedEquipeIdAdmin == t.equipeId;
                                    final isNonWorking = nonWorkingIdsEffective.contains(t.equipeId);
                                    final shiftLabel = t.equipeId == 'hors_equipe'
                                        ? null
                                        : shiftsProvider.getShiftForEquipe(t.equipeId, viewDate)?.shortLabel;
                                    return Material(
                                      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : null,
                                      child: ListTile(
                                        leading: const Icon(Icons.person, size: 20),
                                        title: Text(
                                          '${t.equipeName} — ${t.chefName}${shiftLabel != null ? ' ($shiftLabel)' : ''}',
                                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(isNonWorking ? Icons.work_off : Icons.work_outline, size: 20, color: isNonWorking ? Colors.orange : Colors.grey),
                                              tooltip: tr(context, 'pointage_team_not_working_hint'),
                                              onPressed: () async {
                                                await pointageProvider.setEquipeNonWorkingForDate(viewDate, t.equipeId, !isNonWorking);
                                                if (mounted) setState(() {});
                                              },
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)),
                                              child: Text('${t.workers.length}', style: const TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                        onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
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
                    child: _buildAdminMainContent(
                      context,
                      team: team,
                      workers: workers,
                      borderColor: borderColor,
                      pointageProvider: pointageProvider,
                      getRecord: getRecord,
                      teams: allTeams,
                      nonWorkingIds: nonWorkingIdsEffective,
                      viewDate: viewDate,
                      presentByChef: presentByChef,
                      absentByChef: absentByChef,
                      notInVehicleByChef: notInVehicleByChef,
                      notWorkingByChef: notWorkingByChef,
                    ),
                  ),
                ],
              ),
          ),
          SizedBox(height: mobile ? 10 : 12),
          SizedBox(
            height: mobile ? 48 : 48,
            width: double.infinity,
            child: PrimaryButton(label: tr(context, 'send_report_btn'), onTap: sendReport),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              if (team != null) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    if (team == null) return;
                    final key = teamChefKey(team!.equipeName, team!.chefName);
                    final presentNames = (presentByChef[key] ?? []).map((e) => e.nom).toList();
                    final absentWorkers = absentByChef[key] ?? [];
                    final absentNames = absentWorkers.map((e) => e.nom).toList();
                    final absentReasons = absentWorkers.map((e) => getRecord(e.id)?.absenceReason).toList();
                    final filePath = await PointageExportService.shareDailyReportPdf(
                      date: viewDate,
                      title: trOf(context, 'report_presence_title'),
                      presentNames: presentNames,
                      absentNames: absentNames,
                      absentReasons: absentReasons,
                      signatureLabel: trOf(context, 'pointage_signature_chef'),
                      personName: team!.chefName,
                      equipeName: team!.equipeName,
                    );
                    if (mounted) {
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
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(tr(context, 'pointage_download_pdf_equipe'))),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => _showExcelExportDialog(context, teams, equipes, employes, pointageProvider),
                icon: const Icon(Icons.table_chart, size: 18),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(tr(context, 'pointage_download_excel'))),
              ),
            ],
          ),
          SizedBox(height: mobile ? 12 : 16),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _adminContentView = _adminContentView == _AdminPointageView.report ? _AdminPointageView.workers : _AdminPointageView.report),
                    icon: Icon(_adminContentView == _AdminPointageView.report ? Icons.assignment : Icons.assignment_outlined, size: 18),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(tr(context, 'report_presence_title'))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _adminContentView == _AdminPointageView.report ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _adminContentView = _adminContentView == _AdminPointageView.analysis ? _AdminPointageView.workers : _AdminPointageView.analysis),
                    icon: Icon(_adminContentView == _AdminPointageView.analysis ? Icons.analytics : Icons.analytics_outlined, size: 18),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(tr(context, 'pointage_analysis_title'))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _adminContentView == _AdminPointageView.analysis ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              tr(context, 'pointage_tap_to_open_hint'),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _showExcelExportDialog(
    BuildContext context,
    List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams,
    List<Equipe> equipes,
    List<Employe> employes,
    PointageProvider pointageProvider,
  ) async {
    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, 1);
    DateTime end = now;
    if (!context.mounted) return;
    final picked = await showDialog<({DateTime start, DateTime end})>(
      context: context,
      builder: (ctx) {
        return _ExcelDateRangeDialog(initialStart: start, initialEnd: end);
      },
    );
    if (picked == null || !mounted) return;
    start = picked.start;
    end = picked.end;
    if (start.isAfter(end)) {
      final t = start;
      start = end;
      end = t;
    }
    final records = await pointageProvider.getPointageInDateRange(start, end);
    final employees = <({String id, String nom, String equipeName, String? equipeId})>[];
    // IMPORTANT: les renforts doivent être attribués à l'équipe d'origine dans l'Excel.
    // Donc on construit la liste des employés depuis l'appartenance "réelle" (equipes.membreIds / chefId),
    // et on n'utilise pas la liste temp-aware (teams) pour déterminer equipeId.
    final seen = <String>{};
    for (final eq in equipes) {
      if (eq.id.isEmpty) continue;
      final chefName = getChefName(employes, eq.chefId);
      final label = '${eq.nom} — $chefName';
      final ids = <String>{...eq.membreIds, if (eq.chefId.isNotEmpty) eq.chefId};
      for (final id in ids) {
        if (!seen.add(id)) continue;
        final empList = employes.where((e) => e.id == id).toList();
        if (empList.isEmpty) continue;
        final w = empList.first;
        employees.add((id: w.id, nom: w.nom, equipeName: label, equipeId: eq.id));
      }
    }
    // Garder aussi les employés hors équipe (équipeId = null) s'ils sont visibles dans l'écran.
    for (final t in teams.where((t) => t.equipeId == 'hors_equipe')) {
      for (final w in t.workers) {
        if (!seen.add(w.id)) continue;
        employees.add((id: w.id, nom: w.nom, equipeName: '${t.equipeName} — ${t.chefName}', equipeId: null));
      }
    }
    final reasonConfigs = context.read<AbsenceReasonsProvider>().reasons;
    final shiftsProvider = context.read<ShiftsProvider>();
    final isRestDay = shiftsProvider.hasConfig
        ? (DateTime date, String equipeId) =>
            shiftsProvider.getShiftForEquipe(equipeId, date) == ShiftType.rest
        : null;
    final rows = PointageExportService.computeExcelRows(
      startDate: start,
      endDate: end,
      employees: employees,
      records: records,
      reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
      isRestDay: isRestDay,
    );
    final filePath = await PointageExportService.saveAndOpenExcel(
      startDate: start,
      endDate: end,
      rows: rows,
      reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${trOf(context, 'pointage_export_excel_saved')}: $filePath'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildAdminMobileChefSelector(
    BuildContext context,
    List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams,
  ) {
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
          final isSelected = _selectedEquipeIdAdmin == t.equipeId;
          return FilterChip(
            label: Text('${t.equipeName} — ${t.chefName}', style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedEquipeIdAdmin = t.equipeId),
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.25),
          );
        },
      ),
    );
  }

  Widget _buildAdminWorkersColumn(
    BuildContext context,
    ({String equipeId, String equipeName, String chefName, List<Employe> workers})? team,
    List<Employe> workers,
    Color borderColor,
    PointageProvider pointageProvider,
    PointageRecord? Function(String) getRecord, {
    required List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> allTeams,
    required DateTime viewDate,
  }) {
    if (team == null) {
      return Center(child: Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    if (workers.isEmpty) {
      return Center(child: Text(tr(context, 'no_workers'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    final mobile = isMobile(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView(
        padding: EdgeInsets.all(mobile ? 14 : 12),
        children: [
          Text('${tr(context, 'workers_of')} ${team.equipeName} (${team.chefName})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 16 : 15)),
          SizedBox(height: mobile ? 10 : 8),
          ...workers.map((e) {
            final record = getRecord(e.id);
            final reconciled = record?.reconciledStatus ?? ReconciledStatus.pending;
            final isPresent = record?.isFinalPresent ?? false;
            final isAlreadyFormation = record?.adminFinalStatus == AttendanceStatus.training;
            return Card(
              margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 12 : 10),
                child: Row(
                  children: [
                    SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: mobile ? 22 : 18),
                    SizedBox(width: mobile ? 14 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (record?.tempAssigned == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Renfort', style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
                                ),
                              _DriverChefBadge(
                                label: 'S',
                                value: record?.driverStatus,
                                isDriver: true,
                              ),
                              _DriverChefBadge(
                                label: 'C',
                                value: record?.chefStatus,
                                isDriver: false,
                              ),
                              _ReconciledChip(status: reconciled),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isPresent ? tr(context, 'present') : tr(context, 'absent'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () async {
                                if (record != null) {
                                  await pointageProvider.setAdminOverride(record.id, AttendanceStatus.present);
                                } else {
                                  await pointageProvider.setAdminOverrideForEmployee(
                                    employeId: e.id,
                                    employeNom: e.nom,
                                    employeCin: e.cin,
                                    equipeId: team.equipeId,
                                    equipeName: team.equipeName,
                                    chefName: team.chefName,
                                    status: AttendanceStatus.present,
                                    viewDate: _reportViewDate,
                                  );
                                }
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 6 : 4),
                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(6)),
                                child: Text(tr(context, 'present'), style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.green.shade800)),
                              ),
                            ),
                            SizedBox(width: mobile ? 8 : 6),
                            InkWell(
                              onTap: () async {
                                final reasonId = await _showAbsenceReasonDialog(context);
                                if (reasonId == null || !mounted) return;
                                if (record != null) {
                                  await pointageProvider.setAdminOverride(record.id, AttendanceStatus.absent, absenceReason: reasonId);
                                } else {
                                  await pointageProvider.setAdminOverrideForEmployee(
                                    employeId: e.id,
                                    employeNom: e.nom,
                                    employeCin: e.cin,
                                    equipeId: team.equipeId,
                                    equipeName: team.equipeName,
                                    chefName: team.chefName,
                                    status: AttendanceStatus.absent,
                                    absenceReason: reasonId,
                                    viewDate: _reportViewDate,
                                  );
                                }
                                if (mounted) setState(() {});
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 6 : 4),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                                child: Text(tr(context, 'absent'), style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.red.shade800)),
                              ),
                            ),
                            SizedBox(width: mobile ? 8 : 6),
                            InkWell(
                              onTap: isAlreadyFormation
                                  ? null
                                  : () async {
                                      if (record != null) {
                                        await pointageProvider.setAdminOverride(record.id, AttendanceStatus.training);
                                      } else {
                                        await pointageProvider.setAdminOverrideForEmployee(
                                          employeId: e.id,
                                          employeNom: e.nom,
                                          employeCin: e.cin,
                                          equipeId: team.equipeId,
                                          equipeName: team.equipeName,
                                          chefName: team.chefName,
                                          status: AttendanceStatus.training,
                                          viewDate: _reportViewDate,
                                        );
                                      }
                                      if (mounted) setState(() {});
                                    },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: isAlreadyFormation ? Colors.grey.shade200 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tr(context, isAlreadyFormation ? 'pointage_formation_already' : 'pointage_formation_short'),
                                  style: TextStyle(
                                    fontSize: mobile ? 11 : 10,
                                    color: isAlreadyFormation ? Colors.grey.shade600 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: mobile ? 8 : 6),
                            InkWell(
                              onTap: () async {
                                final ok = await _showRenfortDialog(
                                  context,
                                  employe: e,
                                  currentEquipeId: team.equipeId,
                                  allTeams: allTeams,
                                  viewDate: viewDate,
                                  pointageProvider: pointageProvider,
                                );
                                if (ok == true && mounted) setState(() {});
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Renfort', style: TextStyle(fontSize: mobile ? 11 : 10, color: Colors.orange.shade800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Future<bool?> _showRenfortDialog(
    BuildContext context, {
    required Employe employe,
    required String currentEquipeId,
    required List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> allTeams,
    required DateTime viewDate,
    required PointageProvider pointageProvider,
  }) async {
    // Équipes cibles = celles qui travaillent ce jour (déjà filtrées dans allTeams), hors équipe actuelle
    final targetTeams = allTeams.where((t) => t.equipeId != currentEquipeId && t.equipeId != 'hors_equipe').toList();
    if (targetTeams.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Aucune autre équipe disponible pour ce jour.')));
      return false;
    }
    String? selectedEquipeId = targetTeams.first.equipeId;

    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final sp = ctx.read<ShiftsProvider>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final target = targetTeams.where((t) => t.equipeId == selectedEquipeId).toList();
            final t = target.isEmpty ? null : target.first;
            return AlertDialog(
              title: const Text('Renfort — affectation temporaire'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${employe.nom} → équipe / shift pour le ${viewDate.day}/${viewDate.month}/${viewDate.year}'),
                    const SizedBox(height: 16),
                    const Text('Équipe cible (équipes qui travaillent ce jour)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedEquipeId,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: targetTeams.map((t) {
                        final shift = sp.getShiftForEquipe(t.equipeId, viewDate);
                        final label = '${t.equipeName} (${t.chefName}) — ${shift?.shortLabel ?? '—'}';
                        return DropdownMenuItem(value: t.equipeId, child: Text(label));
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedEquipeId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(context, 'cancel'))),
                FilledButton(
                  onPressed: t == null
                      ? null
                      : () async {
                          await pointageProvider.assignEmployeeTemp(
                            employeId: employe.id,
                            employeNom: employe.nom,
                            employeCin: employe.cin,
                            targetEquipeId: t.equipeId,
                            targetEquipeName: t.equipeName,
                            targetChefName: t.chefName,
                            originalEquipeId: currentEquipeId,
                            day: viewDate,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop(true);
                        },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _showFormationDialog(
    BuildContext context, {
    required PointageProvider pointageProvider,
    required List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams,
    required DateTime initialDate,
    VoidCallback? onSuccess,
  }) async {
    DateTime selectedDateStart = DateTime(initialDate.year, initialDate.month, initialDate.day);
    DateTime selectedDateEnd = DateTime(initialDate.year, initialDate.month, initialDate.day);
    String? selectedEquipeId = teams.isNotEmpty ? teams.first.equipeId : null;
    final Set<String> selectedEmployeIds = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matching = teams.where((t) => t.equipeId == selectedEquipeId).toList();
            final team = matching.isEmpty ? null : matching.first;
            final workers = team?.workers ?? <Employe>[];
            if (selectedDateEnd.isBefore(selectedDateStart)) selectedDateEnd = selectedDateStart;

            return AlertDialog(
              title: Text(tr(context, 'pointage_formation_dialog_title')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr(context, 'pointage_formation_date'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr(context, 'pointage_formation_date_from'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDateStart,
                                    firstDate: DateTime(now.year - 1),
                                    lastDate: today.add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      selectedDateStart = DateTime(picked.year, picked.month, picked.day);
                                      if (selectedDateEnd.isBefore(selectedDateStart)) selectedDateEnd = selectedDateStart;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text('${selectedDateStart.day}/${selectedDateStart.month}/${selectedDateStart.year}'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tr(context, 'pointage_formation_date_to'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              TextButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDateEnd.isBefore(selectedDateStart) ? selectedDateStart : selectedDateEnd,
                                    firstDate: selectedDateStart,
                                    lastDate: today.add(const Duration(days: 365)),
                                  );
                                  if (picked != null) setDialogState(() => selectedDateEnd = DateTime(picked.year, picked.month, picked.day));
                                },
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text('${selectedDateEnd.day}/${selectedDateEnd.month}/${selectedDateEnd.year}'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(tr(context, 'pointage_formation_equipe'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: selectedEquipeId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      items: teams.map((t) => DropdownMenuItem(value: t.equipeId, child: Text('${t.equipeName} — ${t.chefName}'))).toList(),
                      onChanged: (v) => setDialogState(() { selectedEquipeId = v; selectedEmployeIds.clear(); }),
                    ),
                    const SizedBox(height: 16),
                    Text(tr(context, 'pointage_formation_person'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    FutureBuilder<Set<String>>(
                      key: ValueKey('formation-$selectedDateStart-$selectedDateEnd-${workers.map((e) => e.id).join('-')}'),
                      future: () async {
                        final ids = <String>{};
                        for (final e in workers) {
                          final r = await pointageProvider.getRecordForEmployeeForDate(e.id, selectedDateStart);
                          if (r?.adminFinalStatus == AttendanceStatus.training) ids.add(e.id);
                        }
                        return ids;
                      }(),
                      builder: (context, snap) {
                        final inFormationIds = snap.data ?? <String>{};
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...workers.map((e) {
                              final alreadyFormation = inFormationIds.contains(e.id);
                              return CheckboxListTile(
                                value: selectedEmployeIds.contains(e.id),
                                onChanged: alreadyFormation ? null : (v) => setDialogState(() {
                                  if (v == true) selectedEmployeIds.add(e.id); else selectedEmployeIds.remove(e.id);
                                }),
                                title: Text(e.nom, style: TextStyle(color: alreadyFormation ? Colors.grey : null)),
                                subtitle: alreadyFormation ? Text(tr(context, 'pointage_formation_already'), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)) : null,
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(tr(context, 'pointage_formation_hint'), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
                FilledButton.icon(
                  onPressed: selectedEmployeIds.isEmpty || team == null
                      ? null
                      : () async {
                          for (var d = DateTime(selectedDateStart.year, selectedDateStart.month, selectedDateStart.day);
                              !d.isAfter(DateTime(selectedDateEnd.year, selectedDateEnd.month, selectedDateEnd.day));
                              d = d.add(const Duration(days: 1))) {
                            final viewDay = DateTime(d.year, d.month, d.day);
                            for (final id in selectedEmployeIds) {
                              final e = workers.firstWhere((w) => w.id == id);
                              await pointageProvider.setAdminOverrideForEmployee(
                                employeId: e.id,
                                employeNom: e.nom,
                                employeCin: e.cin,
                                equipeId: team.equipeId,
                                equipeName: team.equipeName,
                                chefName: team.chefName,
                                status: AttendanceStatus.training,
                                viewDate: viewDay,
                              );
                            }
                          }
                          pointageProvider.selectReportDate(selectedDateStart);
                          onSuccess?.call();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.school, size: 18),
                  label: Text(tr(context, 'pointage_formation_mark')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminMainContent(
    BuildContext context, {
    required ({String equipeId, String equipeName, String chefName, List<Employe> workers})? team,
    required List<Employe> workers,
    required Color borderColor,
    required PointageProvider pointageProvider,
    required PointageRecord? Function(String) getRecord,
    required List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams,
    required List<String> nonWorkingIds,
    required DateTime viewDate,
    required Map<String, List<Employe>> presentByChef,
    required Map<String, List<Employe>> absentByChef,
    required Map<String, List<Employe>> notInVehicleByChef,
    required Map<String, List<Employe>> notWorkingByChef,
  }) {
    switch (_adminContentView) {
      case _AdminPointageView.workers:
        return _buildAdminWorkersColumn(
          context,
          team,
          workers,
          borderColor,
          pointageProvider,
          getRecord,
          allTeams: teams,
          viewDate: viewDate,
        );
      case _AdminPointageView.report:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.grey.shade100,
              child: InkWell(
                onTap: () => setState(() => _adminContentView = _AdminPointageView.workers),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(tr(context, 'pointage_back_to_workers'), style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReportSection(title: tr(context, 'report_presents'), color: Colors.green, byChef: presentByChef),
                    const SizedBox(height: 16),
                    _ReportSection(title: tr(context, 'report_absents'), color: Colors.red, byChef: absentByChef),
                    const SizedBox(height: 16),
                    _ReportSection(title: tr(context, 'report_not_in_vehicle_list'), color: Colors.orange, byChef: notInVehicleByChef),
                    const SizedBox(height: 16),
                    _ReportSection(title: tr(context, 'pointage_report_not_working'), color: Colors.grey, byChef: notWorkingByChef),
                  ],
                ),
              ),
            ),
          ],
        );
      case _AdminPointageView.analysis:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.grey.shade100,
              child: InkWell(
                onTap: () => setState(() => _adminContentView = _AdminPointageView.workers),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Text(tr(context, 'pointage_back_to_workers'), style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _PointageAnalysisSection(
                teams: teams,
                nonWorkingIds: nonWorkingIds,
                getRecord: getRecord,
                viewDate: viewDate,
              ),
            ),
          ],
        );
    }
  }

  static AttendanceState _chefStatusToState(ChefPointageStatus s) {
    switch (s) {
      case ChefPointageStatus.present:
        return AttendanceState.present;
      case ChefPointageStatus.absent:
        return AttendanceState.absent;
      case ChefPointageStatus.unset:
        return AttendanceState.unmarked;
    }
  }

  static ChefPointageStatus _stateToChefStatus(AttendanceState s) {
    switch (s) {
      case AttendanceState.present:
        return ChefPointageStatus.present;
      case AttendanceState.absent:
        return ChefPointageStatus.absent;
      case AttendanceState.unmarked:
      case AttendanceState.notInVehicle:
        return ChefPointageStatus.unset;
    }
  }

  static const Map<AbsenceReason, String> _absenceReasonKeys = {
    AbsenceReason.maladie: 'absence_reason_maladie',
    AbsenceReason.paternite: 'absence_reason_paternite',
    AbsenceReason.mariage: 'absence_reason_mariage',
    AbsenceReason.deces: 'absence_reason_deces',
    AbsenceReason.autorisee: 'absence_reason_autorisee',
    AbsenceReason.absenceInjustifiee: 'absence_reason_injustifiee',
  };

  /// Returns the reason id (dynamic config) or enum name (fallback). Caller stores this in pointage.
  Future<String?> _showAbsenceReasonDialog(BuildContext context) async {
    final reasonsProvider = context.read<AbsenceReasonsProvider>();
    final configs = reasonsProvider.reasons;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'absence_reason_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: configs.isNotEmpty
                ? configs.map((c) {
                    return ListTile(
                      title: Text(c.label),
                      subtitle: Text(c.deductFromSalary ? 'Déduit du salaire' : 'Non déduit'),
                      onTap: () => Navigator.pop(ctx, c.id),
                    );
                  }).toList()
                : AbsenceReason.values.map((r) {
                    return ListTile(
                      title: Text(tr(ctx, _absenceReasonKeys[r]!)),
                      onTap: () => Navigator.pop(ctx, r.name),
                    );
                  }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildChefContent(
    BuildContext context,
    AuthProvider auth,
    List<Equipe> equipes,
    List<Employe> employes,
    PointageProvider pointageProvider,
  ) {
    final shiftsProvider = context.watch<ShiftsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      pointageProvider.ensureNonWorkingLoadedForDate(DateTime.now());
    });
    final recordByEmployeId = <String, PointageRecord>{};
    for (final r in pointageProvider.todayPointage) recordByEmployeId[r.employeId] = r;
    final now = DateTime.now();
    DateTime? getOriginalShiftEnd(PointageRecord rec) {
      final oid = rec.originalEquipeId;
      if (oid == null || oid.isEmpty) return null;
      final shift = shiftsProvider.getShiftForEquipe(oid, rec.date);
      final d = DateTime(rec.date.year, rec.date.month, rec.date.day);
      return shift?.getShiftEnd(d);
    }
    // Toujours afficher les renforts dans la liste du chef cible pour qu'il voie qui travaillera avec lui (heures sup.)
    bool shouldShowRenfortInTarget(PointageRecord rec) => true;
    // Dans l'équipe d'origine: n'afficher le membre que jusqu'à la fin de sa shift, après il disparaît
    bool shouldShowMemberInOriginal(PointageRecord rec) {
      final end = getOriginalShiftEnd(rec);
      return end != null && now.isBefore(end);
    }
    final workers = getWorkersForEquipeConsideringTemp(
      equipes,
      employes,
      auth.equipeId,
      recordByEmployeId,
      shouldShowRenfortInTarget: shouldShowRenfortInTarget,
      shouldShowMemberInOriginal: shouldShowMemberInOriginal,
    );
    // Afficher tous les travailleurs ; ceux en formation sont en « présent — en formation » sans choix présent/absent
    final workersDisplay = workers;
    final workersInTraining = workers.where((e) => pointageProvider.getRecordForEmployee(e.id)?.adminFinalStatus == AttendanceStatus.training).toList();
    AttendanceState getState(String id) {
      if (pointageProvider.getRecordForEmployee(id)?.adminFinalStatus == AttendanceStatus.training) return AttendanceState.present;
      return _chefStatusToState(pointageProvider.getChefStatusForEmployee(id));
    }
    final reportSentMsgChef = tr(context, 'report_sent');
    final equipeForTitle = equipes.where((e) => e.id == auth.equipeId).toList();
    final equipeNameForTitle = equipeForTitle.isNotEmpty ? equipeForTitle.first.nom : '';

    void sendReport() async {
      final equipeId = auth.equipeId;
      if (equipeId == null || equipeId.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Compte chef non lié à une équipe. Contactez l\'administrateur.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
        return;
      }

      int presentCount = 0;
      int absentCount = 0;
      for (final w in workersDisplay) {
        final s = getState(w.id);
        if (s == AttendanceState.present) presentCount++;
        else if (s == AttendanceState.absent) absentCount++;
      }

      final equipe = equipes.where((e) => e.id == equipeId).toList();
      final equipeName = equipe.isNotEmpty ? equipe.first.nom : '';
      final today = DateTime.now();
      final shiftForEquipe = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, today) : null;
      final pointageConfig = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, today, shiftForEquipe);
      try {
        final ok = await pointageProvider.submitChefReport(equipeId, configOverride: pointageConfig);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trOf(context, 'pointage_hours_cannot_mark')),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.fixed,
            ),
          );
          return;
        }
        await pointageProvider.submitDailyReport(
          equipeId: equipeId,
          equipeName: equipeName,
          chefId: auth.currentUser?.id ?? '',
          chefName: auth.currentUser?.nom ?? '',
          totalEmployees: workersDisplay.length,
          presentCount: presentCount,
          absentCount: absentCount,
          notInVehicleCount: 0,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reportSentMsgChef),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }
    }

    final padding = pagePadding(context);
    final chefEquipeList = equipes.where((e) => e.id == auth.equipeId).toList();
    final chefEquipe = chefEquipeList.isEmpty ? null : chefEquipeList.first;
    final today = DateTime.now();
    final shiftForChef = chefEquipe != null ? shiftsProvider.getShiftForEquipe(chefEquipe.id, today) : null;
    final config = getConfigForEquipeAndDate(chefEquipe, today, shiftForChef);
    final hoursStatus = getPointageHoursStatus(now, config);
    final ignoreTime = pointageProvider.ignoreTimeWindowsForTest;
    final isWithinArrival = ignoreTime || config.canMarkArrivalNow(now);
    final isWithinDeparture = ignoreTime || config.canMarkDepartureNow(now);
    final mobile = isMobile(context);

    final nonWorkingIds = pointageProvider.nonWorkingEquipeIds;
    final effectiveNonWorkingIds = <String>{...nonWorkingIds};
    if (shiftsProvider.hasConfig) {
      for (final eid in shiftsProvider.config!.equipeIds) {
        if (eid.isEmpty) continue;
        if (shiftsProvider.getShiftForEquipe(eid, today) == ShiftType.rest) {
          effectiveNonWorkingIds.add(eid);
        }
      }
    }
    bool isRoboEquipe(Equipe eq) {
      final name = eq.nom.trim().toLowerCase();
      if (name.contains('robo') || name.contains('repos') || name.contains('repo')) return true;
      final shift = shiftsProvider.getShiftForEquipe(eq.id, today);
      return shift == ShiftType.rest;
    }
    final workingEquipes = equipes
        .where((e) => e.chefId.isNotEmpty && !effectiveNonWorkingIds.contains(e.id) && !isRoboEquipe(e))
        .toList();
    final teamsForRenfortSelection = workingEquipes
        .map((eq) => (equipeId: eq.id, equipeName: eq.nom, chefName: getChefName(employes, eq.chefId), workers: <Employe>[]))
        .toList();

    Widget buildWorkerCard(Employe e) {
      final record = pointageProvider.getRecordForEmployee(e.id);
      final isInTraining = record?.adminFinalStatus == AttendanceStatus.training;
      if (isInTraining) {
        return Card(
          margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 14 : 10),
            child: Row(
              children: [
                SmartAvatar(
                  imageUrl: e.photoUrl,
                  fallbackText: e.nom,
                  radius: mobile ? 22 : 18,
                ),
                SizedBox(width: mobile ? 14 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 15 : null)),
                    ],
                  ),
                ),
                Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: 16, color: Colors.teal.shade700),
                      SizedBox(width: 6),
                      Text(tr(context, 'pointage_chef_training_badge'), style: TextStyle(fontSize: mobile ? 11 : 12, fontWeight: FontWeight.w600, color: Colors.teal.shade800)),
                    ],
                  ),
                  backgroundColor: Colors.teal.shade50,
                  side: BorderSide(color: Colors.teal.shade200),
                ),
              ],
            ),
          ),
        );
      }
      final locked = pointageProvider.isChefLockedForEmployee(e.id);
      final equipe = equipes.where((eq) => eq.id == auth.equipeId).toList();
      final equipeName = equipe.isNotEmpty ? equipe.first.nom : '';
      final recordOrPlaceholder = record ??
          PointageRecord(
            id: '',
            employeId: e.id,
            employeNom: e.nom,
            employeCin: e.cin,
            equipeId: auth.equipeId ?? '',
            equipeName: equipeName,
            chefName: auth.currentUser?.nom ?? '',
            status: AttendanceStatus.unmarked,
            date: DateTime.now(),
            createdAt: DateTime.now(),
          );
      final canMarkArrival = !locked && isWithinArrival;
      final canMarkDeparture = isWithinDeparture;
      final canChooseRenfortTeam =
          record == null || !record.tempAssigned || (record.originalEquipeId != null && record.originalEquipeId == auth.equipeId);
      return Card(
        margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 14 : 10),
          child: Row(
            children: [
              SmartAvatar(
                imageUrl: e.photoUrl,
                fallbackText: e.nom,
                radius: mobile ? 22 : 18,
              ),
              SizedBox(width: mobile ? 14 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 15 : null)),
                    if (record?.tempAssigned == true && record?.equipeId == auth.equipeId) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Builder(
                          builder: (_) {
                            final origId = record!.originalEquipeId ?? '';
                            final origEq = equipes.where((eq) => eq.id == origId).toList();
                            final origName = origEq.isEmpty ? origId : origEq.first.nom;
                            return Text(
                              'Heures sup. — Équipe $origName',
                              style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                      ),
                    ],
                    if (canChooseRenfortTeam) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await _showRenfortDialog(
                              context,
                              employe: e,
                              currentEquipeId: auth.equipeId ?? '',
                              allTeams: teamsForRenfortSelection,
                              viewDate: DateTime(now.year, now.month, now.day),
                              pointageProvider: pointageProvider,
                            );
                            if (ok == true && mounted) setState(() {});
                          },
                          icon: Icon(Icons.swap_horiz, size: mobile ? 16 : 14, color: Colors.orange.shade700),
                          label: Text('Heures sup. (équipe)', style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.orange.shade800)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.orange.shade200),
                            padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 8 : 6),
                          ),
                        ),
                      ),
                    ],
                    if (recordOrPlaceholder.departureStatus != DepartureStatus.unset && recordOrPlaceholder.overtimeMinutes != null && recordOrPlaceholder.overtimeMinutes! > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${tr(context, 'pointage_analysis_overtime_h')}: ${(recordOrPlaceholder.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ),
              if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              _wrapIfDisabled(
                disabled: !canMarkArrival,
                child: ChefStatusChips(
                  current: getState(e.id),
                  onSelect: canMarkArrival ? (s) async {
                    String? absenceReason;
                    if (s == AttendanceState.absent) {
                      final reasonId = await _showAbsenceReasonDialog(context);
                      if (reasonId == null || !context.mounted) return;
                      absenceReason = reasonId;
                    }
                    final ok = await pointageProvider.markChefAttendance(
                      employeId: e.id,
                      employeNom: e.nom,
                      employeCin: e.cin,
                      equipeId: auth.equipeId ?? '',
                      equipeName: equipeName,
                      chefName: auth.currentUser?.nom ?? '',
                      chefStatus: _stateToChefStatus(s),
                      chefId: auth.currentUser?.id,
                      absenceReason: absenceReason,
                      configOverride: config,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                      );
                    }
                  } : (_) {},
                  presentLabel: tr(context, 'present'),
                  absentLabel: tr(context, 'absent'),
                ),
              ),
              if (canMarkDeparture)
                _DepartureChips(
                  record: recordOrPlaceholder,
                  config: config,
                  onStillWorking: () async {
                    // "Encore au travail" = اختيار الفريق الذي سيعمل معه ساعات إضافية (الشيفت الذي بعده فقط)
                    ShiftType? nextShift(ShiftType? s) {
                      if (s == null) return null;
                      switch (s) {
                        case ShiftType.morning:
                          return ShiftType.evening;
                        case ShiftType.evening:
                          return ShiftType.night;
                        case ShiftType.night:
                          return ShiftType.morning;
                        case ShiftType.rest:
                          return null;
                      }
                    }
                    final myShift = shiftsProvider.getShiftForEquipe(auth.equipeId ?? '', today);
                    final ns = nextShift(myShift);
                    final todayDate = DateTime(today.year, today.month, today.day);
                    DateTime targetDate = todayDate;
                    // الشيفت الليلي 22→06: الصباح التالي 06→14 يكون إما نفس اليوم (بعد منتصف الليل) أو اليوم الموالي (قبل منتصف الليل)
                    if (myShift == ShiftType.night && ns == ShiftType.morning) {
                      targetDate = now.hour < 6 ? todayDate : todayDate.add(const Duration(days: 1));
                    }
                    final candidates = workingEquipes
                        .where((eq) => eq.id != (auth.equipeId ?? '') && shiftsProvider.getShiftForEquipe(eq.id, targetDate) == ns)
                        .toList();
                    if (candidates.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Aucune équipe disponible pour la shift suivante.'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                        );
                      }
                      return;
                    }
                    final candidateTeams = candidates
                        .map((eq) => (equipeId: eq.id, equipeName: eq.nom, chefName: getChefName(employes, eq.chefId), workers: <Employe>[]))
                        .toList();
                    final ok = await _showRenfortDialog(
                      context,
                      employe: e,
                      currentEquipeId: auth.equipeId ?? '',
                      allTeams: candidateTeams,
                      viewDate: targetDate,
                      pointageProvider: pointageProvider,
                    );
                    if (ok == true && mounted) setState(() {});
                  },
                  onFinished: (int? overtimeMinutes) async {
                    final ok = await pointageProvider.setDepartureStatus(
                      record: recordOrPlaceholder,
                      status: DepartureStatus.finished,
                      overtimeMinutes: overtimeMinutes,
                      configOverride: config,
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
                  finishWithoutOvertimeDialog: true,
                ),
            ],
          ),
        ),
      );
    }

    if (mobile && workersDisplay.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[700], size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, 'pointage_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'pointage_subtitle_chef'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            _PointageHoursBanner(context: context, status: hoursStatus, config: config),
            if (auth.equipeId != null && auth.equipeId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.work_off, size: 20, color: Colors.orange[800]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(context, 'pointage_team_not_working'),
                          style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                        ),
                      ),
                      Switch(
                        value: pointageProvider.isEquipeNonWorking(auth.equipeId!),
                        onChanged: (value) async {
                          await pointageProvider.setEquipeNonWorkingForDate(DateTime.now(), auth.equipeId!, value);
                          if (context.mounted) setState(() {});
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (chefEquipe != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _ChefPointageHoursDialog.show(context, chefEquipe),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(tr(context, 'pointage_chef_hours_btn')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '${tr(context, 'workers_of')} $equipeNameForTitle (${auth.currentUser?.nom ?? ''})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (workersInTraining.isNotEmpty) ...[
              const SizedBox(height: 8),
              Material(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 22, color: Colors.teal.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(context, 'pointage_chef_training_banner').replaceAll('%s', '${workersInTraining.length}'),
                          style: TextStyle(fontSize: 13, color: Colors.teal.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: workersDisplay.length,
                itemBuilder: (context, i) => buildWorkerCard(workersDisplay[i]),
              ),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final presentNames = workersDisplay.where((w) => getState(w.id) == AttendanceState.present).map((e) => e.nom).toList();
                final absentWorkers = workersDisplay.where((w) => getState(w.id) != AttendanceState.present).toList();
                final absentNames = absentWorkers.map((e) => e.nom).toList();
                final absentReasons = absentWorkers.map((e) => pointageProvider.getRecordForEmployee(e.id)?.absenceReason).toList();
                final filePath = await PointageExportService.shareDailyReportPdf(
                  date: DateTime.now(),
                  title: trOf(context, 'report_presence_title'),
                  presentNames: presentNames,
                  absentNames: absentNames,
                  absentReasons: absentReasons,
                  signatureLabel: trOf(context, 'pointage_signature_chef'),
                  personName: auth.currentUser?.nom ?? '',
                  equipeName: equipeNameForTitle.isNotEmpty ? equipeNameForTitle : null,
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
            SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: PrimaryButton(
                label: tr(context, 'send_report_btn'),
                onTap: isWithinArrival ? sendReport : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.grey[700], size: 28),
              const SizedBox(width: 12),
              Text(
                tr(context, 'pointage_title'),
                style: TextStyle(fontSize: mobile ? 18 : 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, 'pointage_subtitle_chef'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          _PointageHoursBanner(context: context, status: hoursStatus, config: config),
          if (auth.equipeId != null && auth.equipeId!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Material(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.work_off, size: 20, color: Colors.orange[800]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(context, 'pointage_team_not_working'),
                        style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                      ),
                    ),
                    Switch(
                      value: pointageProvider.isEquipeNonWorking(auth.equipeId!),
                      onChanged: (value) async {
                        await pointageProvider.setEquipeNonWorkingForDate(DateTime.now(), auth.equipeId!, value);
                        if (context.mounted) setState(() {});
                      },
                      activeColor: Colors.orange,
                    ),
                  ],
                ),
                ),
              ),
            ],
          if (chefEquipe != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _ChefPointageHoursDialog.show(context, chefEquipe),
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(tr(context, 'pointage_chef_hours_btn')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            '${tr(context, 'workers_of')} $equipeNameForTitle (${auth.currentUser?.nom ?? ''})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (workersInTraining.isNotEmpty) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 22, color: Colors.teal.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(context, 'pointage_chef_training_banner').replaceAll('%s', '${workersInTraining.length}'),
                        style: TextStyle(fontSize: 13, color: Colors.teal.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (workersDisplay.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  tr(context, 'no_workers'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...workersDisplay.map((e) => buildWorkerCard(e)),
          OutlinedButton.icon(
            onPressed: () async {
              final presentNames = workersDisplay.where((w) => getState(w.id) == AttendanceState.present).map((e) => e.nom).toList();
              final absentWorkers = workersDisplay.where((w) => getState(w.id) != AttendanceState.present).toList();
              final absentNames = absentWorkers.map((e) => e.nom).toList();
              final absentReasons = absentWorkers.map((e) => pointageProvider.getRecordForEmployee(e.id)?.absenceReason).toList();
              final filePath = await PointageExportService.shareDailyReportPdf(
                date: DateTime.now(),
                title: trOf(context, 'report_presence_title'),
                presentNames: presentNames,
                absentNames: absentNames,
                absentReasons: absentReasons,
                signatureLabel: trOf(context, 'pointage_signature_chef'),
                personName: auth.currentUser?.nom ?? '',
                equipeName: equipeNameForTitle.isNotEmpty ? equipeNameForTitle : null,
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
          SizedBox(height: mobile ? 16 : 24),
          SizedBox(
            height: mobile ? 48 : 52,
            width: double.infinity,
            child: PrimaryButton(
              label: tr(context, 'send_report_btn'),
              onTap: isWithinArrival ? sendReport : null,
            ),
          ),
          SizedBox(height: mobile ? 16 : 24),
        ],
      ),
    );
  }

  static Widget _wrapIfDisabled({required bool disabled, required Widget child}) {
    if (!disabled) return child;
    return Opacity(opacity: 0.6, child: IgnorePointer(child: child));
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
  /// Si true, "Fin du travail" enregistre directement la fin de shift sans demander les heures sup. (0 = 8h normales)
  final bool finishWithoutOvertimeDialog;

  const _DepartureChips({
    required this.record,
    required this.config,
    required this.onStillWorking,
    required this.onFinished,
    required this.stillLabel,
    required this.finishedLabel,
    required this.overtimeLabel,
    required this.overtimeHint,
    this.finishWithoutOvertimeDialog = false,
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
          onSelected: (_) async {
            if (finishWithoutOvertimeDialog) {
              onFinished(0);
              return;
            }
            final controller = TextEditingController();
            final minutes = await showDialog<int?>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  title: Text(overtimeLabel),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: overtimeHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                    ),
                    TextButton(
                      onPressed: () {
                        final v = int.tryParse(controller.text.trim());
                        Navigator.pop(ctx, v != null && v > 0 ? v : null);
                      },
                      child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                    ),
                  ],
                );
              },
            );
            onFinished(minutes);
          },
        ),
      ],
    );
  }
}

/// حوار يسمح للشاف بتحديد أوقات عمل فريقه (فتح/إقفال البوانتاج).
class _ChefPointageHoursDialog extends StatelessWidget {
  final Equipe equipe;

  const _ChefPointageHoursDialog({required this.equipe});

  static Future<void> show(BuildContext context, Equipe eq) {
    return showDialog(
      context: context,
      builder: (_) => _ChefPointageHoursDialog(equipe: eq),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool useCustomHours = equipe.pointageStartHour != null && equipe.pointageEndHour != null;
    int startHour = equipe.pointageStartHour ?? 6;
    int startMinute = equipe.pointageStartMinute ?? 0;
    int endHour = equipe.pointageEndHour ?? 10;
    int endMinute = equipe.pointageEndMinute ?? 0;
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(tr(context, 'pointage_chef_hours_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: useCustomHours,
                  onChanged: (v) => setState(() => useCustomHours = v ?? false),
                  title: Text(tr(context, 'pointage_chef_hours_custom'), style: const TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                if (useCustomHours) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(width: 80, child: Text(tr(context, 'pointage_chef_hours_open'), style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: startHour.clamp(0, 23),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}h', overflow: TextOverflow.ellipsis))),
                          onChanged: (v) => setState(() => startHour = v ?? 6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: [0, 15, 30, 45].contains(startMinute) ? startMinute : 0,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => startMinute = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(width: 80, child: Text(tr(context, 'pointage_chef_hours_close'), style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: endHour.clamp(0, 23),
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}h', overflow: TextOverflow.ellipsis))),
                          onChanged: (v) => setState(() => endHour = v ?? 10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: [0, 15, 30, 45].contains(endMinute) ? endMinute : 0,
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                          items: [0, 15, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('${m.toString().padLeft(2, '0')}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => endMinute = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, 'cancel'))),
            ElevatedButton(
              onPressed: () async {
                final updated = equipe.copyWith(
                  pointageStartHour: useCustomHours ? startHour : null,
                  pointageStartMinute: useCustomHours ? startMinute : null,
                  pointageEndHour: useCustomHours ? endHour : null,
                  pointageEndMinute: useCustomHours ? endMinute : null,
                );
                await context.read<EmployeesProvider>().updateEquipe(updated);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
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

class _PointageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PointageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة تحليل الحضور: قوائم قابلة للطي على الهاتف — اضغط على الفريق لفتح الأعضاء.
class _PointageAnalysisSection extends StatelessWidget {
  final List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams;
  final List<String> nonWorkingIds;
  final PointageRecord? Function(String) getRecord;
  final DateTime viewDate;
  final bool showHeader;

  const _PointageAnalysisSection({
    required this.teams,
    required this.nonWorkingIds,
    required this.getRecord,
    required this.viewDate,
    this.showHeader = true,
  });

  static String _timeStr(DateTime? d) {
    if (d == null) return '—';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _durationStr(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    if (end.isBefore(start)) return '—';
    final minutes = end.difference(start).inMinutes;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  static String _overtimeHoursStr(int? overtimeMinutes) {
    if (overtimeMinutes == null || overtimeMinutes <= 0) return '—';
    final hours = overtimeMinutes / 60;
    return hours == hours.roundToDouble() ? '${hours.toInt()} h' : '${hours.toStringAsFixed(1).replaceAll('.', ',')} h';
  }

  String _valueStr(BuildContext context, String? value, String fallback) {
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final notRecorded = tr(context, 'pointage_analysis_not_recorded');
    final personLabel = tr(context, 'pointage_analysis_person');
    final arrivalLabel = tr(context, 'pointage_analysis_arrival');
    final departureLabel = tr(context, 'pointage_analysis_departure');
    final durationLabel = tr(context, 'pointage_analysis_duration');
    final overtimeLabel = tr(context, 'pointage_analysis_overtime_h');
    final subtitle = tr(context, 'pointage_analysis_subtitle');
    final workersCountLabel = tr(context, 'pointage_analysis_workers_count');
    final mobile = isMobile(context);
    final padding = pagePadding(context);

    final workTeams = teams.where((t) => !nonWorkingIds.contains(t.equipeId)).toList();
    if (workTeams.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Text(tr(context, 'pointage_analysis_title'), style: TextStyle(fontSize: mobile ? 15 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.grey[600])),
              const SizedBox(height: 16),
            ],
            Center(child: Text(tr(context, 'report_no_data'), style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          ],
        ),
      );
    }

    if (mobile) {
      return ListView(
        padding: EdgeInsets.all(padding),
        children: [
          if (showHeader) ...[
            Text(tr(context, 'pointage_analysis_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 12),
          ],
          ...workTeams.map((t) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
                childrenPadding: EdgeInsets.only(left: padding, right: padding, bottom: padding, top: 4),
                leading: Icon(Icons.groups, color: Theme.of(context).primaryColor, size: 22),
                title: Text(
                  '${t.equipeName} — ${t.chefName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(workersCountLabel.replaceFirst('%s', '${t.workers.length}'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                children: t.workers.map((e) {
                  final r = getRecord(e.id);
                  final arrival = r?.arrivalMarkedAt;
                  final departure = r?.departureMarkedAt;
                  final duration = _durationStr(arrival, departure);
                  final overtime = _overtimeHoursStr(r?.overtimeMinutes);
                  final arrivalVal = arrival != null ? _timeStr(arrival) : notRecorded;
                  final departureVal = departure != null ? _timeStr(departure) : notRecorded;
                  final durationVal = (arrival != null && departure != null) ? duration : notRecorded;
                  final overtimeVal = (r?.overtimeMinutes != null && (r!.overtimeMinutes ?? 0) > 0) ? overtime : notRecorded;
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _analysisRow(context, arrivalLabel, arrivalVal),
                          const SizedBox(height: 4),
                          _analysisRow(context, departureLabel, departureVal),
                          const SizedBox(height: 4),
                          _analysisRow(context, durationLabel, durationVal),
                          const SizedBox(height: 4),
                          _analysisRow(context, overtimeLabel, overtimeVal),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(tr(context, 'pointage_analysis_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 20),
          ],
          ...workTeams.map((t) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14, top: 4),
                leading: Icon(Icons.groups, color: Theme.of(context).primaryColor, size: 22),
                title: Text(
                  '${t.equipeName} — ${t.chefName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(workersCountLabel.replaceFirst('%s', '${t.workers.length}'), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useTable = constraints.maxWidth >= 500;
                      if (useTable) {
                        return Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1.2),
                            2: FlexColumnWidth(1.2),
                            3: FlexColumnWidth(1.2),
                            4: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: Colors.grey.shade100),
                              children: [
                                _cell(personLabel, bold: true),
                                _cell(arrivalLabel, bold: true),
                                _cell(departureLabel, bold: true),
                                _cell(durationLabel, bold: true),
                                _cell(overtimeLabel, bold: true),
                              ],
                            ),
                            ...t.workers.map((e) {
                              final r = getRecord(e.id);
                              final arrival = r?.arrivalMarkedAt;
                              final departure = r?.departureMarkedAt;
                              final duration = (arrival != null && departure != null) ? _durationStr(arrival, departure) : notRecorded;
                              final overtime = (r?.overtimeMinutes != null && (r!.overtimeMinutes ?? 0) > 0) ? _overtimeHoursStr(r.overtimeMinutes) : notRecorded;
                              return TableRow(
                                children: [
                                  _cell(e.nom),
                                  _cell(arrival != null ? _timeStr(arrival) : notRecorded),
                                  _cell(departure != null ? _timeStr(departure) : notRecorded),
                                  _cell(duration),
                                  _cell(overtime),
                                ],
                              );
                            }),
                          ],
                        );
                      }
                      return Column(
                        children: t.workers.map((e) {
                          final r = getRecord(e.id);
                          final arrival = r?.arrivalMarkedAt;
                          final departure = r?.departureMarkedAt;
                          final duration = (arrival != null && departure != null) ? _durationStr(arrival, departure) : notRecorded;
                          final overtime = (r?.overtimeMinutes != null && (r!.overtimeMinutes ?? 0) > 0) ? _overtimeHoursStr(r.overtimeMinutes) : notRecorded;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text('$arrivalLabel: ${arrival != null ? _timeStr(arrival) : notRecorded}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                      Text('$departureLabel: ${departure != null ? _timeStr(departure) : notRecorded}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                      Text('$durationLabel: $duration', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                      Text('$overtimeLabel: $overtime', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget _analysisRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  static Widget _cell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ExcelDateRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const _ExcelDateRangeDialog({required this.initialStart, required this.initialEnd});

  @override
  State<_ExcelDateRangeDialog> createState() => _ExcelDateRangeDialogState();
}

class _ExcelDateRangeDialogState extends State<_ExcelDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'pointage_excel_date_range')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(tr(context, 'pointage_excel_from')),
            subtitle: Text('${_start.day}/${_start.month}/${_start.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _start,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) setState(() => _start = p);
            },
          ),
          ListTile(
            title: Text(tr(context, 'pointage_excel_to')),
            subtitle: Text('${_end.day}/${_end.month}/${_end.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _end,
                firstDate: _start,
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) setState(() => _end = p);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (start: _start, end: _end)),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final Color color;
  final Map<String, List<Employe>> byChef;

  const _ReportSection({required this.title, required this.color, required this.byChef});

  @override
  Widget build(BuildContext context) {
    final totalCount = byChef.values.fold<int>(0, (s, list) => s + list.length);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withValues(alpha: 0.4), width: 1)),
      color: color.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text('$totalCount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (byChef.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, 'report_no_data'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              )
            else
              ...byChef.entries.map((e) {
                final count = e.value.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    childrenPadding: const EdgeInsets.only(left: 0, right: 0, top: 4, bottom: 12),
                    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    backgroundColor: color.withValues(alpha: 0.04),
                    collapsedBackgroundColor: Colors.transparent,
                    leading: Icon(Icons.groups, size: 20, color: color.withValues(alpha: 0.9)),
                    title: Text(
                      e.key,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9)),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    ),
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: e.value.map((emp) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))],
                          ),
                          child: Text(emp.nom, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
                        )).toList(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
