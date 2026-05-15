import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../shifts/models/shift_models.dart';
import '../shifts/services/shifts_export_service.dart';
import 'distribution_groups_provider.dart';

class DistributionShiftsPage extends StatefulWidget {
  /// Si false (ex. intégré dans la page Shifts admin), masque le titre/sous-titre du haut.
  final bool showPageHeader;

  const DistributionShiftsPage({super.key, this.showPageHeader = true});

  @override
  State<DistributionShiftsPage> createState() => _DistributionShiftsPageState();
}

class _DistributionShiftsPageState extends State<DistributionShiftsPage> {
  static const String _configDocId = 'distribution_shifts_config';
  static const String _overridesCollection = 'distribution_shifts_overrides';
  static const String _doubleDaysCollection = 'double_days';
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _distributionConfigSavedLocally = false;

  @override
  void initState() {
    super.initState();
    _restoreDistributionConfigFlag();
  }

  Future<File> _distributionConfigFlagFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}distribution_shifts_config_saved.flag');
  }

  Future<void> _restoreDistributionConfigFlag() async {
    try {
      final f = await _distributionConfigFlagFile();
      if (await f.exists() && mounted) {
        setState(() => _distributionConfigSavedLocally = true);
      }
    } catch (_) {}
  }

  Future<void> _markDistributionConfigSaved() async {
    try {
      final f = await _distributionConfigFlagFile();
      await f.writeAsString('1', flush: true);
    } catch (_) {}
    if (mounted && !_distributionConfigSavedLocally) {
      setState(() => _distributionConfigSavedLocally = true);
    }
  }

  Future<void> _clearDistributionConfigSavedFlag() async {
    try {
      final f = await _distributionConfigFlagFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted && _distributionConfigSavedLocally) {
      setState(() => _distributionConfigSavedLocally = false);
    }
  }

  ShiftType _shiftForPosition(int position, DateTime day, DateTime startDay) {
    final d = DateTime(day.year, day.month, day.day);
    final diff = d.difference(startDay).inDays;
    final dayInCycle = diff >= 0 ? diff % ShiftRotationLogic.cycleDays : 0;
    return ShiftRotationLogic.shiftForPosition(position, dayInCycle);
  }

  Future<void> _saveConfig({
    required DateTime startDate,
    required List<String> groupIds,
  }) async {
    final auth = context.read<AuthProvider>();
    await FirebaseFirestore.instance.collection('app_config').doc(_configDocId).set({
      'startDate': DateTime(startDate.year, startDate.month, startDate.day).toIso8601String(),
      'equipeIds': groupIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedById': auth.userId ?? '',
      'updatedByName': auth.currentUser?.nom ?? '',
    }, SetOptions(merge: true));
    await _markDistributionConfigSaved();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _shiftLabel(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return tr(context, 'shifts_morning');
      case ShiftType.evening:
        return tr(context, 'shifts_evening');
      case ShiftType.night:
        return tr(context, 'shifts_night');
      case ShiftType.rest:
        return tr(context, 'shifts_rest');
    }
  }

  Color _shiftColor(ShiftType shift) {
    switch (shift) {
      case ShiftType.morning:
        return Colors.green;
      case ShiftType.evening:
        return Colors.orange;
      case ShiftType.night:
        return Colors.indigo;
      case ShiftType.rest:
        return Colors.grey;
    }
  }

  Future<void> _setShiftOverride(DateTime date, String groupId, ShiftType shift) async {
    final key = _dateKey(date);
    final ref = FirebaseFirestore.instance
        .collection('app_config')
        .doc(_configDocId)
        .collection(_overridesCollection)
        .doc(key);
    final doc = await ref.get();
    final Map<String, String> overrides = {};
    final existing = doc.data()?['overrides'];
    if (existing is Map) {
      existing.forEach((k, v) {
        if (v is String) overrides[k.toString()] = v;
      });
    }
    overrides[groupId] = shift.name;
    await ref.set({'date': key, 'overrides': overrides}, SetOptions(merge: true));
  }

  Future<void> _setDoubleDay(DateTime date, {String? label}) async {
    final day = DateTime(date.year, date.month, date.day);
    final key = _dateKey(day);
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc(_configDocId)
        .collection(_doubleDaysCollection)
        .doc(key)
        .set({
      'date': key,
      'label': (label ?? '').trim(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeDoubleDay(DateTime date) async {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc(_configDocId)
        .collection(_doubleDaysCollection)
        .doc(_dateKey(date))
        .delete();
  }

  Future<void> _resetConfig() async {
    final docRef = FirebaseFirestore.instance.collection('app_config').doc(_configDocId);
    final ovSnap = await docRef.collection(_overridesCollection).get();
    for (final d in ovSnap.docs) {
      await d.reference.delete();
    }
    final ddSnap = await docRef.collection(_doubleDaysCollection).get();
    for (final d in ddSnap.docs) {
      await d.reference.delete();
    }
    await docRef.delete();
    await _clearDistributionConfigSavedFlag();
  }

  Future<void> _exportExcelForDateRange({
    required List<String> selectedIds,
    required Map<String, dynamic> groupsById,
    required ShiftType Function(int position, DateTime day, String groupId) resolveShift,
  }) async {
    try {
      final now = DateTime.now();
      final initialStart = DateTime(now.year, now.month, 1);
      final initialEnd = DateTime(now.year, now.month + 1, 0);
      final pickedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      );
      if (pickedRange == null || !mounted) return;

      final start = DateTime(
        pickedRange.start.year,
        pickedRange.start.month,
        pickedRange.start.day,
      );
      final end = DateTime(
        pickedRange.end.year,
        pickedRange.end.month,
        pickedRange.end.day,
      );
      final dayCount = end.difference(start).inDays + 1;
      if (dayCount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
        );
        return;
      }

      final schedule = <({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe})>[];
      for (var i = 0; i < dayCount; i++) {
        final date = start.add(Duration(days: i));
        final perEquipe = <({String equipeId, ShiftType shift})>[];
        for (var pos = 0; pos < 4; pos++) {
          final id = pos < selectedIds.length ? selectedIds[pos] : '';
          final shift = (id.isEmpty || groupsById[id] == null)
              ? ShiftType.rest
              : resolveShift(pos, date, id);
          perEquipe.add((equipeId: id, shift: shift));
        }
        schedule.add((date: date, perEquipe: perEquipe));
      }
      final equipeNames = List<String>.generate(4, (i) {
        final id = i < selectedIds.length ? selectedIds[i] : '';
        final g = groupsById[id];
        return g == null ? '' : (g.nom as String);
      });
      final bytes = await ShiftsExportService.buildShiftsExcel(
        startDate: start,
        endDate: end,
        schedule: schedule,
        equipeNames: equipeNames,
        positionHeaders: [
          trOf(context, 'shifts_table_p1'),
          trOf(context, 'shifts_table_p2'),
          trOf(context, 'shifts_table_p3'),
          trOf(context, 'shifts_table_rh'),
        ],
      );
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
        );
        return;
      }
      final fileName = 'distribution_shifts_${start.day}-${start.month}-${start.year}_${end.day}-${end.month}-${end.year}.xlsx';
      final path = await ShiftsExportService.saveAndOpenExcel(bytes, fileName);
      if (!mounted) return;
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${trOf(context, 'shifts_export_ok')}: $path'), backgroundColor: Colors.green),
      );
    } catch (e, st) {
      debugPrint('Distribution shifts export error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${trOf(context, 'report_no_data')} / Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final groupsProv = context.watch<DistributionGroupsProvider>();

    if (Firebase.apps.isEmpty) {
      return Center(child: Text(tr(context, 'dist_shifts_firebase_unavailable')));
    }

    final allowedIds = auth.distributionGroupIds;
    final groups = allowedIds.isEmpty
        ? groupsProv.groups
        : groupsProv.groups.where((g) => allowedIds.contains(g.id)).toList();
    if (groups.isEmpty) {
      return Center(child: Text(tr(context, 'dist_shifts_no_group_linked')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('app_config').doc(_configDocId).snapshots(),
      builder: (context, snap) {
        final map = snap.data?.data() ?? const <String, dynamic>{};
        final startRaw = map['startDate'] as String?;
        final startDate = DateTime.tryParse(startRaw ?? '') ?? DateTime.now();
        final startDay = DateTime(startDate.year, startDate.month, startDate.day);
        final idsRaw = map['equipeIds'];
        final configuredIds = idsRaw is List ? idsRaw.map((e) => e.toString()).toList() : <String>[];
        final hasAnyConfigured = configuredIds.any((e) => e.trim().isNotEmpty);
        final effectiveIds = hasAnyConfigured
            ? List<String>.generate(4, (i) => i < configuredIds.length ? configuredIds[i] : '')
            : List<String>.generate(4, (i) => i < groups.length ? groups[i].id : '');

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('app_config')
              .doc(_configDocId)
              .collection(_overridesCollection)
              .snapshots(),
          builder: (context, overrideSnap) {
            final overridesByDate = <String, Map<String, ShiftType>>{};
            for (final d in overrideSnap.data?.docs ?? const []) {
              final raw = d.data()['overrides'];
              if (raw is! Map) continue;
              final perGroup = <String, ShiftType>{};
              raw.forEach((k, v) {
                if (v is! String) return;
                try {
                  perGroup[k.toString()] = ShiftType.values.firstWhere((e) => e.name == v);
                } catch (_) {}
              });
              overridesByDate[d.id] = perGroup;
            }

            ShiftType resolveShift(int position, DateTime day, String groupId) {
              final key = _dateKey(day);
              final override = overridesByDate[key]?[groupId];
              if (override != null) return override;
              return _shiftForPosition(position, day, startDay);
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('app_config')
                  .doc(_configDocId)
                  .collection(_doubleDaysCollection)
                  .snapshots(),
              builder: (context, doubleSnap) {
                final doubleDays = <String, String?>{};
                for (final d in doubleSnap.data?.docs ?? const []) {
                  doubleDays[d.id] = (d.data()['label'] as String?)?.trim();
                }
                final isDoubleDay = (DateTime date) => doubleDays.containsKey(_dateKey(date));
                final doubleDayLabel = (DateTime date) => doubleDays[_dateKey(date)];
                if (hasAnyConfigured && !_distributionConfigSavedLocally) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markDistributionConfigSaved();
                  });
                }
                final shouldShowConfig = !hasAnyConfigured && !_distributionConfigSavedLocally;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, widget.showPageHeader ? 16 : 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (widget.showPageHeader) ...[
                    Text(
                      tr(context, 'nav_shifts'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(context, 'dist_shifts_subtitle'),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (shouldShowConfig) ...[
                    _DistributionConfigSection(
                      groups: groups,
                      startDay: startDay,
                      selectedIds: effectiveIds,
                      onSave: _saveConfig,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _DistributionTodaySection(
                    groupsById: {for (final g in groups) g.id: g},
                    selectedIds: effectiveIds,
                    startDay: startDay,
                    resolveShift: resolveShift,
                    shiftLabel: _shiftLabel,
                    shiftColor: _shiftColor,
                  ),
                  const SizedBox(height: 12),
                  _DistributionPlanningSection(
                    groupsById: {for (final g in groups) g.id: g},
                    selectedIds: effectiveIds,
                    month: _month,
                    onMonthChange: (m) => setState(() => _month = m),
                    resolveShift: resolveShift,
                    onEditShift: (date, groupId, shift) => _setShiftOverride(date, groupId, shift),
                    shiftLabel: _shiftLabel,
                    shiftColor: _shiftColor,
                    isDoubleDay: isDoubleDay,
                    doubleDayLabel: doubleDayLabel,
                    onExportExcel: () => _exportExcelForDateRange(
                      selectedIds: effectiveIds,
                      groupsById: {for (final g in groups) g.id: g},
                      resolveShift: resolveShift,
                    ),
                    onResetConfig: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(tr(ctx, 'shifts_reset_config')),
                          content: Text(tr(ctx, 'shifts_reset_confirm')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ctx, 'cancel'))),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ctx, 'shifts_reset_confirm_btn'))),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await _resetConfig();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr(context, 'shifts_reset_done')), backgroundColor: Colors.orange),
                      );
                    },
                    onAddDoubleDay: _setDoubleDay,
                    onRemoveDoubleDay: _removeDoubleDay,
                  ),
                ],
              ),
            );
              },
            );
          },
        );
      },
    );
  }
}

