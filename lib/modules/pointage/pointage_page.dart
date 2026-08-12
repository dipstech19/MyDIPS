import 'dart:async';
import 'dart:math' as math;

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
import 'data/excel_validation_repository.dart';
import 'data/daily_confirmation_repository.dart';
import 'data/daily_snapshot_repository.dart';
import '../shifts/shifts_provider.dart';
import '../overtime/overtime_provider.dart';
import '../overtime/models/overtime_model.dart';
import '../shifts/models/shift_models.dart';
import 'models/absence_reason_config.dart';
import 'models/pointage_model.dart';
import 'services/pointage_export_service.dart';
import 'widgets/feuille_pointage_share.dart';
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

  bool _isProtectedHigherPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef de zone') ||
        p.contains('chef d\'atelier') ||
        p.contains('rh') ||
        p.contains('admin') ||
        p.contains('directeur');
  }

  bool _isChefAtelierPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef atelier') || p.contains('chef d\'atelier') || p.contains('chef datelier');
  }

  // تأكيدات اليوم (real-time stream)
  List<DailyEquipeConfirmation> _dailyConfirmations = [];
  Stream<List<DailyEquipeConfirmation>>? _confirmationsStream;
  DateTime? _confirmationsStreamDate;

  // تأكيدات الأمس — لتنبيه الأدمن
  List<DailyEquipeConfirmation> _yesterdayConfirmations = [];
  Stream<List<DailyEquipeConfirmation>>? _yesterdayConfirmationsStream;
  DateTime? _yesterdayConfirmationsStreamDate;

  String? _selectedEquipeIdAdmin;
  DateTime _hsFilterDate = DateTime.now();
  String? _lastOvertimeListenDateKey;
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

  /// تحديث stream تأكيدات الأمس (للتنبيه)
  void _ensureYesterdayConfirmationsStream(DateTime today) {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (_yesterdayConfirmationsStreamDate?.isAtSameMomentAs(yesterday) == true) return;
    _yesterdayConfirmationsStreamDate = yesterday;
    _yesterdayConfirmationsStream = _confirmationRepo.watchConfirmationsForDate(yesterday);
  }

  /// Jour affiché pour l’admin : [PointageProvider.selectedReportDate] ou aujourd’ui (flux « today »).
  void _applyAdminViewDay(PointageProvider pointageProvider, DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    if (d == today) {
      pointageProvider.selectReportDate(null);
    } else {
      pointageProvider.selectReportDate(d);
    }
  }

  void _shiftAdminViewDay(PointageProvider pointageProvider, int deltaDays) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = pointageProvider.selectedReportDate;
    final current = selected != null
        ? DateTime(selected.year, selected.month, selected.day)
        : today;
    final next = current.add(Duration(days: deltaDays));
    if (next.isAfter(today)) return;
    if (next.year < 2020) return;
    _applyAdminViewDay(pointageProvider, next);
  }

  void _ensureHsDateListener(OvertimeProvider provider) {
    final key =
        '${_hsFilterDate.year}-${_hsFilterDate.month}-${_hsFilterDate.day}';
    if (_lastOvertimeListenDateKey == key) return;
    _lastOvertimeListenDateKey = key;
    provider.listenForDate(_hsFilterDate);
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

  void _showForceConfirmDialog(
    BuildContext context,
    _TeamWorkers t,
    DateTime logicalDay,
    PointageRecord? Function(String) getRecord,
  ) {
    final missingCount = t.workers.where((w) {
      final rec = getRecord(w.id);
      return rec == null || !rec.chefLocked;
    }).length;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            const Expanded(child: Text('Forcer la confirmation')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.equipeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            if (missingCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$missingCount collaborateur(s) sans rapport du chef.\nIls seront marqués comme absents.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Text(
              'Cette action confirme le pointage sans attendre la validation du chef d\'équipe.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (context.mounted) {
                await _doForceConfirm(context, t, logicalDay, getRecord);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Confirmer quand même'),
          ),
        ],
      ),
    );
  }

  Future<void> _doForceConfirm(
    BuildContext context,
    _TeamWorkers t,
    DateTime logicalDay,
    PointageRecord? Function(String) getRecord,
  ) async {
    final auth = context.read<AuthProvider>();
    final confirmedById = auth.currentUser?.id ?? '';
    int presentC = 0, absentC = 0;

    final empSnapshots = t.workers.map((w) {
      final rec = getRecord(w.id);
      String status;
      String? absenceReason;

      if (rec == null) {
        status = 'absent';
        absentC++;
      } else if (rec.adminFinalStatus == AttendanceStatus.training) {
        status = 'formation';
        presentC++;
      } else if (rec.adminFinalStatus == AttendanceStatus.leave || rec.status == AttendanceStatus.leave) {
        status = 'leave';
        presentC++;
      } else if (rec.isFinalPresent ||
          rec.chefStatus == ChefPointageStatus.present ||
          rec.driverStatus == DriverPointageStatus.present ||
          rec.driverStatus == DriverPointageStatus.enVehicule ||
          rec.status == AttendanceStatus.present) {
        status = 'present';
        presentC++;
      } else {
        status = 'absent';
        absenceReason = rec.absenceReason;
        absentC++;
      }

      return (
        employeId: w.id,
        employeNom: w.nom,
        employeCin: w.cin,
        status: status,
        absenceReason: absenceReason,
        isRestDay: false,
      );
    }).toList();

    try {
      await _snapshotRepo.saveEquipeSnapshot(
        equipeId: t.equipeId,
        equipeName: t.equipeName,
        date: logicalDay,
        confirmedById: confirmedById,
        employees: empSnapshots,
      );
      await _confirmationRepo.confirmEquipe(
        equipeId: t.equipeId,
        equipeName: t.equipeName,
        confirmedById: confirmedById,
        confirmedByName: auth.currentUser?.nom ?? 'Admin',
        date: logicalDay,
        presentCount: presentC,
        absentCount: absentC,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${t.equipeName} : confirmation forcée ✓'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.fixed,
        ));
      }
    }
  }

  void _showDepartureOverrideDialog(
    BuildContext context,
    PointageProvider pointageProvider,
    PointageRecord record,
    String employeeName,
  ) {
    final status = record.departureStatus;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sortie — $employeeName'),
        content: Text(
          switch (status) {
            DepartureStatus.finished => 'La sortie de cet employé est confirmée.',
            DepartureStatus.stillWorking => 'Le chef d\'équipe a signalé que cet employé n\'a pas terminé son poste.',
            DepartureStatus.unset => 'La sortie de cet employé n\'est pas encore confirmée par le chef d\'équipe.',
          },
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          if (status != DepartureStatus.unset)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await pointageProvider.resetDepartureStatus(record);
              },
              child: const Text('Réinitialiser'),
            ),
          if (status != DepartureStatus.finished)
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final ok = await pointageProvider.setDepartureStatus(
                  record: record,
                  status: DepartureStatus.finished,
                  overtimeMinutes: 0,
                  bypassTimeWindows: true,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.fixed),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmer la sortie'),
            ),
        ],
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
    final todayOnly = DateTime(now.year, now.month, now.day);
    final selectedReport = pointageProvider.selectedReportDate;
    final isViewingToday = selectedReport == null;
    final logicalDay = selectedReport != null
        ? DateTime(selectedReport.year, selectedReport.month, selectedReport.day)
        : todayOnly;
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
      pointageProvider.ensureNonWorkingLoadedForDate(logicalDay);
    });
    final nonWorkingIds = pointageProvider.nonWorkingEquipeIds;
    final shiftsProvider = context.watch<ShiftsProvider>();
    final effectiveNonWorkingIds = <String>{...nonWorkingIds};
    if (shiftsProvider.hasConfig) {
      for (final eid in shiftsProvider.config!.equipeIds) {
        if (eid.isEmpty) continue;
        if (shiftsProvider.getShiftForEquipe(eid, logicalDay) == ShiftType.rest) {
          effectiveNonWorkingIds.add(eid);
        }
      }
    }
    // Les équipes Management et Nettoyage ne travaillent pas le dimanche : ne pas les afficher pour le pointage.
    final isSundayForPointage = logicalDay.weekday == DateTime.sunday;
    if (isSundayForPointage) {
      for (final eq in equipes) {
        final dept = eq.magasin.trim().toLowerCase();
        final name = eq.nom.trim().toLowerCase();
        if (dept.contains('management') || dept.contains('managment') ||
            dept.contains('nettoyage') ||
            name.contains('management') || name.contains('managment') ||
            name.contains('nettoyage')) {
          effectiveNonWorkingIds.add(eq.id);
        }
      }
    }
    bool isRoboEquipe(Equipe eq) {
      final name = eq.nom.trim().toLowerCase();
      if (name.contains('robo') || name.contains('repos') || name.contains('repo')) return true;
      // Only treat as "repos" based on shift if the equipe is actually registered in the shifts config.
      if (shiftsProvider.hasConfig && (shiftsProvider.config?.equipeIds.contains(eq.id) ?? false)) {
        final shift = shiftsProvider.getShiftForEquipe(eq.id, logicalDay);
        return shift == ShiftType.rest;
      }
      return false;
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
      // Jour de repos hebdomadaire du groupe (ex: Nettoyage = dimanche) : ne pas l'afficher ce jour-là.
      if (g.weeklyRestWeekday == logicalDay.weekday) continue;
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
    var horsEquipeWorkers = isSundayForPointage
        ? <Employe>[]
        : employes
            .where((e) =>
                e.statut == EmployeStatut.enService &&
                !usedIdsInAnyEquipe.contains(e.id) &&
                !isChefEquipePoste(e.poste) &&
                e.departement.toLowerCase().contains('management') &&
                !e.departement.toLowerCase().contains('distribution'))
            .toList();
    horsEquipeWorkers = horsEquipeWorkers
        .where((e) {
          final rec = recordByEmployeId[e.id];
          if (rec == null || !rec.tempAssigned) return true;
          return rec.originalEquipeId != 'hors_equipe';
        })
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    List<_TeamWorkers> allTeams = [
      if (horsEquipeWorkers.isNotEmpty)
        (equipeId: 'hors_equipe', equipeName: 'Equipe Management', chefName: 'Admin', workers: horsEquipeWorkers),
      ...teams,
      ...groupeTeams,
    ];

    if (auth.isChefZoneAdmin) {
      allTeams = allTeams
          .map((t) => (
                equipeId: t.equipeId,
                equipeName: t.equipeName,
                chefName: t.chefName,
                workers: t.workers.where((w) => _isChefAtelierPoste(w.poste)).toList(),
              ))
          .where((t) => t.workers.isNotEmpty)
          .toList();
    }

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

    /// True = ready to be confirmed by admin:
    /// - both driver + chef already submitted (locked)
    /// - and for "present" cases: entry + exit are marked
    bool isWorkerReadyForAdminConfirm(PointageRecord? rec) {
      if (rec == null) return false;
      // Seul le rapport du chef est requis. L'admin fait la validation finale.
      if (!rec.chefLocked) return false;
      if (rec.chefStatus == ChefPointageStatus.unset) return false;
      return true;
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
              final densePhone = constraints.maxWidth < 480;
              final dateNav = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  Text(
                    'Date :',
                    style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Jour précédent',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _shiftAdminViewDay(pointageProvider, -1),
                    icon: Icon(Icons.chevron_left, size: densePhone ? 22 : 24, color: Colors.blueGrey.shade800),
                  ),
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: logicalDay,
                        firstDate: DateTime(2020),
                        lastDate: todayOnly,
                      );
                      if (p != null) {
                        _applyAdminViewDay(pointageProvider, DateTime(p.year, p.month, p.day));
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        '${logicalDay.day.toString().padLeft(2, '0')}/${logicalDay.month.toString().padLeft(2, '0')}/${logicalDay.year}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: densePhone ? 13 : 14,
                          color: Theme.of(context).primaryColor,
                          decoration: TextDecoration.underline,
                          decorationColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Jour suivant',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: isViewingToday ? null : () => _shiftAdminViewDay(pointageProvider, 1),
                    icon: Icon(Icons.chevron_right, size: densePhone ? 22 : 24, color: Colors.blueGrey.shade800),
                  ),
                  if (!isViewingToday)
                    TextButton(
                      onPressed: () => _applyAdminViewDay(pointageProvider, todayOnly),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Aujourd\'hui'),
                    ),
                  OutlinedButton(
                    onPressed: () => _applyAdminViewDay(pointageProvider, todayOnly.subtract(const Duration(days: 1))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Hier'),
                  ),
                ],
              );

              final exportBtn = ElevatedButton.icon(
                onPressed: () => _showExcelExportDialog(context, allTeams, equipes, employes, pointageProvider, shiftsProvider: shiftsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF000966),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: densePhone ? 12 : 16, vertical: densePhone ? 10 : 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.table_chart_outlined, size: densePhone ? 16 : 18),
                label: Text(
                  densePhone ? 'Exporter' : 'Exporter le pointage',
                  style: TextStyle(fontSize: densePhone ? 12 : 14),
                ),
              );

              if (densePhone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dateNav,
                    const SizedBox(height: 8),
                    exportBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Flexible(child: dateNav),
                  const SizedBox(width: 12),
                  exportBtn,
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
                    viewDate: logicalDay,
                    adminOverridePersistDate: isViewingToday ? null : logicalDay,
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
                  _ensureConfirmationsStream(logicalDay);
                  if (isViewingToday) _ensureYesterdayConfirmationsStream(logicalDay);
                  final workTeams = allTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                  return StreamBuilder<List<DailyEquipeConfirmation>>(
                    stream: _confirmationsStream,
                    builder: (ctx, snap) {
                      final confirmedIds = (snap.data ?? _dailyConfirmations).map((c) => c.equipeId).toSet();
                      if (snap.hasData) _dailyConfirmations = snap.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: workTeams.length,
                        itemBuilder: (_, i) {
                          final t = workTeams[i];
                          final isConfirmed = confirmedIds.contains(t.equipeId);
                          final isGroupScope = t.equipeId == 'hors_equipe' || t.equipeId.startsWith('groupe:');
                          int presentC = 0, absentC = 0;
                          for (final w in t.workers) {
                            final rec = getRecord(w.id);
                            if (isGroupScope) {
                              final admin = rec?.adminFinalStatus;
                              if (admin == AttendanceStatus.present || admin == AttendanceStatus.training || admin == AttendanceStatus.leave) {
                                presentC++;
                              } else {
                                absentC++;
                              }
                            } else {
                              if (rec?.isFinalPresent == true) {
                                presentC++;
                              } else {
                                absentC++;
                              }
                            }
                          }
                          final canConfirm = t.workers.isNotEmpty &&
                              t.workers.every((w) {
                                final rec = getRecord(w.id);
                                if (isGroupScope) {
                                  return rec?.adminFinalStatus == AttendanceStatus.present ||
                                      rec?.adminFinalStatus == AttendanceStatus.absent;
                                }
                                return isWorkerReadyForAdminConfirm(rec);
                              });

                          // Confirmation disponible uniquement après la fin du poste.
                          final cfgEquipeMobile = equipes.where((e) => e.id == t.equipeId).toList();
                          final cfgEquipeObjM = cfgEquipeMobile.isNotEmpty ? cfgEquipeMobile.first : null;
                          final shiftM = cfgEquipeObjM == null ? null : shiftsProvider.getShiftForEquipe(cfgEquipeObjM.id, logicalDay);
                          final cfgM = getConfigForEquipeAndDate(cfgEquipeObjM, logicalDay, shiftM);
                          final confirmWindowOpen = !isViewingToday || isGroupScope || cfgM.canAdminConfirmAfterShiftEnd(now, logicalDay);
                          final confirmWindowHint = confirmWindowOpen ? null : 'Après ${cfgM.shiftEndFormattedOn(logicalDay)}';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // En-tête équipe
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isConfirmed ? Colors.green.shade50 : const Color(0xFF000966).withValues(alpha: 0.06),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isConfirmed ? Icons.check_circle : Icons.groups_outlined,
                                        color: isConfirmed ? Colors.green.shade600 : const Color(0xFF000966),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t.equipeName,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF000966))),
                                            Text(t.chefName,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                            child: Text('P: $presentC',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade800)),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                                            child: Text('A: $absentC',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.red.shade800)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Liste des collaborateurs
                                ...t.workers.map((e) {
                                  final record = getRecord(e.id);
                                  final isPresent = isGroupScope
                                      ? (record?.adminFinalStatus == AttendanceStatus.present ||
                                          record?.adminFinalStatus == AttendanceStatus.training ||
                                          record?.adminFinalStatus == AttendanceStatus.leave)
                                      : (record?.isFinalPresent ?? false);
                                  // Comme sur desktop : formation / congé approuvé
                                  // verrouillent la correction manuelle.
                                  final canEditStatus = isGroupScope ||
                                      (record?.adminFinalStatus != AttendanceStatus.training &&
                                          record?.adminFinalStatus != AttendanceStatus.leave);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                                    child: Row(
                                      children: [
                                        SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: 16),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(e.nom,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        if (!isGroupScope) ...[
                                          _DriverChefBadge(label: 'A', value: record?.driverStatus, isDriver: true),
                                          const SizedBox(width: 4),
                                          _DriverChefBadge(label: 'P', value: record?.chefStatus, isDriver: false),
                                          const SizedBox(width: 8),
                                        ],
                                        // Admin / directeur : le badge est
                                        // cliquable pour corriger la présence
                                        // (équivalent mobile des boutons desktop).
                                        InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: canEditStatus
                                              ? () => _showAdminStatusSheet(
                                                    context,
                                                    pointageProvider: pointageProvider,
                                                    employe: e,
                                                    record: record,
                                                    equipeId: t.equipeId,
                                                    equipeName: t.equipeName,
                                                    chefName: t.chefName,
                                                    isPresent: isPresent,
                                                    adminOverridePersistDate:
                                                        isViewingToday ? null : logicalDay,
                                                  )
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isPresent ? 'Présent' : 'Absent',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isPresent ? Colors.green.shade700 : Colors.red.shade700),
                                                ),
                                                if (canEditStatus) ...[
                                                  const SizedBox(width: 3),
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 11,
                                                    color: isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                // Bouton Confirmer / Confirmé
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                  child: isConfirmed
                                      ? OutlinedButton.icon(
                                          onPressed: () async {
                                            try {
                                              await _confirmationRepo.unconfirmEquipe(t.equipeId, logicalDay);
                                              await _snapshotRepo.deleteEquipeSnapshot(t.equipeId, logicalDay);
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                  content: Text('Erreur: ${e.toString()}'),
                                                  backgroundColor: Colors.red,
                                                  behavior: SnackBarBehavior.fixed,
                                                ));
                                              }
                                            }
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green.shade700,
                                            side: BorderSide(color: Colors.green.shade400),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                                          label: const Text('Confirmé ✓', style: TextStyle(fontSize: 13)),
                                        )
                                      : FilledButton.icon(
                                          onPressed: canConfirm
                                              ? () async {
                                                  final auth = context.read<AuthProvider>();
                                                  final confirmedById = auth.currentUser?.id ?? '';
                                                  final empSnapshots = t.workers.map((w) {
                                                    final rec = getRecord(w.id);
                                                    String status;
                                                    String? absenceReason;
                                                    if (isGroupScope) {
                                                      final admin = rec?.adminFinalStatus;
                                                      if (admin == AttendanceStatus.present ||
                                                          admin == AttendanceStatus.training ||
                                                          admin == AttendanceStatus.leave) {
                                                        status = 'present';
                                                      } else {
                                                        status = 'absent';
                                                        absenceReason = rec?.absenceReason;
                                                      }
                                                    } else {
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
                                                    }
                                                    return (
                                                      employeId: w.id,
                                                      employeNom: w.nom,
                                                      employeCin: w.cin,
                                                      status: status,
                                                      absenceReason: absenceReason,
                                                      isRestDay: false,
                                                    );
                                                  }).toList();
                                                  try {
                                                    await _snapshotRepo.saveEquipeSnapshot(
                                                      equipeId: t.equipeId,
                                                      equipeName: t.equipeName,
                                                      date: logicalDay,
                                                      confirmedById: confirmedById,
                                                      employees: empSnapshots,
                                                    );
                                                    await _confirmationRepo.confirmEquipe(
                                                      equipeId: t.equipeId,
                                                      equipeName: t.equipeName,
                                                      confirmedById: confirmedById,
                                                      confirmedByName: auth.currentUser?.nom ?? 'Admin',
                                                      date: logicalDay,
                                                      presentCount: presentC,
                                                      absentCount: absentC,
                                                    );
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text('Rapport de ${t.equipeName} confirmé avec succès ✓'),
                                                        backgroundColor: Colors.green.shade600,
                                                        behavior: SnackBarBehavior.fixed,
                                                        duration: const Duration(seconds: 3),
                                                      ));
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text('Erreur lors de la confirmation: ${e.toString()}'),
                                                        backgroundColor: Colors.red,
                                                        behavior: SnackBarBehavior.fixed,
                                                      ));
                                                    }
                                                  }
                                                }
                                              : confirmWindowOpen
                                                  ? () => _showForceConfirmDialog(context, t, logicalDay, getRecord)
                                                  : () {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text('Confirmation disponible après la fin du poste (${cfgM.shiftEndFormattedOn(logicalDay)})'),
                                                        backgroundColor: Colors.blue.shade700,
                                                        behavior: SnackBarBehavior.fixed,
                                                        duration: const Duration(seconds: 4),
                                                      ));
                                                    },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: !confirmWindowOpen
                                                ? Colors.grey.shade400
                                                : canConfirm ? Colors.blue.shade600 : Colors.orange.shade700,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          icon: Icon(
                                            !confirmWindowOpen ? Icons.lock_clock : canConfirm ? Icons.check : Icons.warning_amber_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            !confirmWindowOpen ? (confirmWindowHint ?? 'Poste en cours') : canConfirm ? 'Confirmer' : 'Forcer',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                }
                // تحديث stream التأكيدات لليوم الحالي + الأمس (للتنبيه)
                _ensureConfirmationsStream(logicalDay);
                if (isViewingToday) _ensureYesterdayConfirmationsStream(logicalDay);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── بانر تنبيه الفرق غير المؤكدة ──
                    if (isViewingToday)
                      StreamBuilder<List<DailyEquipeConfirmation>>(
                        stream: _yesterdayConfirmationsStream,
                        builder: (context, snapY) {
                          final yesterdayConf = snapY.data ?? _yesterdayConfirmations;
                          if (snapY.hasData) _yesterdayConfirmations = snapY.data!;
                          final yesterday = DateTime(logicalDay.year, logicalDay.month, logicalDay.day - 1);
                          final workTeams = allTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                          final yesterdayConfirmedIds = yesterdayConf.map((c) => c.equipeId).toSet();
                          final notConfirmedYesterday = workTeams.where((t) => !yesterdayConfirmedIds.contains(t.equipeId)).toList();
                          if (notConfirmedYesterday.isEmpty) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pointage non confirmé pour le ${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}/${yesterday.year} :',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red.shade800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notConfirmedYesterday.map((t) => t.equipeName).join(', '),
                                        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _applyAdminViewDay(pointageProvider, yesterday);
                                  },
                                  child: Text('Voir', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    Expanded(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!mobile) Container(
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
                                            shiftsProvider: shiftsProvider,
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
                                          : shiftsProvider.getShiftForEquipe(t.equipeId, logicalDay).shortLabel;
                                      final isSelected = _selectedEquipeIdAdmin == t.equipeId;
                                      final isConfirmed = confirmedIds.contains(t.equipeId);

                                      // حساب الحاضرين/الغائبين لهذا الفريق
                                      final teamWorkers = t.workers;
                                      final isGroupScope = t.equipeId == 'hors_equipe' || t.equipeId.startsWith('groupe:');
                                      int presentC = 0, absentC = 0;
                                      for (final w in teamWorkers) {
                                        final rec = getRecord(w.id);
                                        if (isGroupScope) {
                                          final admin = rec?.adminFinalStatus;
                                          final isPresent = admin == AttendanceStatus.present ||
                                              admin == AttendanceStatus.training ||
                                              admin == AttendanceStatus.leave;
                                          if (isPresent) {
                                            presentC++;
                                          } else {
                                            absentC++;
                                          }
                                        } else {
                                          if (rec?.isFinalPresent == true) {
                                            presentC++;
                                          } else {
                                            absentC++;
                                          }
                                        }
                                      }

                                      final canConfirm = teamWorkers.every((w) {
                                        final rec = getRecord(w.id);
                                        if (isGroupScope) {
                                          return rec?.adminFinalStatus == AttendanceStatus.present ||
                                              rec?.adminFinalStatus == AttendanceStatus.absent;
                                        }
                                        return isWorkerReadyForAdminConfirm(rec);
                                      });

                                      // Confirmation disponible uniquement après la fin du poste.
                                      final cfgEquipeDesk = equipes.where((e) => e.id == t.equipeId).toList();
                                      final cfgEquipeObjD = cfgEquipeDesk.isNotEmpty ? cfgEquipeDesk.first : null;
                                      final shiftD = cfgEquipeObjD == null ? null : shiftsProvider.getShiftForEquipe(cfgEquipeObjD.id, logicalDay);
                                      final cfgD = getConfigForEquipeAndDate(cfgEquipeObjD, logicalDay, shiftD);
                                      final confirmWindowOpen = !isViewingToday || isGroupScope || cfgD.canAdminConfirmAfterShiftEnd(now, logicalDay);
                                      final confirmWindowHint = confirmWindowOpen ? null : 'Confirmation disponible après la fin du poste (${cfgD.shiftEndFormattedOn(logicalDay)})';

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
                                                          try {
                                                            await _confirmationRepo.unconfirmEquipe(t.equipeId, logicalDay);
                                                            await _snapshotRepo.deleteEquipeSnapshot(t.equipeId, logicalDay);
                                                          } catch (e) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Erreur lors de l\'annulation: ${e.toString()}'),
                                                                  backgroundColor: Colors.red,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                ),
                                                              );
                                                            }
                                                          }
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
                                                          // Vérifier la fenêtre de confirmation avant tout.
                                                          if (!confirmWindowOpen) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(confirmWindowHint ?? 'Fenêtre de confirmation non ouverte.'),
                                                                  backgroundColor: Colors.blue.shade700,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                  duration: const Duration(seconds: 4),
                                                                ),
                                                              );
                                                            }
                                                            return;
                                                          }
                                                          if (!canConfirm) {
                                                            if (context.mounted) {
                                                              _showForceConfirmDialog(context, t, logicalDay, getRecord);
                                                            }
                                                            return;
                                                          }
                                                          if (isGroupScope) {
                                                            final go = await showDialog<bool>(
                                                              context: context,
                                                              barrierDismissible: false,
                                                              builder: (dialogCtx) => AlertDialog(
                                                                title: const Text('Confirmer le groupe'),
                                                                content: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                                                  children: [
                                                                    Text(
                                                                      t.equipeName,
                                                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                                                    ),
                                                                    const SizedBox(height: 12),
                                                                    Row(
                                                                      children: [
                                                                        Icon(Icons.person, size: 20, color: Colors.green.shade700),
                                                                        const SizedBox(width: 8),
                                                                        Expanded(
                                                                          child: Text(
                                                                            'Présents : $presentC',
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.w700,
                                                                              color: Colors.green.shade800,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    Row(
                                                                      children: [
                                                                        Icon(Icons.person_off, size: 20, color: Colors.red.shade700),
                                                                        const SizedBox(width: 8),
                                                                        Expanded(
                                                                          child: Text(
                                                                            'Absents : $absentC',
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                              fontWeight: FontWeight.w700,
                                                                              color: Colors.red.shade800,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(height: 8),
                                                                    Text(
                                                                      'Total : ${teamWorkers.length} personne(s)',
                                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                                                    ),
                                                                  ],
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                                                    child: const Text('Annuler'),
                                                                  ),
                                                                  FilledButton(
                                                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                                                    child: const Text('Valider la confirmation'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            if (go != true || !context.mounted) return;
                                                          }
                                                          final auth = context.read<AuthProvider>();
                                                          final confirmedById = auth.currentUser?.id ?? '';

                                                          // بناء قائمة snapshots لكل موظف في الفريق
                                                          final empSnapshots = teamWorkers.map((w) {
                                                            final rec = getRecord(w.id);
                                                            String status;
                                                            String? absenceReason;

                                                            // For group scope: only use admin chosen present/absent.
                                                            if (isGroupScope) {
                                                              final admin = rec?.adminFinalStatus;
                                                              if (admin == AttendanceStatus.present ||
                                                                  admin == AttendanceStatus.training ||
                                                                  admin == AttendanceStatus.leave) {
                                                                status = 'present';
                                                              } else {
                                                                status = 'absent';
                                                                absenceReason = rec?.absenceReason;
                                                              }
                                                            } else {
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
                                                            }
                                                            return (
                                                              employeId: w.id,
                                                              employeNom: w.nom,
                                                              employeCin: w.cin,
                                                              status: status,
                                                              absenceReason: absenceReason,
                                                              isRestDay: false,
                                                            );
                                                          }).toList();

                                                          try {
                                                            await _snapshotRepo.saveEquipeSnapshot(
                                                              equipeId: t.equipeId,
                                                              equipeName: t.equipeName,
                                                              date: logicalDay,
                                                              confirmedById: confirmedById,
                                                              employees: empSnapshots,
                                                            );
                                                            await _confirmationRepo.confirmEquipe(
                                                              equipeId: t.equipeId,
                                                              equipeName: t.equipeName,
                                                              confirmedById: confirmedById,
                                                              confirmedByName: auth.currentUser?.nom ?? 'Admin',
                                                              date: logicalDay,
                                                              presentCount: presentC,
                                                              absentCount: absentC,
                                                            );
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Rapport de ${t.equipeName} confirmé avec succès ✓'),
                                                                  backgroundColor: Colors.green.shade600,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                  duration: const Duration(seconds: 3),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Erreur lors de la confirmation: ${e.toString()}'),
                                                                  backgroundColor: Colors.red,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                        style: FilledButton.styleFrom(
                                                          backgroundColor: !confirmWindowOpen
                                                              ? Colors.grey.shade400
                                                              : canConfirm ? Colors.blue.shade600 : Colors.orange.shade700,
                                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        icon: Icon(
                                                          !confirmWindowOpen ? Icons.lock_clock : canConfirm ? Icons.check : Icons.warning_amber_rounded,
                                                          size: 14,
                                                        ),
                                                        label: Text(
                                                          !confirmWindowOpen
                                                              ? (confirmWindowHint != null ? 'Après ${cfgD.shiftEndFormattedOn(logicalDay)}' : 'Poste en cours')
                                                              : canConfirm ? 'Confirmer' : 'Forcer',
                                                          style: const TextStyle(fontSize: 11),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
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
                    if (!mobile) const SizedBox(width: 14),
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
                        viewDate: logicalDay,
                        adminOverridePersistDate: isViewingToday ? null : logicalDay,
                        presentByChef: presentByChef,
                        absentByChef: absentByChef,
                        notInVehicleByChef: notInVehicleByChef,
                        notWorkingByChef: notWorkingByChef,
                      ),
                    ),
                    ],
                  )),
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
    {String? initialScope,
    String? initialEquipeId,
    ShiftsProvider? shiftsProvider,}
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
          initialScope: initialScope,
          initialEquipeId: initialEquipeId,
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

    try {
    // بناء قائمة الموظفين أولاً حتى نتمكن من تمرير معرفاتهم عند جلب السجلات،
    // مما يضمن جلب سجلاتهم حتى لو لم يُسجَّل لهم أي بوانتاج في الفترة.
    final employees = <({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet, bool isQuitte, String dateQuitte})>[];
    // Helper: parse dd/MM/yyyy → DateTime, returns null on failure.
    DateTime? parseQd(String s) {
      if (s.isEmpty) return null;
      final p = s.split('/');
      if (p.length != 3) return null;
      final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
      if (d == null || m == null || y == null) return null;
      return DateTime(y, m, d);
    }
    final periodStart = DateTime(start.year, start.month, start.day);
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
        // Skip employees who left before (or without a recorded date for) the period start.
        if (w.statut == EmployeStatut.quitte) {
          if (w.dateQuitte.isEmpty) continue; // no date → treat as left before period
          final qd = parseQd(w.dateQuitte);
          if (qd == null || qd.isBefore(periodStart)) continue;
        }
        employees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          poste: w.poste,
          equipeName: label,
          equipeId: eq.id,
          salaireNet: w.salaireBase,
          isQuitte: w.statut == EmployeStatut.quitte,
          dateQuitte: w.dateQuitte,
        ));
      }
    }
    // Garder aussi les employés hors équipe (équipeId = null) s'ils sont visibles dans l'écran.
    for (final t in teams.where((t) => t.equipeId == 'hors_equipe')) {
      for (final w in t.workers) {
        if (!seen.add(w.id)) continue;
        // Skip employees who left before (or without a recorded date for) the period start.
        if (w.statut == EmployeStatut.quitte) {
          if (w.dateQuitte.isEmpty) continue;
          final qd = parseQd(w.dateQuitte);
          if (qd == null || qd.isBefore(periodStart)) continue;
        }
        employees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          poste: w.poste,
          equipeName: '${t.equipeName} — ${t.chefName}',
          equipeId: null,
          salaireNet: w.salaireBase,
          isQuitte: w.statut == EmployeStatut.quitte,
          dateQuitte: w.dateQuitte,
        ));
      }
    }

    // Ajouter aussi les employés des "Groupes" (indépendants) pour permettre l'export Excel.
    // IMPORTANT: le paramètre `teams` peut ne pas inclure les groupes selon l'appelant,
    // donc on lit la configuration des groupes directement depuis le provider.
    final groupesProv = context.read<GroupesProvider>();
    final groupes = groupesProv.groupes;
    for (final g in groupes) {
      final groupeEquipeId = 'groupe:${g.id}';
      final label = 'Groupe: ${g.nom} — Responsable';
      for (final id in g.membreIds) {
        if (!seen.add(id)) continue;
        final empList = employes.where((e) => e.id == id).toList();
        if (empList.isEmpty) continue;
        final w = empList.first;
        if (w.statut != EmployeStatut.enService) continue;
        employees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          poste: w.poste,
          equipeName: label,
          equipeId: groupeEquipeId,
          salaireNet: w.salaireBase,
          isQuitte: false,
          dateQuitte: '',
        ));
      }
    }
    List<({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet, bool isQuitte, String dateQuitte})> filteredEmployees = employees;
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
        ? (DateTime date, String equipeId) {
            // Groupes / Hors équipe: not part of shifts rotation, never treat as "repos".
            if (equipeId.startsWith('groupe:') || equipeId == 'hors_equipe') return false;
            return shiftsProvider.getShiftForEquipe(equipeId, date) == ShiftType.rest;
          }
        : null;
    // جلب overtime_assignments للنطاق الزمني
    final overtimeProvider = context.read<OvertimeProvider>();
    final overtimeAssignments = await overtimeProvider.getForDateRange(start, end);

    // ── المسار الأساسي: snapshots المؤكدة فقط ───────────────────────────
    // Excel يُبنى حصرياً من البيانات المؤكدة (snapshots).
    // إذا لم تكن جميع أيام النطاق مؤكدة للفرق المعنية، يُحذَّر المستخدم ويمكنه إلغاء التصدير.
    final snapshots = await _snapshotRepo.getSnapshotsForRange(start, end);

    final totalRangeDays = end.difference(start).inDays + 1;
    final filteredEmpIds = filteredEmployees.map((e) => e.id).toSet();

    // أيام مؤكدة لكل موظف
    final snapshotDaysByEmp = <String, Set<String>>{};
    for (final s in snapshots) {
      if (!filteredEmpIds.contains(s.employeId)) continue;
      final dk = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      snapshotDaysByEmp.putIfAbsent(s.employeId, () => <String>{}).add(dk);
    }

    // حساب عدد الأيام غير المؤكدة
    final unconfirmedDaysSet = <String>{};
    for (var i = 0; i < totalRangeDays; i++) {
      final d = start.add(Duration(days: i));
      final dk = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      // يوم غير مؤكد إذا لم يكن لدى أي موظف snapshot له
      final hasAnySnapshot = snapshots.any((s) {
        final sdk = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
        return sdk == dk && filteredEmpIds.contains(s.employeId);
      });
      // يوم اليوم يُعذر (قد لا يكون التأكيد تم بعد)
      final today = DateTime.now();
      final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
      if (!hasAnySnapshot && !isToday) unconfirmedDaysSet.add(dk);
    }

    if (unconfirmedDaysSet.isNotEmpty && mounted) {
      // تحويل أيام غير مؤكدة إلى قائمة مقروءة
      final unconfirmedList = unconfirmedDaysSet.toList()..sort();
      final sample = unconfirmedList.take(5).map((dk) {
        final p = dk.split('-');
        return '${p[2]}/${p[1]}/${p[0]}';
      }).join(', ');
      final extra = unconfirmedList.length > 5 ? ' …+${unconfirmedList.length - 5} autre(s)' : '';

      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Pointage non confirmé')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${unconfirmedDaysSet.length} jour(s) dans la période sélectionnée n\'ont pas été confirmés par l\'administrateur :',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  '$sample$extra',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Les jours non confirmés ne seront PAS inclus dans l\'Excel.\nVoulez-vous exporter uniquement les jours confirmés ?',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text('Exporter confirmés seulement'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    // دائماً نستخدم مسار snapshots — يضمن أن Excel يعكس فقط البيانات المؤكدة
    List<PointageExportRow> rows;
    rows = PointageExportService.computeExcelRowsFromSnapshots(
      startDate: start,
      endDate: end,
      employees: filteredEmployees,
      snapshots: snapshots.where((s) => filteredEmpIds.contains(s.employeId)).toList(),
      reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
      isRestDay: isRestDay,
      overtimeAssignments: overtimeAssignments,
    );

    final exportNow = DateTime.now();
    final exportTodayDay = DateTime(exportNow.year, exportNow.month, exportNow.day);
    final exportStartDay = DateTime(start.year, start.month, start.day);
    final exportEndDay = DateTime(end.year, end.month, end.day);
    final isTodayOnlyForLog = exportStartDay == exportTodayDay && exportEndDay == exportTodayDay;
    String filePath;
    try {
      filePath = await PointageExportService.saveAndOpenExcel(
        startDate: start,
        endDate: end,
        rows: rows,
        reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
        useDessalementGrid: true,
        isPublicHoliday: shiftsProvider.isPublicHoliday,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération Excel : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 8),
          ),
        );
      }
      return;
    }
    final auth = context.read<AuthProvider>();
    // التصدير دائماً مبني على snapshots مؤكدة
    final validatedExport = snapshots.isNotEmpty || isTodayOnlyForLog;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export du pointage : $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
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
              width: math.min(MediaQuery.sizeOf(ctx).width * 0.93, 520),
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
                    const Text('2) Collaborateur', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<Employe>(
                      value: employee,
                      decoration: const InputDecoration(labelText: 'Collaborateur', border: OutlineInputBorder()),
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
                          final targetStart = shiftStart(targetShift, pickedDay);
                          if (targetStart.isBefore(originShiftEnd)) {
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

  Widget _buildAdminWorkersColumn(
    BuildContext context,
    ({String equipeId, String equipeName, String chefName, List<Employe> workers})? team,
    List<Employe> workers,
    Color borderColor,
    PointageProvider pointageProvider,
    PointageRecord? Function(String) getRecord, {
    required List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> allTeams,
    /// `null` = journée courante (flux today) ; sinon enregistrement sur ce jour-là.
    required DateTime? adminOverridePersistDate,
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
            final isGroupScope = team.equipeId == 'hors_equipe' || team.equipeId.startsWith('groupe:');
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
                                  if (!isGroupScope) ...[
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
                              isOnLeave
                                  ? 'En congé'
                                  : (isPresent ? tr(context, 'present') : tr(context, 'absent')),
                              style: TextStyle(
                                fontSize: mobile ? 12 : 11,
                                fontWeight: FontWeight.w600,
                                color: isOnLeave
                                    ? const Color(0xFF0D47A1)
                                    : isPresent ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: record == null
                                  ? null
                                  : () => _showDepartureOverrideDialog(context, pointageProvider, record, e.nom),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Entrée: ${record?.arrivalMarkedAt != null ? 'OK' : '--'} | Sortie: ${record?.departureStatus == DepartureStatus.finished ? 'OK' : '--'}',
                                    style: TextStyle(
                                      fontSize: mobile ? 10 : 9,
                                      color: Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (record != null) ...[
                                    const SizedBox(width: 3),
                                    Icon(Icons.edit_outlined, size: 10, color: Colors.blueGrey.shade400),
                                  ],
                                ],
                              ),
                            ),
                            if (!isGroupScope && isAlreadyFormation && formationRangeLabel != null) ...[
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
                            if (!isGroupScope && isOnLeave) ...[
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
                    if (isGroupScope || (!isAlreadyFormation && !isOnLeave))
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                final overrideDay = adminOverridePersistDate ?? DateTime.now();
                                final overrideShift = context
                                    .read<ShiftsProvider>()
                                    .getShiftForEquipe(team.equipeId, overrideDay);
                                if (record != null) {
                                  await pointageProvider.setAdminOverride(
                                    record.id,
                                    AttendanceStatus.present,
                                    shiftType: overrideShift,
                                  );
                                } else {
                                  await pointageProvider.setAdminOverrideForEmployee(
                                    employeId: e.id,
                                    employeNom: e.nom,
                                    employeCin: e.cin,
                                    equipeId: team.equipeId,
                                    equipeName: team.equipeName,
                                    chefName: team.chefName,
                                    status: AttendanceStatus.present,
                                    viewDate: adminOverridePersistDate,
                                    shiftType: overrideShift,
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
                                    viewDate: adminOverridePersistDate,
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
                    if (!isGroupScope && (isAlreadyFormation || isOnLeave))
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
    required DateTime? adminOverridePersistDate,
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
          adminOverridePersistDate: adminOverridePersistDate,
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

  /// Édition du pointage par l'admin / le directeur depuis mobile.
  /// Le layout desktop expose deux boutons Présent / Absent par employé ; sur
  /// mobile la place manque, on ouvre donc la même action dans une bottom sheet
  /// déclenchée par le badge de statut.
  Future<void> _showAdminStatusSheet(
    BuildContext context, {
    required PointageProvider pointageProvider,
    required Employe employe,
    required PointageRecord? record,
    required String equipeId,
    required String equipeName,
    required String chefName,
    required bool isPresent,
    /// `null` = journée courante ; sinon l'override est écrit sur ce jour-là.
    required DateTime? adminOverridePersistDate,
  }) async {
    Future<void> apply(AttendanceStatus status, {String? absenceReason}) async {
      final overrideDay = adminOverridePersistDate ?? DateTime.now();
      final overrideShift =
          context.read<ShiftsProvider>().getShiftForEquipe(equipeId, overrideDay);
      if (record != null) {
        await pointageProvider.setAdminOverride(
          record.id,
          status,
          absenceReason: absenceReason,
          shiftType: overrideShift,
        );
      } else {
        await pointageProvider.setAdminOverrideForEmployee(
          employeId: employe.id,
          employeNom: employe.nom,
          employeCin: employe.cin,
          equipeId: equipeId,
          equipeName: equipeName,
          chefName: chefName,
          status: status,
          absenceReason: absenceReason,
          viewDate: adminOverridePersistDate,
          shiftType: overrideShift,
        );
      }
    }

    final choice = await showModalBottomSheet<AttendanceStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              employe.nom,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              equipeName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green.shade600),
              title: Text(tr(ctx, 'present')),
              trailing: isPresent
                  ? Icon(Icons.done, size: 18, color: Colors.green.shade700)
                  : null,
              onTap: () => Navigator.pop(ctx, AttendanceStatus.present),
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.red.shade600),
              title: Text(tr(ctx, 'absent')),
              trailing: !isPresent
                  ? Icon(Icons.done, size: 18, color: Colors.red.shade700)
                  : null,
              onTap: () => Navigator.pop(ctx, AttendanceStatus.absent),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == AttendanceStatus.absent) {
      final reasonId = await _showAbsenceReasonDialog(context);
      if (reasonId == null || !mounted) return;
      await apply(AttendanceStatus.absent, absenceReason: reasonId);
    } else {
      await apply(AttendanceStatus.present);
    }
    if (mounted) setState(() {});
  }

  // ── Feuille de pointage (PDF) : partage WhatsApp / téléchargement ───────

  /// Lignes de la feuille de pointage à partir de ce que le chef voit à l'écran.
  /// [treatUnmarkedAsAbsent] : après confirmation les non-saisis sont enregistrés
  /// comme absents, la feuille doit donc les afficher ainsi.
  List<FeuillePointageLine> _buildFeuillePointageLines({
    required List<Employe> workers,
    required PointageProvider pointageProvider,
    required List<AbsenceReasonConfig> reasonConfigs,
    required AttendanceState Function(String employeId) getState,
    bool treatUnmarkedAsAbsent = false,
  }) {
    final lines = <FeuillePointageLine>[];
    for (final w in workers) {
      final record = pointageProvider.getRecordForEmployee(w.id);
      String statut = '';
      String commentaire = '';
      if (record?.adminFinalStatus == AttendanceStatus.training) {
        statut = feuilleStatutPresent;
        commentaire = 'Formation';
      } else if (record?.adminFinalStatus == AttendanceStatus.leave) {
        statut = feuilleStatutPresent;
        commentaire = 'Congé approuvé';
      } else {
        switch (getState(w.id)) {
          case AttendanceState.present:
          case AttendanceState.notInVehicle:
            statut = feuilleStatutPresent;
            break;
          case AttendanceState.absent:
            statut = feuilleStatutAbsent;
            commentaire =
                getAbsenceReasonLabel(record?.absenceReason, reasonConfigs);
            break;
          case AttendanceState.unmarked:
            if (treatUnmarkedAsAbsent) statut = feuilleStatutAbsent;
            break;
        }
      }
      lines.add(feuillePointageLine(
        nomComplet: w.nom,
        statut: statut,
        commentaire: commentaire,
      ));
    }
    return lines;
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
    final workersDisplay = workers.where((w) => !_isProtectedHigherPoste(w.poste)).toList();
    Employe? chefPosteFromLink;
    final chefEmpId = auth.currentUser?.chefEmployeId;
    if (chefEmpId != null && chefEmpId.isNotEmpty) {
      final hit = employes.where((e) => e.id == chefEmpId).toList();
      if (hit.isNotEmpty) chefPosteFromLink = hit.first;
    }
    final bypassPointageHours = pointageProvider.ignoreTimeWindowsForTest ||
        auth.canBypassPointageTimeWindows(linkedChefPoste: chefPosteFromLink?.poste);
    // Le chef ne saisit plus la sortie : il pointe présent/absent puis confirme.
    // La sortie est enregistrée automatiquement pour tous les présents à la confirmation.
    final chefToday = DateTime(now.year, now.month, now.day);
    final shiftForChefEarly = chefEquipe != null
        ? shiftsProvider.getShiftForEquipe(chefEquipe.id, chefToday)
        : null;
    // Poste imprimé sur la feuille de pointage (P1/P2/P3), vide si repos/inconnu.
    final posteLabelForExport =
        (shiftForChefEarly == null || shiftForChefEarly == ShiftType.rest)
            ? ''
            : shiftForChefEarly.shortLabel;
    // Bannière « pointage confirmé » à la place du bouton une fois le pointage envoyé.
    final allLocked = workersDisplay.isNotEmpty &&
        workersDisplay.every((w) => pointageProvider.isChefLockedForEmployee(w.id));
    final chefReportLockedForAll = allLocked;
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
    final absenceReasonConfigs = context.watch<AbsenceReasonsProvider>().reasons;
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
      final reportNow = DateTime.now();
      final reportToday = DateTime(reportNow.year, reportNow.month, reportNow.day);
      final shiftForEquipe = equipe.isNotEmpty
          ? shiftsProvider.getShiftForEquipe(equipe.first.id, reportToday)
          : null;
      final pointageConfig = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, reportToday, shiftForEquipe);

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.how_to_reg_rounded, color: Colors.blue.shade700, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(ctx, 'pointage_confirm_title'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                equipeName.isNotEmpty ? equipeName : tr(ctx, 'pointage_confirm_send_message'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '$presentCount',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                          ),
                          Text('Présents', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.cancel, color: Colors.red.shade600, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            '$absentCount',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.red.shade700),
                          ),
                          Text('Absents', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(ctx, 'pointage_confirm_send_message'),
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(tr(ctx, 'pointage_confirm_short')),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;

      final lockIds = workersDisplay.map((w) => w.id).toSet();
      pointageProvider.applyOptimisticChefReportLock(lockIds);
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(trOf(context, 'pointage_report_locked_pending_sync')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
        ),
      );

      unawaited(() async {
        try {
          await pointageProvider.batchMarkUnmarkedAbsentBeforeChefSubmit(
            workersDisplay: workersDisplay,
            overtimeWorkerIds: overtimeWorkerIds,
            equipeId: equipeId,
            equipeName: equipeName,
            chefName: auth.currentUser?.nom ?? '',
            chefId: auth.currentUser?.id,
            configOverride: pointageConfig,
            bypassTimeWindows: bypassPointageHours,
          );
          final ok = await pointageProvider.submitChefReport(
            equipeId,
            configOverride: pointageConfig,
            bypassTimeWindows: bypassPointageHours,
          );
          if (!context.mounted) return;
          if (!ok) {
            pointageProvider.rollbackOptimisticChefReportLock();
            messenger.showSnackBar(
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
          // Le chef ne saisit plus la sortie : elle est enregistrée automatiquement
          // pour tous les présents dès que le pointage est confirmé.
          for (final w in workersDisplay) {
            final r = pointageProvider.getRecordForEmployee(w.id);
            if (r != null &&
                r.chefStatus == ChefPointageStatus.present &&
                r.departureStatus == DepartureStatus.unset) {
              await pointageProvider.setDepartureStatus(
                record: r,
                status: DepartureStatus.finished,
                configOverride: pointageConfig,
                bypassTimeWindows: true,
              );
            }
          }
          if (!context.mounted) return;
          // Pointage confirmé : proposer le partage (WhatsApp) / téléchargement du PDF.
          await showPointageConfirmedDialog(
            context,
            date: reportToday,
            equipeLabel: equipeName,
            posteLabel: posteLabelForExport,
            lines: _buildFeuillePointageLines(
              workers: workersDisplay,
              pointageProvider: pointageProvider,
              reasonConfigs: absenceReasonConfigs,
              getState: getState,
              treatUnmarkedAsAbsent: true,
            ),
          );
        } catch (e) {
          pointageProvider.rollbackOptimisticChefReportLock();
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      }());
    }

    final padding = pagePadding(context);
    final today = DateTime(now.year, now.month, now.day);
    final shiftForChef = chefEquipe != null
        ? shiftsProvider.getShiftForEquipe(chefEquipe.id, today)
        : null;
    final config = getConfigForEquipeAndDate(chefEquipe, today, shiftForChef);
    final hoursStatus =
        bypassPointageHours ? PointageHoursStatus.open : getPointageHoursStatus(now, config);
    final isWithinArrival = bypassPointageHours || config.canMarkArrivalNow(now);
    final mobile = isMobile(context);

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
      final chefChips = _wrapIfDisabled(
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
              ok = await pointageProvider.markOvertimeChefAttendance(
                record: record,
                overtimeChefStatus: _stateToChefStatus(s),
                chefId: auth.currentUser?.id,
                configOverride: config,
                bypassTimeWindows: bypassPointageHours,
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
                bypassTimeWindows: bypassPointageHours,
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
      );
      final nameBlock = Column(
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
      );

      return Card(
        margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 14 : 10),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SmartAvatar(
                          imageUrl: e.photoUrl,
                          fallbackText: e.nom,
                          radius: mobile ? 22 : 18,
                        ),
                        SizedBox(width: mobile ? 14 : 12),
                        Expanded(child: nameBlock),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: chefChips),
                  ],
                )
              : Row(
                  children: [
                    SmartAvatar(
                      imageUrl: e.photoUrl,
                      fallbackText: e.nom,
                      radius: mobile ? 22 : 18,
                    ),
                    SizedBox(width: mobile ? 14 : 12),
                    Expanded(child: nameBlock),
                    if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    chefChips,
                  ],
                ),
        ),
      );
    }

    // Disponible une fois le pointage confirmé : feuille de pointage PDF à
    // partager (WhatsApp…) ou à télécharger sur le téléphone du chef.
    Widget buildFeuilleShareSection() => FeuillePointageShareSection(
          date: today,
          equipeLabel: equipeNameForTitle,
          posteLabel: posteLabelForExport,
          linesBuilder: () => _buildFeuillePointageLines(
            workers: workersDisplay,
            pointageProvider: pointageProvider,
            reasonConfigs: absenceReasonConfigs,
            getState: getState,
            treatUnmarkedAsAbsent: true,
          ),
        );

    final presentCount = workersDisplay.where((w) => getState(w.id) == AttendanceState.present).length;
    final absentCount = workersDisplay.where((w) => getState(w.id) == AttendanceState.absent).length;
    final unmarkedCount = workersDisplay.where((w) => getState(w.id) == AttendanceState.unmarked).length;

    if (mobile && workersDisplay.isNotEmpty) {
      return SingleChildScrollView(
        child: Padding(
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
            const SizedBox(height: 14),
            Text(
              '${tr(context, 'workers_of')} ${auth.currentUser?.nom ?? ''}',
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
            // ── Panneau d'actions groupées ────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.touch_app_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('Actions groupées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                    const Spacer(),
                    // Compteurs rapides
                    _QuickCountChip(count: presentCount, label: 'Présents', color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    _QuickCountChip(count: absentCount, label: 'Absents', color: Colors.red.shade500),
                    const SizedBox(width: 6),
                    _QuickCountChip(count: unmarkedCount, label: 'Non saisis', color: Colors.orange.shade600),
                  ]),
                  const SizedBox(height: 12),
                  // Bouton principal : Confirmer présence de tous
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.how_to_reg_outlined, size: 20),
                      label: Text(
                        unmarkedCount > 0
                            ? 'Confirmer présence de tous  ($unmarkedCount)'
                            : 'Présence de tous confirmée ✓',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (!allLocked && isWithinArrival) ? () async {
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
                              bypassTimeWindows: bypassPointageHours,
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
                              bypassTimeWindows: bypassPointageHours,
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
            const SizedBox(height: 16),
            // ── Résumé avant confirmation ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatSummaryItem(count: presentCount, label: 'Présents', color: Colors.green.shade600, icon: Icons.check_circle_outline),
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
                  _StatSummaryItem(count: absentCount, label: 'Absents', color: Colors.red.shade500, icon: Icons.cancel_outlined),
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
                  _StatSummaryItem(count: unmarkedCount, label: 'Non saisis', color: Colors.orange.shade600, icon: Icons.help_outline_rounded),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: chefReportLockedForAll
                  ? _ReportSentBanner(presentCount: presentCount, absentCount: absentCount)
                  : PrimaryButton(
                      label: tr(context, 'pointage_confirm_btn'),
                      onTap: sendReport,
                    ),
            ),
            // Partage / téléchargement du PDF : uniquement après confirmation.
            if (chefReportLockedForAll) ...[
              const SizedBox(height: 12),
              buildFeuilleShareSection(),
            ],
            const SizedBox(height: 16),
          ],
        ),
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
          const SizedBox(height: 20),
          Text(
            '${tr(context, 'workers_of')} ${auth.currentUser?.nom ?? ''}',
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
          SizedBox(height: mobile ? 16 : 24),
          SizedBox(
            height: mobile ? 48 : 52,
            width: double.infinity,
            child: chefReportLockedForAll
                ? _ReportSentBanner(presentCount: presentCount, absentCount: absentCount)
                : PrimaryButton(
                    label: tr(context, 'pointage_confirm_btn'),
                    onTap: sendReport,
                  ),
          ),
          // Partage / téléchargement du PDF : uniquement après confirmation.
          if (chefReportLockedForAll) ...[
            const SizedBox(height: 12),
            buildFeuilleShareSection(),
          ],
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

/// Bannière affichée à la place du bouton "Confirmer" une fois le pointage verrouillé.
class _ReportSentBanner extends StatelessWidget {
  final int presentCount;
  final int absentCount;
  const _ReportSentBanner({required this.presentCount, required this.absentCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            '${tr(context, 'pointage_confirmed')} ✓',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent.shade100),
                const SizedBox(width: 4),
                Text('$presentCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
                Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade200),
                const SizedBox(width: 4),
                Text('$absentCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
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
  const _PointageAnalysisSection({
    required this.teams,
    required this.nonWorkingIds,
    required this.getRecord,
    required this.viewDate,
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
    int totalAbsentDays = 0;
    for (final w in allWorkers) {
      totalWorkedMin += _workedMinutesForPeriod(w.id);
      totalOvertimeMin += _overtimeMinutesForPeriod(w.id);
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
            Text('Résumé — ${allWorkers.length} collaborateur(s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 14, color: primary)),
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
            if (true) ...[
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
                if (true) ...[
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
    final personLabel = 'Collaborateur';
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
          if (true) ...[
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
            'Planifiez une formation pour un ou plusieurs collaborateurs.',
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
                  Text('Collaborateurs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 13 : 14)),
                  const SizedBox(height: 6),
                  if (_loadingFormation)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (workers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucun collaborateur dans cette équipe.', style: TextStyle(color: Colors.grey[600])),
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

          // ─── Collaborateurs actuellement en formation ──────────────────────────
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
  final String? initialScope;
  final String? initialEquipeId;

  const _ExcelDateRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.equipeOptions,
    this.initialScope,
    this.initialEquipeId,
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
    final s = (widget.initialScope ?? '').trim();
    if (s.isNotEmpty) _scope = s;
    _selectedEquipeId = widget.initialEquipeId;
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
              DropdownMenuItem(value: 'normales', child: Text('Equipe Nettoyage seulement')),
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

// ── Widgets helpers pour la vue chef d'equipe ──────────────────────────────

class _QuickCountChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _QuickCountChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatSummaryItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;
  const _StatSummaryItem({required this.count, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 3),
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }
}
