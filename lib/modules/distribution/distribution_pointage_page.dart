import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import 'distribution_groups_provider.dart';
import 'distribution_swaps_provider.dart';
import 'services/distribution_swap_service.dart';
import 'widgets/distribution_swap_dialog.dart';
import '../pointage/models/pointage_model.dart';
import '../pointage/pointage_provider.dart';
import '../pointage/data/daily_snapshot_repository.dart';
import '../pointage/services/pointage_export_service.dart';
import '../pointage/absence_reasons_provider.dart';
import '../pointage/models/absence_reason_config.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_busy.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../distribution/distribution_shifts_provider.dart';
import '../shifts/models/shift_models.dart';
import '../Demandes/leave_requests_provider.dart';
import '../Demandes/leave_demandes_page.dart' show LeaveRequest, LeaveStatus;
import '../overtime/models/overtime_model.dart';
import '../overtime/overtime_provider.dart';

class DistributionPointagePage extends StatefulWidget {
  final bool reviewOnly;
  const DistributionPointagePage({super.key, this.reviewOnly = false});

  @override
  State<DistributionPointagePage> createState() => _DistributionPointagePageState();
}

class _DistributionPointagePageState extends State<DistributionPointagePage> {
  final DailySnapshotRepository _snapshotRepo = DailySnapshotRepository();
  String? _selectedGroupId;
  int _reloadCounter = 0;
  final Set<String> _manualStatusEditMode = <String>{};
  late DateTime _pointageDay;
  Future<({List<PointageRecord> records, List<OvertimeAssignment> overtime})>? _pointageDataFuture;
  int _pointageDataKey = -1;

  void _loadPointageData(PointageProvider pointageProv, OvertimeProvider overtimeProv, DateTime day) {
    final key = Object.hash(day.year, day.month, day.day, _reloadCounter);
    if (_pointageDataKey == key && _pointageDataFuture != null) return;
    _pointageDataKey = key;
    _pointageDataFuture = () async {
      final records = await pointageProv.getPointageRecordsForDate(day);
      final overtime = await overtimeProv.getForDateRange(day, day);
      return (records: records, overtime: overtime);
    }();
  }

