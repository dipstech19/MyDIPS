import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/app_permissions.dart';
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
import 'data/excel_validation_repository.dart';
import 'data/daily_confirmation_repository.dart';
import 'data/daily_snapshot_repository.dart';
import '../shifts/shifts_provider.dart';
import '../overtime/overtime_provider.dart';
import '../overtime/models/overtime_model.dart';
import '../shifts/models/shift_models.dart';
import 'models/pointage_model.dart';
import 'services/pointage_export_service.dart';
import '../groupes/groupes_provider.dart';
import '../groupes/models/groupe_model.dart';

typedef _TeamWorkers = ({
  String equipeId,
  String equipeName,
  String chefName,
  List<Employe> workers,
});

/// Badge صغير لحالة السائق أو الشاف
class _DriverChefBadge extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool isDriver;

  const _DriverChefBadge({required this.label, this.value, required this.isDriver});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (isDriver) {
      final s = value as DriverPointageStatus?;
      if (s == null || s == DriverPointageStatus.unset) {
        color = Colors.grey;
      } else {
        color = s == DriverPointageStatus.present ? Colors.green : s == DriverPointageStatus.absent ? Colors.red : Colors.orange;
      }
    } else {
      final s = value as ChefPointageStatus?;
      if (s == null || s == ChefPointageStatus.unset) {
        color = Colors.grey;
      } else {
        color = s == ChefPointageStatus.present ? Colors.green : Colors.red;
      }
    }
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 6, vertical: mobile ? 6 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(fontSize: mobile ? 12 : 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _AdminTabChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdminTabChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color.withValues(alpha: 0.25) : Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? color : Colors.grey.shade700),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminTopTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _AdminTopTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final mobile = MediaQuery.sizeOf(context).width < 600;
    final minHeight = mobile ? 48.0 : 40.0;
    final hPad = mobile ? 14.0 : 8.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? primary : Colors.transparent, width: 2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: mobile ? 14 : 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? primary : Colors.grey.shade700,
                  ),
                ),
                if (badge != null) ...[
                  SizedBox(width: mobile ? 10 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(fontSize: mobile ? 12 : 11, fontWeight: FontWeight.w800, color: selected ? primary : Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    final mobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 6, vertical: mobile ? 6 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: mobile ? 12 : 10, fontWeight: FontWeight.w600, color: color)),
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

enum _AdminDesignTab { pointages, statistiques, hs, formation }

class _PointagePageState extends State<PointagePage> {
  final ExcelValidationRepository _excelValidationRepo =
      ExcelValidationRepository();
  final DailyConfirmationRepository _confirmationRepo =
      DailyConfirmationRepository();
  final DailySnapshotRepository _snapshotRepo = DailySnapshotRepository();

  // تأكيدات اليوم (real-time stream)
  List<DailyEquipeConfirmation> _dailyConfirmations = [];
  Stream<List<DailyEquipeConfirmation>>? _confirmationsStream;
  DateTime? _confirmationsStreamDate;

  String? _selectedEquipeIdAdmin;
  String? _lastOvertimeListenEquipeId;
  DateTime _hsFilterDate = DateTime.now();
  String? _lastOvertimeListenDateKey;
  DateTime? _reportViewDate;
  _AdminPointageView _adminContentView = _AdminPointageView.workers;
  _AdminDesignTab _adminTab = _AdminDesignTab.pointages;

  DateTime _adminMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _adminFilterEquipeId;
  String? _adminFilterEmployeId;
  bool _adminMonthLoading = false;
  DateTime? _adminMonthLoaded;
  List<PointageRecord> _adminMonthRecords = [];

  /// تحديث stream التأكيدات عند تغيير التاريخ
  void _ensureConfirmationsStream(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (_confirmationsStreamDate?.isAtSameMomentAs(day) == true) return;
    _confirmationsStreamDate = day;
    _confirmationsStream = _confirmationRepo.watchConfirmationsForDate(day);
  }

  void _ensureHsDateListener(OvertimeProvider provider) {
    final key =
        '${_hsFilterDate.year}-${_hsFilterDate.month}-${_hsFilterDate.day}';
    if (_lastOvertimeListenDateKey == key) return;
    _lastOvertimeListenDateKey = key;
    provider.listenForDate(_hsFilterDate);
  }

  bool _canViewValidatedExcel(AuthProvider auth) {
    if (!auth.isDirecteur) return false;
    final perms = auth.permissions;
    if (perms.contains(AppPermissions.all)) return true;
    return auth.hasPermission(AppPermissions.reportsView) &&
        (auth.hasPermission(AppPermissions.adminsManage) ||
            auth.hasPermission(AppPermissions.groupsManage));
  }

  Future<void> _showValidatedExcelDialog(BuildContext context) async {
    final records = await _excelValidationRepo.getRecentValidated(limit: 60);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fichiers Excel validés'),
        content: SizedBox(
          width: 620,
          child: records.isEmpty
              ? const Text('Aucun fichier validé pour le moment.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = records[i];
                    String fmt(DateTime d) =>
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                    final range = '${fmt(r.startDate)} → ${fmt(r.endDate)}';
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.verified, color: Colors.green),
                      title: Text(range),
                      subtitle: Text(
                        'Par ${r.createdByName.isEmpty ? r.createdById : r.createdByName} • Scope: ${r.scope}${(r.equipeId ?? '').isNotEmpty ? ' • Équipe: ${r.equipeId}' : ''}',
                      ),
                      trailing: const Text(
                        'Validé',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdminMonthRecords(PointageProvider prov) async {
    if (_adminMonthLoading) return;
    final m = DateTime(_adminMonth.year, _adminMonth.month, 1);
    if (_adminMonthLoaded != null &&
        _adminMonthLoaded!.year == m.year &&
        _adminMonthLoaded!.month == m.month) return;
    _adminMonthLoading = true;
    try {
      final start = m;
      final end = DateTime(m.year, m.month + 1, 0);
      final records = await prov.getPointageInDateRange(start, end);
      if (!mounted) return;
      setState(() {
        _adminMonthRecords = records;
        _adminMonthLoaded = m;
        _adminMonthLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adminMonthRecords = [];
        _adminMonthLoaded = m;
        _adminMonthLoading = false;
      });
    }
  }

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
      case AttendanceStatus.leave:
        return AttendanceState.present; // congé = considéré présent pour l'affichage
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

  List<_TeamWorkers> getAllTeamsWithWorkersConsideringTemp(
    List<Equipe> equipes,
    List<Employe> employes,
    Map<String, PointageRecord> recordByEmployeId, {
    Map<String, PointageRecord>? renfortByEmployeId,
  }) {
    final out = <_TeamWorkers>[];
    for (final eq in equipes) {
      final workers = getWorkersForEquipeConsideringTemp(
        equipes,
        employes,
        eq.id,
        recordByEmployeId,
        renfortByEmployeId: renfortByEmployeId,
      );
      out.add((
        equipeId: eq.id,
        equipeName: eq.nom,
        chefName: _chefNameForEquipe(eq, employes),
        workers: workers,
      ));
    }
    return out;
  }

  List<Employe> getWorkersForEquipeConsideringTemp(
    List<Equipe> equipes,
    List<Employe> employes,
    String? equipeId,
    Map<String, PointageRecord> recordByEmployeId, {
    bool Function(PointageRecord rec)? shouldShowRenfortInTarget,
    bool Function(PointageRecord rec)? shouldShowMemberInOriginal,
    Map<String, PointageRecord>? renfortByEmployeId,
  }) {
    if (equipeId == null || equipeId.isEmpty) return <Employe>[];
    final eq = equipes.where((e) => e.id == equipeId).toList();
    if (eq.isEmpty) return <Employe>[];
    final equipe = eq.first;

    final byId = <String, Employe>{for (final e in employes) e.id: e};
    final result = <Employe>[];
    final added = <String>{};

    void addIfValid(String id) {
      if (added.contains(id)) return;
      final e = byId[id];
      if (e == null) return;
      if (e.statut != EmployeStatut.enService) return;
      result.add(e);
      added.add(id);
    }

    // Base members from team definition — always keep them in their original team.
    // Include the chef (team leader) so they appear in the pointage list.
    if (equipe.chefId.isNotEmpty) addIfValid(equipe.chefId);
    for (final id in equipe.membreIds) {
      addIfValid(id);
    }

    // Temporary assignments: use renfortByEmployeId (independent records) to detect Renfort.
    final renfort = renfortByEmployeId ?? recordByEmployeId;
    renfort.forEach((employeId, rec) {
      if (!rec.tempAssigned) return;
      // Show Renfort worker in their TARGET team.
      if (rec.equipeId == equipeId) {
        final ok = shouldShowRenfortInTarget?.call(rec) ?? true;
        if (ok) addIfValid(employeId);
        return;
      }
      // Members whose ORIGINAL team is this equipe: keep them visible here (do not remove).
      // The shouldShowMemberInOriginal callback allows caller to force-remove if needed.
      if (rec.originalEquipeId == equipeId) {
        final keep = shouldShowMemberInOriginal?.call(rec) ?? true;
        if (!keep) {
          result.removeWhere((e) => e.id == employeId);
          added.remove(employeId);
        }
      }
    });

    result.sort((a, b) => a.nom.compareTo(b.nom));
    return result;
  }

  List<Employe> getWorkersForGroupeConsideringTemp(
    Groupe groupe,
    List<Employe> employes,
    Map<String, PointageRecord> recordByEmployeId, {
    Map<String, PointageRecord>? renfortByEmployeId,
  }) {
    final groupeEquipeId = 'groupe:${groupe.id}';
    final byId = <String, Employe>{for (final e in employes) e.id: e};
    final result = <Employe>[];
    final added = <String>{};

    void addIfValid(String id) {
      if (added.contains(id)) return;
      final e = byId[id];
      if (e == null) return;
      if (e.statut != EmployeStatut.enService) return;
      result.add(e);
      added.add(id);
    }

    // Base group members.
    for (final id in groupe.membreIds) {
      addIfValid(id);
    }

    // Renfort assignments using independent records.
    final renfort = renfortByEmployeId ?? recordByEmployeId;
    renfort.forEach((employeId, rec) {
      if (!rec.tempAssigned) return;
      if (rec.equipeId == groupeEquipeId) {
        addIfValid(employeId);
        return;
      }
      // Keep member visible in their original groupe too.
    });

    result.sort((a, b) => a.nom.compareTo(b.nom));
    return result;
  }

  String _chefNameForEquipe(Equipe eq, List<Employe> employes) {
    if (eq.chefId.isEmpty) return '';
    final list = employes.where((e) => e.id == eq.chefId).toList();
    if (list.isEmpty) return eq.chefId;
    return list.first.nom;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final pointageProvider = context.watch<PointageProvider>();
    final isDirecteur = auth.isDirecteur;
    final isChefEquipe = auth.isChefEquipe;
    final hasEquipeLink = (auth.equipeId?.isNotEmpty ?? false);
    final isOperationalChef =
        !auth.isDirecteur && !auth.isChauffeur && !auth.isGroupeResponsable && hasEquipeLink;
    final isRtl = locale.isArabic;

    final showDriverList = isDirecteur;
    final isChefOnly = (isChefEquipe && !isDirecteur) || isOperationalChef;
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
    final auth = context.read<AuthProvider>();
    final now = DateTime.now();
    final viewDate = _reportViewDate ?? now;
    final isViewingToday = _reportViewDate == null ||
        (_reportViewDate!.year == now.year && _reportViewDate!.month == now.month && _reportViewDate!.day == now.day);
    final recordsForDate = isViewingToday ? pointageProvider.todayPointage : pointageProvider.pointageByDate;
    // Build a map employeId → list of all records (may be 2 for Renfort workers).
    final recordsByEmployeId = <String, List<PointageRecord>>{};
    for (final r in recordsForDate) {
      recordsByEmployeId.putIfAbsent(r.employeId, () => []).add(r);
    }
    // Legacy map (employeId → non-renfort record OR first record) for code that only needs one.
    final recordByEmployeId = <String, PointageRecord>{};
    for (final entry in recordsByEmployeId.entries) {
      final nonRenfort = entry.value.where((r) => !r.tempAssigned).toList();
      recordByEmployeId[entry.key] = nonRenfort.isNotEmpty ? nonRenfort.first : entry.value.first;
    }
    // Map for Renfort records only: employeId → renfort record.
    final renfortByEmployeId = <String, PointageRecord>{};
    for (final r in recordsForDate) {
      if (r.tempAssigned) renfortByEmployeId[r.employeId] = r;
    }

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
    final List<_TeamWorkers> teams = getAllTeamsWithWorkersConsideringTemp(
      workingEquipes, employes, recordByEmployeId,
      renfortByEmployeId: renfortByEmployeId,
    );

    // Add Groupes (indépendants) as separate “teams” for admin UI + PDF.
    final groupesProv = context.watch<GroupesProvider>();
    final groupes = groupesProv.groupes;
    final groupeTeams = <_TeamWorkers>[];
    for (final g in groupes) {
      final workers = getWorkersForGroupeConsideringTemp(
        g, employes, recordByEmployeId,
        renfortByEmployeId: renfortByEmployeId,
      );
      groupeTeams.add((
        equipeId: 'groupe:${g.id}',
        equipeName: 'Groupe: ${g.nom}',
        chefName: 'Responsable',
        workers: workers,
      ));
    }
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
      ,
      for (final g in groupes) ...g.membreIds,
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
    final List<_TeamWorkers> allTeams = [
      if (horsEquipeWorkers.isNotEmpty)
        (equipeId: 'hors_equipe', equipeName: 'Hors équipe', chefName: 'Admin', workers: horsEquipeWorkers),
      ...teams,
      ...groupeTeams,
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
      int sortieOk = 0;
      int sortieNotConfirmed = 0;

      for (final t in allTeams) {
        if (nonWorkingIdsEffective.contains(t.equipeId)) continue;
        for (final e in t.workers) {
          totalEmployees++;
          final record = getRecord(e.id);
          if (record?.isFinalPresent ?? false) {
            totalPresent++;
            if (record?.departureStatus == DepartureStatus.finished) {
              sortieOk++;
            } else {
              sortieNotConfirmed++;
            }
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
          SnackBar(
            content: Text('$reportSentMsg — Sortie OK: $sortieOk | Non confirmée: $sortieNotConfirmed'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }

    Future<void> exportSelectedTeamPdf() async {
      if (team == null) return;
      final reasonsProv = context.read<AbsenceReasonsProvider>();
      // If reasons stream hasn't arrived yet, wait briefly so PDF shows labels (not IDs).
      if (reasonsProv.loading) {
        for (int i = 0; i < 10 && reasonsProv.loading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
      final reasonConfigs = reasonsProv.reasons;
      final presentNames = <String>[];
      final presentNoDepartureNames = <String>[];
      final absentNames = <String>[];
      final absentReasons = <String?>[];

      for (final e in workers) {
        if (nonWorkingIdsEffective.contains(team.equipeId)) continue;
        final r = getRecord(e.id);
        final isPresent = r?.isFinalPresent ?? false;
        if (isPresent) {
          if (r?.departureStatus == DepartureStatus.finished) {
            presentNames.add(e.nom);
          } else {
            presentNoDepartureNames.add(e.nom);
          }
        } else {
          absentNames.add(e.nom);
          absentReasons.add(r?.absenceReason);
        }
      }

      final filePath = await PointageExportService.shareDailyReportPdf(
        date: viewDate,
        title: trOf(context, 'report_presence_title'),
        presentNames: presentNames,
        presentNoDepartureNames: presentNoDepartureNames,
        absentNames: absentNames,
        absentReasons: absentReasons,
        reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
        signatureLabel: 'Admin',
        personName: auth.currentUser?.nom ?? 'Admin',
        equipeName: team.equipeName,
        chefName: team.chefName.isNotEmpty ? team.chefName : null,
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
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdminMonthRecords(pointageProvider);
    });

    final content = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 1050;
              final densePhone = constraints.maxWidth < 420;
              final headerSpacing = densePhone ? 8.0 : 10.0;
              final chipH = densePhone ? 8.0 : 10.0;
              final chipV = densePhone ? 4.0 : 6.0;
              final actionH = densePhone ? 10.0 : 14.0;
              final actionV = densePhone ? 8.0 : 12.0;
              final iconSize = densePhone ? 16.0 : 18.0;
              final labelSize = densePhone ? 12.0 : 14.0;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pointage', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${isViewingToday ? recordsForDate.length : pointageProvider.pointageByDate.length} enregistrement(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: headerSpacing,
                runSpacing: headerSpacing,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: chipH, vertical: chipV),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined, size: iconSize, color: Colors.blueGrey[700]),
                        SizedBox(width: densePhone ? 6 : 8),
                        Text('Test (±8h)', style: TextStyle(fontSize: densePhone ? 11 : 12, fontWeight: FontWeight.w600)),
                        SizedBox(width: densePhone ? 6 : 8),
                        Switch(
                          value: pointageProvider.ignoreTimeWindowsForTest,
                          onChanged: (v) => pointageProvider.setIgnoreTimeWindowsForTest(v),
                          activeColor: Colors.blueGrey,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExcelExportDialog(context, teams, equipes, employes, pointageProvider),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.table_chart_outlined, size: iconSize),
                    label: Text('Exporter Excel', style: TextStyle(fontSize: labelSize)),
                  ),
                  if (_canViewValidatedExcel(auth))
                    OutlinedButton.icon(
                      onPressed: () => _showValidatedExcelDialog(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                      ),
                      icon: Icon(Icons.verified_outlined, size: iconSize),
                      label: Text('Excel validés', style: TextStyle(fontSize: labelSize)),
                    ),
                  OutlinedButton.icon(
                    onPressed: team == null ? null : () => exportSelectedTeamPdf(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.picture_as_pdf_outlined, size: iconSize),
                    label: Text('Exporter PDF', style: TextStyle(fontSize: labelSize)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _adminTab = _AdminDesignTab.hs),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.verified_outlined, size: iconSize),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Autorisation H.Sup', style: TextStyle(fontSize: labelSize)),
                        SizedBox(width: densePhone ? 6 : 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: densePhone ? 6 : 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${_adminMonthRecords.where((r) => (r.overtimeMinutes ?? 0) > 0).length}',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: densePhone ? 10 : 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: sendReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.add, size: iconSize),
                    label: Text('Enregistrer Pointage', style: TextStyle(fontSize: labelSize)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await _showResetPointageRangeDialog(context);
                      if (range == null || !mounted) return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Réinitialiser pointage'),
                          content: Text(
                            'Supprimer toutes les données pointage et rapports du '
                            '${range.start.day}/${range.start.month}/${range.start.year} '
                            'au ${range.end.day}/${range.end.month}/${range.end.year} ?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Confirmer'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !mounted) return;
                      await pointageProvider.clearPointageAndReportsInDateRange(range.start, range.end);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pointage réinitialisé pour la période sélectionnée.'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.delete_sweep_outlined, size: iconSize),
                    label: Text('Reset test', style: TextStyle(fontSize: labelSize)),
                  ),
                ],
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: actions,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  Flexible(child: Align(alignment: Alignment.centerRight, child: actions)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Tabs can exceed width on small screens: allow horizontal scroll.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AdminTopTabButton(
                  label: 'Pointages',
                  selected: _adminTab == _AdminDesignTab.pointages,
                  onTap: () => setState(() => _adminTab = _AdminDesignTab.pointages),
                ),
                const SizedBox(width: 14),
                _AdminTopTabButton(
                  label: 'Statistiques',
                  selected: _adminTab == _AdminDesignTab.statistiques,
                  onTap: () => setState(() => _adminTab = _AdminDesignTab.statistiques),
                ),
                const SizedBox(width: 14),
                _AdminTopTabButton(
                  label: 'Autorisations H.Sup',
                  selected: _adminTab == _AdminDesignTab.hs,
                  badge: _adminMonthRecords.where((r) => (r.overtimeMinutes ?? 0) > 0).length,
                  onTap: () => setState(() => _adminTab = _AdminDesignTab.hs),
                ),
                const SizedBox(width: 14),
                _AdminTopTabButton(
                  label: 'Formation',
                  selected: _adminTab == _AdminDesignTab.formation,
                  onTap: () => setState(() => _adminTab = _AdminDesignTab.formation),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Builder(
              builder: (ctx) {
                if (_adminTab == _AdminDesignTab.statistiques) {
                  final prev = _adminContentView;
                  _adminContentView = _AdminPointageView.analysis;
                  final w = _buildAdminMainContent(
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
                  );
                  _adminContentView = prev;
                  return w;
                }
                if (_adminTab == _AdminDesignTab.hs) {
                  final overtimeProvider = context.watch<OvertimeProvider>();
                  _ensureHsDateListener(overtimeProvider);
                  final list = overtimeProvider.dateAssignments
                      .where((a) => _adminFilterEquipeId == null || a.targetEquipeId == _adminFilterEquipeId)
                      .where((a) => _adminFilterEmployeId == null || a.employeId == _adminFilterEmployeId)
                      .toList();
                  return Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final p = await showDatePicker(
                                      context: context,
                                      initialDate: _hsFilterDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (p != null) {
                                      setState(() => _hsFilterDate = DateTime(p.year, p.month, p.day));
                                      if (context.mounted) {
                                        _lastOvertimeListenDateKey = null;
                                        _ensureHsDateListener(
                                          context.read<OvertimeProvider>(),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.calendar_today, size: 16),
                                  label: Text(
                                    'Affectations du ${_hsFilterDate.day}/${_hsFilterDate.month}/${_hsFilterDate.year}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () => _showAssignHsDialog(context, equipes, employes),
                                icon: const Icon(Icons.add),
                                label: const Text('Affecter'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: list.isEmpty
                              ? Center(
                                  child: Text(
                                    'Aucune affectation pour cette date.',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final a = list[i];
                                    final hs = (a.overtimeMinutes / 60).toStringAsFixed(0);
                                    final statusLabel = a.attendanceStatus == OvertimeAttendanceStatus.present
                                        ? 'Présent'
                                        : a.attendanceStatus == OvertimeAttendanceStatus.absent
                                            ? 'Absent'
                                            : 'Non enregistré';
                                    final statusColor = a.attendanceStatus == OvertimeAttendanceStatus.present
                                        ? Colors.green
                                        : a.attendanceStatus == OvertimeAttendanceStatus.absent
                                            ? Colors.red
                                            : Colors.grey;
                                    return ListTile(
                                      title: Text(a.employeNom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      subtitle: Text('${a.originEquipeName} → ${a.targetEquipeName} • $statusLabel'),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3E8FF),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '+$hs h',
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                }
                if (_adminTab == _AdminDesignTab.formation) {
                  return _FormationManagementPage(
                    teams: allTeams,
                    pointageProvider: pointageProvider,
                    employes: employes,
                  );
                }
                // Pointages tab (existing functionality)
                if (mobile) {
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedEquipeIdAdmin,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Équipe',
                        ),
                        items: allTeams
                            .map((t) => DropdownMenuItem(
                                  value: t.equipeId,
                                  child: Text('${t.equipeName} — ${t.chefName}', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedEquipeIdAdmin = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
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
                  );
                }
                // تحديث stream التأكيدات لليوم الحالي
                _ensureConfirmationsStream(viewDate);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 270,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: StreamBuilder<List<DailyEquipeConfirmation>>(
                        stream: _confirmationsStream,
                        builder: (context, snap) {
                          final confirmations = snap.data ?? _dailyConfirmations;
                          if (snap.hasData) _dailyConfirmations = snap.data!;
                          final confirmedIds = confirmations.map((c) => c.equipeId).toSet();
                          final workTeams = allTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                          final confirmedCount = workTeams.where((t) => confirmedIds.contains(t.equipeId)).length;
                          final totalCount = workTeams.length;
                          final allConfirmed = totalCount > 0 && confirmedCount == totalCount;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── رأس القائمة مع شريط التقدم ──
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Chefs d\'équipe',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: allConfirmed ? Colors.green.shade50 : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: allConfirmed ? Colors.green.shade300 : Colors.orange.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            '$confirmedCount/$totalCount confirmés',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: allConfirmed ? Colors.green.shade700 : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: totalCount > 0 ? confirmedCount / totalCount : 0,
                                        minHeight: 5,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          allConfirmed ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    // ── زر إرسال Excel عند اكتمال كل الفرق ──
                                    if (allConfirmed) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () => _showExcelExportDialog(
                                            context, allTeams, equipes, employes, pointageProvider,
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: const Icon(Icons.table_chart, size: 16),
                                          label: const Text('Exporter Excel complet', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
                                      final isNonWorking = nonWorkingIdsEffective.contains(t.equipeId);
                                      final shiftLabel = t.equipeId == 'hors_equipe'
                                          ? null
                                          : shiftsProvider.getShiftForEquipe(t.equipeId, viewDate)?.shortLabel;
                                      final isSelected = _selectedEquipeIdAdmin == t.equipeId;
                                      final isConfirmed = confirmedIds.contains(t.equipeId);

                                      // حساب الحاضرين/الغائبين لهذا الفريق
                                      final teamWorkers = t.workers;
                                      int presentC = 0, absentC = 0;
                                      for (final w in teamWorkers) {
                                        final rec = getRecord(w.id);
                                        if (rec?.isFinalPresent == true) {
                                          presentC++;
                                        } else {
                                          absentC++;
                                        }
                                      }

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            dense: true,
                                            selected: isSelected,
                                            selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                                            onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
                                            leading: Icon(
                                              isConfirmed ? Icons.check_circle : Icons.person,
                                              size: 18,
                                              color: isConfirmed ? Colors.green : (isSelected ? Theme.of(context).primaryColor : Colors.grey),
                                            ),
                                            title: Text(
                                              '${t.equipeName} — ${t.chefName}${shiftLabel != null ? ' ($shiftLabel)' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isNonWorking
                                                    ? Colors.grey.shade400
                                                    : isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
                                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                decoration: isNonWorking ? TextDecoration.lineThrough : null,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: isNonWorking
                                                ? Text('repos', style: TextStyle(fontSize: 10, color: Colors.grey.shade400))
                                                : Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      // عدد الحاضرين
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade50,
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text('$presentC', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade50,
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text('$absentC', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                          // ── زر تأكيد / إلغاء تأكيد الفريق ──
                                          if (!isNonWorking)
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                                              child: SizedBox(
                                                width: double.infinity,
                                                child: isConfirmed
                                                    ? OutlinedButton.icon(
                                                        onPressed: () async {
                                                          await _confirmationRepo.unconfirmEquipe(t.equipeId, viewDate);
                                                          await _snapshotRepo.deleteEquipeSnapshot(t.equipeId, viewDate);
                                                        },
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: Colors.green.shade700,
                                                          side: BorderSide(color: Colors.green.shade300),
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        icon: const Icon(Icons.check_circle, size: 14),
                                                        label: const Text('Confirmé ✓', style: TextStyle(fontSize: 11)),
                                                      )
                                                    : FilledButton.icon(
                                                        onPressed: () async {
                                                          final auth = context.read<AuthProvider>();
                                                          final confirmedById = auth.currentUser?.id ?? '';

                                                          // بناء قائمة snapshots لكل موظف في الفريق
                                                          final empSnapshots = teamWorkers.map((w) {
                                                            final rec = getRecord(w.id);
                                                            String status;
                                                            String? absenceReason;
                                                            if (rec == null) {
                                                              status = 'absent';
                                                            } else if (rec.adminFinalStatus == AttendanceStatus.training) {
                                                              status = 'formation';
                                                            } else if (rec.adminFinalStatus == AttendanceStatus.leave ||
                                                                rec.status == AttendanceStatus.leave) {
                                                              status = 'leave';
                                                            } else if (rec.isFinalPresent ||
                                                                rec.chefStatus == ChefPointageStatus.present ||
                                                                rec.driverStatus == DriverPointageStatus.present ||
                                                                rec.driverStatus == DriverPointageStatus.enVehicule ||
                                                                rec.status == AttendanceStatus.present) {
                                                              status = 'present';
                                                            } else {
                                                              status = 'absent';
                                                              absenceReason = rec.absenceReason;
                                                            }
                                                            return (
                                                              employeId: w.id,
                                                              employeNom: w.nom,
                                                              employeCin: w.cin ?? '',
                                                              status: status,
                                                              absenceReason: absenceReason,
                                                              isRestDay: false,
                                                            );
                                                          }).toList();

                                                          await _snapshotRepo.saveEquipeSnapshot(
                                                            equipeId: t.equipeId,
                                                            equipeName: t.equipeName,
                                                            date: viewDate,
                                                            confirmedById: confirmedById,
                                                            employees: empSnapshots,
                                                          );
                                                          await _confirmationRepo.confirmEquipe(
                                                            equipeId: t.equipeId,
                                                            equipeName: t.equipeName,
                                                            confirmedById: confirmedById,
                                                            confirmedByName: auth.currentUser?.nom ?? 'Admin',
                                                            date: viewDate,
                                                            presentCount: presentC,
                                                            absentCount: absentC,
                                                          );
                                                        },
                                                        style: FilledButton.styleFrom(
                                                          backgroundColor: Colors.blue.shade600,
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        icon: const Icon(Icons.check, size: 14),
                                                        label: const Text('Confirmer', style: TextStyle(fontSize: 11)),
                                                      ),
                                              ),
                                            ),
                                          const Divider(height: 1),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
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
                );
              },
            ),
          ),
          // Bottom actions removed to let the workers area fill the full height.
        ],
      ),
    );
    return mobile ? SafeArea(child: content) : content;
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
    DateTime end = DateTime(now.year, now.month, now.day);
    if (!context.mounted) return;
    final teamOptions = <({String id, String label})>[
      for (final eq in equipes)
        (id: eq.id, label: '${eq.nom} — ${getChefName(employes, eq.chefId)}'),
      for (final t in teams.where((t) => t.equipeId == 'hors_equipe'))
        (id: 'hors_equipe', label: '${t.equipeName} — ${t.chefName}'),
    ];
    final picked = await showDialog<({DateTime start, DateTime end, String scope, String? equipeId})>(
      context: context,
      builder: (ctx) {
        return _ExcelDateRangeDialog(
          initialStart: start,
          initialEnd: end,
          equipeOptions: teamOptions,
        );
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

    // بناء قائمة الموظفين أولاً حتى نتمكن من تمرير معرفاتهم عند جلب السجلات،
    // مما يضمن جلب سجلاتهم حتى لو لم يُسجَّل لهم أي بوانتاج في الفترة.
    final employees = <({String id, String cin, String nom, String equipeName, String? equipeId, double salaireNet})>[];
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
        employees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          equipeName: label,
          equipeId: eq.id,
          salaireNet: w.salaireBase,
        ));
      }
    }
    // Garder aussi les employés hors équipe (équipeId = null) s'ils sont visibles dans l'écran.
    for (final t in teams.where((t) => t.equipeId == 'hors_equipe')) {
      for (final w in t.workers) {
        if (!seen.add(w.id)) continue;
        employees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          equipeName: '${t.equipeName} — ${t.chefName}',
          equipeId: null,
          salaireNet: w.salaireBase,
        ));
      }
    }
    List<({String id, String cin, String nom, String equipeName, String? equipeId, double salaireNet})> filteredEmployees = employees;
    switch (picked.scope) {
      case 'groupes':
        filteredEmployees = employees.where((e) => (e.equipeId ?? '').startsWith('groupe:')).toList();
        break;
      case 'normales':
        filteredEmployees = employees.where((e) => e.equipeId != null && !(e.equipeId!).startsWith('groupe:')).toList();
        break;
      case 'equipe':
        final selectedId = picked.equipeId;
        if (selectedId != null && selectedId.isNotEmpty) {
          filteredEmployees = employees.where((e) {
            if (selectedId == 'hors_equipe') return e.equipeId == null;
            return e.equipeId == selectedId;
          }).toList();
        }
        break;
      case 'all':
      default:
        break;
    }

    final reasonConfigs = context.read<AbsenceReasonsProvider>().reasons;
    final shiftsProvider = context.read<ShiftsProvider>();
    final isRestDay = shiftsProvider.hasConfig
        ? (DateTime date, String equipeId) =>
            shiftsProvider.getShiftForEquipe(equipeId, date) == ShiftType.rest
        : null;
    // جلب overtime_assignments للنطاق الزمني
    final overtimeProvider = context.read<OvertimeProvider>();
    final overtimeAssignments = await overtimeProvider.getForDateRange(start, end);

    // ── المسار الأساسي: snapshots المؤكدة ──────────────────────────────────
    // نحاول أولاً جلب snapshots المخزنة (أكثر دقة وموثوقية من إعادة جلب السجلات).
    final snapshots = await _snapshotRepo.getSnapshotsForRange(start, end);

    // نحسب عدد الأيام في النطاق وعدد التأكيدات لكل موظف
    final totalRangeDays = end.difference(start).inDays + 1;
    final filteredEmpIds = filteredEmployees.map((e) => e.id).toSet();

    // عدد الأيام التي لها snapshots لكل موظف ضمن الفلتر
    final snapshotDaysByEmp = <String, Set<String>>{};
    for (final s in snapshots) {
      if (!filteredEmpIds.contains(s.employeId)) continue;
      final dk = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      snapshotDaysByEmp.putIfAbsent(s.employeId, () => <String>{}).add(dk);
    }

    // إذا كانت كل الأيام مؤكدة لأغلب الموظفين (≥80% من الموظفين لهم snapshots لكل الأيام)
    // نستخدم مسار snapshots مباشرةً، وإلا نستخدم المسار القديم (جلب records)
    final fullyConfirmedCount = filteredEmployees
        .where((e) => (snapshotDaysByEmp[e.id]?.length ?? 0) >= totalRangeDays)
        .length;
    final useSnapshotPath = snapshots.isNotEmpty &&
        (filteredEmployees.isEmpty ||
            fullyConfirmedCount >= (filteredEmployees.length * 0.8).ceil());

    List<PointageExportRow> rows;

    if (useSnapshotPath) {
      // ── مسار snapshots (دقيق وسريع) ──────────────────────────────────
      rows = PointageExportService.computeExcelRowsFromSnapshots(
        startDate: start,
        endDate: end,
        employees: filteredEmployees,
        snapshots: snapshots.where((s) => filteredEmpIds.contains(s.employeId)).toList(),
        reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
        isRestDay: isRestDay,
        overtimeAssignments: overtimeAssignments,
      );
    } else {
      // ── مسار records (fallback للأيام غير المؤكدة) ──────────────────
      final records = await pointageProvider.getPointageInDateRange(
        start,
        end,
        knownEmployeIds: filteredEmpIds,
      );

      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);
      final startDay = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      final isTodayOnly = startDay == todayDay && endDay == todayDay;
      final unconfirmedCount = isTodayOnly
          ? _countUnconfirmedPresenceInRange(
              start: start,
              end: end,
              records: records,
              employeeIds: filteredEmpIds,
            )
          : 0;
      var requireConfirmedEntryExit = false;
      if (isTodayOnly && unconfirmedCount > 0) {
        final decision = await _showAdminExcelValidationDialog(context, unconfirmedCount: unconfirmedCount);
        if (decision == null || !mounted) return;
        if (!decision) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export annulé: veuillez confirmer entrées/sorties avant génération Excel.'),
              behavior: SnackBarBehavior.fixed,
            ),
          );
          return;
        }
        requireConfirmedEntryExit = decision;
      }

      rows = PointageExportService.computeExcelRows(
        startDate: start,
        endDate: end,
        employees: filteredEmployees,
        records: records,
        reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
        isRestDay: isRestDay,
        requireConfirmedEntryExit: isTodayOnly && requireConfirmedEntryExit,
        overtimeAssignments: overtimeAssignments,
      );
    }

    // للمتغيرات المستخدمة لاحقاً في logExport
    final exportNow = DateTime.now();
    final exportTodayDay = DateTime(exportNow.year, exportNow.month, exportNow.day);
    final exportStartDay = DateTime(start.year, start.month, start.day);
    final exportEndDay = DateTime(end.year, end.month, end.day);
    final isTodayOnlyForLog = exportStartDay == exportTodayDay && exportEndDay == exportTodayDay;
    final filePath = await PointageExportService.saveAndOpenExcel(
      startDate: start,
      endDate: end,
      rows: rows,
      reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
    );
    final auth = context.read<AuthProvider>();
    // يُعتبر التصدير "مُتحقَّقاً" إما عبر مسار snapshots أو إذا كان اليوم الحالي فقط
    final validatedExport = useSnapshotPath || isTodayOnlyForLog;
    await _excelValidationRepo.logExport(
      createdById: auth.currentUser?.id ?? '',
      createdByName: auth.currentUser?.nom ?? '',
      startDate: start,
      endDate: end,
      scope: picked.scope,
      equipeId: picked.equipeId,
      validated: validatedExport,
      filePath: filePath,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validatedExport
                ? '${trOf(context, 'pointage_export_excel_saved')}: $filePath\nExport validé et visible pour RH/Chef de zone.'
                : '${trOf(context, 'pointage_export_excel_saved')}: $filePath',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  int _countUnconfirmedPresenceInRange({
    required DateTime start,
    required DateTime end,
    required List<PointageRecord> records,
    required Set<String> employeeIds,
  }) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final byKey = <String, bool>{};
    for (final r in records) {
      if (!employeeIds.contains(r.employeId)) continue;
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (d.isBefore(s) || d.isAfter(e)) continue;
      if (!r.isFinalPresent) continue;
      final confirmed = r.arrivalMarkedAt != null &&
          r.departureMarkedAt != null &&
          r.departureStatus == DepartureStatus.finished;
      if (!confirmed) {
        byKey['${r.employeId}-${d.toIso8601String()}'] = true;
      }
    }
    return byKey.length;
  }

  Future<bool?> _showAdminExcelValidationDialog(
    BuildContext context, {
    required int unconfirmedCount,
  }) async {
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validation Admin avant Excel'),
        content: Text(
          'Il y a $unconfirmedCount présence(s) sans entrée/sortie confirmées.\n\n'
          'Choisissez une option avant export :',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bloquer et corriger'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exporter + Non confirmés = Absents'),
          ),
        ],
      ),
    );
  }

  Future<({DateTime start, DateTime end})?> _showResetPointageRangeDialog(BuildContext context) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = now;
    if (!context.mounted) return null;
    return showDialog<({DateTime start, DateTime end})>(
      context: context,
      builder: (_) => _ResetPointageRangeDialog(initialStart: start, initialEnd: end),
    );
  }

  Future<void> _showAssignHsDialog(
    BuildContext context,
    List<Equipe> equipes,
    List<Employe> employes,
  ) async {
    DateTime shiftEnd(ShiftType shift, DateTime day) {
      switch (shift) {
        case ShiftType.morning:
          return DateTime(day.year, day.month, day.day, 14);
        case ShiftType.evening:
          return DateTime(day.year, day.month, day.day, 22);
        case ShiftType.night:
          return DateTime(day.year, day.month, day.day + 1, 6);
        case ShiftType.rest:
          return DateTime(day.year, day.month, day.day);
      }
    }

    DateTime shiftStart(ShiftType shift, DateTime day) {
      switch (shift) {
        case ShiftType.morning:
          return DateTime(day.year, day.month, day.day, 6);
        case ShiftType.evening:
          return DateTime(day.year, day.month, day.day, 14);
        case ShiftType.night:
          return DateTime(day.year, day.month, day.day, 22);
        case ShiftType.rest:
          return DateTime(day.year, day.month, day.day);
      }
    }

    final sortedEquipes = List<Equipe>.from(equipes)..sort((a, b) => a.nom.compareTo(b.nom));
    Equipe? origin;
    Employe? employee;
    Equipe? target;
    DateTime date = DateTime.now().add(const Duration(days: 1));
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final shiftsProvider = context.watch<ShiftsProvider>();
          final today = DateTime.now();
          final todayDay = DateTime(today.year, today.month, today.day);
          final pickedDay = DateTime(date.year, date.month, date.day);
          final sameDay = pickedDay.year == todayDay.year &&
              pickedDay.month == todayDay.month &&
              pickedDay.day == todayDay.day;

          ShiftType? originShift;
          DateTime? originShiftEnd;
          if (origin != null && shiftsProvider.hasConfig) {
            originShift = shiftsProvider.getShiftForEquipe(origin!.id, today);
            originShiftEnd = shiftEnd(originShift, today);
          }

          final members = origin == null
              ? <Employe>[]
              : employes.where((e) => origin!.membreIds.contains(e.id) || origin!.chefId == e.id).toList();
          final targets = origin == null ? <Equipe>[] : sortedEquipes.where((q) => q.id != origin!.id).toList();
          return AlertDialog(
            title: const Text('Affecter heures supplémentaires'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1) Équipe d\'origine', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Equipe>(
                      value: origin,
                      decoration: const InputDecoration(labelText: 'Équipe d\'origine', border: OutlineInputBorder()),
                      items: sortedEquipes.map((q) => DropdownMenuItem(value: q, child: Text(q.nom))).toList(),
                      onChanged: (v) => setD(() {
                        origin = v;
                        employee = null;
                        target = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                    const Text('2) Employé', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Employe>(
                      value: employee,
                      decoration: const InputDecoration(labelText: 'Employé', border: OutlineInputBorder()),
                      items: members.map((e) => DropdownMenuItem(value: e, child: Text(e.nom))).toList(),
                      onChanged: (v) => setD(() => employee = v),
                    ),
                    const SizedBox(height: 10),
                    const Text('3) Date et équipe cible', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => setD(() {
                            date = todayDay;
                            target = null;
                          }),
                          child: const Text('Aujourd\'hui'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => setD(() {
                            date = todayDay.add(const Duration(days: 1));
                            target = null;
                          }),
                          child: const Text('Demain'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final p = await showDatePicker(
                              context: ctx,
                              initialDate: date,
                              firstDate: todayDay,
                              lastDate: todayDay.add(const Duration(days: 30)),
                            );
                            if (p != null) setD(() {
                              date = DateTime(p.year, p.month, p.day);
                              target = null;
                            });
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('${date.day}/${date.month}/${date.year}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (originShift != null && originShift != ShiftType.rest)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Text(
                          'Shift actuel: ${originShift.shortLabel} (${originShift.timeRange}). '
                          'Même jour: seulement les shifts qui commencent après la fin (${originShiftEnd != null ? '${originShiftEnd.hour.toString().padLeft(2, '0')}:${originShiftEnd.minute.toString().padLeft(2, '0')}' : '--'}).',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ...targets.map((q) {
                      ShiftType? targetShift;
                      String? disabledReason;
                      if (shiftsProvider.hasConfig) {
                        targetShift = shiftsProvider.getShiftForEquipe(q.id, pickedDay);
                        if (targetShift == ShiftType.rest) {
                          disabledReason = 'En repos ce jour-là';
                        } else if (sameDay && originShiftEnd != null) {
                          final targetStart = shiftStart(targetShift!, pickedDay);
                          if (targetStart.isBefore(originShiftEnd!)) {
                            disabledReason = 'Commence avant la fin du shift original';
                          }
                        }
                      }
                      final selected = target?.id == q.id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          onTap: disabledReason == null ? () => setD(() => target = q) : null,
                          selected: selected,
                          selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.10),
                          leading: Icon(Icons.groups, color: selected ? Theme.of(context).primaryColor : Colors.grey.shade700),
                          title: Text(q.nom),
                          subtitle: Text(
                            disabledReason ??
                                (targetShift == null ? 'Shift non configuré' : '${targetShift.shortLabel} (${targetShift.timeRange})'),
                            style: TextStyle(
                              color: disabledReason == null ? Colors.grey.shade700 : Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                          trailing: selected ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: (origin == null || employee == null || target == null)
                    ? null
                    : () async {
                        final auth = context.read<AuthProvider>();
                        await context.read<OvertimeProvider>().assignOvertime(
                              employeId: employee!.id,
                              employeNom: employee!.nom,
                              originEquipeId: origin!.id,
                              originEquipeName: origin!.nom,
                              targetEquipeId: target!.id,
                              targetEquipeName: target!.nom,
                              date: date,
                              adminId: auth.currentUser?.id ?? '',
                            );
                        if (context.mounted) {
                          context.read<OvertimeProvider>().listenForDate(_hsFilterDate);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
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
    String originTeamName(String? originId) {
      if (originId == null || originId.isEmpty) return '—';
      final t = allTeams.where((x) => x.equipeId == originId).toList();
      if (t.isNotEmpty) return t.first.equipeName;
      return originId;
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 12,
          mobile ? 14 : 12,
          mobile ? 14 : 12,
          mobile ? 28 : 12,
        ),
        children: [
          Text('${tr(context, 'workers_of')} ${team.equipeName} (${team.chefName})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 16 : 15)),
          SizedBox(height: mobile ? 10 : 8),
          ...workers.map((e) {
            final record = getRecord(e.id);
            final reconciled = record?.reconciledStatus ?? ReconciledStatus.confirmedAbsent;
            final isPresent = record?.isFinalPresent ?? false;
            final isAlreadyFormation = record?.adminFinalStatus == AttendanceStatus.training;
            final isOnLeave = record?.adminFinalStatus == AttendanceStatus.leave;
            final trainingStartAt = record?.trainingStartAt;
            final trainingEndAt = record?.trainingEndAt;
            final formationRangeLabel = (trainingStartAt != null && trainingEndAt != null)
                ? '${trainingStartAt.day.toString().padLeft(2, '0')}/${trainingStartAt.month.toString().padLeft(2, '0')}'
                    ' - '
                    '${trainingEndAt.day.toString().padLeft(2, '0')}/${trainingEndAt.month.toString().padLeft(2, '0')}'
                : null;
            return Card(
              margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 12 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: mobile ? 22 : 18),
                        SizedBox(width: mobile ? 12 : 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.nom, style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 16 : 14)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _DriverChefBadge(
                                    label: 'T',
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
                        SizedBox(width: mobile ? 8 : 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isPresent ? tr(context, 'present') : tr(context, 'absent'),
                              style: TextStyle(
                                fontSize: mobile ? 12 : 11,
                                fontWeight: FontWeight.w600,
                                color: isOnLeave
                                    ? const Color(0xFF0D47A1) // congé: bleu foncé
                                    : isPresent ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Entrée: ${record?.arrivalMarkedAt != null ? 'OK' : '--'} | Sortie: ${record?.departureStatus == DepartureStatus.finished ? 'OK' : '--'}',
                              style: TextStyle(
                                fontSize: mobile ? 10 : 9,
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isAlreadyFormation && formationRangeLabel != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Formation',
                                    style: TextStyle(
                                      fontSize: mobile ? 10 : 9,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formationRangeLabel,
                                    style: TextStyle(
                                      fontSize: mobile ? 10 : 9,
                                      color: Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (isOnLeave) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Congé approuvé',
                                style: TextStyle(
                                  fontSize: mobile ? 10 : 9,
                                  color: const Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: mobile ? 8 : 6),
                    if (!isAlreadyFormation && !isOnLeave)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
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
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 8 : 6),
                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
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
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 8 : 6),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text(tr(context, 'absent'), style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.red.shade800)),
                              ),
                              ),
                          ],
                        ),
                      ),
                    if (isAlreadyFormation || isOnLeave)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            isAlreadyFormation
                                ? 'Formation active: modification des boutons désactivée'
                                : 'Congé approuvé: modification des boutons désactivée',
                            style: TextStyle(
                              fontSize: mobile ? 11 : 10,
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  static Future<({DateTime startDate, DateTime endDate})?> _showFormationDateRangeDialog(
    BuildContext context, {
    required String employeNom,
    required DateTime day,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
  }) async {
    DateTime startDate = DateTime(
      (initialStartDate ?? day).year,
      (initialStartDate ?? day).month,
      (initialStartDate ?? day).day,
    );
    DateTime endDate = DateTime(
      (initialEndDate ?? day).year,
      (initialEndDate ?? day).month,
      (initialEndDate ?? day).day,
    );
    if (!context.mounted) return null;
    return showDialog<({DateTime startDate, DateTime endDate})>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final invalidRange = endDate.isBefore(startDate);
            return AlertDialog(
              title: const Text('Planifier formation (jours)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(employeNom, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Date début'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(day.year - 1),
                          lastDate: DateTime(day.year + 2, 12, 31),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = DateTime(picked.year, picked.month, picked.day);
                            if (endDate.isBefore(startDate)) endDate = startDate;
                          });
                        }
                      },
                      child: Text('${startDate.day}/${startDate.month}/${startDate.year}'),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available),
                    title: const Text('Date fin'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate.isBefore(startDate) ? startDate : endDate,
                          firstDate: startDate,
                          lastDate: DateTime(day.year + 2, 12, 31),
                        );
                        if (picked != null) {
                          setDialogState(() => endDate = DateTime(picked.year, picked.month, picked.day));
                        }
                      },
                      child: Text('${endDate.day}/${endDate.month}/${endDate.year}'),
                    ),
                  ),
                  if (invalidRange)
                    Text(
                      'La date de fin doit être après (ou égale à) la date de début.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
                FilledButton.icon(
                  onPressed: invalidRange
                      ? null
                      : () => Navigator.of(context).pop((startDate: startDate, endDate: endDate)),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Appliquer'),
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
    final chefEquipeList = equipes.where((e) => e.id == auth.equipeId).toList();
    final chefEquipe = chefEquipeList.isEmpty ? null : chefEquipeList.first;
    final baseWorkers = getWorkersForEquipeConsideringTemp(
      equipes,
      employes,
      auth.equipeId,
      recordByEmployeId,
      // Keep renfort visible in target team for chef pointage.
      shouldShowRenfortInTarget: (_) => true,
      // Remove from original team view when assigned temporarily elsewhere.
      shouldShowMemberInOriginal: (_) => true,
    );
    final overtimeWorkerIds = <String>{};

    // Keep pointage focused on the team list only; overtime follows the dedicated page.
    final workers = List<Employe>.from(baseWorkers)
      ..sort((a, b) => a.nom.compareTo(b.nom));
    workers.sort((a, b) => a.nom.compareTo(b.nom));
    // Afficher tous les travailleurs ; ceux en formation/congé sont en badge sans choix présent/absent
    final workersDisplay = workers;
    final overtimeWorkers = workersDisplay.where((w) => overtimeWorkerIds.contains(w.id)).toList();
    final regularWorkers = workersDisplay.where((w) => !overtimeWorkerIds.contains(w.id)).toList();
    final workersInTraining = workers.where((e) => pointageProvider.getRecordForEmployee(e.id)?.adminFinalStatus == AttendanceStatus.training).toList();
    AttendanceState getState(String id) {
      final record = pointageProvider.getRecordForEmployee(id);
      if (record?.adminFinalStatus == AttendanceStatus.training) return AttendanceState.present;
      if (record?.adminFinalStatus == AttendanceStatus.leave) return AttendanceState.present;
      if (overtimeWorkerIds.contains(id)) {
        final s = record?.overtimeChefStatus ?? ChefPointageStatus.unset;
        return _chefStatusToState(s);
      }
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
        // Ensure all workers have a locked-in status before locking the report.
        // Unmarked workers are treated as absent.
        // Skip workers on approved leave or in training (already handled by admin).
        // For overtime workers, check overtimeChefStatus; for regular workers, check chefStatus.
        for (final w in workersDisplay) {
          final isOvertimeWorker = overtimeWorkerIds.contains(w.id);
          final r = pointageProvider.getRecordForEmployee(w.id);
          // Skip leave/training — their status is set by admin, not chef
          if (r?.adminFinalStatus == AttendanceStatus.leave ||
              r?.adminFinalStatus == AttendanceStatus.training) continue;
          final isUnmarked = isOvertimeWorker
              ? (r?.overtimeChefStatus ?? ChefPointageStatus.unset) == ChefPointageStatus.unset
              : (r == null || r.chefStatus == ChefPointageStatus.unset);
          if (isUnmarked) {
            if (isOvertimeWorker && r != null) {
              await pointageProvider.markOvertimeChefAttendance(
                record: r,
                overtimeChefStatus: ChefPointageStatus.absent,
                chefId: auth.currentUser?.id,
                configOverride: pointageConfig,
              );
            } else {
              await pointageProvider.markChefAttendance(
                employeId: w.id,
                employeNom: w.nom,
                employeCin: w.cin,
                equipeId: equipeId,
                equipeName: equipeName,
                chefName: auth.currentUser?.nom ?? '',
                chefStatus: ChefPointageStatus.absent,
                chefId: auth.currentUser?.id,
                absenceReason: null,
                configOverride: pointageConfig,
              );
            }
          }
        }
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
          final sortieOk = workersDisplay.where((w) {
            final r = pointageProvider.getRecordForEmployee(w.id);
            return (r?.isFinalPresent ?? false) && r?.departureStatus == DepartureStatus.finished;
          }).length;
          final sortieNotConfirmed = workersDisplay.where((w) {
            final r = pointageProvider.getRecordForEmployee(w.id);
            return (r?.isFinalPresent ?? false) && r?.departureStatus != DepartureStatus.finished;
          }).length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$reportSentMsgChef — Sortie OK: $sortieOk | Non confirmée: $sortieNotConfirmed'),
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
    final today = DateTime(now.year, now.month, now.day);
    final shiftForChef = chefEquipe != null ? shiftsProvider.getShiftForEquipe(chefEquipe.id, today) : null;
    final config = getConfigForEquipeAndDate(chefEquipe, today, shiftForChef);
    final hoursStatus = getPointageHoursStatus(now, config);
    final ignoreTime = pointageProvider.ignoreTimeWindowsForTest;
    final isWithinArrival = ignoreTime || config.canMarkArrivalNow(now);
    final isWithinDeparture = ignoreTime || config.canMarkDepartureNow(now);
    final mobile = isMobile(context);

    final nonWorkingIds = pointageProvider.nonWorkingEquipeIds;

    Widget buildWorkerCard(Employe e) {
      final isOvertimeWorker = overtimeWorkerIds.contains(e.id);
      final record = pointageProvider.getRecordForEmployee(e.id);
      final isInTraining = record?.adminFinalStatus == AttendanceStatus.training;
      final isOnLeave = record?.adminFinalStatus == AttendanceStatus.leave;

      // Congé approuvé: carte non-interactive identique au badge formation
      if (isOnLeave) {
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
                      Icon(Icons.beach_access, size: 16, color: const Color(0xFF0D47A1)),
                      SizedBox(width: 6),
                      Text('Congé approuvé', style: TextStyle(fontSize: mobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0D47A1))),
                    ],
                  ),
                  backgroundColor: const Color(0xFFE3F2FD),
                  side: const BorderSide(color: Color(0xFF90CAF9)),
                ),
              ],
            ),
          ),
        );
      }

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
            date: getPointageDateForConfig(config, now),
            createdAt: DateTime.now(),
          );
      final canMarkArrival = !locked && isWithinArrival;
      final canMarkDeparture = isWithinDeparture;
      AttendanceState getOvertimeState(String id) {
        final r = pointageProvider.getRecordForEmployee(id);
        final s = r?.overtimeChefStatus ?? ChefPointageStatus.unset;
        if (s == ChefPointageStatus.present) return AttendanceState.present;
        if (s == ChefPointageStatus.absent) return AttendanceState.absent;
        return AttendanceState.unmarked;
      }
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
                    if (isOvertimeWorker)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tr(context, 'overtime_extra_shift'),
                            style: TextStyle(fontSize: mobile ? 11 : 10, color: Colors.purple.shade700),
                          ),
                        ),
                      ),
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
                    bool ok;
                    if (isOvertimeWorker && record != null) {
                      // Overtime workers: mark using overtimeChefStatus, not the original chefStatus.
                      ok = await pointageProvider.markOvertimeChefAttendance(
                        record: record,
                        overtimeChefStatus: _stateToChefStatus(s),
                        chefId: auth.currentUser?.id,
                        configOverride: config,
                      );
                    } else {
                      ok = await pointageProvider.markChefAttendance(
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
                    }
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
                  onStillWorking: (int? workedMinutesBeforeStop, String? incompleteShiftReason) async {
                    final ok = await pointageProvider.setDepartureStatus(
                      record: recordOrPlaceholder,
                      status: DepartureStatus.stillWorking,
                      workedMinutesBeforeStop: workedMinutesBeforeStop,
                      incompleteShiftReason: incompleteShiftReason,
                      configOverride: config,
                    );
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                      );
                    }
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
                  stillLabel: 'N\'a pas terminé',
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
            if (overtimeWorkers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Material(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 22, color: Colors.purple.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Heures sup.: ${overtimeWorkers.length} personne(s) vont compléter un shift avec vous.',
                          style: TextStyle(fontSize: 13, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            // ── أزرار تأكيد جماعي ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmer présence de tous', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isWithinArrival ? () async {
                      final equipeId = auth.equipeId ?? '';
                      final equipe = equipes.where((e) => e.id == equipeId).toList();
                      final equipeName = equipe.isNotEmpty ? equipe.first.nom : '';
                      final today = DateTime.now();
                      final shiftForEquipe = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, today) : null;
                      final cfg = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, today, shiftForEquipe);
                      for (final w in workersDisplay) {
                        final isOvertimeW = overtimeWorkerIds.contains(w.id);
                        final r = pointageProvider.getRecordForEmployee(w.id);
                        final alreadyMarked = isOvertimeW
                            ? (r?.overtimeChefStatus ?? ChefPointageStatus.unset) != ChefPointageStatus.unset
                            : (r != null && r.chefStatus != ChefPointageStatus.unset);
                        if (alreadyMarked) continue;
                        if (isOvertimeW && r != null) {
                          await pointageProvider.markOvertimeChefAttendance(
                            record: r,
                            overtimeChefStatus: ChefPointageStatus.present,
                            chefId: auth.currentUser?.id,
                            configOverride: cfg,
                          );
                        } else {
                          await pointageProvider.markChefAttendance(
                            employeId: w.id,
                            employeNom: w.nom,
                            employeCin: w.cin,
                            equipeId: equipeId,
                            equipeName: equipeName,
                            chefName: auth.currentUser?.nom ?? '',
                            chefStatus: ChefPointageStatus.present,
                            chefId: auth.currentUser?.id,
                            absenceReason: null,
                            configOverride: cfg,
                          );
                        }
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Présence de tous les membres confirmée'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    } : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Confirmer sortie de tous', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: isWithinDeparture ? () async {
                      final equipe = equipes.where((e) => e.id == auth.equipeId).toList();
                      final today = DateTime.now();
                      final shiftForEquipe = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, today) : null;
                      final cfg = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, today, shiftForEquipe);
                      for (final w in workersDisplay) {
                        final r = pointageProvider.getRecordForEmployee(w.id);
                        if (r == null) continue;
                        if (!(r.isFinalPresent)) continue;
                        if (r.departureStatus == DepartureStatus.finished) continue;
                        await pointageProvider.setDepartureStatus(
                          record: r,
                          status: DepartureStatus.finished,
                          overtimeMinutes: 0,
                          configOverride: cfg,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sortie de tous les membres présents confirmée'),
                            backgroundColor: Colors.blue,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    } : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  ...regularWorkers.map((e) => buildWorkerCard(e)),
                  if (overtimeWorkers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        'Personnes Heures Sup. (section séparée)',
                        style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...overtimeWorkers.map((e) => buildWorkerCard(e)),
                  ],
                ],
              ),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final presentNames = <String>[];
                final presentNoDepartureNames = <String>[];
                final absentWorkers = workersDisplay.where((w) => getState(w.id) != AttendanceState.present).toList();
                for (final w in workersDisplay) {
                  if (getState(w.id) != AttendanceState.present) continue;
                  final r = pointageProvider.getRecordForEmployee(w.id);
                  if (r?.departureStatus == DepartureStatus.finished) {
                    presentNames.add(w.nom);
                  } else {
                    presentNoDepartureNames.add(w.nom);
                  }
                }
                final absentNames = absentWorkers.map((e) => e.nom).toList();
                final absentReasons = absentWorkers.map((e) => pointageProvider.getRecordForEmployee(e.id)?.absenceReason).toList();
                final chefExportName = chefEquipe != null ? _chefNameForEquipe(chefEquipe, employes) : '';
                final filePath = await PointageExportService.shareDailyReportPdf(
                  date: DateTime.now(),
                  title: trOf(context, 'report_presence_title'),
                  presentNames: presentNames,
                  presentNoDepartureNames: presentNoDepartureNames,
                  absentNames: absentNames,
                  absentReasons: absentReasons,
                  signatureLabel: trOf(context, 'pointage_signature_chef'),
                  personName: auth.currentUser?.nom ?? '',
                  equipeName: equipeNameForTitle.isNotEmpty ? equipeNameForTitle : null,
                  chefName: chefExportName.isNotEmpty ? chefExportName : null,
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
                onTap: isWithinDeparture ? sendReport : null,
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
          const SizedBox(height: 10),
          Material(
            color: Colors.blueGrey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 20, color: Colors.blueGrey[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Test créneaux (± 8h)',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey[800]),
                    ),
                  ),
                  Switch(
                    value: pointageProvider.ignoreTimeWindowsForTest,
                    onChanged: (v) => pointageProvider.setIgnoreTimeWindowsForTest(v),
                    activeColor: Colors.blueGrey,
                  ),
                ],
              ),
            ),
          ),
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
          if (overtimeWorkers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 22, color: Colors.purple.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Heures sup.: ${overtimeWorkers.length} personne(s) vont compléter un shift avec vous.',
                        style: TextStyle(fontSize: 13, color: Colors.purple.shade900, fontWeight: FontWeight.w600),
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
          else ...[
            ...regularWorkers.map((e) => buildWorkerCard(e)),
            if (overtimeWorkers.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Text(
                  'Personnes Heures Sup. (section séparée)',
                  style: TextStyle(color: Colors.purple.shade800, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              ...overtimeWorkers.map((e) => buildWorkerCard(e)),
            ],
          ],
          OutlinedButton.icon(
            onPressed: () async {
              final presentNames = <String>[];
              final presentNoDepartureNames = <String>[];
              final absentWorkers = workersDisplay.where((w) => getState(w.id) != AttendanceState.present).toList();
              for (final w in workersDisplay) {
                if (getState(w.id) != AttendanceState.present) continue;
                final r = pointageProvider.getRecordForEmployee(w.id);
                if (r?.departureStatus == DepartureStatus.finished) {
                  presentNames.add(w.nom);
                } else {
                  presentNoDepartureNames.add(w.nom);
                }
              }
              final absentNames = absentWorkers.map((e) => e.nom).toList();
              final absentReasons = absentWorkers.map((e) => pointageProvider.getRecordForEmployee(e.id)?.absenceReason).toList();
              final chefExportName = chefEquipe != null ? _chefNameForEquipe(chefEquipe, employes) : '';
              final filePath = await PointageExportService.shareDailyReportPdf(
                date: DateTime.now(),
                title: trOf(context, 'report_presence_title'),
                presentNames: presentNames,
                presentNoDepartureNames: presentNoDepartureNames,
                absentNames: absentNames,
                absentReasons: absentReasons,
                signatureLabel: trOf(context, 'pointage_signature_chef'),
                personName: auth.currentUser?.nom ?? '',
                equipeName: equipeNameForTitle.isNotEmpty ? equipeNameForTitle : null,
                chefName: chefExportName.isNotEmpty ? chefExportName : null,
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
              onTap: isWithinDeparture ? sendReport : null,
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
  final void Function(int? workedMinutesBeforeStop, String? incompleteShiftReason) onStillWorking;
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
          onSelected: (_) async {
            final workedHoursCtrl = TextEditingController();
            final reasonCtrl = TextEditingController();
            final data = await showDialog<({int? workedMinutes, String? reason})>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
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
                    TextButton(
                      onPressed: () {
                        final hours = double.tryParse(workedHoursCtrl.text.trim().replaceAll(',', '.'));
                        final workedMinutes = (hours != null && hours >= 0) ? (hours * 60).round() : null;
                        final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
                        Navigator.pop(ctx, (workedMinutes: workedMinutes, reason: reason));
                      },
                      child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                    ),
                  ],
                );
              },
            );
            onStillWorking(data?.workedMinutes, data?.reason);
          },
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
        msg = tr(this.context, 'pointage_arrival_window').replaceFirst('%s', config.arrivalWindowFormatted(now));
      } else if (config.isWithinDepartureWindow(now)) {
        msg = tr(this.context, 'pointage_departure_window').replaceFirst('%s', config.departureWindowFormatted(now));
      } else {
        msg = tr(this.context, 'pointage_arrival_window').replaceFirst('%s', config.arrivalWindowFormatted(now));
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
// ─────────────────────────────────────────────────────────────────────────────
// Période preset pour les statistiques d'analyse
// ─────────────────────────────────────────────────────────────────────────────
enum _PeriodPreset { today, week, month, custom }

class _PointageAnalysisSection extends StatefulWidget {
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

  @override
  State<_PointageAnalysisSection> createState() => _PointageAnalysisSectionState();
}

class _PointageAnalysisSectionState extends State<_PointageAnalysisSection> {
  _PeriodPreset _preset = _PeriodPreset.today;
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  List<PointageRecord>? _rangeRecords;
  bool _loadingRange = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _rangeStart = DateTime(today.year, today.month, today.day);
    _rangeEnd = _rangeStart;
  }

  bool get _isMultiDay => !_rangeStart.isAtSameMomentAs(_rangeEnd) ||
      _rangeStart.day != _rangeEnd.day ||
      _rangeStart.month != _rangeEnd.month ||
      _rangeStart.year != _rangeEnd.year;

  Future<void> _loadRange() async {
    setState(() { _loadingRange = true; });
    try {
      final provider = context.read<PointageProvider>();
      final records = await provider.getPointageForDateRange(_rangeStart, _rangeEnd);
      if (mounted) setState(() { _rangeRecords = records; _loadingRange = false; });
    } catch (_) {
      if (mounted) setState(() { _rangeRecords = []; _loadingRange = false; });
    }
  }

  void _applyPreset(_PeriodPreset preset) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    DateTime start, end;
    switch (preset) {
      case _PeriodPreset.today:
        start = todayDate;
        end = todayDate;
        break;
      case _PeriodPreset.week:
        final weekday = today.weekday;
        start = todayDate.subtract(Duration(days: weekday - 1));
        end = todayDate;
        break;
      case _PeriodPreset.month:
        start = DateTime(today.year, today.month, 1);
        end = todayDate;
        break;
      case _PeriodPreset.custom:
        start = _rangeStart;
        end = _rangeEnd;
        break;
    }
    setState(() {
      _preset = preset;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeRecords = null;
    });
    if (preset != _PeriodPreset.today) _loadRange();
  }

  PointageRecord? _getRecordForPeriod(String employeId) {
    if (_preset == _PeriodPreset.today) return widget.getRecord(employeId);
    if (_rangeRecords == null) return null;
    final list = _rangeRecords!.where((r) => r.employeId == employeId && !r.tempAssigned).toList();
    return list.isEmpty ? null : list.first;
  }

  /// 8 heures fixes (480 min) par jour de présence confirmée.
  static const int _shiftMinutes = 8 * 60;

  int _workedMinutesForPeriod(String employeId) {
    return _presentDaysForPeriod(employeId) * _shiftMinutes;
  }

  /// Nombre de jours présents sur la période pour un employé.
  int _presentDaysForPeriod(String employeId) {
    if (_preset == _PeriodPreset.today) {
      final r = widget.getRecord(employeId);
      return (r?.isFinalPresent ?? false) ? 1 : 0;
    }
    if (_rangeRecords == null) return 0;
    return _rangeRecords!.where((r) => r.employeId == employeId && !r.tempAssigned && r.isFinalPresent).length;
  }

  /// Nombre de jours absents sur la période pour un employé.
  int _absentDaysForPeriod(String employeId, int totalDays) {
    return totalDays - _presentDaysForPeriod(employeId);
  }

  /// Total ساعات إضافية (دقائق) لموظف على الفترة.
  int _overtimeMinutesForPeriod(String employeId) {
    if (_preset == _PeriodPreset.today) {
      final r = widget.getRecord(employeId);
      return (r?.overtimeMinutes ?? 0) < 0 ? 0 : (r?.overtimeMinutes ?? 0);
    }
    if (_rangeRecords == null) return 0;
    int total = 0;
    for (final r in _rangeRecords!.where((r) => r.employeId == employeId && !r.tempAssigned)) {
      total += (r.overtimeMinutes ?? 0) < 0 ? 0 : (r.overtimeMinutes ?? 0);
    }
    return total;
  }

  /// عدد أيام العمل في الفترة (أيام تقويمية).
  int get _totalDaysInRange {
    return _rangeEnd.difference(_rangeStart).inDays + 1;
  }

  static String _minToHStr(int minutes) {
    if (minutes <= 0) return '0 h';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h h';
    return '$h h $m min';
  }


  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final primary = Theme.of(context).primaryColor;
    final workTeams = widget.teams.where((t) => !widget.nonWorkingIds.contains(t.equipeId)).toList();
    final multiDay = _isMultiDay;
    final totalDays = _totalDaysInRange;

    // ─── Sélecteur de période ───────────────────────────────────────────────
    Widget periodSelector = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _periodChip(context, _PeriodPreset.today, 'Aujourd\'hui', Icons.today),
        _periodChip(context, _PeriodPreset.week, 'Cette semaine', Icons.view_week),
        _periodChip(context, _PeriodPreset.month, 'Ce mois', Icons.calendar_month),
        _periodChip(context, _PeriodPreset.custom, 'Personnalisé', Icons.date_range),
      ],
    );

    Widget customDateRow = const SizedBox.shrink();
    if (_preset == _PeriodPreset.custom) {
      final fmt = (DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      customDateRow = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            _datePickerBtn(context, 'De: ${fmt(_rangeStart)}', () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _rangeStart,
                firstDate: DateTime(2023),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() {
                  _rangeStart = DateTime(picked.year, picked.month, picked.day);
                  if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = _rangeStart;
                  _rangeRecords = null;
                });
                _loadRange();
              }
            }),
            const SizedBox(width: 8),
            _datePickerBtn(context, 'À: ${fmt(_rangeEnd)}', () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _rangeEnd.isBefore(_rangeStart) ? _rangeStart : _rangeEnd,
                firstDate: _rangeStart,
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() {
                  _rangeEnd = DateTime(picked.year, picked.month, picked.day);
                  _rangeRecords = null;
                });
                _loadRange();
              }
            }),
          ],
        ),
      );
    }

    // ─── Résumé de la période ───────────────────────────────────────────────
    final allWorkers = workTeams.expand((t) => t.workers).toList();
    final effectiveTotalDays = multiDay ? totalDays : 1;
    int totalWorkedMin = 0;
    int totalOvertimeMin = 0;
    int totalPresentDays = 0;
    int totalAbsentDays = 0;
    for (final w in allWorkers) {
      totalWorkedMin += _workedMinutesForPeriod(w.id);
      totalOvertimeMin += _overtimeMinutesForPeriod(w.id);
      totalPresentDays += _presentDaysForPeriod(w.id);
      totalAbsentDays += _absentDaysForPeriod(w.id, effectiveTotalDays);
    }
    final totalAbsenceMin = totalAbsentDays * _shiftMinutes;

    Widget summaryCard = Card(
      color: primary.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary.withValues(alpha: 0.15)),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Résumé — ${allWorkers.length} employé(s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 14, color: primary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _summaryChip(context, Icons.check_circle_outline, 'Heures travaillées', _minToHStr(totalWorkedMin), Colors.green),
                _summaryChip(context, Icons.cancel_outlined, 'Heures absences (≈)', _minToHStr(totalAbsenceMin), Colors.red),
                _summaryChip(context, Icons.more_time, 'Heures sup.', _minToHStr(totalOvertimeMin), Colors.orange),
                _summaryChip(context, Icons.summarize_outlined, 'Total (travail + sup.)', _minToHStr(totalWorkedMin + totalOvertimeMin), primary),
              ],
            ),
          ],
        ),
      ),
    );

    if (workTeams.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              Text('Analyse présence', style: TextStyle(fontSize: mobile ? 15 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Par équipe — durée, arrivée, départ, heures sup.', style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
            ],
            periodSelector,
            customDateRow,
            const SizedBox(height: 16),
            Center(child: Text('Aucune donnée', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          ],
        ),
      );
    }

    if (_loadingRange) {
      return Column(
        children: [
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showHeader) ...[
                  Text('Analyse présence', style: TextStyle(fontSize: mobile ? 15 : 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                periodSelector,
                customDateRow,
              ],
            ),
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    // ─── Contenu principal ──────────────────────────────────────────────────
    final notRecorded = '—';
    final personLabel = 'Employé';
    final workedLabel = 'Heures travaillées';
    final overtimeLabel = 'Heures sup.';
    final totalLabel = 'Total';

    List<Widget> teamCards = workTeams.map((t) {
      int teamWorked = 0, teamOvertime = 0;
      for (final w in t.workers) {
        teamWorked += _workedMinutesForPeriod(w.id);
        teamOvertime += _overtimeMinutesForPeriod(w.id);
      }

      if (mobile) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: padding, vertical: 6),
            childrenPadding: EdgeInsets.only(left: padding, right: padding, bottom: padding, top: 4),
            leading: Icon(Icons.groups, color: primary, size: 22),
            title: Text('${t.equipeName} — ${t.chefName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${t.workers.length} travailleur(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text('Travaillé: ${_minToHStr(teamWorked)} | Sup: ${_minToHStr(teamOvertime)} | Total: ${_minToHStr(teamWorked + teamOvertime)}', style: TextStyle(fontSize: 11, color: primary)),
              ],
            ),
            children: [
              ...t.workers.map((e) {
                final workedMin = _workedMinutesForPeriod(e.id);
                final overtimeMin = _overtimeMinutesForPeriod(e.id);
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
                        _analysisRow(context, workedLabel, _minToHStr(workedMin), Colors.blue.shade700),
                        const SizedBox(height: 4),
                        _analysisRow(context, overtimeLabel, overtimeMin > 0 ? _minToHStr(overtimeMin) : notRecorded, Colors.orange),
                        const SizedBox(height: 4),
                        _analysisRow(context, totalLabel, _minToHStr(workedMin + overtimeMin), primary),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }

      // Desktop
      return Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          childrenPadding: const EdgeInsets.only(left: 14, right: 14, bottom: 14, top: 4),
          leading: Icon(Icons.groups, color: primary, size: 22),
          title: Text('${t.equipeName} — ${t.chefName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${t.workers.length} travailleur(s)  |  Travaillé: ${_minToHStr(teamWorked)}  |  Sup: ${_minToHStr(teamOvertime)}  |  Total: ${_minToHStr(teamWorked + teamOvertime)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: [
                    _cell(personLabel, bold: true),
                    _cell(workedLabel, bold: true),
                    _cell(overtimeLabel, bold: true),
                    _cell(totalLabel, bold: true),
                  ],
                ),
                ...t.workers.map((e) {
                  final workedMin = _workedMinutesForPeriod(e.id);
                  final overtimeMin = _overtimeMinutesForPeriod(e.id);
                  return TableRow(children: [
                    _cell(e.nom),
                    _cell(_minToHStr(workedMin), color: Colors.blue.shade700),
                    _cell(overtimeMin > 0 ? _minToHStr(overtimeMin) : notRecorded, color: overtimeMin > 0 ? Colors.orange : null),
                    _cell(_minToHStr(workedMin + overtimeMin), color: primary, bold: true),
                  ]);
                }),
                TableRow(
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.07)),
                  children: [
                    _cell('Total équipe', bold: true),
                    _cell(_minToHStr(teamWorked), color: Colors.blue.shade700, bold: true),
                    _cell(_minToHStr(teamOvertime), color: Colors.orange, bold: true),
                    _cell(_minToHStr(teamWorked + teamOvertime), color: primary, bold: true),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            Text('Analyse présence', style: TextStyle(fontSize: mobile ? 15 : 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Par équipe — durée, arrivée, départ, heures sup.', style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
          ],
          periodSelector,
          customDateRow,
          const SizedBox(height: 12),
          summaryCard,
          ...teamCards,
        ],
      ),
    );
  }

  Widget _periodChip(BuildContext context, _PeriodPreset preset, String label, IconData icon) {
    final selected = _preset == preset;
    final color = Theme.of(context).primaryColor;
    return FilterChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: selected ? color : Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: selected ? color : Colors.grey.shade800)),
        ],
      ),
      onSelected: (_) => _applyPreset(preset),
      selectedColor: color.withValues(alpha: 0.12),
      checkmarkColor: color,
      side: BorderSide(color: selected ? color.withValues(alpha: 0.4) : Colors.grey.shade300),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  Widget _datePickerBtn(BuildContext context, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.07),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static Widget _summaryChip(BuildContext context, IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _analysisRow(BuildContext context, String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: valueColor, fontWeight: valueColor != null ? FontWeight.w600 : null), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  static Widget _cell(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet Formation — gestion des formations pour les employés
// ─────────────────────────────────────────────────────────────────────────────
class _FormationManagementPage extends StatefulWidget {
  final List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams;
  final PointageProvider pointageProvider;
  final List<Employe> employes;

  const _FormationManagementPage({
    required this.teams,
    required this.pointageProvider,
    required this.employes,
  });

  @override
  State<_FormationManagementPage> createState() => _FormationManagementPageState();
}

class _FormationManagementPageState extends State<_FormationManagementPage> {
  String? _selectedEquipeId;
  final Set<String> _selectedEmployeIds = {};
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _saving = false;

  // Formation records already active (loaded once per equipe selection)
  Set<String> _alreadyInFormationIds = {};
  bool _loadingFormation = false;

  @override
  void initState() {
    super.initState();
    if (widget.teams.isNotEmpty) {
      _selectedEquipeId = widget.teams.first.equipeId;
      _loadFormationStatus();
    }
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = _startDate;
  }

  List<Employe> get _currentWorkers {
    if (_selectedEquipeId == null) return [];
    final t = widget.teams.where((t) => t.equipeId == _selectedEquipeId).toList();
    return t.isEmpty ? [] : t.first.workers;
  }

  Future<void> _loadFormationStatus() async {
    setState(() { _loadingFormation = true; _alreadyInFormationIds = {}; });
    final ids = <String>{};
    for (final e in _currentWorkers) {
      final r = await widget.pointageProvider.getRecordForEmployeeForDate(e.id, _startDate);
      if (r?.adminFinalStatus == AttendanceStatus.training) ids.add(e.id);
    }
    if (mounted) setState(() { _alreadyInFormationIds = ids; _loadingFormation = false; });
  }

  Future<void> _save() async {
    if (_selectedEmployeIds.isEmpty) return;
    final team = widget.teams.where((t) => t.equipeId == _selectedEquipeId).toList();
    if (team.isEmpty) return;
    setState(() => _saving = true);
    final t = team.first;
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      for (final id in _selectedEmployeIds) {
        final empList = _currentWorkers.where((w) => w.id == id).toList();
        if (empList.isEmpty) continue;
        final e = empList.first;
        await widget.pointageProvider.setAdminOverrideForEmployee(
          employeId: e.id,
          employeNom: e.nom,
          employeCin: e.cin,
          equipeId: t.equipeId,
          equipeName: t.equipeName,
          chefName: t.chefName,
          status: AttendanceStatus.training,
          viewDate: d,
          trainingStartAt: start,
          trainingEndAt: DateTime(end.year, end.month, end.day, 23, 59, 59),
        );
      }
    }
    if (mounted) {
      setState(() { _saving = false; _selectedEmployeIds.clear(); });
      await _loadFormationStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formation planifiée avec succès'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final workers = _currentWorkers;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Titre ───────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Gestion des Formations',
                style: TextStyle(fontSize: mobile ? 16 : 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Planifiez une formation pour un ou plusieurs employés.',
            style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          // ─── Formulaire ───────────────────────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(mobile ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélection équipe
                  Text('Équipe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 13 : 14)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedEquipeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: widget.teams
                        .map((t) => DropdownMenuItem(
                              value: t.equipeId,
                              child: Text('${t.equipeName} — ${t.chefName}', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedEquipeId = v;
                        _selectedEmployeIds.clear();
                      });
                      _loadFormationStatus();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Période
                  Text('Période de formation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 13 : 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'Du',
                          date: _startDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _startDate = DateTime(picked.year, picked.month, picked.day);
                                if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                                _selectedEmployeIds.clear();
                              });
                              _loadFormationStatus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateButton(
                          label: 'Au',
                          date: _endDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && mounted) {
                              setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Liste des employés
                  Text('Employés', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 13 : 14)),
                  const SizedBox(height: 6),
                  if (_loadingFormation)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (workers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucun employé dans cette équipe.', style: TextStyle(color: Colors.grey[600])),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: workers.map((e) {
                          final alreadyIn = _alreadyInFormationIds.contains(e.id);
                          final selected = _selectedEmployeIds.contains(e.id);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            onChanged: alreadyIn
                                ? null
                                : (v) => setState(() {
                                      if (v == true) {
                                        _selectedEmployeIds.add(e.id);
                                      } else {
                                        _selectedEmployeIds.remove(e.id);
                                      }
                                    }),
                            title: Text(
                              e.nom,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: alreadyIn ? Colors.grey : null,
                              ),
                            ),
                            subtitle: alreadyIn
                                ? Text(
                                    'Déjà en formation — ${_fmtDate(_startDate)}',
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                                  )
                                : null,
                            secondary: alreadyIn
                                ? Icon(Icons.school, size: 18, color: Colors.blue.shade400)
                                : null,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Bouton enregistrer
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_selectedEmployeIds.isEmpty || _saving)
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.school, size: 18),
                      label: Text(
                        _saving
                            ? 'Enregistrement...'
                            : 'Planifier la formation (${_fmtDate(_startDate)} → ${_fmtDate(_endDate)})',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Employés actuellement en formation ──────────────────────────
          if (_alreadyInFormationIds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Text(
                  'En formation le ${_fmtDate(_startDate)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 14, color: Colors.blue.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...workers.where((w) => _alreadyInFormationIds.contains(w.id)).map((e) => Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.school, color: Colors.blue.shade700, size: 20),
                    title: Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.check_circle, color: Colors.blue.shade400, size: 18),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final fmt = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text(fmt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcelDateRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final List<({String id, String label})> equipeOptions;

  const _ExcelDateRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.equipeOptions,
  });

  @override
  State<_ExcelDateRangeDialog> createState() => _ExcelDateRangeDialogState();
}

class _ExcelDateRangeDialogState extends State<_ExcelDateRangeDialog> {
  late DateTime _start;
  late DateTime _end;
  String _scope = 'all';
  String? _selectedEquipeId;

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
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _scope,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Données à exporter',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Toutes les équipes')),
              DropdownMenuItem(value: 'groupes', child: Text('Groupes seulement')),
              DropdownMenuItem(value: 'normales', child: Text('Équipes normales seulement')),
              DropdownMenuItem(value: 'equipe', child: Text('Équipe spécifique')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _scope = v);
            },
          ),
          if (_scope == 'equipe') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedEquipeId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Choisir équipe',
                isDense: true,
              ),
              items: widget.equipeOptions
                  .map((e) => DropdownMenuItem<String>(
                        value: e.id,
                        child: Text(e.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedEquipeId = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (_scope == 'equipe' && (_selectedEquipeId == null || _selectedEquipeId!.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Choisissez une équipe pour continuer.'),
                  behavior: SnackBarBehavior.fixed,
                ),
              );
              return;
            }
            Navigator.pop(context, (
              start: _start,
              end: _end,
              scope: _scope,
              equipeId: _selectedEquipeId,
            ));
          },
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

class _ResetPointageRangeDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const _ResetPointageRangeDialog({
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<_ResetPointageRangeDialog> createState() => _ResetPointageRangeDialogState();
}

class _ResetPointageRangeDialogState extends State<_ResetPointageRangeDialog> {
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
      title: const Text('Plage à réinitialiser'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Du'),
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
            title: const Text('Au'),
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
