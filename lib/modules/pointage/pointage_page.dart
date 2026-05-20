import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/app_permissions.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_busy.dart';
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
import '../distribution/distribution_shifts_provider.dart';
import '../groupes/models/groupe_model.dart';
import '../distribution/distribution_groups_provider.dart';
import '../Demandes/leave_requests_provider.dart';
import '../Demandes/leave_demandes_page.dart' show LeaveStatus;

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
    final densePhone = MediaQuery.sizeOf(context).width < 420;
    final minHeight = densePhone ? 36.0 : (mobile ? 44.0 : 40.0);
    final hPad = densePhone ? 8.0 : (mobile ? 14.0 : 8.0);
    final vPad = densePhone ? 6.0 : 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? primary : Colors.transparent, width: densePhone ? 1.5 : 2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: densePhone ? 12 : (mobile ? 14 : 13),
                    fontWeight: FontWeight.w700,
                    color: selected ? primary : Colors.grey.shade700,
                  ),
                ),
                if (badge != null) ...[
                  SizedBox(width: densePhone ? 6 : (mobile ? 10 : 8)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: densePhone ? 6 : (mobile ? 10 : 8), vertical: 2),
                    decoration: BoxDecoration(
                      color: selected ? primary.withValues(alpha: 0.12) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(fontSize: densePhone ? 10 : (mobile ? 12 : 11), fontWeight: FontWeight.w800, color: selected ? primary : Colors.grey.shade700),
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
enum _AdminTeamScope { all, equipes, distribution, others }
enum _AdminConfirmScope { all, confirmed, unconfirmed }

class _PointagePageState extends State<PointagePage> {
  final ExcelValidationRepository _excelValidationRepo =
      ExcelValidationRepository();
  final DailyConfirmationRepository _confirmationRepo =
      DailyConfirmationRepository();
  final DailySnapshotRepository _snapshotRepo = DailySnapshotRepository();
  PointageProvider? _pointageExportHintListenTarget;
  final ScrollController _adminActionsScrollController = ScrollController();
  final ScrollController _adminTabsScrollController = ScrollController();
  final ScrollController _adminTeamScopeScrollController = ScrollController();
  final ScrollController _adminConfirmScopeScrollController = ScrollController();
  Timer? _pointageClockRefreshTimer;

  bool _isProtectedHigherPoste(String poste) {
    final p = poste.trim().toLowerCase();
    return p.contains('chef de zone') ||
        p.contains('chef d\'atelier') ||
        p.contains('rh') ||
        p.contains('admin') ||
        p.contains('directeur');
  }

  /// Chef de zone : édition / confirmation uniquement pour les groupes Distribution qui lui sont rattachés.
  bool _chefZoneMayActOnDistribution(AuthProvider auth, String equipeId) {
    if (!equipeId.startsWith('distribution:')) return false;
    final gid = equipeId.substring('distribution:'.length);
    final allowed = auth.distributionGroupIds;
    if (allowed.isEmpty) return true;
    return allowed.contains(gid);
  }

  bool _isRhAdmin(AuthProvider auth) {
    final r = auth.adminRole.trim().toLowerCase();
    return r.contains('rh') || r.contains('ressource');
  }

  /// Remarque shift 22h→6h : Chef d'atelier, Chef de zone, RH, admin central — pas les profils directeur restreints (même logique que hors équipe).
  bool _maySeeNightShiftSupervisorNote(AuthProvider auth) {
    if (!auth.isDirecteur) return false;
    if (auth.isChefAtelierAdmin) return true;
    if (auth.isChefZoneAdmin) return true;
    if (_isRhAdmin(auth)) return true;
    if (auth.permissions.contains(AppPermissions.all)) return true;
    if (auth.hasPermission(AppPermissions.adminsManage)) return true;
    final r = auth.adminRole.trim().toLowerCase();
    if (r.contains('général') || r.contains('general')) return true;
    return false;
  }

  bool _isNightShiftEntryOnlyAdminContext(
    String equipeId,
    DateTime logicalDay,
    List<Equipe> equipes,
    ShiftsProvider shiftsProvider,
  ) {
    if (equipeId == 'hors_equipe' || equipeId.startsWith('groupe:') || _isDistributionEquipeId(equipeId)) {
      return false;
    }
    final cfgEquipe = equipes.where((e) => e.id == equipeId).toList();
    final equipe = cfgEquipe.isNotEmpty ? cfgEquipe.first : null;
    final shiftForEquipe = equipe == null ? null : shiftsProvider.getShiftForEquipe(equipe.id, logicalDay);
    final cfg = getConfigForEquipeAndDate(equipe, logicalDay, shiftForEquipe);
    return cfg.isNightShift || shiftForEquipe == ShiftType.night;
  }

  /// Pointage « hors équipe » : réservé au Chef de zone et à l’admin RH.
  bool _mayEditHorsEquipe(AuthProvider auth) =>
      auth.isChefZoneAdmin || _isRhAdmin(auth);

  /// Afficher la ligne « Hors équipe » dans le pointage admin : pas pour Chef d’atelier ni profils restreints
  /// (ex. magasin seul) — seulement admin central, Chef de zone et RH.
  bool _mayViewHorsEquipeTeam(AuthProvider auth) {
    if (!auth.isDirecteur) return false;
    if (auth.isChefAtelierAdmin) return false;
    if (auth.isChefZoneAdmin) return true;
    if (_isRhAdmin(auth)) return true;
    if (auth.permissions.contains(AppPermissions.all)) return true;
    if (auth.hasPermission(AppPermissions.adminsManage)) return true;
    final r = auth.adminRole.trim().toLowerCase();
    if (r.contains('général') || r.contains('general')) return true;
    return false;
  }

  /// Planning Distribution : afficher le groupe seulement s’il travaille ce jour (comme les équipes).
  bool _distributionGroupActiveForChefZoneList({
    required String groupId,
    required DateTime logicalDay,
    required bool isViewingToday,
    required bool isEarlyMorningTodayView,
    required DistributionShiftsProvider distShifts,
    required List<PointageRecord> recordsForDate,
  }) {
    if (!distShifts.hasConfig) return true;
    if (!distShifts.hasRotationSlotForGroup(groupId)) {
      final distEq = 'distribution:$groupId';
      return recordsForDate.any((r) => r.equipeId == distEq);
    }
    final todayShift = distShifts.getShiftForGroup(groupId, logicalDay);
    if (todayShift != ShiftType.rest) return true;
    if (!isEarlyMorningTodayView || !isViewingToday) return false;
    final prev = DateTime(logicalDay.year, logicalDay.month, logicalDay.day - 1);
    return distShifts.getShiftForGroup(groupId, prev) == ShiftType.night;
  }

  /// Panneau travailleurs : lecture seule pour la plupart des directeurs.
  /// Édition : Chef d'atelier (équipes + groupes normaux), Chef de zone (Distribution + hors équipe), pas les profils RH sur le périmètre équipes.
  bool _adminPanelReadOnlyForEquipe(AuthProvider auth, String? equipeId) {
    final id = equipeId ?? '';
    if (id == 'hors_equipe') {
      if (_mayEditHorsEquipe(auth)) return false;
      return auth.isDirecteur;
    }
    if (auth.isChefAtelierAdmin) {
      if (_isDistributionEquipeId(id)) return true;
      return false;
    }
    if (_isRhAdmin(auth)) return true;
    if (auth.isChefZoneAdmin) {
      if (equipeId == null || equipeId.isEmpty) return true;
      return !_chefZoneMayActOnDistribution(auth, equipeId);
    }
    return auth.isDirecteur;
  }

  /// Confirmer équipe : Chef d'atelier (équipes / groupes, pas Distribution) ; chef de zone (Distribution + hors équipe) ; RH (hors équipe).
  bool _adminMayConfirmEquipe(AuthProvider auth, String equipeId) {
    if (equipeId == 'hors_equipe') return _mayEditHorsEquipe(auth);
    if (auth.isChefZoneAdmin) return _chefZoneMayActOnDistribution(auth, equipeId);
    if (auth.isChefAtelierAdmin) return !_isDistributionEquipeId(equipeId);
    return true;
  }

  /// Distribution : pas de flux chauffeur — uniquement le responsable (chef) du groupe.
  bool _isDistributionEquipeId(String equipeId) => equipeId.startsWith('distribution:');

  PointageRecord? _pickDistributionRecordForTeam(
    List<PointageRecord> list,
    String equipeId,
  ) {
    if (list.isEmpty) return null;
    final arrangement = list.where(
      (r) => r.distSwapArrangement && r.equipeId == equipeId,
    );
    if (arrangement.isNotEmpty) return arrangement.first;
    final home = list.where(
      (r) => r.equipeId == equipeId && !r.tempAssigned && !r.distSwapArrangement,
    );
    if (home.isNotEmpty) return home.first;
    final guest = list.where((r) => r.tempAssigned && r.equipeId == equipeId);
    if (guest.isNotEmpty) return guest.first;
    final anyHome = list.where((r) => !r.tempAssigned && !r.distSwapArrangement);
    return anyHome.isNotEmpty ? anyHome.first : list.first;
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
  String? _lastOvertimeListenEquipeId;
  DateTime _hsFilterDate = DateTime.now();
  String? _lastOvertimeListenDateKey;
  _AdminPointageView _adminContentView = _AdminPointageView.workers;
  _AdminDesignTab _adminTab = _AdminDesignTab.pointages;
  _AdminTeamScope _adminTeamScope = _AdminTeamScope.all;
  _AdminConfirmScope _adminConfirmScope = _AdminConfirmScope.all;

  DateTime _adminMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _adminFilterEquipeId;
  String? _adminFilterEmployeId;
  bool _adminMonthLoading = false;
  DateTime? _adminMonthLoaded;
  List<PointageRecord> _adminMonthRecords = [];
  final Set<String> _chefDepartureReportLocks = <String>{};
  final Map<String, ChefPointageStatus> _chefDraftStatus = <String, ChefPointageStatus>{};
  final Map<String, String?> _chefDraftAbsenceReason = <String, String?>{};
  final Map<String, DepartureStatus> _chefDraftDeparture = <String, DepartureStatus>{};
  final Map<String, int?> _chefDraftOvertimeMinutes = <String, int?>{};
  final Map<String, int?> _chefDraftWorkedMinutes = <String, int?>{};
  final Map<String, String?> _chefDraftIncompleteReason = <String, String?>{};

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

  bool _canViewValidatedExcel(AuthProvider auth) {
    if (!auth.isDirecteur) return false;
    final perms = auth.permissions;
    if (perms.contains(AppPermissions.all)) return true;
    return auth.hasPermission(AppPermissions.reportsView) &&
        (auth.hasPermission(AppPermissions.adminsManage) ||
            auth.hasPermission(AppPermissions.groupsManage));
  }

  void _onPointageProviderExportHint() {
    if (!mounted) return;
    final p = _pointageExportHintListenTarget;
    if (p == null) return;
    final key = p.takeExportReconfirmHint();
    if (key == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trOf(context, key)),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 7),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Keep pointage time windows reactive while user stays on page.
    _pointageClockRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<PointageProvider>();
      _pointageExportHintListenTarget = p;
      p.addListener(_onPointageProviderExportHint);
    });
  }

  @override
  void dispose() {
    _pointageExportHintListenTarget?.removeListener(_onPointageProviderExportHint);
    _pointageExportHintListenTarget = null;
    _pointageClockRefreshTimer?.cancel();
    _adminActionsScrollController.dispose();
    _adminTabsScrollController.dispose();
    _adminTeamScopeScrollController.dispose();
    _adminConfirmScopeScrollController.dispose();
    super.dispose();
  }

  void _scrollHorizontally(ScrollController controller, double delta) {
    if (!controller.hasClients) return;
    final target = (controller.offset + delta).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildHorizontalMouseNavigator({
    required ScrollController controller,
    required Widget child,
    bool showButtons = true,
    /// Colonnes étroites : flèches plus petites pour ne pas masquer les chips.
    bool compactNav = false,
  }) {
    if (!showButtons) {
      return SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: child,
      );
    }
    final step = compactNav ? 140.0 : 260.0;
    Widget arrow({required bool left}) {
      final icon = Icon(
        left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        size: compactNav ? 18 : 24,
      );
      if (compactNav) {
        return IconButton(
          tooltip: left ? 'Défiler à gauche' : 'Défiler à droite',
          onPressed: () => _scrollHorizontally(controller, left ? -step : step),
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            minimumSize: const Size(26, 28),
            maximumSize: const Size(28, 32),
          ),
          icon: icon,
        );
      }
      return IconButton(
        tooltip: left ? 'Défiler à gauche' : 'Défiler à droite',
        onPressed: () => _scrollHorizontally(controller, left ? -step : step),
        icon: icon,
      );
    }
    return Row(
      children: [
        arrow(left: true),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
        arrow(left: false),
      ],
    );
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
    final todayOnly = DateTime(now.year, now.month, now.day);
    final selectedReport = pointageProvider.selectedReportDate;
    final isViewingToday = selectedReport == null;
    // Aligner avec le flux Firestore (watchTodayPointage) : pour les shifts de nuit,
    // le « jour pointage » peut être le jour civil précédent — sinon la fin de shift et le repos sont calculés sur le mauvais jour.
    final DateTime logicalDay;
    if (isViewingToday) {
      logicalDay = getPointageDateForConfig(const PointageHoursConfig(), now);
    } else {
      // isViewingToday == false ⇒ selectedReport != null
      logicalDay = DateTime(selectedReport.year, selectedReport.month, selectedReport.day);
    }
    final isPastCalendarDay = logicalDay.isBefore(todayOnly);
    /// Journée civile déjà terminée : le directeur peut clôturer l’équipe même sans entrée/sortie complètes (historique / oublis).
    final allowIncompleteConfirmPastDay = auth.isDirecteur && isPastCalendarDay;
    _ensureConfirmationsStream(logicalDay);
    if (isViewingToday) _ensureYesterdayConfirmationsStream(logicalDay);
    /// Référence stable pour les fenêtres T/C (évite minuit sur un jour passé pour les shifts de nuit).
    final shiftWindowRef =
        isViewingToday ? now : DateTime(logicalDay.year, logicalDay.month, logicalDay.day, 12);
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
    final groupesProv = context.watch<GroupesProvider>();
    final groupes = groupesProv.groupes;
    final groupeById = <String, Groupe>{for (final g in groupes) g.id: g};
    bool isWeeklyRestForGroupe(String groupeEquipeId, DateTime date) {
      if (!groupeEquipeId.startsWith('groupe:')) return false;
      final gid = groupeEquipeId.substring('groupe:'.length);
      final weekday = groupeById[gid]?.weeklyRestWeekday;
      if (weekday == null) return false;
      return date.weekday == weekday;
    }
    final isEarlyMorningTodayView = isViewingToday && now.hour < 7;
    final previousLogicalDay = DateTime(logicalDay.year, logicalDay.month, logicalDay.day - 1);
    final carryOverNightTeamIds = <String>{};
    bool _isActiveTeamForDisplay(String equipeId) {
      if (!shiftsProvider.hasConfig) return true;
      final todayShift = shiftsProvider.getShiftForEquipe(equipeId, logicalDay);
      if (todayShift != ShiftType.rest) return true;
      if (!isEarlyMorningTodayView) return false;
      final yShift = shiftsProvider.getShiftForEquipe(equipeId, previousLogicalDay);
      return yShift == ShiftType.night;
    }
    final effectiveNonWorkingIds = <String>{...nonWorkingIds};
    if (shiftsProvider.hasConfig) {
      for (final eid in shiftsProvider.config!.equipeIds) {
        if (eid.isEmpty) continue;
        final yShift = isEarlyMorningTodayView
            ? shiftsProvider.getShiftForEquipe(eid, previousLogicalDay)
            : null;
        if (isEarlyMorningTodayView && yShift == ShiftType.night) {
          carryOverNightTeamIds.add(eid);
          continue;
        }
        if (shiftsProvider.getShiftForEquipe(eid, logicalDay) == ShiftType.rest) {
          effectiveNonWorkingIds.add(eid);
        }
      }
    }
    for (final g in groupes) {
      if (g.id.isEmpty) continue;
      final gid = 'groupe:${g.id}';
      if (isWeeklyRestForGroupe(gid, logicalDay)) {
        effectiveNonWorkingIds.add(gid);
      }
    }
    if (isHorsEquipeWeeklyRestDay(logicalDay)) {
      effectiveNonWorkingIds.add(horsEquipeVirtualId);
    }
    if (shiftsProvider.isPublicHoliday(logicalDay)) {
      effectiveNonWorkingIds.add(horsEquipeVirtualId);
      for (final g in groupes) {
        effectiveNonWorkingIds.add('groupe:${g.id}');
      }
    }
    bool isRoboEquipe(Equipe eq) {
      final name = eq.nom.trim().toLowerCase();
      if (name.contains('robo') || name.contains('repos') || name.contains('repo')) return true;
      // Only treat as "repos" based on shift if the equipe is actually registered in the shifts config.
      if (shiftsProvider.hasConfig && (shiftsProvider.config?.equipeIds.contains(eq.id) ?? false)) {
        if (carryOverNightTeamIds.contains(eq.id)) return false;
        final shift = shiftsProvider.getShiftForEquipe(eq.id, logicalDay);
        return shift == ShiftType.rest;
      }
      return false;
    }
    final workingEquipes = equipes.where((e) {
      if (e.chefId.isEmpty) return false;
      if (effectiveNonWorkingIds.contains(e.id) && !carryOverNightTeamIds.contains(e.id)) return false;
      if (isRoboEquipe(e)) return false;
      // Planning actif : n'afficher que les équipes du planning ce jour-là (≠ repos).
      // Équipe hors planning : uniquement si du pointage existe déjà ce jour pour elle (sinon liste inutile).
      if (shiftsProvider.hasConfig) {
        final rotationIds = shiftsProvider.config!.equipeIds;
        if (rotationIds.contains(e.id)) {
          return _isActiveTeamForDisplay(e.id);
        }
        return recordsForDate.any((r) => r.equipeId == e.id);
      }
      return true;
    }).toList();
    final List<_TeamWorkers> teams = getAllTeamsWithWorkersConsideringTemp(
      workingEquipes, employes, recordByEmployeId,
      renfortByEmployeId: renfortByEmployeId,
    ).where((t) => t.workers.isNotEmpty).toList();

    // Add Groupes (indépendants) as separate “teams” for admin UI + PDF.
    final groupeTeams = <_TeamWorkers>[];
    for (final g in groupes) {
      if (g.membreIds.isEmpty) continue;
      final workers = getWorkersForGroupeConsideringTemp(
        g, employes, recordByEmployeId,
        renfortByEmployeId: renfortByEmployeId,
      );
      if (workers.isEmpty) continue;
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
    List<_TeamWorkers> allTeams = [
      if (horsEquipeWorkers.isNotEmpty && _mayViewHorsEquipeTeam(auth))
        (equipeId: 'hors_equipe', equipeName: 'Hors équipe', chefName: 'Admin', workers: horsEquipeWorkers),
      ...teams,
      ...groupeTeams,
    ];
    final distGroupsProv = context.watch<DistributionGroupsProvider>();
    final distributionTeams = <_TeamWorkers>[];
    for (final g in distGroupsProv.groups) {
      if (g.membreIds.isEmpty) continue;
      final workers = employes
          .where((e) => g.membreIds.contains(e.id) && e.statut == EmployeStatut.enService)
          .toList()
        ..sort((a, b) => a.nom.compareTo(b.nom));
      if (workers.isEmpty) continue;
      distributionTeams.add((
        equipeId: 'distribution:${g.id}',
        equipeName: 'Distribution: ${g.nom}',
        chefName: 'Responsable Distribution',
        workers: workers,
      ));
    }
    if (!auth.isChefZoneAdmin &&
        !auth.isChefAtelierAdmin &&
        distributionTeams.isNotEmpty) {
      allTeams = [...allTeams, ...distributionTeams];
    }

    if (auth.isChefZoneAdmin) {
      final distShiftsProv = context.watch<DistributionShiftsProvider>();
      final zoneDistributionTeams = <_TeamWorkers>[];
      final distributionMemberIds = <String>{};
      final zoneSiteIds = auth.currentUser?.allowedSiteIds ?? const <String>['all'];
      final zoneHasAllSites = zoneSiteIds.isEmpty || zoneSiteIds.contains('all');
      final zoneDistFilter = auth.distributionGroupIds;
      for (final g in distGroupsProv.groups) {
        if (g.membreIds.isEmpty) continue;
        if (zoneDistFilter.isNotEmpty && !zoneDistFilter.contains(g.id)) continue;
        if (!_distributionGroupActiveForChefZoneList(
          groupId: g.id,
          logicalDay: logicalDay,
          isViewingToday: isViewingToday,
          isEarlyMorningTodayView: isEarlyMorningTodayView,
          distShifts: distShiftsProv,
          recordsForDate: recordsForDate,
        )) {
          continue;
        }
        final workers = employes
            .where((e) =>
                g.membreIds.contains(e.id) &&
                e.statut == EmployeStatut.enService &&
                (zoneHasAllSites || zoneSiteIds.contains(e.siteId)))
            .toList()
          ..sort((a, b) => a.nom.compareTo(b.nom));
        if (workers.isEmpty) continue;
        distributionMemberIds.addAll(workers.map((w) => w.id));
        zoneDistributionTeams.add((
          equipeId: 'distribution:${g.id}',
          equipeName: 'Groupe Distribution: ${g.nom}',
          chefName: 'Responsable Distribution',
          workers: workers,
        ));
      }
      // For Chef zone: only Distribution groups + workers not attached to any group/team.
      final usedByAnyTeamOrGroup = <String>{
        for (final eq in equipes) ...[
          if (eq.chefId.isNotEmpty) eq.chefId,
          ...eq.membreIds,
        ],
        for (final g in groupes) ...g.membreIds,
        ...distributionMemberIds,
      };
      final zoneOrphanWorkers = employes
          .where((e) =>
              e.statut == EmployeStatut.enService &&
              !usedByAnyTeamOrGroup.contains(e.id) &&
              (zoneHasAllSites || zoneSiteIds.contains(e.siteId)))
          .toList()
        ..sort((a, b) => a.nom.compareTo(b.nom));

      allTeams = [
        ...zoneDistributionTeams,
        if (zoneOrphanWorkers.isNotEmpty && _mayViewHorsEquipeTeam(auth))
          (
            equipeId: 'hors_equipe',
            equipeName: 'Hors équipe',
            chefName: 'Chef zone',
            workers: zoneOrphanWorkers,
          ),
      ];
    } else if (auth.isChefAtelierAdmin) {
      // Chef d'atelier : pas hors équipe, pas Distribution (réservé zone / RH / admin central).
      allTeams = allTeams
          .where((t) => t.equipeId != 'hors_equipe' && !_isDistributionEquipeId(t.equipeId))
          .map((t) => (
                equipeId: t.equipeId,
                equipeName: t.equipeName,
                chefName: t.chefName,
                workers: t.workers.where((w) => !_isProtectedHigherPoste(w.poste)).toList(),
              ))
          .where((t) => t.workers.isNotEmpty)
          .toList();
    }

    bool isDistributionTeam(String id) => id.startsWith('distribution:');
    bool isOtherTeam(String id) => id == 'hors_equipe' || id.startsWith('groupe:');
    final adminTeamScopeEffective = auth.isChefAtelierAdmin &&
            _adminTeamScope == _AdminTeamScope.distribution ? _AdminTeamScope.all
        : _adminTeamScope;
    final filteredTeams = allTeams.where((t) {
      switch (adminTeamScopeEffective) {
        case _AdminTeamScope.all:
          return true;
        case _AdminTeamScope.equipes:
          return !isDistributionTeam(t.equipeId) && !isOtherTeam(t.equipeId);
        case _AdminTeamScope.distribution:
          return isDistributionTeam(t.equipeId);
        case _AdminTeamScope.others:
          return isOtherTeam(t.equipeId);
      }
    }).where((t) {
      final confirmedIds = _dailyConfirmations.map((c) => c.equipeId).toSet();
      switch (_adminConfirmScope) {
        case _AdminConfirmScope.all:
          return true;
        case _AdminConfirmScope.confirmed:
          return confirmedIds.contains(t.equipeId);
        case _AdminConfirmScope.unconfirmed:
          return !confirmedIds.contains(t.equipeId);
      }
    }).toList();

    if (_selectedEquipeIdAdmin == null ||
        (filteredTeams.isNotEmpty && !filteredTeams.any((t) => t.equipeId == _selectedEquipeIdAdmin))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedEquipeIdAdmin = filteredTeams.isEmpty ? null : filteredTeams.first.equipeId);
      });
    }

    final selectedTeam = filteredTeams.where((t) => t.equipeId == _selectedEquipeIdAdmin).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    final adminReadOnly = _adminPanelReadOnlyForEquipe(auth, team?.equipeId);
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);
    final showFixedAdminHeader = !mobile;
    final bottomScrollPadding = mobileBottomContentInset(context);

    final nonWorkingIdsEffective = effectiveNonWorkingIds.toList();

    PointageRecord? getRecord(String employeId, {String? equipeId}) {
      if (isViewingToday) {
        if (equipeId != null && _isDistributionEquipeId(equipeId)) {
          final all = pointageProvider.todayPointage
              .where((p) => p.employeId == employeId)
              .toList();
          return _pickDistributionRecordForTeam(all, equipeId) ??
              pointageProvider.getRecordForEmployee(employeId);
        }
        return pointageProvider.getRecordForEmployee(employeId);
      }
      final list = pointageProvider.pointageByDate
          .where((p) => p.employeId == employeId)
          .toList();
      if (equipeId != null && _isDistributionEquipeId(equipeId)) {
        return _pickDistributionRecordForTeam(list, equipeId);
      }
      return list.isEmpty ? null : list.first;
    }

    /// True = ready to be confirmed by admin:
    /// - both driver + chef already submitted (locked)
    /// - and for "present" cases: entry + exit are marked
    bool departureOkForAdmin(PointageRecord rec) {
      return rec.departureStatus == DepartureStatus.finished ||
          rec.departureStatus == DepartureStatus.stillWorking;
    }

    bool isWorkerReadyForAdminConfirm(PointageRecord? rec, String equipeId) {
      if (rec == null) return false;
      if (rec.chefStatus == ChefPointageStatus.unset) return false;
      final isDistributionScope = _isDistributionEquipeId(equipeId);
      if (!isDistributionScope) {
        final driverParticipated = rec.driverStatus != DriverPointageStatus.unset;
        if (driverParticipated && !rec.driverLocked) return false;
      }
      if (!rec.chefLocked) return false;

      final nightEntryOnly =
          _isNightShiftEntryOnlyAdminContext(equipeId, logicalDay, equipes, shiftsProvider);

      // Only enforce entry/exit for "present" confirmed by driver/chef statuses.
      // adminFinalStatus (training/leave/present) is handled separately (often without entry/exit).
      // Distribution : ignorer totalement le chauffeur.
      final isPresentByDriverOrChef = isDistributionScope
          ? rec.chefStatus == ChefPointageStatus.present
          : (rec.driverStatus == DriverPointageStatus.present ||
              rec.driverStatus == DriverPointageStatus.enVehicule ||
              rec.chefStatus == ChefPointageStatus.present);

      if (isPresentByDriverOrChef) {
        if (rec.arrivalMarkedAt == null) return false;
        if (!nightEntryOnly) {
          if (!departureOkForAdmin(rec)) return false;
          if (rec.departureMarkedAt == null) return false;
        }
        if (rec.submittedByChefAt == null) return false;
        if (!isDistributionScope) {
          final driverParticipated = rec.driverStatus != DriverPointageStatus.unset;
          if (driverParticipated && rec.submittedByDriverAt == null) return false;
        }

        // Cohérence: entrée avant sortie (évite les données incohérentes).
        if (!nightEntryOnly &&
            rec.departureMarkedAt != null &&
            rec.arrivalMarkedAt != null &&
            rec.departureMarkedAt!.isBefore(rec.arrivalMarkedAt!)) {
          return false;
        }
      }

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
        date: logicalDay,
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
        await _offerMobileShare(context, filePath, text: 'Rapport pointage');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdminMonthRecords(pointageProvider);
    });

    Widget adminPointageToolbar(BuildContext context, BoxConstraints constraints) {
              final compactHeader = constraints.maxWidth < 1050;
              final densePhone = constraints.maxWidth < 420;
              final headerSpacing = densePhone ? 6.0 : 8.0;
              final chipH = densePhone ? 8.0 : 10.0;
              final chipV = densePhone ? 4.0 : 6.0;
              final actionH = densePhone ? 8.0 : 12.0;
              final actionV = densePhone ? 6.0 : 10.0;
              final iconSize = densePhone ? 16.0 : 18.0;
              final labelSize = densePhone ? 12.0 : 14.0;
              final compactDateInline = constraints.maxWidth < 700;
              final dateControls = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: densePhone ? 2 : 4,
                runSpacing: densePhone ? 4 : 6,
                children: [
                  IconButton(
                    tooltip: 'Jour précédent',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: densePhone ? 30 : 34, minHeight: densePhone ? 30 : 34),
                    onPressed: () => _shiftAdminViewDay(pointageProvider, -1),
                    icon: Icon(Icons.chevron_left, size: densePhone ? 20 : 22, color: Colors.blueGrey.shade800),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    constraints: BoxConstraints(minWidth: densePhone ? 30 : 34, minHeight: densePhone ? 30 : 34),
                    onPressed: isViewingToday
                        ? null
                        : () => _shiftAdminViewDay(pointageProvider, 1),
                    icon: Icon(Icons.chevron_right, size: densePhone ? 20 : 22, color: Colors.blueGrey.shade800),
                  ),
                  if (!isViewingToday)
                    TextButton(
                      onPressed: () => _applyAdminViewDay(pointageProvider, todayOnly),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Aujourd\'hui'),
                    ),
                  OutlinedButton(
                    onPressed: () {
                      final y = todayOnly.subtract(const Duration(days: 1));
                      _applyAdminViewDay(pointageProvider, y);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Hier'),
                  ),
                ],
              );
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Pointage', style: TextStyle(fontSize: densePhone ? 18 : 22, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: compactDateInline
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: dateControls,
                                )
                              : dateControls,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recordsForDate.length} enregistrement(s)${isViewingToday ? '' : ' (jour sélectionné)'}',
                    style: TextStyle(fontSize: densePhone ? 11 : 12, color: Colors.grey[600]),
                  ),
                  if (mobile && isViewingToday)
                    StreamBuilder<List<DailyEquipeConfirmation>>(
                      stream: _yesterdayConfirmationsStream,
                      builder: (context, snapY) {
                        final yesterdayConf = snapY.data ?? _yesterdayConfirmations;
                        if (snapY.hasData) _yesterdayConfirmations = snapY.data!;
                        final yesterday = DateTime(logicalDay.year, logicalDay.month, logicalDay.day - 1);
                        final workTeams = filteredTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                        final yesterdayConfirmedIds = yesterdayConf.map((c) => c.equipeId).toSet();
                        final notConfirmedYesterday = workTeams.where((t) => !yesterdayConfirmedIds.contains(t.equipeId)).toList();
                        if (notConfirmedYesterday.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 14),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Non confirmé (${notConfirmedYesterday.length})',
                                    style: TextStyle(fontSize: 10.5, color: Colors.red.shade800, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _applyAdminViewDay(pointageProvider, yesterday),
                                  child: Text(
                                    'Voir',
                                    style: TextStyle(fontSize: 10.5, color: Colors.red.shade700, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                    onPressed: pointageProvider.ignoreTimeWindowsForTest
                        ? () {
                            pointageProvider.startTestCycle(arrivalMinutes: 5);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test démarré: Entrée pendant 5 min puis sortie.'),
                                  behavior: SnackBarBehavior.fixed,
                                ),
                              );
                            }
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.play_circle_outline, size: iconSize),
                    label: Text('Démarrer test 5 min', style: TextStyle(fontSize: labelSize)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExcelExportDialog(context, allTeams, equipes, employes, pointageProvider),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.table_chart_outlined, size: iconSize),
                    label: Text('Exporter Excel', style: TextStyle(fontSize: labelSize)),
                  ),
                  // Raccourcis (sans supprimer le bouton existant)
                  OutlinedButton.icon(
                    onPressed: () => _showExcelExportDialog(
                      context,
                      allTeams,
                      equipes,
                      employes,
                      pointageProvider,
                      initialScope: 'groupes',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.groups_outlined, size: iconSize),
                    label: Text('Excel Groupes', style: TextStyle(fontSize: labelSize)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExcelExportDialog(
                      context,
                      allTeams,
                      equipes,
                      employes,
                      pointageProvider,
                      initialScope: 'all',
                      forceSingleSheet: true,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.business_outlined, size: iconSize),
                    label: Text('Excel Société', style: TextStyle(fontSize: labelSize)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExcelExportDialog(
                      context,
                      allTeams,
                      equipes,
                      employes,
                      pointageProvider,
                      initialScope: 'all',
                      useOcpGrid: true,
                      excludeDistribution: true,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: actionH, vertical: actionV),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: densePhone ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    icon: Icon(Icons.grid_view_outlined, size: iconSize),
                    label: Text('Excel OCP', style: TextStyle(fontSize: labelSize)),
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      final reset = await _showResetPointageDayDialog(
                        context,
                        filteredTeams.map((t) => (id: t.equipeId, label: '${t.equipeName} — ${t.chefName}')).toList(),
                        logicalDay,
                      );
                      if (reset == null || !mounted) return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Réinitialiser pointage'),
                          content: Text(
                            reset.equipeId == null
                                ? 'Supprimer toutes les données pointage et rapports du '
                                    '${logicalDay.day}/${logicalDay.month}/${logicalDay.year} ?'
                                : 'Supprimer le pointage du '
                                    '${logicalDay.day}/${logicalDay.month}/${logicalDay.year} '
                                    'pour ${reset.equipeLabel} uniquement ?',
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
                      await pointageProvider.clearPointageAndReportsForDay(
                        logicalDay,
                        equipeId: reset.equipeId,
                      );
                      if (reset.equipeId == null) {
                        for (final t in allTeams) {
                          await _confirmationRepo.unconfirmEquipe(t.equipeId, logicalDay);
                          await _snapshotRepo.deleteEquipeSnapshot(t.equipeId, logicalDay);
                        }
                      } else {
                        await _confirmationRepo.unconfirmEquipe(reset.equipeId!, logicalDay);
                        await _snapshotRepo.deleteEquipeSnapshot(reset.equipeId!, logicalDay);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              reset.equipeId == null
                                  ? 'Pointage réinitialisé pour ce jour.'
                                  : 'Pointage réinitialisé pour l\'équipe sélectionnée.',
                            ),
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
                    SizedBox(height: densePhone ? 4 : 8),
                    _buildHorizontalMouseNavigator(
                      controller: _adminActionsScrollController,
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
    }

    Widget adminTabsRow() {
      final tabGap = mobile ? 8.0 : 14.0;
      return _buildHorizontalMouseNavigator(
        controller: _adminTabsScrollController,
        child: Row(
          children: [
            _AdminTopTabButton(
              label: 'Pointages',
              selected: _adminTab == _AdminDesignTab.pointages,
              onTap: () => setState(() => _adminTab = _AdminDesignTab.pointages),
            ),
            SizedBox(width: tabGap),
            _AdminTopTabButton(
              label: 'Statistiques',
              selected: _adminTab == _AdminDesignTab.statistiques,
              onTap: () => setState(() => _adminTab = _AdminDesignTab.statistiques),
            ),
            SizedBox(width: tabGap),
            _AdminTopTabButton(
              label: 'Autorisations H.Sup',
              selected: _adminTab == _AdminDesignTab.hs,
              badge: _adminMonthRecords.where((r) => (r.overtimeMinutes ?? 0) > 0).length,
              onTap: () => setState(() => _adminTab = _AdminDesignTab.hs),
            ),
            SizedBox(width: tabGap),
            _AdminTopTabButton(
              label: 'Formation',
              selected: _adminTab == _AdminDesignTab.formation,
              onTap: () => setState(() => _adminTab = _AdminDesignTab.formation),
            ),
            SizedBox(width: tabGap),
          ],
        ),
      );
    }

    List<Widget> adminMobileHeaderSlivers(BoxConstraints constraints) {
      final narrow = constraints.maxWidth < 420;
      return [
        SliverToBoxAdapter(child: adminPointageToolbar(context, constraints)),
        SliverToBoxAdapter(child: SizedBox(height: narrow ? 4 : 6)),
        SliverToBoxAdapter(child: adminTabsRow()),
        SliverToBoxAdapter(child: SizedBox(height: narrow ? 4 : 8)),
      ];
    }

    final content = Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFixedAdminHeader) ...[
            LayoutBuilder(builder: adminPointageToolbar),
            SizedBox(height: mobile ? 6 : 8),
            adminTabsRow(),
            SizedBox(height: mobile ? 6 : 8),
          ],
          Expanded(
            child: Builder(
              builder: (ctx) {
                if (_adminTab == _AdminDesignTab.statistiques) {
                  final prev = _adminContentView;
                  _adminContentView = _AdminPointageView.analysis;
                  if (mobile) {
                    final inner = _buildAdminMainContent(
                      context,
                      team: team,
                      workers: workers,
                      borderColor: borderColor,
                      pointageProvider: pointageProvider,
                      getRecord: getRecord,
                      teams: filteredTeams,
                      equipes: equipes,
                      adminLogicalDay: logicalDay,
                      nonWorkingIds: nonWorkingIdsEffective,
                      viewDate: logicalDay,
                      adminOverridePersistDate: isViewingToday ? null : logicalDay,
                      presentByChef: presentByChef,
                      absentByChef: absentByChef,
                      notInVehicleByChef: notInVehicleByChef,
                      notWorkingByChef: notWorkingByChef,
                      readOnly: adminReadOnly,
                      nestInParentScroll: true,
                    );
                    _adminContentView = prev;
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomScrollView(
                          slivers: [
                            ...adminMobileHeaderSlivers(constraints),
                            SliverToBoxAdapter(child: inner),
                            SliverToBoxAdapter(child: SizedBox(height: bottomScrollPadding)),
                          ],
                        );
                      },
                    );
                  }
                  final w = _buildAdminMainContent(
                    context,
                    team: team,
                    workers: workers,
                    borderColor: borderColor,
                    pointageProvider: pointageProvider,
                    getRecord: getRecord,
                    teams: filteredTeams,
                    equipes: equipes,
                    adminLogicalDay: logicalDay,
                    nonWorkingIds: nonWorkingIdsEffective,
                    viewDate: logicalDay,
                    adminOverridePersistDate: isViewingToday ? null : logicalDay,
                    presentByChef: presentByChef,
                    absentByChef: absentByChef,
                    notInVehicleByChef: notInVehicleByChef,
                    notWorkingByChef: notWorkingByChef,
                    readOnly: adminReadOnly,
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
                  if (mobile) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomScrollView(
                          slivers: [
                            ...adminMobileHeaderSlivers(constraints),
                            SliverToBoxAdapter(
                              child: Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
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
                              ),
                            ),
                            SliverToBoxAdapter(child: Divider(height: 1, color: Colors.grey.shade300)),
                            if (list.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'Aucune affectation pour cette date.',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                                sliver: SliverList.separated(
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
                            SliverToBoxAdapter(child: SizedBox(height: bottomScrollPadding)),
                          ],
                        );
                      },
                    );
                  }
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
                  if (mobile) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomScrollView(
                          slivers: [
                            ...adminMobileHeaderSlivers(constraints),
                            SliverToBoxAdapter(
                              child: _FormationManagementPage(
                                teams: filteredTeams,
                                pointageProvider: pointageProvider,
                                employes: employes,
                                nestInOuterScroll: true,
                              ),
                            ),
                            SliverToBoxAdapter(child: SizedBox(height: bottomScrollPadding)),
                          ],
                        );
                      },
                    );
                  }
                  return _FormationManagementPage(
                    teams: filteredTeams,
                    pointageProvider: pointageProvider,
                    employes: employes,
                  );
                }
                // Pointages tab (existing functionality)
                if (mobile) {
                  Future<void> confirmTeam(
                    ({String equipeId, String equipeName, String chefName, List<Employe> workers}) t,
                  ) async {
                    final isGroupScope = t.equipeId == 'hors_equipe' || t.equipeId.startsWith('groupe:');
                    final isDistributionScope = _isDistributionEquipeId(t.equipeId);
                    final reasonConfigsList = context.read<AbsenceReasonsProvider>().reasons;
                    final reasonConfigsForSnapshot =
                        reasonConfigsList.isEmpty ? null : reasonConfigsList;
                    final teamWorkers = t.workers;
                    int presentC = 0, absentC = 0, sortieOkC = 0;
                    final nightTeamMobile = _isNightShiftEntryOnlyAdminContext(t.equipeId, logicalDay, equipes, shiftsProvider);
                    for (final w in teamWorkers) {
                      final rec = getRecord(w.id, equipeId: t.equipeId);
                      if (isGroupScope) {
                        final admin = rec?.adminFinalStatus;
                        final isPresent = admin == AttendanceStatus.present || admin == AttendanceStatus.training || admin == AttendanceStatus.leave;
                        if (isPresent) {
                          presentC++;
                        } else {
                          absentC++;
                        }
                      } else {
                        if (rec?.isFinalPresent == true) {
                          presentC++;
                          if (rec != null) {
                            if (nightTeamMobile) {
                              if (rec.arrivalMarkedAt != null && rec.submittedByChefAt != null) {
                                sortieOkC++;
                              }
                            } else if (rec.departureStatus == DepartureStatus.finished ||
                                rec.departureStatus == DepartureStatus.stillWorking) {
                              sortieOkC++;
                            }
                          }
                        } else {
                          absentC++;
                        }
                      }
                    }
                    final canConfirm = teamWorkers.every((w) {
                      final rec = getRecord(w.id, equipeId: t.equipeId);
                      if (isGroupScope) {
                        final ok = rec?.adminFinalStatus == AttendanceStatus.present || rec?.adminFinalStatus == AttendanceStatus.absent;
                        if (ok) return true;
                        return allowIncompleteConfirmPastDay;
                      }
                      if (allowIncompleteConfirmPastDay) return true;
                      return isWorkerReadyForAdminConfirm(rec, t.equipeId);
                    });

                    bool confirmWindowOpen = true;
                    String? confirmWindowHint;
                    if (!isGroupScope && !isDistributionScope && isViewingToday) {
                      final cfgEquipe = equipes.where((e) => e.id == t.equipeId).toList();
                      final equipe = cfgEquipe.isNotEmpty ? cfgEquipe.first : null;
                      final shiftForEquipe = equipe == null ? null : shiftsProvider.getShiftForEquipe(equipe.id, logicalDay);
                      final cfg = getConfigForEquipeAndDate(equipe, logicalDay, shiftForEquipe);
                      final nightTeam = cfg.isNightShift || shiftForEquipe == ShiftType.night;
                      final allReadyNightEntry =
                          nightTeam && teamWorkers.every((w) => isWorkerReadyForAdminConfirm(getRecord(w.id, equipeId: t.equipeId), t.equipeId));
                      confirmWindowOpen = cfg.canAdminConfirmAfterShiftEnd(now, logicalDay) || allReadyNightEntry;
                      if (!confirmWindowOpen) {
                        confirmWindowHint = tr(context, 'pointage_admin_confirm_after_shift').replaceFirst('%s', cfg.shiftEndFormattedOn(logicalDay));
                      }
                    }
                    if (!confirmWindowOpen) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(confirmWindowHint ?? 'Fenêtre de confirmation non ouverte.'),
                            backgroundColor: AppColors.brand,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                      return;
                    }
                    if (!canConfirm) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isGroupScope
                                ? 'Veuillez sélectionner Présent/Absent pour chaque personne.'
                                : (presentC > 0
                                    ? '${tr(context, 'pointage_admin_pointage_incomplete_short')} ($sortieOkC/$presentC sorties)'
                                    : tr(context, 'pointage_admin_pointage_incomplete'))),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                      return;
                    }
                    final auth = context.read<AuthProvider>();
                    final confirmedById = auth.currentUser?.id ?? '';
                    final empSnapshots = teamWorkers.map((w) {
                      final rec = getRecord(w.id, equipeId: t.equipeId);
                      final status = PointageExportService.resolveSnapshotStatus(
                        rec: rec,
                        isGroupScope: isGroupScope,
                        isDistributionScope: isDistributionScope,
                        reasonConfigs: reasonConfigsForSnapshot,
                      );
                      final absenceReason =
                          status == 'absent' || status == 'paid_absence' ? rec?.absenceReason : null;
                      final workerRestDay = t.equipeId == horsEquipeVirtualId
                          ? (isHorsEquipeWeeklyRestDay(logicalDay) ||
                              shiftsProvider.isPublicHoliday(logicalDay))
                          : (t.equipeId.startsWith('groupe:')
                              ? (isWeeklyRestForGroupe(t.equipeId, logicalDay) ||
                                  shiftsProvider.isPublicHoliday(logicalDay))
                              : isWeeklyRestForGroupe(t.equipeId, logicalDay));
                      return (
                        employeId: w.id,
                        employeNom: w.nom,
                        employeCin: w.cin ?? '',
                        status: status,
                        absenceReason: absenceReason,
                        isRestDay: workerRestDay,
                      );
                    }).toList();
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
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 420;
                      return CustomScrollView(
                        slivers: [
                          ...adminMobileHeaderSlivers(constraints),
                          SliverToBoxAdapter(
                            child: DropdownButtonFormField<String>(
                              value: _selectedEquipeIdAdmin,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: 'Équipe',
                                isDense: narrow,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: narrow ? 8 : 14),
                              ),
                              items: allTeams
                                  .map((t) => DropdownMenuItem(
                                        value: t.equipeId,
                                        child: Text(
                                          '${t.equipeName} — ${t.chefName}',
                                          maxLines: 4,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedEquipeIdAdmin = v),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: narrow ? 6 : 10)),
                          SliverToBoxAdapter(
                            child: _buildAdminMainContent(
                              context,
                              team: team,
                              workers: workers,
                              borderColor: borderColor,
                              pointageProvider: pointageProvider,
                              getRecord: getRecord,
                              teams: filteredTeams,
                              equipes: equipes,
                              adminLogicalDay: logicalDay,
                              nonWorkingIds: nonWorkingIdsEffective,
                              viewDate: logicalDay,
                              adminOverridePersistDate: isViewingToday ? null : logicalDay,
                              presentByChef: presentByChef,
                              absentByChef: absentByChef,
                              notInVehicleByChef: notInVehicleByChef,
                              notWorkingByChef: notWorkingByChef,
                              readOnly: adminReadOnly,
                              nestInParentScroll: true,
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: narrow ? 6 : 8)),
                          SliverToBoxAdapter(
                            child: Container(
                              width: double.infinity,
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
                                  final workTeams = filteredTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                                  final confirmScopeTeams = auth.isChefZoneAdmin
                                      ? workTeams
                                          .where((t) =>
                                              _chefZoneMayActOnDistribution(auth, t.equipeId) ||
                                              t.equipeId == 'hors_equipe')
                                          .toList()
                                      : workTeams;
                                  final confirmedCount =
                                      confirmScopeTeams.where((t) => confirmedIds.contains(t.equipeId)).length;
                                  final totalCount = confirmScopeTeams.length;

                                  return ExpansionTile(
                                    tilePadding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 10, vertical: 0),
                                    childrenPadding: const EdgeInsets.only(bottom: 8),
                                    initiallyExpanded: false,
                                    title: Text(
                                      'Confirmations • $confirmedCount/$totalCount',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: narrow ? 11 : 11.5,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    trailing: Icon(Icons.expand_more, size: narrow ? 20 : 24),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () async {
                                              final toConfirm = confirmScopeTeams
                                                  .where((t) => !confirmedIds.contains(t.equipeId))
                                                  .toList();
                                              for (final t in toConfirm) {
                                                await confirmTeam(t);
                                              }
                                            },
                                            icon: Icon(Icons.done_all, size: narrow ? 14 : 15),
                                            label: Text('Tout confirmer', style: TextStyle(fontSize: narrow ? 10 : 11)),
                                            style: FilledButton.styleFrom(
                                              padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 10, vertical: narrow ? 6 : 8),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ),
                                        ),
                                      ),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: narrow ? 180 : 220),
                                        child: ListView.builder(
                                          primary: false,
                                          shrinkWrap: true,
                                          itemCount: allTeams.length,
                                          itemBuilder: (context, i) {
                                            final t = allTeams[i];
                                            final isNonWorking = nonWorkingIdsEffective.contains(t.equipeId);
                                            final isConfirmed = confirmedIds.contains(t.equipeId);
                                            return ListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              isThreeLine: narrow,
                                              onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
                                              title: Text(
                                                '${t.equipeName} — ${t.chefName}',
                                                maxLines: narrow ? 5 : 2,
                                                softWrap: true,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: narrow ? 11 : 12, height: narrow ? 1.2 : null),
                                              ),
                                              subtitle: isNonWorking ? Text('Disponible après fin de shift (—)', style: TextStyle(fontSize: narrow ? 9 : 10)) : null,
                                              trailing: isNonWorking
                                                  ? null
                                                  : !_adminMayConfirmEquipe(auth, t.equipeId)
                                                      ? Padding(
                                                          padding: const EdgeInsets.only(right: 6),
                                                          child: Text(
                                                            '—',
                                                            style: TextStyle(fontSize: narrow ? 11 : 12, color: Colors.grey.shade500),
                                                          ),
                                                        )
                                                      : isConfirmed
                                                          ? OutlinedButton.icon(
                                                              onPressed: () async {
                                                                await _confirmationRepo.unconfirmEquipe(t.equipeId, logicalDay);
                                                                await _snapshotRepo.deleteEquipeSnapshot(t.equipeId, logicalDay);
                                                              },
                                                              icon: Icon(Icons.check_circle, size: narrow ? 12 : 14),
                                                              label: Text('Confirmé', style: TextStyle(fontSize: narrow ? 9 : 9.5)),
                                                              style: OutlinedButton.styleFrom(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                visualDensity: VisualDensity.compact,
                                                              ),
                                                            )
                                                          : FilledButton(
                                                              onPressed: () => confirmTeam(t),
                                                              style: FilledButton.styleFrom(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                visualDensity: VisualDensity.compact,
                                                              ),
                                                              child: Text('Confirmer', style: TextStyle(fontSize: narrow ? 9 : 9.5)),
                                                            ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: bottomScrollPadding)),
                        ],
                      );
                    },
                  );
                }
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
                          final workTeams = filteredTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
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
                    Expanded(child: LayoutBuilder(
                  builder: (context, constraints) {
                    final leftPaneWidth = (constraints.maxWidth * 0.25).clamp(240.0, 360.0);
                    // Les filtres sont dans une colonne étroite : ne pas utiliser la largeur écran (MediaQuery).
                    final adminFilterScrollOnly = leftPaneWidth < 560;
                    return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: leftPaneWidth,
                      child: Container(
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
                          final workTeams = filteredTeams.where((t) => !nonWorkingIdsEffective.contains(t.equipeId)).toList();
                          final confirmedCount = workTeams.where((t) => confirmedIds.contains(t.equipeId)).length;
                          final totalCount = workTeams.length;
                          final allConfirmed = totalCount > 0 && confirmedCount == totalCount;
                          final visibleTeams = filteredTeams.where((t) {
                            final isConfirmed = confirmedIds.contains(t.equipeId);
                            switch (_adminConfirmScope) {
                              case _AdminConfirmScope.all:
                                return true;
                              case _AdminConfirmScope.confirmed:
                                return isConfirmed;
                              case _AdminConfirmScope.unconfirmed:
                                return !isConfirmed;
                            }
                          }).toList();
                          final chipFontSize = adminFilterScrollOnly ? 10.0 : 12.0;
                          final chipGap = adminFilterScrollOnly ? 4.0 : 6.0;
                          TextStyle chipTextStyle([FontWeight? w]) => TextStyle(fontSize: chipFontSize, fontWeight: w);

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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                                child: _buildHorizontalMouseNavigator(
                                  controller: _adminTeamScopeScrollController,
                                  showButtons: true,
                                  compactNav: adminFilterScrollOnly,
                                  child: Row(
                                    children: [
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Tous', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminTeamScope == _AdminTeamScope.all,
                                        onSelected: (_) => setState(() => _adminTeamScope = _AdminTeamScope.all),
                                      ),
                                      SizedBox(width: chipGap),
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Équipes', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminTeamScope == _AdminTeamScope.equipes,
                                        onSelected: (_) => setState(() => _adminTeamScope = _AdminTeamScope.equipes),
                                      ),
                                      if (!auth.isChefAtelierAdmin) ...[
                                        SizedBox(width: chipGap),
                                        ChoiceChip(
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          label: Text('Distribution', style: chipTextStyle()),
                                          labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                          selected: _adminTeamScope == _AdminTeamScope.distribution,
                                          onSelected: (_) => setState(() => _adminTeamScope = _AdminTeamScope.distribution),
                                        ),
                                      ],
                                      SizedBox(width: chipGap),
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Autres', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminTeamScope == _AdminTeamScope.others,
                                        onSelected: (_) => setState(() => _adminTeamScope = _AdminTeamScope.others),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                                child: _buildHorizontalMouseNavigator(
                                  controller: _adminConfirmScopeScrollController,
                                  showButtons: true,
                                  compactNav: adminFilterScrollOnly,
                                  child: Row(
                                    children: [
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Tous états', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminConfirmScope == _AdminConfirmScope.all,
                                        onSelected: (_) => setState(() => _adminConfirmScope = _AdminConfirmScope.all),
                                      ),
                                      SizedBox(width: chipGap),
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Confirmés', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminConfirmScope == _AdminConfirmScope.confirmed,
                                        onSelected: (_) => setState(() => _adminConfirmScope = _AdminConfirmScope.confirmed),
                                      ),
                                      SizedBox(width: chipGap),
                                      ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        label: Text('Non confirmés', style: chipTextStyle()),
                                        labelPadding: EdgeInsets.symmetric(horizontal: adminFilterScrollOnly ? 6 : 8),
                                        selected: _adminConfirmScope == _AdminConfirmScope.unconfirmed,
                                        onSelected: (_) => setState(() => _adminConfirmScope = _AdminConfirmScope.unconfirmed),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (visibleTeams.isEmpty)
                                Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600])))
                              else
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: visibleTeams.length,
                                    itemBuilder: (context, i) {
                                      final t = visibleTeams[i];
                                      final isNonWorking = nonWorkingIdsEffective.contains(t.equipeId);
                                      final shiftLabel = t.equipeId == horsEquipeVirtualId
                                          ? (shiftsProvider.isPublicHoliday(logicalDay)
                                              ? 'JF'
                                              : (isHorsEquipeWeeklyRestDay(logicalDay) ? 'Repos' : null))
                                          : t.equipeId.startsWith('groupe:')
                                              ? (shiftsProvider.isPublicHoliday(logicalDay)
                                                  ? 'JF'
                                                  : (isWeeklyRestForGroupe(t.equipeId, logicalDay)
                                                      ? 'Repos'
                                                      : null))
                                              : shiftsProvider.getShiftForEquipe(t.equipeId, logicalDay)?.shortLabel;
                                      final isSpecialScope =
                                          t.equipeId == 'hors_equipe' || t.equipeId.startsWith('groupe:');
                                      final showPhaseBadge = isViewingToday && !isSpecialScope;
                                      final isCarryOverNight = carryOverNightTeamIds.contains(t.equipeId);
                                      final phaseBadgeText = !showPhaseBadge
                                          ? null
                                          : (isCarryOverNight ? 'Sortie nuit (hier)' : "Shift aujourd'hui");
                                      final isSelected = _selectedEquipeIdAdmin == t.equipeId;
                                      final isConfirmed = confirmedIds.contains(t.equipeId);

                                      // حساب الحاضرين/الغائبين لهذا الفريق
                                      final teamWorkers = t.workers;
                                      final isGroupScope = t.equipeId == 'hors_equipe' || t.equipeId.startsWith('groupe:');
                                      final isDistributionScope = _isDistributionEquipeId(t.equipeId);
                                      final nightTeamRow =
                                          _isNightShiftEntryOnlyAdminContext(t.equipeId, logicalDay, equipes, shiftsProvider);
                                      int presentC = 0, absentC = 0;
                                      int sortieOkC = 0;
                                      for (final w in teamWorkers) {
                                        final rec = getRecord(w.id, equipeId: t.equipeId);
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
                                            if (rec != null) {
                                              if (nightTeamRow) {
                                                if (rec.arrivalMarkedAt != null && rec.submittedByChefAt != null) {
                                                  sortieOkC++;
                                                }
                                              } else if (rec.departureStatus == DepartureStatus.finished ||
                                                  rec.departureStatus == DepartureStatus.stillWorking) {
                                                sortieOkC++;
                                              }
                                            }
                                          } else {
                                            absentC++;
                                          }
                                        }
                                      }

                                      final canConfirm = teamWorkers.every((w) {
                                        final rec = getRecord(w.id, equipeId: t.equipeId);
                                        if (isGroupScope) {
                                          final ok = rec?.adminFinalStatus == AttendanceStatus.present ||
                                              rec?.adminFinalStatus == AttendanceStatus.absent;
                                          if (ok) return true;
                                          return allowIncompleteConfirmPastDay;
                                        }
                                        if (allowIncompleteConfirmPastDay) return true;
                                        return isWorkerReadyForAdminConfirm(rec, t.equipeId);
                                      });

                                      // ── Fenêtre de confirmation admin ──
                                      // Équipes normales : pas avant la **fin du shift** (pas la fenêtre départ −30 min).
                                      // Jour passé (sélecteur de date) : toujours confirmable (après coup).
                                      bool confirmWindowOpen = true;
                                      String? confirmWindowHint;
                                      if (!isGroupScope && !isDistributionScope && isViewingToday) {
                                        final cfgEquipe = equipes.where((e) => e.id == t.equipeId).toList();
                                        final equipe = cfgEquipe.isNotEmpty ? cfgEquipe.first : null;
                                        final shiftForEquipe = equipe == null ? null : shiftsProvider.getShiftForEquipe(equipe.id, logicalDay);
                                        final cfg = getConfigForEquipeAndDate(equipe, logicalDay, shiftForEquipe);
                                        final nightTeam = cfg.isNightShift || shiftForEquipe == ShiftType.night;
                                        final allReadyNightEntry = nightTeam &&
                                            teamWorkers.every((w) => isWorkerReadyForAdminConfirm(getRecord(w.id, equipeId: t.equipeId), t.equipeId));
                                        confirmWindowOpen =
                                            cfg.canAdminConfirmAfterShiftEnd(now, logicalDay) || allReadyNightEntry;
                                        if (!confirmWindowOpen) {
                                          confirmWindowHint = tr(context, 'pointage_admin_confirm_after_shift')
                                              .replaceFirst('%s', cfg.shiftEndFormattedOn(logicalDay));
                                        }
                                      }

                                      String? lockHint;
                                      if (!canConfirm) {
                                        if (isGroupScope) {
                                          lockHint = 'Veuillez sélectionner Présent/Absent pour chaque personne.';
                                        } else {
                                          lockHint = presentC > 0
                                              ? '${tr(context, 'pointage_admin_pointage_incomplete_short')} ($sortieOkC/$presentC sorties)'
                                              : tr(context, 'pointage_admin_pointage_incomplete');
                                        }
                                      }

                                      final teamRowCompact = mobile;
                                      final badgePadH = teamRowCompact ? 3.0 : 5.0;
                                      final badgePadV = teamRowCompact ? 0.0 : 1.0;
                                      final badgeFont = teamRowCompact ? 8.5 : 10.0;
                                      final badgeGap = teamRowCompact ? 2.0 : 3.0;
                                      final titleFont = teamRowCompact ? 11.5 : 11.0;
                                      final phaseFont = teamRowCompact ? 8.0 : 9.0;
                                      final teamTitleText =
                                          '${t.equipeName} — ${t.chefName}${shiftLabel != null ? ' ($shiftLabel)' : ''}';
                                      final teamTitleStyle = TextStyle(
                                        fontSize: titleFont,
                                        height: teamRowCompact ? 1.2 : null,
                                        color: isNonWorking
                                            ? Colors.grey.shade400
                                            : isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey.shade700,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        decoration: isNonWorking ? TextDecoration.lineThrough : null,
                                      );
                                      final teamCountBadges = <Widget>[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: badgePadH, vertical: badgePadV),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$presentC',
                                            style: TextStyle(
                                              fontSize: badgeFont,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: badgePadH, vertical: badgePadV),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$absentC',
                                            style: TextStyle(
                                              fontSize: badgeFont,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (!isGroupScope)
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: badgePadH, vertical: badgePadV),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.teal.shade200),
                                            ),
                                            child: Text(
                                              '$sortieOkC',
                                              style: TextStyle(
                                                fontSize: badgeFont,
                                                color: Colors.teal.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ];
                                      final phaseBadgeWidget = phaseBadgeText == null
                                          ? null
                                          : Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: teamRowCompact ? 4 : 6,
                                                vertical: teamRowCompact ? 0 : 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isCarryOverNight
                                                    ? Colors.deepOrange.withValues(alpha: 0.12)
                                                    : AppColors.brand.withValues(alpha: 0.10),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: isCarryOverNight
                                                      ? Colors.deepOrange.withValues(alpha: 0.40)
                                                      : AppColors.brand.withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Text(
                                                phaseBadgeText,
                                                style: TextStyle(
                                                  fontSize: phaseFont,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCarryOverNight
                                                      ? Colors.deepOrange.shade700
                                                      : AppColors.brand,
                                                ),
                                              ),
                                            );

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (teamRowCompact)
                                            Material(
                                              color: isSelected
                                                  ? Theme.of(context).primaryColor.withValues(alpha: 0.10)
                                                  : Colors.transparent,
                                              child: InkWell(
                                                onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
                                                child: Padding(
                                                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2),
                                                            child: Icon(
                                                              isConfirmed ? Icons.check_circle : Icons.person,
                                                              size: 14,
                                                              color: isConfirmed
                                                                  ? Colors.green
                                                                  : (isSelected
                                                                      ? Theme.of(context).primaryColor
                                                                      : Colors.grey),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Expanded(
                                                            child: Text(
                                                              teamTitleText,
                                                              style: teamTitleStyle,
                                                              softWrap: true,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (phaseBadgeWidget != null) ...[
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 20, top: 4),
                                                          child: phaseBadgeWidget,
                                                        ),
                                                      ],
                                                      Padding(
                                                        padding: EdgeInsets.only(
                                                          left: 20,
                                                          top: phaseBadgeWidget != null ? 6 : 6,
                                                        ),
                                                        child: isNonWorking
                                                            ? Text(
                                                                'repos',
                                                                style: TextStyle(
                                                                  fontSize: 8,
                                                                  color: Colors.grey.shade400,
                                                                ),
                                                              )
                                                            : Wrap(
                                                                spacing: badgeGap,
                                                                runSpacing: 4,
                                                                children: teamCountBadges,
                                                              ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            ListTile(
                                              dense: true,
                                              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                                              minVerticalPadding: 0,
                                              horizontalTitleGap: 12,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                              selected: isSelected,
                                              selectedTileColor:
                                                  Theme.of(context).primaryColor.withValues(alpha: 0.10),
                                              onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
                                              leading: Icon(
                                                isConfirmed ? Icons.check_circle : Icons.person,
                                                size: 18,
                                                color: isConfirmed
                                                    ? Colors.green
                                                    : (isSelected ? Theme.of(context).primaryColor : Colors.grey),
                                              ),
                                              title: Text(
                                                teamTitleText,
                                                maxLines: 1,
                                                style: teamTitleStyle,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: phaseBadgeWidget == null
                                                  ? null
                                                  : Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Align(
                                                        alignment: AlignmentDirectional.centerStart,
                                                        child: phaseBadgeWidget,
                                                      ),
                                                    ),
                                              trailing: isNonWorking
                                                  ? Text(
                                                      'repos',
                                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                                                    )
                                                  : Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        for (var i = 0; i < teamCountBadges.length; i++) ...[
                                                          if (i > 0) SizedBox(width: badgeGap),
                                                          teamCountBadges[i],
                                                        ],
                                                      ],
                                                    ),
                                            ),
                                          // ── زر تأكيد / إلغاء تأكيد الفريق ──
                                          if (!isNonWorking && _adminMayConfirmEquipe(auth, t.equipeId))
                                            Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                adminFilterScrollOnly ? 8 : 12,
                                                0,
                                                adminFilterScrollOnly ? 8 : 12,
                                                adminFilterScrollOnly ? 4 : 6,
                                              ),
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
                                                          padding: EdgeInsets.symmetric(
                                                            vertical: adminFilterScrollOnly ? 2 : 4,
                                                            horizontal: adminFilterScrollOnly ? 6 : 10,
                                                          ),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          visualDensity: VisualDensity.compact,
                                                          minimumSize: Size(0, adminFilterScrollOnly ? 30 : 36),
                                                        ),
                                                        icon: Icon(Icons.check_circle, size: adminFilterScrollOnly ? 12 : 14),
                                                        label: Text(
                                                          'Confirmé ✓',
                                                          style: TextStyle(fontSize: adminFilterScrollOnly ? 9.5 : 11),
                                                        ),
                                                      )
                                                    : FilledButton.icon(
                                                        onPressed: () async {
                                                          // Vérifier la fenêtre de confirmation avant tout.
                                                          if (!confirmWindowOpen) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(confirmWindowHint ?? 'Fenêtre de confirmation non ouverte.'),
                                                                  backgroundColor: AppColors.brand,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                  duration: const Duration(seconds: 4),
                                                                ),
                                                              );
                                                            }
                                                            return;
                                                          }
                                                          if (!canConfirm) {
                                                            if (context.mounted) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(lockHint ?? 'Verrouillé'),
                                                                  backgroundColor: Colors.orange,
                                                                  behavior: SnackBarBehavior.fixed,
                                                                ),
                                                              );
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
                                                          final reasonConfigsList =
                                                              context.read<AbsenceReasonsProvider>().reasons;
                                                          final reasonConfigsForSnapshot =
                                                              reasonConfigsList.isEmpty ? null : reasonConfigsList;

                                                          // بناء قائمة snapshots لكل موظف في الفريق
                                                          final empSnapshots = teamWorkers.map((w) {
                                                            final rec = getRecord(w.id, equipeId: t.equipeId);
                                                            final status = PointageExportService.resolveSnapshotStatus(
                                                              rec: rec,
                                                              isGroupScope: isGroupScope,
                                                              isDistributionScope: isDistributionScope,
                                                              reasonConfigs: reasonConfigsForSnapshot,
                                                            );
                                                            final absenceReason =
                                                                status == 'absent' || status == 'paid_absence'
                                                                    ? rec?.absenceReason
                                                                    : null;
                                                            final workerRestDay = t.equipeId == horsEquipeVirtualId
                                                                ? (isHorsEquipeWeeklyRestDay(logicalDay) ||
                                                                    shiftsProvider.isPublicHoliday(logicalDay))
                                                                : isWeeklyRestForGroupe(t.equipeId, logicalDay);
                                                            return (
                                                              employeId: w.id,
                                                              employeNom: w.nom,
                                                              employeCin: w.cin ?? '',
                                                              status: status,
                                                              absenceReason: absenceReason,
                                                              isRestDay: workerRestDay,
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
                                                              : AppColors.brand,
                                                          padding: EdgeInsets.symmetric(
                                                            vertical: adminFilterScrollOnly ? 2 : 4,
                                                            horizontal: adminFilterScrollOnly ? 6 : 10,
                                                          ),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          visualDensity: VisualDensity.compact,
                                                          minimumSize: Size(0, adminFilterScrollOnly ? 30 : 36),
                                                        ),
                                                        icon: Icon(
                                                          !confirmWindowOpen ? Icons.schedule : Icons.check,
                                                          size: adminFilterScrollOnly ? 12 : 14,
                                                        ),
                                                        label: Text(
                                                          !confirmWindowOpen
                                                              ? (confirmWindowHint ?? 'Attendre ouverture')
                                                              : (isGroupScope || canConfirm)
                                                                  ? 'Confirmer'
                                                                  : 'Confirmer • ${lockHint ?? ''}',
                                                          style: TextStyle(fontSize: adminFilterScrollOnly ? 9.5 : 11),
                                                          maxLines: 1,
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
                      )),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildAdminMainContent(
                        context,
                        team: team,
                        workers: workers,
                        borderColor: borderColor,
                        pointageProvider: pointageProvider,
                        getRecord: getRecord,
                        teams: filteredTeams,
                        equipes: equipes,
                        adminLogicalDay: logicalDay,
                        nonWorkingIds: nonWorkingIdsEffective,
                        viewDate: logicalDay,
                        adminOverridePersistDate: isViewingToday ? null : logicalDay,
                        presentByChef: presentByChef,
                        absentByChef: absentByChef,
                        notInVehicleByChef: notInVehicleByChef,
                        notWorkingByChef: notWorkingByChef,
                        readOnly: adminReadOnly,
                      ),
                    ),
                    ],
                  );},
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
    if (mobile) {
      return SafeArea(
        bottom: false,
        child: content,
      );
    }
    return content;
  }

  Future<void> _showExcelExportDialog(
    BuildContext context,
    List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> teams,
    List<Equipe> equipes,
    List<Employe> employes,
    PointageProvider pointageProvider,
    {String? initialScope,
    String? initialEquipeId,
    bool forceSingleSheet = false,
    bool excludeDistribution = false,
    bool useOcpGrid = false,}
  ) async {
    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, 1);
    DateTime end = DateTime(now.year, now.month, now.day);
    if (!context.mounted) return;
    final authExport = context.read<AuthProvider>();
    final zoneDistIds = authExport.distributionGroupIds;
    final teamOptions = <({String id, String label})>[
      for (final eq in equipes)
        (id: eq.id, label: '${eq.nom} — ${getChefName(employes, eq.chefId)}'),
      for (final t in teams.where((t) => t.equipeId == 'hors_equipe'))
        (id: 'hors_equipe', label: '${t.equipeName} — ${t.chefName}'),
      for (final t in teams.where((t) => t.equipeId.startsWith('distribution:')))
        if (!excludeDistribution)
        if (!authExport.isChefZoneAdmin ||
            zoneDistIds.isEmpty ||
            zoneDistIds.contains(t.equipeId.substring('distribution:'.length)))
          (id: t.equipeId, label: t.equipeName),
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

    // بناء قائمة الموظفين أولاً حتى نتمكن من تمرير معرفاتهم عند جلب السجلات،
    // مما يضمن جلب سجلاتهم حتى لو لم يُسجَّل لهم أي بوانتاج في الفترة.
    final employees = <({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})>[];
    final distributionEmployees = <({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})>[];
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
          poste: w.poste,
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
          poste: w.poste,
          equipeName: '${t.equipeName} — ${t.chefName}',
          equipeId: horsEquipeVirtualId,
          salaireNet: w.salaireBase,
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
        ));
      }
    }
    final distGroupsForExport = context.read<DistributionGroupsProvider>().groups;
    final distributionMemberIdsByGroup = <String, Set<String>>{};
    for (final g in distGroupsForExport) {
      if (authExport.isChefZoneAdmin &&
          zoneDistIds.isNotEmpty &&
          !zoneDistIds.contains(g.id)) {
        continue;
      }
      final distEqId = 'distribution:${g.id}';
      final label = 'Distribution: ${g.nom}';
      final seenInThisGroup = <String>{};
      final memberIds = <String>{};
      for (final id in g.membreIds) {
        if (!seenInThisGroup.add(id)) continue;
        memberIds.add(id);
        final empList = employes.where((e) => e.id == id).toList();
        if (empList.isEmpty) continue;
        final w = empList.first;
        if (w.statut != EmployeStatut.enService) continue;
        distributionEmployees.add((
          id: w.id,
          cin: w.cin,
          nom: w.nom,
          poste: w.poste,
          equipeName: label,
          equipeId: distEqId,
          salaireNet: w.salaireBase,
        ));
      }
      distributionMemberIdsByGroup[distEqId] = memberIds;
    }
    final allById =
        <String, ({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})>{};
    for (final e in employees) {
      allById[e.id] = e;
    }
    // Si un employé appartient à un groupe Distribution, on privilégie son
    // rattachement Distribution dans l'export global pour un tri visuel correct.
    if (!excludeDistribution) {
      for (final e in distributionEmployees) {
        allById[e.id] = e;
      }
    }
    final allEmployees = allById.values.toList();

    List<({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})> filteredEmployees =
        List.of(allEmployees);
    switch (picked.scope) {
      case 'groupes':
        filteredEmployees = allEmployees
            .where((e) => (e.equipeId ?? '').startsWith('groupe:'))
            .toList();
        break;
      case 'normales':
        filteredEmployees = allEmployees
            .where((e) =>
                e.equipeId != null &&
                !(e.equipeId!).startsWith('groupe:') &&
                !(e.equipeId!).startsWith('distribution:'))
            .toList();
        break;
      case 'distribution':
        filteredEmployees =
            excludeDistribution ? <({String id, String cin, String nom, String poste, String equipeName, String? equipeId, double salaireNet})>[] : distributionEmployees;
        break;
      case 'equipe':
        final selectedId = picked.equipeId;
        if (selectedId != null && selectedId.isNotEmpty) {
          filteredEmployees = allEmployees.where((e) {
            if (selectedId == 'hors_equipe') return e.equipeId == null;
            return e.equipeId == selectedId;
          }).toList();
        }
        break;
      case 'all':
      default:
        break;
    }
    if (excludeDistribution) {
      bool hasDistributionKeyword(String value) {
        final v = value.trim().toLowerCase();
        return v.contains('distribution') || v.contains('distrib');
      }

      filteredEmployees = filteredEmployees
          .where((e) {
            final byEquipeId =
                e.equipeId == null || !(e.equipeId!).startsWith('distribution:');
            final byPoste = !hasDistributionKeyword(e.poste);
            final byEquipeName = !hasDistributionKeyword(e.equipeName);
            return byEquipeId && byPoste && byEquipeName;
          })
          .toList();
    }

    final reasonConfigs = context.read<AbsenceReasonsProvider>().reasons;
    final shiftsProvider = context.read<ShiftsProvider>();
    final distShiftsExport = context.read<DistributionShiftsProvider>();
    final weeklyRestByGroupeId = <String, int>{
      for (final g in groupes) g.id: g.weeklyRestWeekday,
    };
    bool isPublicHoliday(DateTime date) =>
        shiftsProvider.isPublicHoliday(date);

    bool isRestDay(DateTime date, String equipeId) {
      if (equipeId == horsEquipeVirtualId) {
        return isHorsEquipeWeeklyRestDay(date);
      }
      if (equipeId.startsWith('distribution:')) {
        final gid = equipeId.substring('distribution:'.length);
        if (distShiftsExport.hasRotationSlotForGroup(gid)) {
          return distShiftsExport.getShiftForGroup(gid, date) == ShiftType.rest;
        }
        return false;
      }
      if (equipeId.startsWith('groupe:')) {
        final gid = equipeId.substring('groupe:'.length);
        final weekday = weeklyRestByGroupeId[gid];
        return weekday != null && date.weekday == weekday;
      }
      final byShiftRest = shiftsProvider.hasConfig &&
          shiftsProvider.getShiftForEquipe(equipeId, date) == ShiftType.rest;
      return byShiftRest;
    }
    // جلب overtime_assignments للنطاق الزمني
    final overtimeProvider = context.read<OvertimeProvider>();
    final overtimeAssignments = await overtimeProvider.getForDateRange(start, end);

    // Export grille OCP : uniquement les employés avec un bloc OCP explicite (fiche employé).
    if (useOcpGrid) {
      final ocpSegmentByEmpId = {
        for (final e in employes) e.id: e.ocpExcelSegment.trim(),
      };
      filteredEmployees = filteredEmployees
          .where((e) => OcpExcelSegmentCode.hasExplicitPlacement(
                ocpSegmentByEmpId[e.id] ?? '',
              ))
          .toList();
    }

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

    final ocpExcelSegmentByEmployeId = <String, String>{
      for (final e in employes)
        if (OcpExcelSegmentCode.hasExplicitPlacement(e.ocpExcelSegment))
          e.id: e.ocpExcelSegment.trim(),
    };
    final ocpForceSalleControleByEmployeId = <String, bool>{
      for (final e in employes)
        if (e.ocpForceSalleControle) e.id: true,
    };

    final pointageRecordsForExport =
        await context.read<PointageProvider>().getPointageForDateRange(start, end);

    // دائماً نستخدم مسار snapshots — يضمن أن Excel يعكس فقط البيانات المؤكدة
    List<PointageExportRow> rows;
    rows = PointageExportService.computeExcelRowsFromSnapshots(
        startDate: start,
        endDate: end,
        employees: filteredEmployees,
      snapshots: snapshots.where((s) => filteredEmpIds.contains(s.employeId)).toList(),
        reasonConfigs: reasonConfigs.isEmpty ? null : reasonConfigs,
        isRestDay: isRestDay,
        isPublicHoliday: isPublicHoliday,
        overtimeAssignments: overtimeAssignments,
        ocpExcelSegmentByEmployeId:
            ocpExcelSegmentByEmployeId.isEmpty ? null : ocpExcelSegmentByEmployeId,
        ocpForceSalleControleByEmployeId:
            ocpForceSalleControleByEmployeId.isEmpty ? null : ocpForceSalleControleByEmployeId,
        pointageRecords: pointageRecordsForExport,
      );
    if (picked.scope == 'distribution' && distributionMemberIdsByGroup.isNotEmpty) {
      rows = rows
          .where((r) {
            final eqId = r.equipeId;
            if (eqId == null || !eqId.startsWith('distribution:')) return false;
            final allowed = distributionMemberIdsByGroup[eqId];
            return allowed != null && allowed.contains(r.employeId);
          })
          .toList();
    }

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
        useOcpGrid: useOcpGrid,
        singleSheet: forceSingleSheet,
        singleSheetName: 'Société',
        includeEquipeColumnInSingleSheet: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec export Excel: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.fixed,
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
      await _offerMobileShare(context, filePath, text: 'Export Excel pointage');
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

  Future<({String? equipeId, String equipeLabel})?> _showResetPointageDayDialog(
    BuildContext context,
    List<({String id, String label})> teamOptions,
    DateTime day,
  ) async {
    if (!context.mounted) return null;
    return showDialog<({String? equipeId, String equipeLabel})>(
      context: context,
      builder: (ctx) {
        bool resetAll = true;
        String? selectedId = teamOptions.isNotEmpty ? teamOptions.first.id : null;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Réinitialiser pointage (jour)'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${day.day}/${day.month}/${day.year}'),
                  const SizedBox(height: 10),
                  RadioListTile<bool>(
                    value: true,
                    groupValue: resetAll,
                    onChanged: (v) => setD(() => resetAll = v ?? true),
                    title: const Text('Tous les équipes'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: resetAll,
                    onChanged: (v) => setD(() => resetAll = v ?? true),
                    title: const Text('Équipe spécifique'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!resetAll) ...[
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      decoration: const InputDecoration(
                        labelText: 'Choisir l\'équipe',
                        border: OutlineInputBorder(),
                      ),
                      items: teamOptions
                          .map((t) => DropdownMenuItem<String>(
                                value: t.id,
                                child: Text(t.label, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setD(() => selectedId = v),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () {
                  if (!resetAll && (selectedId == null || selectedId!.isEmpty)) return;
                  if (resetAll) {
                    Navigator.pop(ctx, (equipeId: null, equipeLabel: 'Tous'));
                    return;
                  }
                  final selected = teamOptions.where((t) => t.id == selectedId).toList();
                  final label = selected.isNotEmpty ? selected.first.label : 'Équipe';
                  Navigator.pop(ctx, (equipeId: selectedId, equipeLabel: label));
                },
                child: const Text('Continuer'),
              ),
            ],
          ),
        );
      },
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
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
                    ),
                    const SizedBox(height: 8),
                    if (originShift != null && originShift != ShiftType.rest)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brandLight),
                        ),
                        child: Text(
                          'Shift actuel: ${originShift.shortLabel} (${originShift.timeRange}). '
                          'Même jour: seulement les shifts qui commencent après la fin (${originShiftEnd != null ? '${originShiftEnd.hour.toString().padLeft(2, '0')}:${originShiftEnd.minute.toString().padLeft(2, '0')}' : '--'}).',
                          style: TextStyle(fontSize: 12, color: AppColors.brandDark),
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
    required List<Equipe> equipes,
    required DateTime adminLogicalDay,
    /// `null` = journée courante (flux today) ; sinon enregistrement sur ce jour-là.
    required DateTime? adminOverridePersistDate,
    required bool readOnly,
    bool nestInParentScroll = false,
  }) {
    if (team == null) {
      return Center(child: Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    if (workers.isEmpty) {
      return Center(child: Text(tr(context, 'no_workers'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    final shiftsProv = context.watch<ShiftsProvider>();
    final authProv = context.watch<AuthProvider>();
    var nightContextForTeam = false;
    if (team.equipeId != 'hors_equipe' &&
        !team.equipeId.startsWith('groupe:') &&
        !_isDistributionEquipeId(team.equipeId)) {
      final cfgEq = equipes.where((e) => e.id == team.equipeId).toList();
      final equipeCfg = cfgEq.isNotEmpty ? cfgEq.first : null;
      final shift = equipeCfg == null ? null : shiftsProv.getShiftForEquipe(equipeCfg.id, adminLogicalDay);
      final cfg = getConfigForEquipeAndDate(equipeCfg, adminLogicalDay, shift);
      nightContextForTeam = cfg.isNightShift || shift == ShiftType.night;
    }
    final mobile = isMobile(context);
    final leaveRequestsProvider = context.watch<LeaveRequestsProvider>();
    bool hasApprovedLeaveOnDay(String employeId, DateTime day) {
      final target = DateTime(day.year, day.month, day.day);
      for (final req in leaveRequestsProvider.requests) {
        if (req.employeeId != employeId || req.status != LeaveStatus.approved) continue;
        final start = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
        final end = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
        if (!target.isBefore(start) && !target.isAfter(end)) return true;
      }
      return false;
    }
    final absenceReasonById = {
      for (final r in context.watch<AbsenceReasonsProvider>().reasons) r.id: r.label,
    };
    String? resolvedAbsenceMotif(PointageRecord? rec) {
      final raw = rec?.absenceReason?.trim();
      if (raw == null || raw.isEmpty) return null;
      return absenceReasonById[raw] ?? raw;
    }
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
        primary: false,
        shrinkWrap: nestInParentScroll,
        physics: nestInParentScroll ? const NeverScrollableScrollPhysics() : null,
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 12,
          mobile ? 14 : 12,
          mobile ? 14 : 12,
          nestInParentScroll ? (mobile ? 16 : 12) : (mobile ? 28 : 12),
        ),
        children: [
          Text('${tr(context, 'workers_of')} ${team.equipeName} (${team.chefName})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 16 : 15)),
          SizedBox(height: mobile ? 10 : 8),
          ...workers.map((e) {
            final record = getRecord(e.id);
            final reconciled = record?.reconciledStatus ?? ReconciledStatus.confirmedAbsent;
            final isPresent = record?.isFinalPresent ?? false;
            final adminStatus = record?.adminFinalStatus;
            final isAlreadyFormation =
                record?.adminFinalStatus == AttendanceStatus.training || record?.status == AttendanceStatus.training;
            final hasLeaveRequest = hasApprovedLeaveOnDay(e.id, adminLogicalDay);
            final isOnLeave = (record?.adminFinalStatus == AttendanceStatus.leave ||
                    record?.status == AttendanceStatus.leave) &&
                hasLeaveRequest;
            final isGroupScope = team.equipeId == 'hors_equipe' || team.equipeId.startsWith('groupe:');
            final isDistributionScope = _isDistributionEquipeId(team.equipeId);
            final canManualPointage =
                !readOnly && !isOnLeave && (isGroupScope || isDistributionScope || !isAlreadyFormation);
            final isMarkedPresent = adminStatus == AttendanceStatus.present;
            final isMarkedAbsent = adminStatus == AttendanceStatus.absent;
            final statusLabel = isOnLeave ? 'Congé' : (isPresent ? tr(context, 'present') : tr(context, 'absent'));
            final showAbsentMotifLine = !isOnLeave && !isPresent;
            final absentMotifResolved = showAbsentMotifLine ? resolvedAbsenceMotif(record) : null;
            final trainingStartAt = record?.trainingStartAt;
            final trainingEndAt = record?.trainingEndAt;
            final formationRangeLabel = (trainingStartAt != null && trainingEndAt != null)
                ? '${trainingStartAt.day.toString().padLeft(2, '0')}/${trainingStartAt.month.toString().padLeft(2, '0')}'
                    ' - '
                    '${trainingEndAt.day.toString().padLeft(2, '0')}/${trainingEndAt.month.toString().padLeft(2, '0')}'
                : null;
            final nightNote = record?.nightShiftSupervisorNote?.trim();
            final showNightChefNoteBanner = nightContextForTeam &&
                _maySeeNightShiftSupervisorNote(authProv) &&
                nightNote != null &&
                nightNote.isNotEmpty;
            return Card(
              margin: EdgeInsets.only(bottom: mobile ? 10 : 8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 12, vertical: mobile ? 12 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    if (!isGroupScope && !isDistributionScope)
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _DriverChefBadge(label: 'T', value: record?.driverStatus, isDriver: true),
                                          _DriverChefBadge(label: 'C', value: record?.chefStatus, isDriver: false),
                                          _ReconciledChip(status: reconciled),
                                        ],
                                      ),
                                    if (!isGroupScope && isDistributionScope)
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _DriverChefBadge(label: 'C', value: record?.chefStatus, isDriver: false),
                                          _ReconciledChip(status: reconciled),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOnLeave ? const Color(0xFF00044D) : isPresent ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          if (showAbsentMotifLine) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Motif : ${absentMotifResolved ?? 'Non renseigné'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: absentMotifResolved != null ? Colors.red.shade900 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            'Entrée: ${record?.arrivalMarkedAt != null ? 'OK' : '--'} | Sortie: ${record != null && (record.departureStatus == DepartureStatus.finished || record.departureStatus == DepartureStatus.stillWorking) ? 'OK' : '--'}',
                            style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                          ),
                          if (!isGroupScope && isAlreadyFormation && formationRangeLabel != null) ...[
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              children: [
                                Text(
                                  'Formation',
                                  style: TextStyle(fontSize: 10, color: AppColors.brand, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  formationRangeLabel,
                                  style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                          if (!isGroupScope && isOnLeave) ...[
                            const SizedBox(height: 2),
                            const Text(
                              'Congé approuvé',
                              style: TextStyle(fontSize: 10, color: Color(0xFF00044D), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      )
                    else
                      Row(
                        children: [
                          SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 4),
                                if (!isGroupScope && !isDistributionScope)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _DriverChefBadge(label: 'T', value: record?.driverStatus, isDriver: true),
                                      _DriverChefBadge(label: 'C', value: record?.chefStatus, isDriver: false),
                                      _ReconciledChip(status: reconciled),
                                    ],
                                  ),
                                if (!isGroupScope && isDistributionScope)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      _DriverChefBadge(label: 'C', value: record?.chefStatus, isDriver: false),
                                      _ReconciledChip(status: reconciled),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOnLeave ? const Color(0xFF00044D) : isPresent ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              if (showAbsentMotifLine) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Motif : ${absentMotifResolved ?? 'Non renseigné'}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: absentMotifResolved != null ? Colors.red.shade900 : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'Entrée: ${record?.arrivalMarkedAt != null ? 'OK' : '--'} | Sortie: ${record != null && (record.departureStatus == DepartureStatus.finished || record.departureStatus == DepartureStatus.stillWorking) ? 'OK' : '--'}',
                                style: TextStyle(fontSize: 9, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                              ),
                              if (!isGroupScope && isAlreadyFormation && formationRangeLabel != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Formation',
                                      style: TextStyle(fontSize: 9, color: AppColors.brand, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formationRangeLabel,
                                      style: TextStyle(fontSize: 9, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                              if (!isGroupScope && isOnLeave) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'Congé approuvé',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF00044D), fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    if (showNightChefNoteBanner) ...[
                      SizedBox(height: mobile ? 8 : 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade700),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.nightlight_round, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nuit (remarque chef) : $nightNote',
                                style: TextStyle(
                                  fontSize: mobile ? 11 : 10,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: mobile ? 8 : 6),
                    if (canManualPointage)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (!isMarkedPresent && !isMarkedAbsent) ...[
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
                                      viewDate: adminOverridePersistDate,
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
                            ] else if (isMarkedPresent) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 8 : 6),
                                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text(tr(context, 'present'), style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.green.shade800)),
                              ),
                              SizedBox(width: mobile ? 8 : 6),
                              TextButton(
                                onPressed: () async {
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
                                child: const Text('Changer -> Absent'),
                              ),
                            ] else ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 8, vertical: mobile ? 8 : 6),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                                alignment: Alignment.center,
                                child: Text(tr(context, 'absent'), style: TextStyle(fontSize: mobile ? 12 : 11, color: Colors.red.shade800)),
                              ),
                              SizedBox(width: mobile ? 8 : 6),
                              TextButton(
                                onPressed: () async {
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
                                      viewDate: adminOverridePersistDate,
                                    );
                                  }
                                  if (mounted) setState(() {});
                                },
                                child: const Text('Changer -> Présent'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (readOnly)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            team.equipeId == 'hors_equipe'
                                ? 'Lecture seule : le pointage « hors équipe » est réservé au Chef de zone et à l’admin RH.'
                                : 'Mode lecture seule: consultation uniquement (Admin/RH).',
                            style: TextStyle(
                              fontSize: mobile ? 11 : 10,
                              color: Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (isOnLeave || (!isGroupScope && isAlreadyFormation))
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
                    isMobile(context)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Column(
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
                              const SizedBox(height: 8),
                              Column(
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
                            ],
                          )
                        : Row(
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
    required List<Equipe> equipes,
    required DateTime adminLogicalDay,
    required List<String> nonWorkingIds,
    required DateTime viewDate,
    required Map<String, List<Employe>> presentByChef,
    required Map<String, List<Employe>> absentByChef,
    required Map<String, List<Employe>> notInVehicleByChef,
    required Map<String, List<Employe>> notWorkingByChef,
    required DateTime? adminOverridePersistDate,
    required bool readOnly,
    bool nestInParentScroll = false,
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
          equipes: equipes,
          adminLogicalDay: adminLogicalDay,
          adminOverridePersistDate: adminOverridePersistDate,
          readOnly: readOnly,
          nestInParentScroll: nestInParentScroll,
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
        final backBar = Material(
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
        );
        final analysisBody = _PointageAnalysisSection(
          teams: teams,
          nonWorkingIds: nonWorkingIds,
          getRecord: getRecord,
          viewDate: viewDate,
          nestInOuterScroll: nestInParentScroll,
        );
        if (nestInParentScroll) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              backBar,
              analysisBody,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            backBar,
            Expanded(child: analysisBody),
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
    if (pointageProvider.ignoreTimeWindowsForTest && !pointageProvider.hasActiveTestCycle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PointageProvider>().startTestCycle(arrivalMinutes: 5);
      });
    }
    final equipeIdForLock = auth.equipeId ?? '';
    final nowDay = DateTime.now();
    final dayKey = '${nowDay.year}-${nowDay.month}-${nowDay.day}';
    final departureLockKey = '${equipeIdForLock}_$dayKey';
    final departureReportLocked = _chefDepartureReportLocks.contains(departureLockKey);
    final chefReportLockedForAll =
        departureReportLocked ||
        pointageProvider.chefReportSyncPending ||
        (equipeIdForLock.isNotEmpty &&
            pointageProvider.hasEquipeDailyReportSubmittedToday(equipeIdForLock)) ||
        (workersDisplay.isNotEmpty &&
            workersDisplay.every((w) => pointageProvider.isChefLockedForEmployee(w.id)));
    final overtimeWorkers = workersDisplay.where((w) => overtimeWorkerIds.contains(w.id)).toList();
    final regularWorkers = workersDisplay.where((w) => !overtimeWorkerIds.contains(w.id)).toList();
    final workersInTraining = workers.where((e) => pointageProvider.getRecordForEmployee(e.id)?.adminFinalStatus == AttendanceStatus.training).toList();
    AttendanceState getState(String id) {
      final drafted = _chefDraftStatus[id];
      if (drafted != null) return _chefStatusToState(drafted);
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
      final unmarkedWorkers = workersDisplay
          .where((w) => getState(w.id) == AttendanceState.unmarked)
          .toList();
      if (unmarkedWorkers.isNotEmpty) {
        if (context.mounted) {
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
                      '${unmarkedWorkers.length} personne(s) sans pointage:',
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
        return;
      }

      final equipe = equipes.where((e) => e.id == equipeId).toList();
      final equipeName = equipe.isNotEmpty ? equipe.first.nom : '';
      final nowRef = DateTime.now();
      final logicalToday = DateTime(nowRef.year, nowRef.month, nowRef.day);
      final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
      final shiftToday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalToday) : null;
      final shiftYesterday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalYesterday) : null;
      final useYesterdayNight = nowRef.hour < 7 && shiftYesterday == ShiftType.night;
      final shiftForEquipe = useYesterdayNight ? shiftYesterday : shiftToday;
      final configDay = useYesterdayNight ? logicalYesterday : logicalToday;
      final pointageConfig = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, configDay, shiftForEquipe);
      final nowForDep = DateTime.now();
      final inTestCycleNow = pointageProvider.ignoreTimeWindowsForTest && pointageProvider.hasActiveTestCycle;
      final inDepartureWindow = inTestCycleNow
          ? pointageProvider.isInTestDeparturePhase
          : (bypassPointageHours || pointageConfig.canMarkDepartureNow(nowForDep));
      final lockAfterSend = inDepartureWindow ? departureReportLocked : chefReportLockedForAll;

      // Statuts de sortie pour les présents (fin shift / avant fin / en attente)
      int departureFinishedCount = 0;
      int departureStillWorkingCount = 0;
      int departurePendingCount = 0;
      for (final w in workersDisplay) {
        final r = pointageProvider.getRecordForEmployee(w.id);
        final isPresent = (r?.isFinalPresent ?? false) || getState(w.id) == AttendanceState.present;
        if (!isPresent) continue;
        final dep = _chefDraftDeparture[w.id] ?? (r?.departureStatus ?? DepartureStatus.unset);
        if (dep == DepartureStatus.finished) {
          departureFinishedCount++;
        } else if (dep == DepartureStatus.stillWorking) {
          departureStillWorkingCount++;
        } else {
          departurePendingCount++;
        }
      }

      // Bloquer l'envoi si on est dans la fenêtre de départ et des présents n'ont pas confirmé leur sortie
      if (inDepartureWindow && departurePendingCount > 0) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Sortie non confirmée')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.orange.shade700, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          '$departurePendingCount',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.orange.shade800),
                        ),
                        Text(
                          departurePendingCount == 1
                              ? 'travailleur sans confirmation de sortie'
                              : 'travailleurs sans confirmation de sortie',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Veuillez confirmer la sortie de tous les travailleurs présents (Fin du travail ou N\'a pas terminé) avant d\'envoyer le rapport.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
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
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.send_rounded, color: AppColors.brand, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(tr(ctx, 'pointage_confirm_send_title'))),
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
              // Fenêtre arrivée : Présents / Absents. Fenêtre départ : fin shift / avant fin (+ note absents).
              if (inDepartureWindow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                                Icon(Icons.task_alt_rounded, color: Colors.green.shade600, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  '$departureFinishedCount',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.green.shade700),
                                ),
                                Text(
                                  tr(ctx, 'departure_finished'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(ctx, 'pointage_chef_card_shift_complete'),
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.schedule_rounded, color: Colors.orange.shade700, size: 28),
                                const SizedBox(height: 6),
                                Text(
                                  '$departureStillWorkingCount',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.orange.shade800),
                                ),
                                Text(
                                  tr(ctx, 'pointage_chef_not_finished_title'),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tr(ctx, 'pointage_chef_card_shift_early'),
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (absentCount > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        tr(ctx, 'pointage_chef_absents_note').replaceFirst('%s', '$absentCount'),
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                )
              else
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
                            Text(tr(ctx, 'report_presents'), style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
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
                            Text(tr(ctx, 'report_absents'), style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
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
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brandLight),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(ctx, 'pointage_confirm_send_message'),
                        style: TextStyle(fontSize: 12, color: AppColors.brandDark),
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
              icon: const Icon(Icons.send_rounded, size: 16),
              label: Text(tr(ctx, 'report_send')),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;

      var nightShiftSupervisorNotes = <String, String>{};
      final isNightChefReport = pointageConfig.isNightShift && shiftForEquipe == ShiftType.night;
      if (isNightChefReport && context.mounted) {
        final presentForNotes =
            workersDisplay.where((w) => getState(w.id) == AttendanceState.present).toList();
        if (presentForNotes.isNotEmpty) {
          final notes = await showDialog<Map<String, String>>(
            context: context,
            builder: (ctx) => _NightShiftChefNotesDialog(workers: presentForNotes),
          );
          nightShiftSupervisorNotes = notes ?? const {};
        }
      }

      // Immediate lock in UI (no wait for network).
      if (inDepartureWindow) {
        setState(() => _chefDepartureReportLocks.add(departureLockKey));
      }
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

      // Flush local drafts to Firestore right before final submit.
      for (final w in workersDisplay) {
        final drafted = _chefDraftStatus[w.id];
        if (drafted != null) {
          await pointageProvider.markChefAttendance(
            employeId: w.id,
            employeNom: w.nom,
            employeCin: w.cin,
            equipeId: auth.equipeId ?? '',
            equipeName: equipeName,
            chefName: auth.currentUser?.nom ?? '',
            chefStatus: drafted,
            chefId: auth.currentUser?.id,
            absenceReason: drafted == ChefPointageStatus.absent ? _chefDraftAbsenceReason[w.id] : null,
            configOverride: pointageConfig,
            bypassTimeWindows: true,
          );
        }
        final dep = _chefDraftDeparture[w.id];
        if (dep != null && dep != DepartureStatus.unset) {
          final r = pointageProvider.getRecordForEmployee(w.id);
          if (r != null) {
            await pointageProvider.setDepartureStatus(
              record: r,
              status: dep,
              overtimeMinutes: _chefDraftOvertimeMinutes[w.id],
              workedMinutesBeforeStop: _chefDraftWorkedMinutes[w.id],
              incompleteShiftReason: _chefDraftIncompleteReason[w.id],
              configOverride: pointageConfig,
              bypassTimeWindows: true,
            );
          }
        }
      }
      _chefDraftStatus.clear();
      _chefDraftAbsenceReason.clear();
      _chefDraftDeparture.clear();
      _chefDraftOvertimeMinutes.clear();
      _chefDraftWorkedMinutes.clear();
      _chefDraftIncompleteReason.clear();
      unawaited(() async {
        final accepted = await pointageProvider.submitChefReportWithRetry(
          workersDisplay: workersDisplay,
          overtimeWorkerIds: overtimeWorkerIds,
          equipeId: equipeId,
          equipeName: equipeName,
          chefName: auth.currentUser?.nom ?? '',
          chefId: auth.currentUser?.id,
          configOverride: pointageConfig,
          bypassTimeWindows: bypassPointageHours,
          totalEmployees: workersDisplay.length,
          presentCount: presentCount,
          absentCount: absentCount,
          nightShiftSupervisorNotes:
              nightShiftSupervisorNotes.isEmpty ? null : nightShiftSupervisorNotes,
        );
        if (!context.mounted) return;
        if (!accepted) {
          pointageProvider.rollbackOptimisticChefReportLock();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                trOf(
                  context,
                  pointageProvider.firebaseAvailable
                      ? 'pointage_hours_cannot_mark'
                      : 'pointage_firebase_unavailable',
                ),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.fixed,
            ),
          );
          return;
        }
        final sortieOk = workersDisplay.where((w) {
          final r = pointageProvider.getRecordForEmployee(w.id);
          if (getState(w.id) != AttendanceState.present) return false;
          final dep = _chefDraftDeparture[w.id] ?? (r?.departureStatus ?? DepartureStatus.unset);
          return dep == DepartureStatus.finished;
        }).length;
        final sortieNotConfirmed = workersDisplay.where((w) {
          final r = pointageProvider.getRecordForEmployee(w.id);
          if (getState(w.id) != AttendanceState.present) return false;
          final dep = _chefDraftDeparture[w.id] ?? (r?.departureStatus ?? DepartureStatus.unset);
          return dep != DepartureStatus.finished;
        }).length;
        final successMsg = inDepartureWindow
            ? '$reportSentMsgChef — Sortie OK: $sortieOk | Non confirmée: $sortieNotConfirmed'
            : '$reportSentMsgChef — Présents: $presentCount | Absents: $absentCount';
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }());
    }

    final padding = pagePadding(context);
    final logicalToday = DateTime(now.year, now.month, now.day);
    final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
    final shiftToday = chefEquipe != null ? shiftsProvider.getShiftForEquipe(chefEquipe.id, logicalToday) : null;
    final shiftYesterday = chefEquipe != null ? shiftsProvider.getShiftForEquipe(chefEquipe.id, logicalYesterday) : null;
    final useYesterdayNight = now.hour < 7 && shiftYesterday == ShiftType.night;
    final shiftForChef = useYesterdayNight ? shiftYesterday : shiftToday;
    final configDay = useYesterdayNight ? logicalYesterday : logicalToday;
    final config = getConfigForEquipeAndDate(chefEquipe, configDay, shiftForChef);
    final inTestCycle = pointageProvider.ignoreTimeWindowsForTest && pointageProvider.hasActiveTestCycle;
    final hoursStatus = (bypassPointageHours || inTestCycle)
        ? PointageHoursStatus.open
        : getPointageHoursStatus(now, config);
    final isWithinArrival = inTestCycle
        ? pointageProvider.isInTestArrivalPhase
        : (bypassPointageHours || config.canMarkArrivalNow(now));
    final isWithinDeparture = inTestCycle
        ? pointageProvider.isInTestDeparturePhase
        : (bypassPointageHours || config.canMarkDepartureNow(now));
    final lockAfterSendUi = isWithinDeparture ? departureReportLocked : chefReportLockedForAll;
    final mobile = isMobile(context);

    final chefBannerPresent = workersDisplay.where((w) => getState(w.id) == AttendanceState.present).length;
    final chefBannerAbsent = workersDisplay.where((w) => getState(w.id) == AttendanceState.absent).length;
    final chefBannerDepFinished = workersDisplay.where((w) {
      if (getState(w.id) != AttendanceState.present) {
        return false;
      }
      final dep = _chefDraftDeparture[w.id] ??
          (pointageProvider.getRecordForEmployee(w.id)?.departureStatus ?? DepartureStatus.unset);
      return dep == DepartureStatus.finished;
    }).length;
    final chefBannerDepStill = workersDisplay.where((w) {
      if (getState(w.id) != AttendanceState.present) {
        return false;
      }
      final dep = _chefDraftDeparture[w.id] ??
          (pointageProvider.getRecordForEmployee(w.id)?.departureStatus ?? DepartureStatus.unset);
      return dep == DepartureStatus.stillWorking;
    }).length;

    final nonWorkingIds = pointageProvider.nonWorkingEquipeIds;
    final leaveRequestsProvider = context.watch<LeaveRequestsProvider>();
    bool hasApprovedLeaveOnConfigDay(String employeId) {
      final target = DateTime(configDay.year, configDay.month, configDay.day);
      for (final req in leaveRequestsProvider.requests) {
        if (req.employeeId != employeId || req.status != LeaveStatus.approved) continue;
        final start = DateTime(req.startDate.year, req.startDate.month, req.startDate.day);
        final end = DateTime(req.endDate.year, req.endDate.month, req.endDate.day);
        if (!target.isBefore(start) && !target.isAfter(end)) return true;
      }
      return false;
    }

    void showChefPointageFailSnack() {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trOf(
              context,
              pointageProvider.firebaseAvailable ? 'pointage_hours_cannot_mark' : 'pointage_firebase_unavailable',
            ),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }

    Widget buildWorkerCard(Employe e) {
      final isOvertimeWorker = overtimeWorkerIds.contains(e.id);
      final record = pointageProvider.getRecordForEmployee(e.id);
      final isInTraining = record?.adminFinalStatus == AttendanceStatus.training;
      final isOnLeave =
          record?.adminFinalStatus == AttendanceStatus.leave && hasApprovedLeaveOnConfigDay(e.id);

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
                      Icon(Icons.beach_access, size: 16, color: const Color(0xFF00044D)),
                      SizedBox(width: 6),
                      Text('Congé approuvé', style: TextStyle(fontSize: mobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF00044D))),
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
      final rawLocked = pointageProvider.isChefLockedForEmployee(e.id);
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
      final draftDep = _chefDraftDeparture[e.id];
      final recordForUi = draftDep == null
          ? recordOrPlaceholder
          : recordOrPlaceholder.copyWith(
              departureStatus: draftDep,
              overtimeMinutes: _chefDraftOvertimeMinutes[e.id] ?? recordOrPlaceholder.overtimeMinutes,
              workedMinutesBeforeStop: _chefDraftWorkedMinutes[e.id] ?? recordOrPlaceholder.workedMinutesBeforeStop,
              incompleteShiftReason: _chefDraftIncompleteReason[e.id] ?? recordOrPlaceholder.incompleteShiftReason,
            );
      // Phase départ : afficher les chips sortie ; éditable seulement si pas verrouillé après envoi.
      final isWorkerPresent = getState(e.id) == AttendanceState.present;
      final locked = (isWithinDeparture && isWorkerPresent && !lockAfterSendUi)
          ? false
          : (rawLocked || lockAfterSendUi);
      final canMarkArrival = !locked && isWithinArrival;
      final inDeparturePhaseUi = isWithinDeparture && isWorkerPresent;
      final showDepartureChips = inDeparturePhaseUi;
      final showArrivalChips = !isWithinDeparture && !showDepartureChips;
      final departureEditable = !locked && isWithinDeparture;
      final chefChips = showArrivalChips ? _wrapIfDisabled(
        disabled: !canMarkArrival,
        child: ChefStatusChips(
          current: getState(e.id),
          onSelect: canMarkArrival ? (s) async {
            String? absenceReason = _chefDraftAbsenceReason[e.id];
            if (s == AttendanceState.absent) {
              final reasonId = await _showAbsenceReasonDialog(context);
              if (reasonId == null || !context.mounted) return;
              absenceReason = reasonId;
            }
            final nextStatus = _stateToChefStatus(s);
            setState(() {
              _chefDraftStatus[e.id] = nextStatus;
              if (nextStatus == ChefPointageStatus.absent) {
                _chefDraftAbsenceReason[e.id] = absenceReason;
              } else {
                _chefDraftAbsenceReason.remove(e.id);
              }
            });
          } : (_) {},
          presentLabel: tr(context, 'present'),
          absentLabel: tr(context, 'absent'),
        ),
      ) : null;
      final departureChips = showDepartureChips
          ? _DepartureChips(
              record: recordForUi,
              config: config,
              onStillWorking: (int? workedMinutesBeforeStop, String? incompleteShiftReason) async {
                setState(() {
                  _chefDraftDeparture[e.id] = DepartureStatus.stillWorking;
                  _chefDraftWorkedMinutes[e.id] = workedMinutesBeforeStop;
                  _chefDraftIncompleteReason[e.id] = incompleteShiftReason;
                });
              },
              onFinished: (int? overtimeMinutes) async {
                setState(() {
                  _chefDraftDeparture[e.id] = DepartureStatus.finished;
                  _chefDraftOvertimeMinutes[e.id] = overtimeMinutes;
                  _chefDraftWorkedMinutes.remove(e.id);
                  _chefDraftIncompleteReason.remove(e.id);
                });
              },
              onCancel: () async {
                setState(() {
                  _chefDraftDeparture[e.id] = DepartureStatus.unset;
                  _chefDraftOvertimeMinutes.remove(e.id);
                  _chefDraftWorkedMinutes.remove(e.id);
                  _chefDraftIncompleteReason.remove(e.id);
                });
              },
              stillLabel: 'N\'a pas terminé',
              finishedLabel: tr(context, 'departure_finished'),
              overtimeLabel: tr(context, 'overtime_minutes'),
              overtimeHint: tr(context, 'overtime_minutes_hint'),
              finishWithoutOvertimeDialog: true,
              enabled: departureEditable,
            )
          : null;

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
          if (recordForUi.departureStatus != DepartureStatus.unset && recordForUi.overtimeMinutes != null && recordForUi.overtimeMinutes! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${tr(context, 'pointage_analysis_overtime_h')}: ${(recordForUi.overtimeMinutes! / 60).toStringAsFixed(1).replaceAll('.', ',')}',
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
                        if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (chefChips != null) chefChips,
                        if (departureChips != null) departureChips,
                      ],
                    ),
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
                    const SizedBox(width: 8),
                    if (chefChips != null) chefChips,
                    if (departureChips != null) departureChips,
                  ],
                ),
        ),
      );
    }

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
                    onPressed: (lockAfterSendUi || !isWithinArrival) ? null : () async {
                      final equipeId = auth.equipeId ?? '';
                      final equipe = equipes.where((e) => e.id == equipeId).toList();
                      final equipeName = equipe.isNotEmpty ? equipe.first.nom : '';
                      final nowRef = DateTime.now();
                      final logicalToday = DateTime(nowRef.year, nowRef.month, nowRef.day);
                      final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
                      final shiftToday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalToday) : null;
                      final shiftYesterday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalYesterday) : null;
                      final useYesterdayNight = nowRef.hour < 7 && shiftYesterday == ShiftType.night;
                      final shiftForEquipe = useYesterdayNight ? shiftYesterday : shiftToday;
                      final configDay = useYesterdayNight ? logicalYesterday : logicalToday;
                      final cfg = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, configDay, shiftForEquipe);
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
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Confirmer sortie de tous', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      side: BorderSide(color: AppColors.brand),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: (!isWithinDeparture || lockAfterSendUi || pointageProvider.chefReportSyncPending) ? null : () async {
                      final equipe = equipes.where((e) => e.id == auth.equipeId).toList();
                      final nowRef = DateTime.now();
                      final logicalToday = DateTime(nowRef.year, nowRef.month, nowRef.day);
                      final logicalYesterday = logicalToday.subtract(const Duration(days: 1));
                      final shiftToday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalToday) : null;
                      final shiftYesterday = equipe.isNotEmpty ? shiftsProvider.getShiftForEquipe(equipe.first.id, logicalYesterday) : null;
                      final useYesterdayNight = nowRef.hour < 7 && shiftYesterday == ShiftType.night;
                      final shiftForEquipe = useYesterdayNight ? shiftYesterday : shiftToday;
                      final configDay = useYesterdayNight ? logicalYesterday : logicalToday;
                      final cfg = getConfigForEquipeAndDate(equipe.isEmpty ? null : equipe.first, configDay, shiftForEquipe);
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
                          bypassTimeWindows: bypassPointageHours,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sortie de tous les membres présents confirmée'),
                            backgroundColor: AppColors.brand,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: lockAfterSendUi
                  ? _ReportSentBanner(
                      departurePhase: isWithinDeparture,
                      presentCount: chefBannerPresent,
                      absentCount: chefBannerAbsent,
                      finishedDepartureCount: chefBannerDepFinished,
                      stillWorkingDepartureCount: chefBannerDepStill,
                    )
                  : PrimaryButton(
                      label: tr(context, 'send_report_btn'),
                      onTap: (lockAfterSendUi || pointageProvider.chefReportSyncPending) ? null : sendReport,
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
                  await _offerMobileShare(context, filePath, text: 'Rapport pointage');
                }
              },
              icon: const Icon(Icons.download, size: 20),
              label: Text(tr(context, 'pointage_download_report')),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: lockAfterSendUi
                  ? _ReportSentBanner(
                      departurePhase: isWithinDeparture,
                      presentCount: chefBannerPresent,
                      absentCount: chefBannerAbsent,
                      finishedDepartureCount: chefBannerDepFinished,
                      stillWorkingDepartureCount: chefBannerDepStill,
                    )
                  : PrimaryButton(
                label: tr(context, 'send_report_btn'),
                      onTap: (lockAfterSendUi || pointageProvider.chefReportSyncPending) ? null : sendReport,
              ),
            ),
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
                await _offerMobileShare(context, filePath, text: 'Rapport pointage');
              }
            },
            icon: const Icon(Icons.download, size: 20),
            label: Text(tr(context, 'pointage_download_report')),
          ),
          SizedBox(height: mobile ? 16 : 24),
          SizedBox(
            height: mobile ? 48 : 52,
            width: double.infinity,
            child: lockAfterSendUi
                ? _ReportSentBanner(
                    departurePhase: isWithinDeparture,
                    presentCount: chefBannerPresent,
                    absentCount: chefBannerAbsent,
                    finishedDepartureCount: chefBannerDepFinished,
                    stillWorkingDepartureCount: chefBannerDepStill,
                  )
                : PrimaryButton(
              label: tr(context, 'send_report_btn'),
                    onTap: (lockAfterSendUi || pointageProvider.chefReportSyncPending) ? null : sendReport,
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

class _NightShiftChefNotesDialog extends StatefulWidget {
  final List<Employe> workers;

  const _NightShiftChefNotesDialog({required this.workers});

  @override
  State<_NightShiftChefNotesDialog> createState() => _NightShiftChefNotesDialogState();
}

class _NightShiftChefNotesDialogState extends State<_NightShiftChefNotesDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {for (final w in widget.workers) w.id: TextEditingController()};
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collect() {
    final out = <String, String>{};
    for (final e in _controllers.entries) {
      final t = e.value.text.trim();
      if (t.isNotEmpty) out[e.key] = t;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.nightlight_round, color: Colors.indigo.shade700),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Remarques équipe de nuit',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Optionnel : départ anticipé, incident, etc. Visible pour l\'administration (22h–6h).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              ...widget.workers.map((w) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _controllers[w.id],
                        maxLines: 2,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Remarque…',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, <String, String>{}),
          child: const Text('Ignorer'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _collect()),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

/// Bannière affichée à la place du bouton "Envoyer rapport" une fois le rapport verrouillé/envoyé.
class _ReportSentBanner extends StatelessWidget {
  /// Si true (créneau départ) : affiche les compteurs de sortie. Sinon : Présents / Absents (arrivée).
  final bool departurePhase;
  final int presentCount;
  final int absentCount;
  final int finishedDepartureCount;
  final int stillWorkingDepartureCount;

  const _ReportSentBanner({
    required this.departurePhase,
    required this.presentCount,
    required this.absentCount,
    required this.finishedDepartureCount,
    required this.stillWorkingDepartureCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade600,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Rapport envoyé ✓',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: departurePhase
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.task_alt_rounded, size: 14, color: Colors.greenAccent.shade100),
                            const SizedBox(width: 4),
                            Text('$finishedDepartureCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              tr(context, 'pointage_chef_card_shift_complete'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: Colors.orange.shade100),
                            const SizedBox(width: 4),
                            Text('$stillWorkingDepartureCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            const SizedBox(width: 2),
                            Text(
                              tr(context, 'pointage_chef_card_shift_early'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
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
          ),
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
  final VoidCallback? onCancel;
  final String stillLabel;
  final String finishedLabel;
  final String overtimeLabel;
  final String overtimeHint;
  /// Si true, "Fin du travail" enregistre directement sans dialogue (0 = 8h normales).
  final bool finishWithoutOvertimeDialog;
  /// Après envoi du rapport chef : lecture seule.
  final bool enabled;

  const _DepartureChips({
    required this.record,
    required this.config,
    required this.onStillWorking,
    required this.onFinished,
    this.onCancel,
    required this.stillLabel,
    required this.finishedLabel,
    required this.overtimeLabel,
    required this.overtimeHint,
    this.finishWithoutOvertimeDialog = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isStill = record.departureStatus == DepartureStatus.stillWorking;
    final isFinished = record.departureStatus == DepartureStatus.finished;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // ── N'a pas terminé ──────────────────────────────────────────────
        FilterChip(
          label: Text(stillLabel, style: const TextStyle(fontSize: 12)),
          selected: isStill,
          selectedColor: Colors.orange.shade100,
          checkmarkColor: Colors.orange.shade800,
          onSelected: !enabled
              ? null
              : (_) async {
            // Re-appui → annulation
            if (isStill) {
              onCancel?.call();
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
        // ── Fin du travail ───────────────────────────────────────────────
        FilterChip(
          label: Text(finishedLabel, style: const TextStyle(fontSize: 12)),
          selected: isFinished,
          selectedColor: Colors.green.shade100,
          checkmarkColor: Colors.green.shade800,
          onSelected: !enabled
              ? null
              : (_) async {
            // Re-appui → annulation
            if (isFinished) {
              onCancel?.call();
              return;
            }
            if (finishWithoutOvertimeDialog) {
              onFinished(null);
              return;
            }
            final controller = TextEditingController();
            final minutes = await showDialog<int?>(
              context: context,
              builder: (ctx) => AlertDialog(
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
                  FilledButton(
                      onPressed: () {
                        final v = int.tryParse(controller.text.trim());
                        Navigator.pop(ctx, v != null && v > 0 ? v : null);
                      },
                      child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                    ),
                  ],
              ),
            );
            onFinished(minutes);
          },
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
  /// When true, content is a single [Column] for embedding in a parent [CustomScrollView].
  final bool nestInOuterScroll;

  const _PointageAnalysisSection({
    required this.teams,
    required this.nonWorkingIds,
    required this.getRecord,
    required this.viewDate,
    this.showHeader = true,
    this.nestInOuterScroll = false,
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
    return m == 0 ? '$h h' : '$h h $m min';
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
      final emptyChildren = <Widget>[
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
      ];
      if (widget.nestInOuterScroll) {
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: emptyChildren,
          ),
        );
      }
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: emptyChildren,
        ),
      );
    }

    if (_loadingRange) {
      final loadingTop = Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showHeader) ...[
              Text('Analyse présence', style: TextStyle(fontSize: mobile ? 15 : 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            periodSelector,
            customDateRow,
          ],
        ),
      );
      if (widget.nestInOuterScroll) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            loadingTop,
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 24),
          ],
        );
      }
      return Column(
        children: [
          loadingTop,
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
                        _analysisRow(context, workedLabel, _minToHStr(workedMin), AppColors.brand),
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
                    _cell(_minToHStr(workedMin), color: AppColors.brand),
                    _cell(overtimeMin > 0 ? _minToHStr(overtimeMin) : notRecorded, color: overtimeMin > 0 ? Colors.orange : null),
                    _cell(_minToHStr(workedMin + overtimeMin), color: primary, bold: true),
                  ]);
                }),
                TableRow(
                  decoration: BoxDecoration(color: primary.withValues(alpha: 0.07)),
                  children: [
                    _cell('Total équipe', bold: true),
                    _cell(_minToHStr(teamWorked), color: AppColors.brand, bold: true),
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

    final mainColumnChildren = <Widget>[
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
    ];
    if (widget.nestInOuterScroll) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: mainColumnChildren,
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mainColumnChildren,
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
  final bool nestInOuterScroll;

  const _FormationManagementPage({
    required this.teams,
    required this.pointageProvider,
    required this.employes,
    this.nestInOuterScroll = false,
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
          backgroundColor: AppColors.brand,
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

    final body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Titre ───────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.school, color: AppColors.brand, size: 22),
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
                                    style: TextStyle(fontSize: 11, color: AppColors.brand),
                                  )
                                : null,
                            secondary: alreadyIn
                                ? Icon(Icons.school, size: 18, color: AppColors.brand)
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
                        backgroundColor: AppColors.brand,
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
                Icon(Icons.info_outline, size: 18, color: AppColors.brand),
                const SizedBox(width: 6),
                Text(
                  'En formation le ${_fmtDate(_startDate)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 14, color: AppColors.brand),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...workers.where((w) => _alreadyInFormationIds.contains(w.id)).map((e) => Card(
                  color: AppColors.brandLight,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.school, color: AppColors.brand, size: 20),
                    title: Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Icon(Icons.check_circle, color: AppColors.brand, size: 18),
                  ),
                )),
          ],
        ],
    );

    if (widget.nestInOuterScroll) {
      return Padding(
        padding: EdgeInsets.all(padding),
        child: body,
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: body,
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
              DropdownMenuItem(value: 'normales', child: Text('Équipes normales seulement')),
              DropdownMenuItem(value: 'distribution', child: Text('Distribution seulement')),
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