  Future<void> _reloadPointageDataAfterAction(
    PointageProvider pointageProv,
    OvertimeProvider overtimeProv,
    DateTime day,
  ) async {
    final records = await pointageProv.getPointageRecordsForDate(day);
    final overtime = await overtimeProv.getForDateRange(day, day);
    if (!mounted) return;
    setState(() {
      _reloadCounter++;
      _pointageDataKey = Object.hash(day.year, day.month, day.day, _reloadCounter);
      _pointageDataFuture = Future.value((records: records, overtime: overtime));
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pointageDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  }

  Future<void> _pickPointageDay(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _pointageDay,
      firstDate: today.subtract(const Duration(days: 120)),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _pointageDay = DateTime(picked.year, picked.month, picked.day);
        _reloadCounter++;
      });
    }
  }

  String _shiftLabel(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return 'P1 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.evening:
        return 'P2 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.night:
        return 'P3 (${shift.timeRange.replaceAll('–', '-')})';
      case ShiftType.rest:
        return 'P4';
    }
  }

  Future<String?> _showAbsenceReasonDialog(
    BuildContext context,
    List<AbsenceReasonConfig> configs,
  ) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner la raison d\'absence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: configs.isNotEmpty
                ? configs
                    .map((c) => ListTile(
                          title: Text(c.label),
                          onTap: () => Navigator.pop(ctx, c.id),
                        ))
                    .toList()
                : AbsenceReason.values
                    .map((r) => ListTile(
                          title: Text(r.label),
                          onTap: () => Navigator.pop(ctx, r.name),
                        ))
                    .toList(),
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

  DateTime _shiftStartFor(ShiftType shift, DateTime day) {
    switch (shift) {
      case ShiftType.morning:
        return DateTime(day.year, day.month, day.day, 6, 0);
      case ShiftType.evening:
        return DateTime(day.year, day.month, day.day, 14, 0);
      case ShiftType.night:
        return DateTime(day.year, day.month, day.day, 22, 0);
      case ShiftType.rest:
        return DateTime(day.year, day.month, day.day, 0, 0);
    }
  }

  DateTime _shiftEndFor(ShiftType shift, DateTime day) {
    switch (shift) {
      case ShiftType.morning:
        return DateTime(day.year, day.month, day.day, 14, 0);
      case ShiftType.evening:
        return DateTime(day.year, day.month, day.day, 22, 0);
      case ShiftType.night:
        return DateTime(day.year, day.month, day.day).add(const Duration(days: 1, hours: 6));
      case ShiftType.rest:
        return DateTime(day.year, day.month, day.day, 0, 0);
    }
  }

  List<int> _allowedHoursInShift(DateTime shiftStartAt, DateTime shiftEndAt) {
    final hours = <int>[];
    var cursor = DateTime(
      shiftStartAt.year,
      shiftStartAt.month,
      shiftStartAt.day,
      shiftStartAt.hour,
    );
    final endHour = DateTime(
      shiftEndAt.year,
      shiftEndAt.month,
      shiftEndAt.day,
      shiftEndAt.hour,
    );
    while (!cursor.isAfter(endHour)) {
      final h = cursor.hour;
      if (!hours.contains(h)) hours.add(h);
      cursor = cursor.add(const Duration(hours: 1));
    }
    return hours;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final allowedIds = auth.distributionGroupIds;
    final groupsProv = context.watch<DistributionGroupsProvider>();
    final empsProv = context.watch<EmployeesProvider>();
    final pointageProv = context.watch<PointageProvider>();
    final absenceReasonsProv = context.watch<AbsenceReasonsProvider>();
    final distShiftsProv = context.watch<DistributionShiftsProvider>();
    final leaveReqProv = context.watch<LeaveRequestsProvider>();
    final overtimeProv = context.read<OvertimeProvider>();
    final day = _pointageDay;

    final readOnlyByRole = auth.isDirecteur || auth.adminRole.contains('rh') || auth.isChefZoneAdmin;
    final isReviewer = widget.reviewOnly || readOnlyByRole;
    final canResetYesterdayPointage = auth.isChefZoneAdmin;
    final reviewerCanSeeAll = isReviewer && (auth.isChefAtelierAdmin || auth.isDirecteur || auth.isChefZoneAdmin);
    final zoneCanSeeAll = auth.isChefZoneAdmin || auth.isDirecteur;
    if (allowedIds.isEmpty && !reviewerCanSeeAll && !zoneCanSeeAll) {
      return const Center(child: Text('Compte non lié à un groupe Distribution.'));
    }
    final availableGroupsRaw = (reviewerCanSeeAll || zoneCanSeeAll)
        ? groupsProv.groups
        : groupsProv.groups.where((g) => allowedIds.contains(g.id)).toList();
    final availableGroups = availableGroupsRaw
        .where((g) => !distShiftsProv.hasRotationSlotForGroup(g.id) || distShiftsProv.getShiftForGroup(g.id, day) != ShiftType.rest)
        .toList();
    if (availableGroups.isEmpty) {
      return const Center(child: Text('Aucun groupe Distribution en service pour cette date.'));
    }
    _selectedGroupId ??= availableGroups.first.id;
    if (!availableGroups.any((e) => e.id == _selectedGroupId)) {
      _selectedGroupId = availableGroups.first.id;
    }
    final g = availableGroups.firstWhere((e) => e.id == _selectedGroupId);
    final shift = distShiftsProv.hasRotationSlotForGroup(g.id)
        ? distShiftsProv.getShiftForGroup(g.id, day)
        : ShiftType.rest;
    final shiftLabel = _shiftLabel(shift);
    final swapsProv = context.watch<DistributionSwapsProvider>();
    final canManageSwaps = DistributionSwapDialogs.canOpen(auth);

    _loadPointageData(pointageProv, overtimeProv, day);
    return FutureBuilder<({List<PointageRecord> records, List<OvertimeAssignment> overtime})>(
      key: ValueKey(_pointageDataKey),
      future: _pointageDataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snap.data?.records ?? const <PointageRecord>[];
        final overtimeAssignments = snap.data?.overtime ?? const <OvertimeAssignment>[];
        PointageRecord? recFor(String id) {
          try {
            return records.firstWhere((r) => r.employeId == id);
          } catch (_) {
            return null;
          }
        }
        final currentEquipeId = 'distribution:${g.id}';
        final pointageMembers = DistributionSwapService.membersForPointage(
          group: g,
          allEmployes: empsProv.employes,
          dayRecords: records,
          swaps: swapsProv.swaps,
          day: day,
        );

        PointageRecord? recordForRow(
          ({Employe employe, PointageRecord? record, bool isGuest, bool isArrangement, bool arrangementPending, bool isAwayOnRenfort}) row,
        ) {
          if (row.isArrangement || row.isGuest) return row.record;
          if (row.record != null && row.record!.equipeId == currentEquipeId) return row.record;
          final matches = records
              .where((r) =>
                  r.employeId == row.employe.id &&
                  r.equipeId == currentEquipeId &&
                  !r.distSwapArrangement)
              .toList();
          if (matches.isNotEmpty) {
            final home = matches.where((r) => !r.tempAssigned).toList();
            return home.isNotEmpty ? home.first : matches.first;
          }
          final stdId = DistributionSwapService.standardDayDocId(row.employe.id, day);
          try {
            return records.firstWhere(
              (r) => r.id == stdId && !r.tempAssigned && !r.distSwapArrangement,
            );
          } catch (_) {
            return null;
          }
        }

        String? incompleteReason(
          ({Employe employe, PointageRecord? record, bool isGuest, bool isArrangement, bool arrangementPending, bool isAwayOnRenfort}) row,
        ) {
          if (row.isArrangement || row.isAwayOnRenfort) return null;
          final r = recordForRow(row);
          if (r == null) return 'non marqué';
          if (r.chefStatus == ChefPointageStatus.unset) return 'non marqué';
          if (r.chefStatus == ChefPointageStatus.present &&
              r.departureStatus == DepartureStatus.unset) {
            return 'sortie non confirmée';
          }
          return null;
        }

        bool isMemberPointageComplete(
          ({Employe employe, PointageRecord? record, bool isGuest, bool isArrangement, bool arrangementPending, bool isAwayOnRenfort}) row,
        ) {
          if (row.isArrangement || row.isAwayOnRenfort) return true;
          final r = recordForRow(row);
          if (r == null) return false;
          return r.chefStatus != ChefPointageStatus.unset;
        }

        final incompleteForConfirm = pointageMembers
            .map((row) => (row: row, reason: incompleteReason(row)))
            .where((e) => e.reason != null)
            .toList();
        final unmarkedNames = pointageMembers
            .where((row) => incompleteReason(row) == 'non marqué')
            .map((r) => r.employe.nom)
            .toList();
        final activeMembers = pointageMembers
            .where((m) => !m.isArrangement && !m.isAwayOnRenfort)
            .toList();
        final reportConfirmed = activeMembers.isNotEmpty &&
            activeMembers.every((m) {
              final rec = recordForRow(m);
              return rec?.submittedByChefAt != null;
            });
        final canConfirmAll =
            pointageMembers.isNotEmpty && pointageMembers.every(isMemberPointageComplete);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.14),
                      theme.colorScheme.primary.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.24),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pointage Distribution — ${g.nom}',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.calendar_today, size: 16),
                          label: Text('${day.day}/${day.month}/${day.year}'),
                          onPressed: isReviewer ? null : () => _pickPointageDay(context),
                        ),
                        Chip(
                          avatar: const Icon(Icons.schedule, size: 16),
                          label: Text(shiftLabel),
                        ),
                        if (canManageSwaps && !isReviewer)
                          ActionChip(
                            avatar: const Icon(Icons.swap_horiz, size: 16),
                            label: const Text('Échanges'),
                            onPressed: () async {
                              await DistributionSwapDialogs.showManageSheet(context);
                              // Recharge les enregistrements pointage après toute
                              // modification d'échange (step 1 ou step 2).
                              if (mounted) {
                                await _reloadPointageDataAfterAction(
                                  pointageProv, overtimeProv, day);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (availableGroups.length > 1)
                DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Groupe Distribution',
                    border: OutlineInputBorder(),
                  ),
                  items: availableGroups
                      .map((x) => DropdownMenuItem<String>(value: x.id, child: Text(x.nom)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
              const SizedBox(height: 12),
              if (pointageMembers.isEmpty)
                Text('Aucun membre dans ce groupe.', style: TextStyle(color: Colors.grey[700]))
              else
                ...pointageMembers.map((row) {
                  final e = row.employe;
                  final r = recordForRow(row);
                  final isArrangement = row.isArrangement;
                  final arrangementPending = row.arrangementPending;
                  final isGuest = row.isGuest;
                  final isAwayOnRenfort = row.isAwayOnRenfort;
                  final chefStatus = r?.chefStatus ?? ChefPointageStatus.unset;
                  final present = chefStatus == ChefPointageStatus.present;
                  final absent = chefStatus == ChefPointageStatus.absent;
                  final arrival = r?.arrivalMarkedAt;
                  final departure = r?.departureMarkedAt;
                  final equipeId = r?.equipeId ?? currentEquipeId;
                  final equipeName = r?.equipeName ?? 'Distribution: ${g.nom}';
                  final chefName = auth.currentUser?.nom ?? 'Responsable Distribution';

                  Future<void> setPresent() async {
                    if (isReviewer || isArrangement || isAwayOnRenfort) return;
                    final shiftStartAt = _shiftStartFor(shift, day);
                    final bool ok;
                    if (r != null && r.id.isNotEmpty && r.tempAssigned) {
                      ok = await pointageProv.markRenfortChefAttendance(
                        renfortRecord: r,
                        chefStatus: ChefPointageStatus.present,
                        chefId: auth.currentUser?.id,
                        bypassTimeWindows: true,
                      );
                    } else {
                      ok = await pointageProv.markDistributionAttendanceForDate(
                        employeId: e.id,
                        employeNom: e.nom,
                        employeCin: e.cin,
                        equipeId: currentEquipeId,
                        equipeName: 'Distribution: ${g.nom}',
                        chefName: chefName,
                        chefStatus: ChefPointageStatus.present,
                        pointageDate: day,
                        chefId: auth.currentUser?.id,
                        arrivalAt: shiftStartAt,
                      );
                    }
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Échec enregistrement (Firebase indisponible ?)')),
                      );
                      return;
                    }
                    await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                  }

                  Future<void> setAbsent() async {
                    if (isReviewer || isArrangement || isAwayOnRenfort) return;
                    final reason = await _showAbsenceReasonDialog(context, absenceReasonsProv.reasons);
                    if (reason == null) return;
                    if (r != null && r.id.isNotEmpty && r.tempAssigned) {
                      final okRenfort = await pointageProv.markRenfortChefAttendance(
                        renfortRecord: r,
                        chefStatus: ChefPointageStatus.absent,
                        chefId: auth.currentUser?.id,
                        absenceReason: reason,
                        bypassTimeWindows: true,
                      );
                      if (!context.mounted) return;
                      if (!okRenfort) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Échec enregistrement (Firebase indisponible ?)')),
                        );
                        return;
                      }
                    } else {
                      final ok = await pointageProv.markDistributionAttendanceForDate(
                        employeId: e.id,
                        employeNom: e.nom,
                        employeCin: e.cin,
                        equipeId: currentEquipeId,
                        equipeName: 'Distribution: ${g.nom}',
                        chefName: chefName,
                        chefStatus: ChefPointageStatus.absent,
                        pointageDate: day,
                        chefId: auth.currentUser?.id,
                        absenceReason: reason,
                      );
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Échec enregistrement (Firebase indisponible ?)')),
                        );
                        return;
                      }
                    }
                    await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                  }

                  Future<void> markFinished() async {
                    if (isReviewer || isArrangement || isAwayOnRenfort) return;
                    final shiftEndAt = _shiftEndFor(shift, day);
                    final record = r ??
                        PointageRecord(
                          id: '',
                          employeId: e.id,
                          employeNom: e.nom,
                          employeCin: e.cin,
                          equipeId: equipeId,
                          equipeName: equipeName,
                          chefName: chefName,
                          status: AttendanceStatus.unmarked,
                          date: day,
                          createdAt: DateTime.now(),
                          chefStatus: ChefPointageStatus.present,
                          tempAssigned: isGuest,
                          originalEquipeId: isGuest ? (r?.originalEquipeId ?? '') : null,
                        );
                    await pointageProv.setDepartureStatus(
                      record: record,
                      status: DepartureStatus.finished,
                      overtimeMinutes: 0,
                      departureAt: shiftEndAt,
                      bypassTimeWindows: true,
                    );
                    await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                  }

                  Future<void> markNotCompleted() async {
                    if (isReviewer || isArrangement || isAwayOnRenfort) return;
                    final record = r ??
                        PointageRecord(
                          id: '',
                          employeId: e.id,
                          employeNom: e.nom,
                          employeCin: e.cin,
                          equipeId: equipeId,
                          equipeName: equipeName,
                          chefName: chefName,
                          status: AttendanceStatus.unmarked,
                          date: day,
                          createdAt: DateTime.now(),
                          chefStatus: ChefPointageStatus.present,
                        );
                    final reasonCtrl = TextEditingController();
                    final formKey = GlobalKey<FormState>();
                    int? selectedHour;
                    int? selectedMinute;
                    final shiftStartAt = _shiftStartFor(shift, day);
                    final shiftEndAt = _shiftEndFor(shift, day);
                    final allowedHours = _allowedHoursInShift(shiftStartAt, shiftEndAt);
                    final payload = await showDialog<({String? reason, int workedMinutes, DateTime departureAt})>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("N'a pas terminé"),
                        content: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatefulBuilder(
                                builder: (ctx, setInnerState) => FormField<bool>(
                                  validator: (_) {
                                    if (selectedHour == null || selectedMinute == null) {
                                      return 'Heure de sortie obligatoire';
                                    }
                                    DateTime exitAt = DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                      selectedHour!,
                                      selectedMinute!,
                                    );
                                    if (shift == ShiftType.night && exitAt.isBefore(shiftStartAt)) {
                                      exitAt = exitAt.add(const Duration(days: 1));
                                    }
                                    if (exitAt.isBefore(shiftStartAt) || exitAt.isAfter(shiftEndAt)) {
                                      final from =
                                          '${shiftStartAt.hour.toString().padLeft(2, '0')}:${shiftStartAt.minute.toString().padLeft(2, '0')}';
                                      final to =
                                          '${shiftEndAt.hour.toString().padLeft(2, '0')}:${shiftEndAt.minute.toString().padLeft(2, '0')}';
                                      return 'Heure hors plage du shift ($from - $to)';
                                    }
                                    return null;
                                  },
                                  builder: (state) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              value: selectedHour,
                                              decoration: const InputDecoration(
                                                labelText: 'Heure',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: allowedHours
                                                  .map(
                                                    (h) => DropdownMenuItem<int>(
                                                      value: h,
                                                      child: Text(h.toString().padLeft(2, '0')),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) {
                                                setInnerState(() => selectedHour = v);
                                                state.didChange(true);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              value: selectedMinute,
                                              decoration: const InputDecoration(
                                                labelText: 'Minute',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: List.generate(
                                                60,
                                                (i) => DropdownMenuItem<int>(
                                                  value: i,
                                                  child: Text(i.toString().padLeft(2, '0')),
                                                ),
                                              ),
                                              onChanged: (v) {
                                                setInnerState(() => selectedMinute = v);
                                                state.didChange(true);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Plage autorisée: '
                                        '${shiftStartAt.hour.toString().padLeft(2, '0')}:${shiftStartAt.minute.toString().padLeft(2, '0')}'
                                        ' - '
                                        '${shiftEndAt.hour.toString().padLeft(2, '0')}:${shiftEndAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                      ),
                                      if (state.errorText != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6, left: 2),
                                          child: Text(
                                            state.errorText!,
                                            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                                          ),
                                        ),
                                    ],
                                  ),
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
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                          ),
                          TextButton(
                            onPressed: () {
                              if (!(formKey.currentState?.validate() ?? false)) return;
                              DateTime exitAt =
                                  DateTime(day.year, day.month, day.day, selectedHour!, selectedMinute!);
                              if (shift == ShiftType.night && exitAt.isBefore(shiftStartAt)) {
                                exitAt = exitAt.add(const Duration(days: 1));
                              }
                              final mins = exitAt.difference(shiftStartAt).inMinutes;
                              final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
                              Navigator.pop(
                                ctx,
                                (reason: reason, workedMinutes: mins, departureAt: exitAt),
                              );
                            },
                            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                          ),
                        ],
                      ),
                    );
                    if (payload == null) return;
                    await pointageProv.setDepartureStatus(
                      record: record,
                      status: DepartureStatus.stillWorking,
                      workedMinutesBeforeStop: payload.workedMinutes,
                      incompleteShiftReason: payload.reason,
                      departureAt: payload.departureAt,
                      bypassTimeWindows: true,
                    );
                    await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                  }

                  String fmt(DateTime? d) => d == null
                      ? '--:--'
                      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                  final actionChips = <Widget>[
                    if (present && !isArrangement)
                      FilterChip(
                        label: const Text('Terminé'),
                        selected: r?.departureStatus == DepartureStatus.finished,
                        onSelected: reportConfirmed ? null : (_) => markFinished(),
                      ),
                    if (present && !isArrangement)
                      FilterChip(
                        label: const Text("N'a pas terminé"),
                        selected: r?.departureStatus == DepartureStatus.stillWorking,
                        onSelected: reportConfirmed ? null : (_) => markNotCompleted(),
                      ),
                    if (isReviewer && r != null)
                      FilterChip(
                        label: Text(r.adminFinalStatus == null ? 'Consultation' : 'Confirmé'),
                        selected: r.adminFinalStatus != null,
                        onSelected: null,
                      ),
                  ];
                  final statusChooser = <Widget>[
                    if (isArrangement) ...[
                      Chip(
                        avatar: Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: arrangementPending ? Colors.orange[900] : Colors.green[900],
                        ),
                        backgroundColor: arrangementPending ? const Color(0xFFFFF9C4) : const Color(0xFFFFF59D),
                        label: Text(
                          arrangementPending
                              ? 'E — en attente du retour de l\'autre'
                              : 'E — 8h (arrangement confirmé)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: arrangementPending ? Colors.orange[900] : Colors.green[900],
                          ),
                        ),
                      ),
                    ] else if (isAwayOnRenfort) ...[
                      Chip(
                        avatar: const Icon(Icons.close, size: 16, color: Colors.white),
                        label: const Text(
                          'Absent — Échange Distribution',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: Colors.red[400],
                      ),
                      if (r != null && r.distSwapArrangement)
                        Chip(
                          avatar: Icon(
                            Icons.swap_horiz,
                            size: 16,
                            color: r.distSwapArrangementPending ? Colors.orange[900] : Colors.green[900],
                          ),
                          backgroundColor: r.distSwapArrangementPending
                              ? const Color(0xFFFFF9C4)
                              : const Color(0xFFFFF59D),
                          label: Text(
                            r.distSwapArrangementPending ? 'E — en attente' : 'E — 8h confirmés',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: r.distSwapArrangementPending ? Colors.orange[900] : Colors.green[900],
                            ),
                          ),
                        ),
                    ],
                    if (!isArrangement && !isAwayOnRenfort && !isReviewer && !reportConfirmed) ...[
                      if ((present || absent) && !_manualStatusEditMode.contains(e.id)) ...[
                        Chip(
                          avatar: Icon(
                            present ? Icons.check : Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                          backgroundColor: present ? Colors.green : Colors.red,
                          label: Text(
                            present ? 'Présent' : 'Absent',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ActionChip(
                          label: const Text('Changer'),
                          onPressed: () => setState(() => _manualStatusEditMode.add(e.id)),
                        ),
                      ] else ...[
                        ChefStatusChips(
                          showBothOptions: _manualStatusEditMode.contains(e.id),
                          current: present
                              ? AttendanceState.present
                              : absent
                                  ? AttendanceState.absent
                                  : AttendanceState.unmarked,
                          onSelect: (s) async {
                            if (s == AttendanceState.present) {
                              if (r != null &&
                                  r.departureStatus != DepartureStatus.unset &&
                                  r.id.isNotEmpty) {
                                await pointageProv.resetDepartureStatus(r);
                              }
                              await setPresent();
                              if (mounted) {
                                setState(() => _manualStatusEditMode.remove(e.id));
                              }
                            } else if (s == AttendanceState.absent) {
                              if (r != null &&
                                  r.departureStatus != DepartureStatus.unset &&
                                  r.id.isNotEmpty) {
                                await pointageProv.resetDepartureStatus(r);
                              }
                              await setAbsent();
                              if (mounted) {
                                setState(() => _manualStatusEditMode.remove(e.id));
                              }
                            }
                          },
                          presentLabel: 'Présent',
                          absentLabel: 'Absent',
                        ),
                        if (_manualStatusEditMode.contains(e.id))
                          TextButton(
                            onPressed: () => setState(() => _manualStatusEditMode.remove(e.id)),
                            child: const Text('Annuler'),
                          ),
                      ],
                    ],
                    if (reportConfirmed && (present || absent))
                      Chip(
                        avatar: const Icon(Icons.lock, size: 16),
                        label: const Text('Pointage verrouillé'),
                      ),
                  ];
                  final leaveReqForDay = leaveReqProv.requests.where((req) {
                    final sameEmp = req.employeeId == e.id;
                    final statusOk =
                        req.status == LeaveStatus.pending || req.status == LeaveStatus.approved;
                    final overlapsDay = !day.isBefore(
                          DateTime(req.startDate.year, req.startDate.month, req.startDate.day),
                        ) &&
                        !day.isAfter(DateTime(req.endDate.year, req.endDate.month, req.endDate.day));
                    return sameEmp && statusOk && overlapsDay;
                  }).toList();
                  leaveReqForDay.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final LeaveRequest? activeLeave = leaveReqForDay.isEmpty ? null : leaveReqForDay.first;
                  final overtimeForEmployee = overtimeAssignments.where((a) {
                    final sameEmp = a.employeId == e.id;
                    final sameDay = a.date.year == day.year &&
                        a.date.month == day.month &&
                        a.date.day == day.day;
                    return sameEmp && sameDay;
                  }).toList();
                  overtimeForEmployee.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final OvertimeAssignment? overtimeForDay =
                      overtimeForEmployee.isEmpty ? null : overtimeForEmployee.first;
                  final absenceReasonLabel = getAbsenceReasonLabel(
                    r?.absenceReason,
                    absenceReasonsProv.reasons,
                  );

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: isMobile(context)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  e.nom,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isGuest)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.swap_horiz, size: 13, color: Colors.blue[700]),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Remplaçant (échange)',
                                          style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  isArrangement
                                      ? (arrangementPending
                                          ? 'Arrangement — 8h comptées après le retour de l\'autre'
                                          : 'Arrangement — 8h comptées automatiquement (E)')
                                      : isAwayOnRenfort
                                          ? 'Absent — en manœuvre dans un autre groupe'
                                          : 'Entrée: ${fmt(arrival)}  •  Sortie: ${fmt(departure)}',
                                  style: TextStyle(fontSize: 12, color: isAwayOnRenfort ? Colors.red[300] : Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                if (present && !isArrangement)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Présence confirmée',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                if (absent)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Absence confirmée',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                if (absenceReasonLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Motif absence: $absenceReasonLabel',
                                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                  ),
                                ],
                                if (activeLeave != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Demande congé (${activeLeave.status == LeaveStatus.approved ? 'approuvée' : 'en attente'}): ${activeLeave.leaveTypeLabel}',
                                    style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                                  ),
                                ],
                                if (overtimeForDay != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'HS shift autre équipe: ${overtimeForDay.targetEquipeName} (${overtimeForDay.targetEquipeId})',
                                    style: TextStyle(fontSize: 12, color: Colors.indigo[700]),
                                  ),
                                ],
                                if ((r?.workedMinutesBeforeStop ?? 0) > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Temps travaillé réel: ${((r!.workedMinutesBeforeStop!) / 60).toStringAsFixed(2)} h',
                                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ...statusChooser,
                                    ...actionChips,
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.nom,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isGuest)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.swap_horiz, size: 13, color: Colors.blue[700]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Remplaçant (échange)',
                                                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isArrangement
                                            ? (arrangementPending
                                                ? 'Arrangement — 8h comptées après le retour de l\'autre'
                                                : 'Arrangement — 8h comptées automatiquement (E)')
                                            : isAwayOnRenfort
                                                ? 'Absent — en manœuvre dans un autre groupe'
                                                : 'Entrée: ${fmt(arrival)}  •  Sortie: ${fmt(departure)}',
                                        style: TextStyle(fontSize: 12, color: isAwayOnRenfort ? Colors.red[300] : Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 6),
                                      if (present && !isArrangement)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Présence confirmée',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      if (absent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: const Text(
                                            'Absence confirmée',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      if (absenceReasonLabel.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Motif absence: $absenceReasonLabel',
                                          style: TextStyle(fontSize: 12, color: Colors.red[700]),
                                        ),
                                      ],
                                      if (activeLeave != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Demande congé (${activeLeave.status == LeaveStatus.approved ? 'approuvée' : 'en attente'}): ${activeLeave.leaveTypeLabel}',
                                          style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                                        ),
                                      ],
                                      if (overtimeForDay != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'HS shift autre équipe: ${overtimeForDay.targetEquipeName} (${overtimeForDay.targetEquipeId})',
                                          style: TextStyle(fontSize: 12, color: Colors.indigo[700]),
                                        ),
                                      ],
                                      if ((r?.workedMinutesBeforeStop ?? 0) > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Temps travaillé réel: ${((r!.workedMinutesBeforeStop!) / 60).toStringAsFixed(2)} h',
                                          style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      ...statusChooser,
                                      ...actionChips,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                  final present = <String>[];
                  final absent = <String>[];
                  final absentReasons = <String?>[];
                  for (final row in pointageMembers) {
                    if (row.isArrangement) continue;
                    if (row.isAwayOnRenfort) {
                      absent.add(row.employe.nom);
                      absentReasons.add('Échange Distribution');
                      continue;
                    }
                    final r = recordForRow(row);
                    if (r?.chefStatus == ChefPointageStatus.present) {
                      present.add(row.employe.nom);
                    } else if (r?.chefStatus == ChefPointageStatus.absent) {
                      absent.add(row.employe.nom);
                      absentReasons.add(r?.absenceReason);
                    }
                  }
                  final path = await PointageExportService.shareDailyReportPdfForDriver(
                    date: day,
                    title: 'Rapport Distribution',
                    signatureLabel: 'Responsable Distribution',
                    personName: auth.currentUser?.nom ?? '',
                    equipes: [
                      (
                        equipeName: g.nom,
                        chefName: auth.currentUser?.nom,
                        presentNames: present,
                        presentNoDepartureNames: const <String>[],
                        absentNames: absent,
                        absentReasons: absentReasons,
                      )
                    ],
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF généré: $path')),
                  );
                },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Télécharger PDF (hier)'),
                    ),
                  ),
                ],
              ),
              if (canResetYesterdayPointage) const SizedBox(height: 8),
              if (canResetYesterdayPointage)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Réinitialiser pointage (hier)'),
                        content: Text(
                          'Cette action va supprimer le pointage de ${day.day}/${day.month}/${day.year} '
                          'pour ${g.nom} uniquement. Continuer ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Confirmer'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await pointageProv.clearPointageAndReportsForDay(
                      day,
                      equipeId: 'distribution:${g.id}',
                    );
                    if (!context.mounted) return;
                    await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pointage d\'hier réinitialisé pour ce groupe.')),
                    );
                  },
                  icon: const Icon(Icons.restart_alt, color: Colors.red),
                  label: const Text(
                    'Réinitialiser pointage (hier)',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (!isReviewer && unmarkedNames.isNotEmpty && !reportConfirmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Pointage incomplet (Présent/Absent requis) : ${unmarkedNames.join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ),
              if (!isReviewer && canConfirmAll && incompleteForConfirm.isNotEmpty && !reportConfirmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'À la confirmation, la sortie sera enregistrée automatiquement pour : '
                    '${incompleteForConfirm.map((e) => e.row.employe.nom).join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                  ),
                ),
              if (!isReviewer) const SizedBox(height: 8),
              if (!isReviewer)
                ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: reportConfirmed
                    ? null
                    : () async {
                  if (!canConfirmAll) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          unmarkedNames.isNotEmpty
                              ? 'Marquez Présent ou Absent pour : ${unmarkedNames.join(', ')}'
                              : 'Complétez le pointage de tous les membres.',
                        ),
                      ),
                    );
                    return;
                  }
                  final reasonConfigsList = context.read<AbsenceReasonsProvider>().reasons;
                  final reasonConfigsForSnapshot =
                      reasonConfigsList.isEmpty ? null : reasonConfigsList;
                  try {
                    await withLoadingDialog<void>(
                      context,
                      (() async {
                        final shiftEnd = _shiftEndFor(shift, day);
                        final chefNameConfirm = auth.currentUser?.nom ?? 'Responsable Distribution';
                        for (final row in pointageMembers) {
                          if (row.isArrangement || row.isAwayOnRenfort) continue;
                          var rec = recordForRow(row);
                          if (rec == null || rec.chefStatus == ChefPointageStatus.unset) {
                            if (rec != null && rec.id.isNotEmpty && rec.tempAssigned) {
                              // Remplaçant (renfort) non marqué → absent via renfort record
                              await pointageProv.markRenfortChefAttendance(
                                renfortRecord: rec,
                                chefStatus: ChefPointageStatus.absent,
                                chefId: auth.currentUser?.id,
                                bypassTimeWindows: true,
                              );
                            } else {
                              await pointageProv.markDistributionAttendanceForDate(
                                employeId: row.employe.id,
                                employeNom: row.employe.nom,
                                employeCin: row.employe.cin,
                                equipeId: currentEquipeId,
                                equipeName: 'Distribution: ${g.nom}',
                                chefName: chefNameConfirm,
                                chefStatus: ChefPointageStatus.absent,
                                pointageDate: day,
                                chefId: auth.currentUser?.id,
                              );
                            }
                          }
                          rec = recordForRow(row);
                          if (rec != null &&
                              rec.chefStatus == ChefPointageStatus.present &&
                              rec.departureStatus == DepartureStatus.unset) {
                            await pointageProv.setDepartureStatus(
                              record: rec,
                              status: DepartureStatus.finished,
                              overtimeMinutes: 0,
                              departureAt: shiftEnd,
                              bypassTimeWindows: true,
                            );
                          }
                        }
                        await pointageProv.submitChefReportForDateManual(
                          currentEquipeId,
                          day,
                          equipeName: 'Distribution: ${g.nom}',
                          chefName: chefNameConfirm,
                        );
                        final isRest = distShiftsProv.hasRotationSlotForGroup(g.id) &&
                            distShiftsProv.getShiftForGroup(g.id, day) == ShiftType.rest;
                        final empSnapshots = <({
                          String employeId,
                          String employeNom,
                          String employeCin,
                          String status,
                          String? absenceReason,
                          bool isRestDay,
                        })>[];
                        for (final row in pointageMembers) {
                          if (row.isAwayOnRenfort) {
                            empSnapshots.add((
                              employeId: row.employe.id,
                              employeNom: row.employe.nom,
                              employeCin: row.employe.cin,
                              status: 'absent',
                              absenceReason: 'echange_distribution',
                              isRestDay: isRest,
                            ));
                            continue;
                          }
                          if (row.isArrangement) {
                            empSnapshots.add((
                              employeId: row.employe.id,
                              employeNom: row.employe.nom,
                              employeCin: row.employe.cin,
                              status: row.arrangementPending ? 'arrangement_pending' : 'arrangement',
                              absenceReason: null,
                              isRestDay: isRest,
                            ));
                            continue;
                          }
                          final rec = recordForRow(row);
                          final status = PointageExportService.resolveSnapshotStatus(
                            rec: rec,
                            isGroupScope: false,
                            isDistributionScope: true,
                            reasonConfigs: reasonConfigsForSnapshot,
                          );
                          empSnapshots.add((
                            employeId: row.employe.id,
                            employeNom: row.employe.nom,
                            employeCin: row.employe.cin,
                            status: status,
                            absenceReason:
                                status == 'absent' || status == 'paid_absence'
                                    ? rec?.absenceReason
                                    : null,
                            isRestDay: isRest,
                          ));
                        }
                        if (empSnapshots.isNotEmpty) {
                          await _snapshotRepo.saveEquipeSnapshot(
                            equipeId: currentEquipeId,
                            equipeName: 'Distribution: ${g.nom}',
                            date: day,
                            confirmedById: auth.currentUser?.id ?? '',
                            employees: empSnapshots,
                          );
                        }
                        if (!context.mounted) return;
                        await _reloadPointageDataAfterAction(pointageProv, overtimeProv, day);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rapport Distribution confirmé.')),
                        );
                      })(),
                      message: 'Envoi en cours...',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur : $e')),
                      );
                    }
                  }
                },
                  icon: const Icon(Icons.check_circle),
                  label: Text('Confirmer pointage (${day.day}/${day.month})'),
                ),
            ],
          ),
        );
      },
    );
  }
}

