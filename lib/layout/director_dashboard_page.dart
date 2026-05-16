import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_provider.dart';
import '../core/site/site_model.dart';
import '../core/site/site_provider.dart';
import '../core/utils/responsive.dart';
import '../modules/Demandes/leave_demandes_page.dart' show LeaveRequest, LeaveStatus;
import '../modules/Demandes/leave_requests_provider.dart';
import '../modules/distribution/distribution_groups_provider.dart';
import '../modules/distribution/models/distribution_group_model.dart';
import '../modules/groupes/models/groupe_model.dart';
import '../modules/employees/employees_provider.dart';
import '../modules/employees/models/employe_model.dart';
import '../modules/employees/models/equipe_model.dart';
import '../modules/groupes/groupes_provider.dart';
import '../modules/magasin/magasin_provider.dart';
import '../modules/overtime/models/overtime_model.dart';
import '../modules/overtime/overtime_provider.dart';
import '../modules/Paramètres/chauffeurs_provider.dart';
import '../modules/pointage/models/pointage_model.dart';
import '../modules/pointage/pointage_provider.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _leaveCoversDay(LeaveRequest r, DateTime day) {
  final d = _dateOnly(day);
  final s = _dateOnly(r.startDate);
  final e = _dateOnly(r.endDate);
  return !d.isBefore(s) && !d.isAfter(e);
}

/// Tableau de bord — filtre par jour, indicateurs complets, UI moderne.
class DirectorDashboardPage extends StatefulWidget {
  const DirectorDashboardPage({super.key});

  static const Color primary = Color(0xFF000966);
  static const Color bg = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  State<DirectorDashboardPage> createState() => _DirectorDashboardPageState();
}

class _DirectorDashboardPageState extends State<DirectorDashboardPage> {
  late DateTime _day;
  Future<List<PointageRecord>>? _pointageFuture;
  Future<List<OvertimeAssignment>>? _otFuture;
  var _depsReady = false;

  @override
  void initState() {
    super.initState();
    _day = _dateOnly(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_depsReady) return;
    _depsReady = true;
    final p = context.read<PointageProvider>();
    final o = context.read<OvertimeProvider>();
    _pointageFuture = p.getPointageRecordsForDate(_day);
    _otFuture = o.getForDateRange(_day, _day);
  }

  void _reloadFutures() {
    final p = context.read<PointageProvider>();
    final o = context.read<OvertimeProvider>();
    _pointageFuture = p.getPointageRecordsForDate(_day);
    _otFuture = o.getForDateRange(_day, _day);
  }

  void _setDay(DateTime d) {
    final n = _dateOnly(d);
    if (n == _day) return;
    setState(() {
      _day = n;
      _reloadFutures();
    });
  }