class _DistributionConfigSection extends StatefulWidget {
  final List<dynamic> groups;
  final DateTime startDay;
  final List<String> selectedIds;
  final Future<void> Function({required DateTime startDate, required List<String> groupIds}) onSave;

  const _DistributionConfigSection({
    required this.groups,
    required this.startDay,
    required this.selectedIds,
    required this.onSave,
  });

  @override
  State<_DistributionConfigSection> createState() => _DistributionConfigSectionState();
}

class _DistributionConfigSectionState extends State<_DistributionConfigSection> {
  late DateTime _startDate;
  late List<String?> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDay;
    _selectedIds = widget.selectedIds.map((e) => e.isEmpty ? null : e).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(context, 'shifts_config'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked == null) return;
                      setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
                    },
              icon: const Icon(Icons.calendar_today),
              label: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < 4; i++) ...[
              Text(
                tr(context, 'dist_shifts_group_position').replaceAll('%s', '${i + 1}'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedIds[i],
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('—')),
                  ...widget.groups.map(
                    (g) => DropdownMenuItem<String>(value: g.id as String, child: Text(g.nom as String)),
                  ),
                ],
                onChanged: _saving ? null : (v) => setState(() => _selectedIds[i] = v),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onSave(
                          startDate: _startDate,
                          groupIds: _selectedIds.map((e) => e ?? '').toList(),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(context, 'dist_shifts_config_saved')), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${tr(context, 'dist_shifts_error_prefix')}: $e'), backgroundColor: Colors.red),
                        );
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? tr(context, 'dist_shifts_saving') : tr(context, 'shifts_save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionTodaySection extends StatelessWidget {
  final Map<String, dynamic> groupsById;
  final List<String> selectedIds;
  final DateTime startDay;
  final ShiftType Function(int position, DateTime day, String groupId) resolveShift;
  final String Function(ShiftType shift) shiftLabel;
  final Color Function(ShiftType shift) shiftColor;

  const _DistributionTodaySection({
    required this.groupsById,
    required this.selectedIds,
    required this.startDay,
    required this.resolveShift,
    required this.shiftLabel,
    required this.shiftColor,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final mobile = isMobile(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(context, 'shifts_today'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (var i = 0; i < 4; i++) ...[
              Builder(
                builder: (_) {
                  final id = i < selectedIds.length ? selectedIds[i] : '';
                  final group = groupsById[id];
                  if (id.isEmpty || group == null) {
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(child: Icon(Icons.groups_2)),
                      title: Text(
                        tr(context, 'dist_shifts_group_position')
                            .replaceAll('%s', '${i + 1}')
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(tr(context, 'dist_shifts_not_configured')),
                    );
                  }
                  final shift = resolveShift(i, today, id);
                  final color = shiftColor(shift);
                  if (mobile) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x11000000)),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(Icons.groups_2, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (group.nom as String).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${shiftLabel(shift)} ${shift.timeRange.replaceAll('–', '-')}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    label: Text(
                                      shiftLabel(shift),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: color.withValues(alpha: 0.15),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(Icons.groups_2, color: color),
                    ),
                    title: Text(
                      (group.nom as String).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${shiftLabel(shift)} ${shift.timeRange.replaceAll('–', '-')}'),
                    trailing: Chip(
                      label: Text(shiftLabel(shift), style: const TextStyle(fontSize: 12)),
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DistributionPlanningSection extends StatelessWidget {
  final Map<String, dynamic> groupsById;
  final List<String> selectedIds;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChange;
  final ShiftType Function(int position, DateTime day, String groupId) resolveShift;
  final Future<void> Function(DateTime date, String groupId, ShiftType shift) onEditShift;
  final String Function(ShiftType shift) shiftLabel;
  final Color Function(ShiftType shift) shiftColor;
  final bool Function(DateTime date) isDoubleDay;
  final String? Function(DateTime date) doubleDayLabel;
  final Future<void> Function() onExportExcel;
  final Future<void> Function() onResetConfig;
  final Future<void> Function(DateTime date, {String? label}) onAddDoubleDay;
  final Future<void> Function(DateTime date) onRemoveDoubleDay;

  const _DistributionPlanningSection({
    required this.groupsById,
    required this.selectedIds,
    required this.month,
    required this.onMonthChange,
    required this.resolveShift,
    required this.onEditShift,
    required this.shiftLabel,
    required this.shiftColor,
    required this.isDoubleDay,
    required this.doubleDayLabel,
    required this.onExportExcel,
    required this.onResetConfig,
    required this.onAddDoubleDay,
    required this.onRemoveDoubleDay,
  });

  static const List<String> _monthNamesShort = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
  ];
  static const List<String> _monthNamesLong = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = List.generate(days, (i) => first.add(Duration(days: i)));
    final positionHeaders = [
      tr(context, 'shifts_table_p1'),
      tr(context, 'shifts_table_p2'),
      tr(context, 'shifts_table_p3'),
      tr(context, 'shifts_table_rh'),
    ];
    final groupNames = List<String>.generate(4, (i) {
      final id = i < selectedIds.length ? selectedIds[i] : '';
      final g = groupsById[id];
      return g == null ? '' : (g.nom as String);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(context, 'shifts_schedule'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: onExportExcel,
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(tr(context, 'shifts_export_excel')),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onResetConfig,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(tr(context, 'shifts_reset_config')),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: month,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked == null) return;
                            final labelCtrl = TextEditingController(text: doubleDayLabel(picked) ?? '');
                            final action = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Jour ×2'),
                                content: TextField(
                                  controller: labelCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Label (optionnel)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                actions: [
                                  if (isDoubleDay(picked))
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, 'remove'),
                                      child: const Text('Supprimer'),
                                    ),
                                  TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(tr(ctx, 'cancel'))),
                                  FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Enregistrer')),
                                ],
                              ),
                            );
                            if (action == 'remove') {
                              await onRemoveDoubleDay(DateTime(picked.year, picked.month, picked.day));
                            } else if (action == 'save') {
                              await onAddDoubleDay(DateTime(picked.year, picked.month, picked.day), label: labelCtrl.text.trim());
                            }
                          },
                          icon: const Icon(Icons.event_available),
                          label: const Text('Jour férié ×2'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onExportExcel,
                        icon: const Icon(Icons.download, size: 16),
                        label: Text(tr(context, 'shifts_export_excel')),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: onResetConfig,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(tr(context, 'shifts_reset_config')),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: month,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked == null) return;
                          final labelCtrl = TextEditingController(text: doubleDayLabel(picked) ?? '');
                          final action = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Jour ×2'),
                              content: TextField(
                                controller: labelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Label (optionnel)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                if (isDoubleDay(picked))
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, 'remove'),
                                    child: const Text('Supprimer'),
                                  ),
                                TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: Text(tr(ctx, 'cancel'))),
                                FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Enregistrer')),
                              ],
                            ),
                          );
                          if (action == 'remove') {
                            await onRemoveDoubleDay(DateTime(picked.year, picked.month, picked.day));
                          } else if (action == 'save') {
                            await onAddDoubleDay(DateTime(picked.year, picked.month, picked.day), label: labelCtrl.text.trim());
                          }
                        },
                        icon: const Icon(Icons.event_available),
                        label: const Text('Jour férié ×2'),
                      ),
                    ],
                  ),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<int>(
                  value: month.month,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text(_monthNamesShort[i]),
                    ),
                  ),
                  onChanged: (v) {
                    if (v == null) return;
                    onMonthChange(DateTime(month.year, v, 1));
                  },
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: month.year,
                  items: List.generate(5, (i) {
                    final y = DateTime.now().year - 1 + i;
                    return DropdownMenuItem<int>(value: y, child: Text('$y'));
                  }),
                  onChanged: (v) {
                    if (v == null) return;
                    onMonthChange(DateTime(v, month.month, 1));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_monthNamesLong[month.month - 1]} ${month.year}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: [
                  DataColumn(
                    label: Text(
                      tr(context, 'shifts_table_date'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 11 : 12),
                    ),
                  ),
                  for (var pos = 0; pos < 4; pos++)
                    DataColumn(
                      label: Text(
                        '${positionHeaders[pos]}\n(${groupNames[pos]})',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 10 : 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                rows: rows.map((d) {
                  ShiftType? cellShift(int i) {
                    final id = i < selectedIds.length ? selectedIds[i] : '';
                    final g = groupsById[id];
                    if (id.isEmpty || g == null) return null;
                    return resolveShift(i, d, id);
                  }

                  DataCell editableCell(int i) {
                    final id = i < selectedIds.length ? selectedIds[i] : '';
                    final shift = cellShift(i);
                    if (id.isEmpty || shift == null) return const DataCell(Text('—'));
                    final color = shiftColor(shift);
                    return DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${shiftLabel(shift)} ${shift.timeRange.replaceAll('–', '-')}',
                          style: TextStyle(
                            color: color.withValues(alpha: 0.95),
                            fontWeight: FontWeight.normal,
                            fontSize: mobile ? 10 : 12,
                          ),
                        ),
                      ),
                      onTap: () async {
                        final chosen = await showDialog<ShiftType>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(tr(context, 'dist_shifts_edit_shift')),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: ShiftType.values
                                  .map(
                                    (s) => ListTile(
                                      leading: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: shiftColor(s).withValues(alpha: 0.2),
                                        child: Icon(Icons.schedule, size: 14, color: shiftColor(s)),
                                      ),
                                      title: Text('${shiftLabel(s)} (${s.timeRange.replaceAll('–', '-')})'),
                                      onTap: () => Navigator.pop(ctx, s),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        );
                        if (chosen == null) return;
                        await onEditShift(d, id, chosen);
                      },
                    );
                  }

                  return DataRow(
                    color: isDoubleDay(d)
                        ? WidgetStateProperty.all(Colors.orange.shade50)
                        : null,
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${d.day}/${d.month}',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: mobile ? 11 : 12),
                            ),
                            if (isDoubleDay(d)) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: (doubleDayLabel(d)?.isNotEmpty ?? false) ? '×2 — ${doubleDayLabel(d)}' : 'Jour ×2',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade700,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('×2', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      editableCell(0),
                      editableCell(1),
                      editableCell(2),
                      editableCell(3),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