  Future<void> _pickDate() async {
    final first = DateTime.now().subtract(const Duration(days: 400));
    final last = DateTime.now().add(const Duration(days: 31));
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(last) ? last : (_day.isBefore(first) ? first : _day),
      firstDate: first,
      lastDate: last,
      helpText: 'Choisir une date',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );
    if (picked != null) _setDay(picked);
  }

  String _formatLong(DateTime d) {
    try {
      return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(d);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
  }

  String _formatShort(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final emp = context.watch<EmployeesProvider>();
    final pointage = context.watch<PointageProvider>();
    final magasin = context.watch<MagasinProvider>();
    final leavesProv = context.watch<LeaveRequestsProvider>();
    final groupesProv = context.watch<GroupesProvider>();
    final distProv = context.watch<DistributionGroupsProvider>();
    final chauffeursProv = context.watch<ChauffeursProvider>();

    final mobile = isMobile(context);
    final pad = pagePadding(context);
    final maxW = maxContentWidth(context);
    final today = _dateOnly(DateTime.now());
    final isToday = _day == today;

    final filteredEmployes = SiteId.filterBySite(
      emp.employes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );
    final filteredProduits = SiteId.filterBySite(
      magasin.produits,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (p) => p.siteId,
    );
    final filteredEquipes = SiteId.filterBySite(
      emp.equipes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );

    final employeIds = filteredEmployes.map((e) => e.id).toSet();
    final equipeIds = filteredEquipes.map((e) => e.id).toSet();

    final employesCount = filteredEmployes.length;
    final stockTotal = filteredProduits.fold<int>(0, (s, p) => s + p.total);

    final reportsFiltered = pointage.reports
        .where((r) => equipeIds.isEmpty || equipeIds.contains(r.equipeId))
        .toList();

    final reportsThisDay = reportsFiltered
        .where((r) => _dateOnly(r.date) == _day)
        .length;

    final monthlyReports = reportsFiltered.where((r) {
      return r.submittedAt.year == _day.year && r.submittedAt.month == _day.month;
    }).length;

    final mouvementsScoped = SiteId.filterBySite(
      [...magasin.entrees, ...magasin.sorties],
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (m) => m.siteId,
    );
    final entreesDay = mouvementsScoped.where((m) => m.type == 'entree' && _dateOnly(m.date) == _day).toList();
    final sortiesDay = mouvementsScoped.where((m) => m.type == 'sortie' && _dateOnly(m.date) == _day).toList();
    final entDayCount = entreesDay.length;
    final entDayUnits = entreesDay.fold<int>(0, (s, m) => s + m.totalQte);
    final sorDayCount = sortiesDay.length;
    final sorDayUnits = sortiesDay.fold<int>(0, (s, m) => s + m.totalQte);

    final last7 = _reportsLast7Ending(reportsFiltered, _day);

    final leaveScoped =
        leavesProv.requests.where((r) => employeIds.contains(r.employeeId)).toList();
    final leaveOnDay = leaveScoped.where((r) => _leaveCoversDay(r, _day)).toList();
    final leavePendingDay = leaveOnDay.where((r) => r.status == LeaveStatus.pending).length;
    final leaveApprovedDay = leaveOnDay.where((r) => r.status == LeaveStatus.approved).length;

    var groupesMembresScoped = 0;
    for (final g in groupesProv.groupes) {
      groupesMembresScoped += g.membreIds.where(employeIds.contains).length;
    }
    final distMembresTotal = distProv.groups.fold<int>(0, (s, g) => s + g.membreIds.length);
    final chauffeursActifs = chauffeursProv.chauffeurs.where((c) => c.actif).length;

    final scopeLabel = auth.currentUser?.isSuperAdmin == true && site.selectedSiteId != null
        ? SiteId.labelFr(site.selectedSiteId!)
        : null;

    final statutSlices = _statutDistribution(filteredEmployes);

    return ColoredBox(
      color: DirectorDashboardPage.bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + mobileBottomContentInset(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW.isFinite ? maxW : 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroHeader(
                  userName: auth.currentUser?.nom ?? '',
                  dateLine: _formatLong(_day),
                  scopeLabel: scopeLabel,
                  mobile: mobile,
                  filterHint: isToday ? 'Données pour aujourd’hui' : 'Date sélectionnée : ${_formatShort(_day)}',
                ),
                const SizedBox(height: 14),
                _DateFilterBar(
                  dayLabel: _formatShort(_day),
                  isToday: isToday,
                  mobile: mobile,
                  onPickDate: _pickDate,
                  onToday: () => _setDay(DateTime.now()),
                ),
                const SizedBox(height: 20),
                if (pointage.loading)
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: LinearProgressIndicator(minHeight: 3, color: DirectorDashboardPage.primary),
                  ),
                if (pointage.loading) const SizedBox(height: 12),
                _SectionIntro(
                  eyebrow: 'INDICATEURS',
                  title: 'Chiffres clés',
                  subtitle:
                      'Effectif, présence et rapports pour le jour choisi. Le stock reste l’état actuel du périmètre.',
                ),
                const SizedBox(height: 14),
                FutureBuilder<List<PointageRecord>>(
                  future: _pointageFuture,
                  builder: (context, snap) {
                    final list = snap.data;
                    final presentDay = list
                        ?.where((p) => employeIds.contains(p.employeId) && p.isFinalPresent)
                        .length;
                    final loadingP = snap.connectionState == ConnectionState.waiting && list == null;

                    return LayoutBuilder(
                      builder: (ctx, c) {
                        final narrow = c.maxWidth < 560;
                        final metrics = <_MetricSpec>[
                          _MetricSpec(
                            label: 'Collaborateurs',
                            value: '$employesCount',
                            hint: 'Effectif dans le périmètre',
                            icon: Icons.groups_2_rounded,
                            accent: const Color(0xFF000966),
                          ),
                          _MetricSpec(
                            label: 'Présents (${_formatShort(_day)})',
                            value: loadingP ? '…' : '${presentDay ?? '—'}',
                            hint: employesCount > 0 && presentDay != null
                                ? '${((presentDay / employesCount) * 100).clamp(0, 100).toStringAsFixed(0)} % de l’effectif'
                                : 'Pointage pour la date filtrée',
                            icon: Icons.how_to_reg_rounded,
                            accent: const Color(0xFF059669),
                          ),
                          _MetricSpec(
                            label: 'Stock (unités)',
                            value: '$stockTotal',
                            hint: 'Inventaire actuel — périmètre',
                            icon: Icons.inventory_2_rounded,
                            accent: const Color(0xFFD97706),
                          ),
                          _MetricSpec(
                            label: 'Rapports (jour)',
                            value: '$reportsThisDay',
                            hint: 'Rapports enregistrés ce jour-là',
                            icon: Icons.assignment_turned_in_rounded,
                            accent: const Color(0xFF7C3AED),
                          ),
                        ];
                        final metrics2 = <_MetricSpec>[
                          _MetricSpec(
                            label: 'Rapports (mois)',
                            value: '$monthlyReports',
                            hint: 'Total du mois ${_day.month}/${_day.year} (soumissions)',
                            icon: Icons.calendar_month_rounded,
                            accent: const Color(0xFF0D9488),
                          ),
                          _MetricSpec(
                            label: 'Entrées stock',
                            value: '$entDayCount',
                            hint: '$entDayUnits unité(s) — jour filtré',
                            icon: Icons.south_west_rounded,
                            accent: const Color(0xFF16A34A),
                          ),
                          _MetricSpec(
                            label: 'Sorties stock',
                            value: '$sorDayCount',
                            hint: '$sorDayUnits unité(s) — jour filtré',
                            icon: Icons.north_east_rounded,
                            accent: const Color(0xFFEA580C),
                          ),
                        ];
                        Widget row(List<_MetricSpec> m) {
                          if (narrow) {
                            return Column(
                              children: [
                                for (var i = 0; i < m.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  _MetricTile(spec: m[i]),
                                ],
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < m.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(child: _MetricTile(spec: m[i])),
                              ],
                            ],
                          );
                        }

                        return Column(
                          children: [
                            row(metrics),
                            const SizedBox(height: 12),
                            row(metrics2),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (employesCount > 0) ...[
                  const SizedBox(height: 16),
                  FutureBuilder<List<PointageRecord>>(
                    future: _pointageFuture,
                    builder: (context, snap) {
                      final list = snap.data ?? [];
                      final pres =
                          list.where((p) => employeIds.contains(p.employeId) && p.isFinalPresent).length;
                      if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                        return const _PresencePanelSkeleton();
                      }
                      return _PresencePanel(
                        present: pres,
                        total: employesCount,
                        dayLabel: _formatShort(_day),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'ÉQUIPES',
                  title: 'Présence par équipe',
                  subtitle: 'Effectif et présents pour la date filtrée (membres du périmètre).',
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<PointageRecord>>(
                  future: _pointageFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                    }
                    final rows = _equipePresenceRows(filteredEquipes, filteredEmployes, snap.data ?? []);
                    if (rows.isEmpty) {
                      return _InfoCard(
                        child: Text(
                          'Aucune équipe avec des membres dans ce périmètre.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      );
                    }
                    return _InfoCard(child: _EquipesPresenceTable(rows: rows, mobile: mobile));
                  },
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'GROUPES CRÉNEAUX',
                  title: 'Présence par groupe (horaires)',
                  subtitle:
                      'Groupes « normaux » de pointage — effectif et présents dans le périmètre pour la date filtrée.',
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<PointageRecord>>(
                  future: _pointageFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                      return const Center(
                        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                      );
                    }
                    final rows = _membershipPresenceRowsFromGroupes(
                      groupesProv.groupes,
                      employeIds,
                      snap.data ?? [],
                    );
                    if (rows.isEmpty) {
                      return _InfoCard(
                        child: Text(
                          'Aucun groupe de créneau avec des membres dans ce périmètre.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      );
                    }
                    return _InfoCard(
                      child: _EquipesPresenceTable(
                        rows: rows,
                        mobile: mobile,
                        firstColumnLabel: 'Groupe',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'DISTRIBUTION',
                  title: 'Présence par groupe distribution',
                  subtitle:
                      'Groupes liés à la distribution — mêmes indicateurs (effectif / présents / taux) pour la date choisie.',
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<PointageRecord>>(
                  future: _pointageFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                      return const Center(
                        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                      );
                    }
                    final rows = _membershipPresenceRowsFromDistribution(
                      distProv.groups,
                      employeIds,
                      snap.data ?? [],
                    );
                    if (rows.isEmpty) {
                      return _InfoCard(
                        child: Text(
                          'Aucun groupe distribution avec des membres dans ce périmètre.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      );
                    }
                    return _InfoCard(
                      child: _EquipesPresenceTable(
                        rows: rows,
                        mobile: mobile,
                        firstColumnLabel: 'Groupe',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'AFFECTATION',
                  title: 'Collaborateurs sans équipe ni groupe',
                  subtitle:
                      'Personnes du périmètre qui ne figurent dans aucune équipe, aucun groupe créneau et aucun groupe distribution.',
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<PointageRecord>>(
                  future: _pointageFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                      return const Center(
                        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                      );
                    }
                    final row = _unassignedPresenceRow(
                      filteredEquipes,
                      groupesProv.groupes,
                      distProv.groups,
                      employeIds,
                      snap.data ?? [],
                    );
                    if (row == null) {
                      return _InfoCard(
                        child: Text(
                          'Tous les collaborateurs du périmètre sont affectés à au moins une équipe ou un groupe.',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      );
                    }
                    return _InfoCard(
                      child: _EquipesPresenceTable(
                        rows: [row],
                        mobile: mobile,
                        firstColumnLabel: 'Catégorie',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'CONGÉS',
                  title: 'Demandes concernant ce jour',
                  subtitle:
                      'Demandes qui couvrent la date filtrée (en attente / approuvées). $leavePendingDay en attente, $leaveApprovedDay approuvée(s) ce jour dans le périmètre.',
                ),
                const SizedBox(height: 12),
                if (leavesProv.loading)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _miniRow(Icons.pending_actions_outlined, 'En attente (couvre ce jour)', '$leavePendingDay'),
                        const Divider(height: 20),
                        _miniRow(Icons.check_circle_outline, 'Approuvées (couvre ce jour)', '$leaveApprovedDay'),
                        if (leaveOnDay.length > 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${leaveOnDay.length - 8} autre(s) demande(s) — voir menu Demandes',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'RESSOURCES',
                  title: 'Groupes, distribution, chauffeurs',
                  subtitle:
                      'Groupes pointage : ${groupesProv.groupes.length} · $groupesMembresScoped membre(s) lié(s). Distribution : ${distProv.groups.length} groupe(s), $distMembresTotal membre(s). Chauffeurs actifs : $chauffeursActifs.',
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _miniRow(Icons.schedule_rounded, 'Groupes pointage (créneaux)', '${groupesProv.groupes.length}'),
                      const Divider(height: 20),
                      _miniRow(Icons.local_shipping_outlined, 'Groupes distribution', '${distProv.groups.length}'),
                      const Divider(height: 20),
                      _miniRow(Icons.directions_car_filled_outlined, 'Comptes chauffeurs actifs', '$chauffeursActifs'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'HEURES SUP.',
                  title: 'Affectations pour la date filtrée',
                  subtitle: 'Dépassements planifiés dont la date correspond au jour choisi (périmètre équipes / employés).',
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<OvertimeAssignment>>(
                  future: _otFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                    }
                    final all = snap.data ?? [];
                    final scoped = all
                        .where(
                          (a) =>
                              employeIds.contains(a.employeId) ||
                              equipeIds.contains(a.targetEquipeId) ||
                              equipeIds.contains(a.originEquipeId),
                        )
                        .toList();
                    return _InfoCard(
                      child: Text(
                        '${scoped.length} affectation(s) — ${_formatShort(_day)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DirectorDashboardPage.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'STATUT RH',
                  title: 'Collaborateurs par statut',
                  subtitle: 'Répartition actuelle de l’effectif filtré.',
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  child: statutSlices.isEmpty
                      ? Text('Aucun collaborateur.', style: TextStyle(color: Colors.grey.shade600))
                      : _StatutRowSection(slices: statutSlices, mobile: mobile),
                ),
                const SizedBox(height: 24),
                _SectionIntro(
                  eyebrow: 'ACTIVITÉ',
                  title: 'Rapports quotidiens (7 jours)',
                  subtitle:
                      'Fenêtre glissante se terminant à la date filtrée : ${_formatShort(_day)}.',
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  child: _ReportsLineChart(days: last7, mobile: mobile),
                ),
                const SizedBox(height: 16),
                _InfoCard(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: DirectorDashboardPage.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Filtre date : les présences, équipes, congés du jour, mouvements et HS utilisent le jour affiché. Le stock est toujours la situation actuelle.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: DirectorDashboardPage.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Date filter ─────────────────────────────────────────────────────────────

class _DateFilterBar extends StatelessWidget {
  final String dayLabel;
  final bool isToday;
  final bool mobile;
  final VoidCallback onPickDate;
  final VoidCallback onToday;

  const _DateFilterBar({
    required this.dayLabel,
    required this.isToday,
    required this.mobile,
    required this.onPickDate,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          Icon(Icons.filter_alt_rounded, color: DirectorDashboardPage.primary, size: 22),
          Text(
            'Filtrer par date',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: mobile ? 14 : 15,
              color: DirectorDashboardPage.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.tonalIcon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: Text('Choisir… ($dayLabel)'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8E9F3),
              foregroundColor: DirectorDashboardPage.primary,
            ),
          ),
          if (!isToday)
            OutlinedButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Aujourd’hui'),
            ),
        ],
      ),
    );
  }
}

// ─── Hero ───────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String userName;
  final String dateLine;
  final String? scopeLabel;
  final String filterHint;
  final bool mobile;

  const _HeroHeader({
    required this.userName,
    required this.dateLine,
    required this.mobile,
    required this.filterHint,
    this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF000966),
            Color(0xFF00044D),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000966).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.all(mobile ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TABLEAU DE BORD',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            userName.isNotEmpty ? 'Bonjour, $userName' : 'Bonjour',
            style: TextStyle(
              fontSize: mobile ? 22 : 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLine,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filterHint,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          if (scopeLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Périmètre : $scopeLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _SectionIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: DirectorDashboardPage.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DirectorDashboardPage.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: DirectorDashboardPage.textSecondary.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

Widget _miniRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 22, color: DirectorDashboardPage.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: DirectorDashboardPage.textPrimary),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: DirectorDashboardPage.primary),
      ),
    ],
  );
}

class _MetricSpec {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color accent;

  _MetricSpec({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.accent,
  });
}

class _MetricTile extends StatelessWidget {
  final _MetricSpec spec;

  const _MetricTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: spec.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(spec.icon, color: spec.accent, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              spec.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: DirectorDashboardPage.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              spec.value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: spec.accent,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              spec.hint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresencePanelSkeleton extends StatelessWidget {
  const _PresencePanelSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _PresencePanel extends StatelessWidget {
  final int present;
  final int total;
  final String dayLabel;

  const _PresencePanel({
    required this.present,
    required this.total,
    required this.dayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (present / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: DirectorDashboardPage.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TAUX DE PRÉSENCE — $dayLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: DirectorDashboardPage.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$present sur $total',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: DirectorDashboardPage.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Collaborateurs marqués présents parmi l’effectif du périmètre (jour filtré).',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              backgroundColor: const Color(0xFFE2E8F0),
              color: DirectorDashboardPage.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(ratio * 100).toStringAsFixed(0)} %',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: DirectorDashboardPage.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipesPresenceTable extends StatelessWidget {
  final List<_EquipePresenceRow> rows;
  final bool mobile;
  final String firstColumnLabel;

  const _EquipesPresenceTable({
    required this.rows,
    required this.mobile,
    this.firstColumnLabel = 'Équipe',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 42,
        dataRowMinHeight: 40,
        columnSpacing: 20,
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: DirectorDashboardPage.primary,
        ),
        columns: [
          DataColumn(label: Text(firstColumnLabel)),
          const DataColumn(label: Text('Effectif'), numeric: true),
          const DataColumn(label: Text('Présents'), numeric: true),
          const DataColumn(label: Text('Taux'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: mobile ? 140 : 220),
                    child: Text(
                      r.nom,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
                DataCell(Text('${r.membres}', style: const TextStyle(fontSize: 13))),
                DataCell(Text('${r.presents}', style: const TextStyle(fontSize: 13))),
                DataCell(
                  Text(
                    '${(r.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: r.ratio >= 0.85
                          ? Colors.green.shade700
                          : r.ratio >= 0.5
                              ? Colors.orange.shade800
                              : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatutRowSection extends StatelessWidget {
  final List<_NamedSlice> slices;
  final bool mobile;

  const _StatutRowSection({required this.slices, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final sum = slices.fold<double>(0, (a, b) => a + b.value);
    if (sum <= 0) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: mobile ? 36 : 40,
          child: Row(
            children: [
              for (var i = 0; i < slices.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  flex: math.max(1, slices[i].value.round()),
                  child: Container(
                    decoration: BoxDecoration(
                      color: slices[i].color,
                      borderRadius: BorderRadius.horizontal(
                        left: i == 0 ? const Radius.circular(8) : Radius.zero,
                        right: i == slices.length - 1 ? const Radius.circular(8) : Radius.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in slices)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${s.name}: ${s.value.toInt()}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ReportsLineChart extends StatelessWidget {
  final List<(DateTime day, int count)> days;
  final bool mobile;

  const _ReportsLineChart({required this.days, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final maxC = days.fold<int>(0, (m, e) => math.max(m, e.$2));
    final maxY = math.max(4.0, maxC * 1.15).toDouble();
    final spots = <FlSpot>[
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].$2.toDouble()),
    ];

    return SizedBox(
      height: mobile ? 220 : 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (days.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY <= 4 ? 1 : maxY / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: const Color(0xFFE2E8F0),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: maxY <= 4 ? 1 : null,
                getTitlesWidget: (v, meta) => Text(
                  v == v.roundToDouble() ? '${v.toInt()}' : '',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= days.length) return const SizedBox();
                  final d = days[i].$1;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.28,
              color: DirectorDashboardPage.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: DirectorDashboardPage.primary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DirectorDashboardPage.primary.withValues(alpha: 0.22),
                    DirectorDashboardPage.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xFF1E293B),
              getTooltipItems: (touched) {
                return [
                  for (final t in touched)
                    LineTooltipItem(
                      '${days[t.x.toInt()].$1.day}/${days[t.x.toInt()].$1.month}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: '${t.y.toInt()} rapport(s)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                ];
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }
}

// ─── Data models / helpers ─────────────────────────────────────────────────

class _EquipePresenceRow {
  final String nom;
  final int membres;
  final int presents;

  _EquipePresenceRow({required this.nom, required this.membres, required this.presents});

  double get ratio => membres > 0 ? presents / membres : 0.0;
}

int _presentEmployeCount(Set<String> membresScoped, List<PointageRecord> dayRecords) {
  final seen = <String>{};
  for (final p in dayRecords) {
    if (membresScoped.contains(p.employeId) && p.isFinalPresent) {
      seen.add(p.employeId);
    }
  }
  return seen.length;
}

List<_EquipePresenceRow> _membershipPresenceRowsFromGroupes(
  List<Groupe> groupes,
  Set<String> employeIds,
  List<PointageRecord> dayRecords,
) {
  final rows = <_EquipePresenceRow>[];
  for (final g in groupes) {
    final membres = g.membreIds.where(employeIds.contains).toSet();
    if (membres.isEmpty) continue;
    final pres = _presentEmployeCount(membres, dayRecords);
    rows.add(_EquipePresenceRow(nom: g.nom.isNotEmpty ? g.nom : g.id, membres: membres.length, presents: pres));
  }
  rows.sort((a, b) => b.membres.compareTo(a.membres));
  return rows;
}

List<_EquipePresenceRow> _membershipPresenceRowsFromDistribution(
  List<DistributionGroup> groups,
  Set<String> employeIds,
  List<PointageRecord> dayRecords,
) {
  final rows = <_EquipePresenceRow>[];
  for (final g in groups) {
    final membres = g.membreIds.where(employeIds.contains).toSet();
    if (membres.isEmpty) continue;
    final pres = _presentEmployeCount(membres, dayRecords);
    rows.add(_EquipePresenceRow(nom: g.nom.isNotEmpty ? g.nom : g.id, membres: membres.length, presents: pres));
  }
  rows.sort((a, b) => b.membres.compareTo(a.membres));
  return rows;
}

_EquipePresenceRow? _unassignedPresenceRow(
  List<Equipe> equipes,
  List<Groupe> groupes,
  List<DistributionGroup> distGroups,
  Set<String> employeIds,
  List<PointageRecord> dayRecords,
) {
  final assigned = <String>{};
  for (final eq in equipes) {
    assigned.addAll(eq.membreIds);
    if (eq.chefId.isNotEmpty) assigned.add(eq.chefId);
  }
  for (final g in groupes) {
    assigned.addAll(g.membreIds);
  }
  for (final d in distGroups) {
    assigned.addAll(d.membreIds);
  }
  final unassigned = employeIds.difference(assigned);
  if (unassigned.isEmpty) return null;
  final pres = _presentEmployeCount(unassigned, dayRecords);
  return _EquipePresenceRow(
    nom: 'Non affectés (aucune équipe / groupe)',
    membres: unassigned.length,
    presents: pres,
  );
}

List<_EquipePresenceRow> _equipePresenceRows(
  List<Equipe> equipes,
  List<Employe> employesFiltered,
  List<PointageRecord> dayRecords,
) {
  final idSet = employesFiltered.map((e) => e.id).toSet();
  final rows = <_EquipePresenceRow>[];
  for (final eq in equipes) {
    final membres = eq.membreIds.where(idSet.contains).length;
    if (membres == 0) continue;
    final pres = dayRecords
        .where((p) => p.equipeId == eq.id && idSet.contains(p.employeId) && p.isFinalPresent)
        .length;
    rows.add(_EquipePresenceRow(nom: eq.nom, membres: membres, presents: pres));
  }
  rows.sort((a, b) => b.membres.compareTo(a.membres));
  return rows;
}

class _NamedSlice {
  final String name;
  final double value;
  final Color color;

  _NamedSlice({required this.name, required this.value, required this.color});
}

List<_NamedSlice> _statutDistribution(List<Employe> employes) {
  final m = <EmployeStatut, int>{};
  for (final e in employes) {
    m[e.statut] = (m[e.statut] ?? 0) + 1;
  }
  if (m.isEmpty) return [];
  final order = [
    EmployeStatut.enService,
    EmployeStatut.enConge,
    EmployeStatut.enMaladie,
    EmployeStatut.quitte,
  ];
  final out = <_NamedSlice>[];
  for (final s in order) {
    final n = m[s];
    if (n != null && n > 0) {
      out.add(_NamedSlice(name: s.label, value: n.toDouble(), color: s.color));
    }
  }
  return out;
}

List<(DateTime day, int count)> _reportsLast7Ending(List<DailyReport> reports, DateTime endDay) {
  final end = _dateOnly(endDay);
  final start = end.subtract(const Duration(days: 6));
  final days = List.generate(7, (i) => start.add(Duration(days: i)));
  final counts = List<int>.filled(7, 0);
  for (final r in reports) {
    final d = DateTime(r.date.year, r.date.month, r.date.day);
    final diff = d.difference(start).inDays;
    if (diff >= 0 && diff < 7) {
      counts[diff]++;
    }
  }
  return List.generate(7, (i) => (days[i], counts[i]));
}
