import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../modules/employees/employees_provider.dart';
import '../../modules/employees/models/equipe_model.dart';
import '../distribution/distribution_shifts_page.dart';
import 'models/shift_models.dart';
import 'shifts_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import 'services/shifts_export_service.dart';

enum _AdminShiftsScope { equipes, distribution }

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  bool _loadingTooLong = false;
  Timer? _loadTimer;
  _AdminShiftsScope _adminScope = _AdminShiftsScope.equipes;

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadingTooLong = false;
    _loadTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      final shifts = context.read<ShiftsProvider>();
      if (shifts.loading) {
        setState(() => _loadingTooLong = true);
      }
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  Widget _shiftsTitleHeader(BuildContext context, {required bool distributionMode}) {
    return Row(
      children: [
        Icon(Icons.rotate_right, color: Colors.grey[700], size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                distributionMode ? tr(context, 'shifts_title_distribution') : tr(context, 'shifts_title'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                distributionMode ? tr(context, 'dist_shifts_subtitle') : tr(context, 'shifts_subtitle'),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final emp = context.watch<EmployeesProvider>();
    final shifts = context.watch<ShiftsProvider>();
    final isRtl = locale.isArabic;
    final isAdmin = auth.isDirecteur;
    final mobile = isMobile(context);
    final equipes = SiteId.filterBySite(
      emp.equipes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );
    final pad = pagePadding(context);

    final equipesBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
            if (shifts.loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: _loadingTooLong
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text('Connexion lente ou indisponible.',
                                style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                _startLoadTimer();
                                context.read<ShiftsProvider>().refresh();
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Réessayer'),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(),
                ),
              )
            else if (shifts.error != null)
              Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    SizedBox(width: 12),
                    Expanded(child: Text(shifts.error!, style: TextStyle(color: Colors.red.shade900))),
                    SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => context.read<ShiftsProvider>().refresh(),
                      icon: Icon(Icons.refresh, size: 18),
                      label: Text('Réessayer'),
                    ),
                  ]),
                ),
              )
            else if (!shifts.hasConfig) ...[
              Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(tr(context, 'shifts_no_config'), style: TextStyle(color: Colors.orange.shade900)),
                ),
              ),
              if (isAdmin) ...[
                SizedBox(height: 20),
                _ConfigSection(equipes: equipes),
              ],
            ]
            else ...[
              _TodaySummary(equipes: equipes),
              SizedBox(height: 24),
              if (isAdmin)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'shifts_schedule'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            message: tr(context, 'shifts_refresh_tooltip'),
                            child: IconButton(
                              icon: const Icon(Icons.sync, size: 22),
                              onPressed: () async {
                                await context.read<ShiftsProvider>().refresh();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(tr(context, 'shifts_refreshed')), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                                  );
                                }
                              },
                            ),
                          ),
                          SizedBox(width: mobile ? 2 : 4),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(tr(context, 'shifts_export_excel')),
                            onPressed: () => _showShiftsExportDialog(context, shifts, equipes),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 20),
                            label: Text(tr(context, 'shifts_reset_config')),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(tr(ctx, 'shifts_reset_config')),
                                  content: Text(tr(ctx, 'shifts_reset_confirm')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
                                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ctx, 'shifts_reset_confirm_btn'))),
                                  ],
                                ),
                              );
                              if (ok == true && context.mounted) {
                                final now = DateTime.now();
                                await context.read<ShiftsProvider>().setConfig(RotationConfig(
                                  startDate: DateTime(now.year, now.month, now.day),
                                  equipeIds: ['', '', '', ''],
                                ));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(tr(context, 'shifts_reset_done')), backgroundColor: Colors.orange),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, 'shifts_schedule'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 18),
                        label: Text(tr(context, 'shifts_export_excel')),
                        onPressed: () => _showShiftsExportDialog(context, shifts, equipes),
                      ),
                    ),
                  ],
                ),
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 280),
                child: _ScheduleTable(equipes: equipes, isAdmin: isAdmin),
              ),
              SizedBox(height: 32),
              _DoubleDaysSection(isAdmin: isAdmin),
            ],
      ],
    );

    if (!isAdmin) {
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _shiftsTitleHeader(context, distributionMode: false),
              SizedBox(height: 24),
              equipesBody,
            ],
          ),
        ),
      );
    }

    final hideDistributionShifts = auth.isChefAtelierAdmin;
    final adminScopeEffective = hideDistributionShifts
        ? _AdminShiftsScope.equipes
        : _adminScope;
    final distributionMode = adminScopeEffective == _AdminShiftsScope.distribution;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _shiftsTitleHeader(context, distributionMode: distributionMode),
          if (!hideDistributionShifts) ...[
            SizedBox(height: 12),
            SegmentedButton<_AdminShiftsScope>(
              segments: [
                ButtonSegment<_AdminShiftsScope>(
                  value: _AdminShiftsScope.equipes,
                  label: Text(tr(context, 'shifts_filter_equipes')),
                  icon: Icon(Icons.groups_outlined, size: 18),
                ),
                ButtonSegment<_AdminShiftsScope>(
                  value: _AdminShiftsScope.distribution,
                  label: Text(tr(context, 'shifts_filter_distribution')),
                  icon: Icon(Icons.local_shipping_outlined, size: 18),
                ),
              ],
              selected: {_adminScope},
              onSelectionChanged: (Set<_AdminShiftsScope> next) {
                setState(() => _adminScope = next.first);
              },
            ),
          ],
        ],
      ),
    );

    if (mobile && adminScopeEffective == _AdminShiftsScope.equipes) {
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 0),
                child: equipesBody,
              ),
            ],
          ),
        ),
      );
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: 16),
          Expanded(
            child: adminScopeEffective == _AdminShiftsScope.distribution
                ? Padding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                    child: DistributionShiftsPage(showPageHeader: false),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                    child: equipesBody,
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showShiftsExportDialog(BuildContext context, ShiftsProvider shifts, List<Equipe> equipes) async {
  final config = shifts.config;
  if (config == null) return;
  final equipeNames = config.equipeIds.map((id) {
    final eq = equipes.where((e) => e.id == id).toList();
    return eq.isEmpty ? id : eq.first.nom;
  }).toList();
  final positionHeaders = [
    trOf(context, 'shifts_table_p1'),
    trOf(context, 'shifts_table_p2'),
    trOf(context, 'shifts_table_p3'),
    trOf(context, 'shifts_table_rh'),
  ];
  if (!context.mounted) return;

  // بدلاً من حوار مخصص قد لا يظهر على بعض الأجهزة،
  // نستخدم `showDateRangePicker` القياسي لاختيار الفترة.
  final now = DateTime.now();
  final initialStart = DateTime(now.year, now.month, 1);
  final initialEnd = DateTime(now.year, now.month + 1, 0);
  final pickedRange = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
  );
  if (pickedRange == null || !context.mounted) return;
  final start = DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day);
  final end = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day);
  final dayCount = end.difference(start).inDays + 1;
  if (dayCount <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
      );
    }
    return;
  }
  final schedule = shifts.getScheduleForDays(start, dayCount);
  if (schedule.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
      );
    }
    return;
  }
  try {
    final bytes = await ShiftsExportService.buildShiftsExcel(
      startDate: start,
      endDate: end,
      schedule: schedule,
      equipeNames: equipeNames,
      positionHeaders: positionHeaders,
    );
    if (bytes.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trOf(context, 'report_no_data')), backgroundColor: Colors.orange),
      );
      return;
    }
    final fileName = 'shifts_${start.day}-${start.month}-${start.year}_${end.day}-${end.month}-${end.year}.xlsx';
    final filePath = await ShiftsExportService.saveAndOpenExcel(bytes, fileName);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${trOf(context, 'shifts_export_ok')}: $filePath'), backgroundColor: Colors.green),
      );
    }
  } catch (e, st) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'report_no_data')} / Erreur: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    debugPrint('Shifts export error: $e\n$st');
  }
}

class _TodaySummary extends StatelessWidget {
  final List<Equipe> equipes;

  const _TodaySummary({required this.equipes});

  String _shiftLabel(BuildContext context, ShiftType s) {
    switch (s) {
      case ShiftType.morning: return tr(context, 'shifts_morning');
      case ShiftType.evening: return tr(context, 'shifts_evening');
      case ShiftType.night: return tr(context, 'shifts_night');
      case ShiftType.rest: return tr(context, 'shifts_rest');
    }
  }

  Color _shiftColor(ShiftType s) {
    switch (s) {
      case ShiftType.morning: return Colors.green;
      case ShiftType.evening: return Colors.orange;
      case ShiftType.night: return Colors.indigo;
      case ShiftType.rest: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shifts = context.watch<ShiftsProvider>();
    final config = shifts.config!;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);

    final items = <Widget>[];
    for (var i = 0; i < config.equipeIds.length; i++) {
      final eid = config.equipeIds[i];
      if (eid.isEmpty) continue;
      final eqList = equipes.where((e) => e.id == eid).toList();
      final name = eqList.isEmpty ? eid : eqList.first.nom;
      final shift = ShiftRotationLogic.shiftForPosition(i, shifts.dayInCycle(day));
      final color = _shiftColor(shift);
      items.add(
        Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.groups, color: color)),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${_shiftLabel(context, shift)} — ${shift.timeRange}'),
            trailing: Chip(
              label: Text(_shiftLabel(context, shift), style: TextStyle(fontSize: 12)),
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'shifts_today'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        ...items,
      ],
    );
  }
}

class _ScheduleTable extends StatefulWidget {
  final List<Equipe> equipes;
  final bool isAdmin;

  const _ScheduleTable({required this.equipes, this.isAdmin = false});

  @override
  State<_ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<_ScheduleTable> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  String _shiftLabel(BuildContext context, ShiftType s) {
    switch (s) {
      case ShiftType.morning: return tr(context, 'shifts_morning');
      case ShiftType.evening: return tr(context, 'shifts_evening');
      case ShiftType.night: return tr(context, 'shifts_night');
      case ShiftType.rest: return tr(context, 'shifts_rest');
    }
  }

  Color _shiftColor(ShiftType s) {
    switch (s) {
      case ShiftType.morning: return Colors.green;
      case ShiftType.evening: return Colors.orange;
      case ShiftType.night: return Colors.indigo;
      case ShiftType.rest: return Colors.grey;
    }
  }

  /// عدد أيام الشهر (شهر 1–12). شباط 28 أو 29 حسب السنة الكبيسة.
  int _daysInMonth(int year, int month) {
    const daysPerMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    return daysPerMonth[month - 1];
  }

  static const List<String> _monthNamesShort = [
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
  ];
  static const List<String> _monthNamesLong = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  /// الأشهر المعروضة: الشهر المختار فقط.
  List<({int year, int month})> _monthsToShow() {
    return [(year: _year, month: _month)];
  }

  @override
  Widget build(BuildContext context) {
    final shifts = context.watch<ShiftsProvider>();
    final config = shifts.config!;
    final mobile = isMobile(context);

    final equipeNames = config.equipeIds.map((id) {
      final eqList = widget.equipes.where((e) => e.id == id).toList();
      return eqList.isEmpty ? id : eqList.first.nom;
    }).toList();

    final monthsToShow = _monthsToShow();
    final positionHeaders = [tr(context, 'shifts_table_p1'), tr(context, 'shifts_table_p2'), tr(context, 'shifts_table_p3'), tr(context, 'shifts_table_rh')];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DropdownButton<int>(
              value: _month,
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNamesShort[i]))),
              onChanged: (v) => setState(() => _month = v ?? _month),
            ),
            SizedBox(width: 12),
            DropdownButton<int>(
              value: _year,
              items: List.generate(5, (i) {
                final y = DateTime.now().year - 1 + i;
                return DropdownMenuItem(value: y, child: Text('$y'));
              }),
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
          ],
        ),
        SizedBox(height: 16),
        ...monthsToShow.map((m) {
          final daysInMonth = _daysInMonth(m.year, m.month);
          final startDay = DateTime(m.year, m.month, 1);
          final schedule = shifts.getScheduleForDays(startDay, daysInMonth);
          if (schedule.isEmpty) return SizedBox.shrink();
          final monthTitle = '${_monthNamesLong[m.month - 1]} ${m.year}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    monthTitle,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columns: [
                      DataColumn(label: Text(tr(context, 'shifts_table_date'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 11 : 12))),
                      for (var pos = 0; pos < 4; pos++)
                        DataColumn(
                          label: Text(
                            '${positionHeaders[pos]}\n(${equipeNames.length > pos ? equipeNames[pos] : ''})',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 10 : 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    rows: [
                      for (final s in schedule) ...[
                        () {
                          final isDouble = shifts.isDoubleDay(s.date);
                          final doubleLabel = shifts.doubleDayLabel(s.date);
                          return DataRow(
                            color: isDouble
                                ? WidgetStateProperty.all(Colors.orange.shade50)
                                : null,
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${s.date.day}/${s.date.month}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: mobile ? 11 : 12,
                                        color: isDouble ? Colors.orange.shade900 : null,
                                      ),
                                    ),
                                    if (isDouble) ...[
                                      const SizedBox(width: 4),
                                      Tooltip(
                                        message: doubleLabel?.isNotEmpty == true ? '×2 — $doubleLabel' : 'Jour ×2',
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
                              for (var pos = 0; pos < 4; pos++)
                                DataCell(_buildShiftCell(context, shifts, s, pos, config, mobile, isDouble: isDouble)),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildShiftCell(
    BuildContext context,
    ShiftsProvider shifts,
    ({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe}) s,
    int pos,
    RotationConfig config,
    bool mobile, {
    bool isDouble = false,
  }) {
    final shift = s.perEquipe.length > pos ? s.perEquipe[pos].shift : ShiftType.rest;
    final equipeId = config.equipeIds.length > pos ? config.equipeIds[pos] : '';
    final isWorking = shift != ShiftType.rest;
    return InkWell(
      onTap: widget.isAdmin && equipeId.isNotEmpty
          ? () => _showEditShiftDialog(context, shifts, s.date, equipeId, shift)
          : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _shiftColor(shift).withValues(alpha: isDouble && isWorking ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(6),
              border: isDouble && isWorking
                  ? Border.all(color: Colors.orange.shade400, width: 1.5)
                  : null,
            ),
            child: Text(
              '${_shiftLabel(context, shift)} ${shift.timeRange.replaceAll('–', '-')}',
              style: TextStyle(
                fontSize: mobile ? 10 : 12,
                fontWeight: isDouble && isWorking ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          if (isDouble && isWorking)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('★', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditShiftDialog(BuildContext context, ShiftsProvider shifts, DateTime date, String equipeId, ShiftType current) async {
    final chosen = await showDialog<ShiftType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${date.day}/${date.month}/${date.year}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ShiftType.values.map((s) {
            return ListTile(
              leading: Icon(Icons.schedule, color: _shiftColor(s)),
              title: Text(_shiftLabel(ctx, s)),
              subtitle: s != ShiftType.rest ? Text(s.timeRange) : null,
              selected: s == current,
              onTap: () => Navigator.pop(ctx, s),
            );
          }).toList(),
        ),
      ),
    );
    if (chosen != null && chosen != current && context.mounted) {
      await shifts.setShiftOverride(date, equipeId, chosen);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'shifts_save')), backgroundColor: Colors.green),
        );
      }
    }
  }
}

/// حوار اختيار الفترة: شهر محدد، سنة كاملة، أو مدى مخصص.
class _ShiftsExportRangeDialog extends StatefulWidget {
  @override
  State<_ShiftsExportRangeDialog> createState() => _ShiftsExportRangeDialogState();
}

class _ShiftsExportRangeDialogState extends State<_ShiftsExportRangeDialog> {
  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
  ];

  int _mode = 0; // 0=month, 1=year, 2=custom
  late int _month;
  late int _year;
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = now.month;
    _year = now.year;
    _customStart = DateTime(now.year, now.month, 1);
    _customEnd = DateTime(now.year, now.month, now.day);
  }

  int _daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  ({DateTime start, DateTime end}) _getRange() {
    switch (_mode) {
      case 0:
        final start = DateTime(_year, _month, 1);
        final end = DateTime(_year, _month, _daysInMonth(_year, _month));
        return (start: start, end: end);
      case 1:
        final start = DateTime(_year, 1, 1);
        final end = DateTime(_year, 12, 31);
        return (start: start, end: end);
      case 2:
        return (start: _customStart, end: _customEnd);
      default:
        return (start: DateTime.now(), end: DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(context, 'shifts_export_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, 'shifts_export_select_period'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            SizedBox(height: 12),
            RadioListTile<int>(
              title: Text(tr(context, 'shifts_export_month')),
              value: 0,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? 0),
            ),
            if (_mode == 0) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 320;
                    if (!compact) {
                      return Row(
                        children: [
                          DropdownButton<int>(
                            value: _month,
                            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                            onChanged: (v) => setState(() => _month = v ?? _month),
                          ),
                          SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _year,
                            items: List.generate(5, (i) {
                              final y = DateTime.now().year - 1 + i;
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            }),
                            onChanged: (v) => setState(() => _year = v ?? _year),
                          ),
                        ],
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          DropdownButton<int>(
                            value: _month,
                            items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                            onChanged: (v) => setState(() => _month = v ?? _month),
                          ),
                          SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _year,
                            items: List.generate(5, (i) {
                              final y = DateTime.now().year - 1 + i;
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            }),
                            onChanged: (v) => setState(() => _year = v ?? _year),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            RadioListTile<int>(
              title: Text(tr(context, 'shifts_export_year')),
              value: 1,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? 1),
            ),
            if (_mode == 1)
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: DropdownButton<int>(
                  value: _year,
                  items: List.generate(5, (i) {
                    final y = DateTime.now().year - 1 + i;
                    return DropdownMenuItem(value: y, child: Text('$y'));
                  }),
                  onChanged: (v) => setState(() => _year = v ?? _year),
                ),
              ),
            RadioListTile<int>(
              title: Text(tr(context, 'shifts_export_custom')),
              value: 2,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v ?? 2),
            ),
            if (_mode == 2) ...[
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, 'shifts_export_from')),
                      trailing: TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(context: context, initialDate: _customStart, firstDate: DateTime(2020), lastDate: DateTime(2030));
                          if (p != null) setState(() => _customStart = DateTime(p.year, p.month, p.day));
                        },
                        child: Text('${_customStart.day}/${_customStart.month}/${_customStart.year}'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, 'shifts_export_to')),
                      trailing: TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(context: context, initialDate: _customEnd, firstDate: _customStart, lastDate: DateTime(2030));
                          if (p != null) setState(() => _customEnd = DateTime(p.year, p.month, p.day));
                        },
                        child: Text('${_customEnd.day}/${_customEnd.month}/${_customEnd.year}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _getRange()),
          child: Text(tr(context, 'shifts_export_excel')),
        ),
      ],
    );
  }
}

class _ConfigSection extends StatefulWidget {
  final List<Equipe> equipes;

  const _ConfigSection({required this.equipes});

  @override
  State<_ConfigSection> createState() => _ConfigSectionState();
}

class _ConfigSectionState extends State<_ConfigSection> {
  late DateTime _startDate;
  late List<String?> _selectedIds;
  late ShiftsProvider _shifts;
  /// True si l’utilisateur a modifié le formulaire localement — on n’écrase pas avec le provider.
  bool _dirty = false;

  String _positionHintKey(int positionIndex) {
    switch (positionIndex) {
      case 0: return tr(context, 'shifts_config_position_hint_p1');
      case 1: return tr(context, 'shifts_config_position_hint_p2');
      case 2: return tr(context, 'shifts_config_position_hint_p3');
      case 3: return tr(context, 'shifts_config_position_hint_rh');
      default: return '';
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _selectedIds = ['', '', '', ''];
    _shifts = context.read<ShiftsProvider>();
    _shifts.addListener(_onShiftsChanged);
    _applyProviderToForm();
  }

  void _onShiftsChanged() {
    if (!mounted || _dirty) return;
    setState(_applyProviderToForm);
  }

  /// Aligner le formulaire sur Firestore / cache (une fois le chargement terminé).
  void _applyProviderToForm() {
    if (_shifts.loading) return;
    final config = _shifts.config;
    if (config == null) return;
    _startDate = config.startDay;
    if (!config.equipeIds.any((id) => id.isNotEmpty)) {
      _selectedIds = ['', '', '', ''];
      return;
    }
    for (var i = 0; i < 4; i++) {
      final v = i < config.equipeIds.length ? config.equipeIds[i] : '';
      _selectedIds[i] = v.isEmpty ? '' : v;
    }
  }

  @override
  void dispose() {
    _shifts.removeListener(_onShiftsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final equipes = widget.equipes;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr(context, 'shifts_config'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(tr(context, 'shifts_config_start')),
            SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _dirty = true;
                    _startDate = DateTime(picked.year, picked.month, picked.day);
                  });
                }
              },
              icon: Icon(Icons.calendar_today),
              label: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(tr(context, 'shifts_config_position_legend'), style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            ),
            SizedBox(height: 20),
            for (var i = 0; i < 4; i++) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, 'shifts_config_equipe').replaceAll('%s', '${i + 1}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_positionHintKey(i), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(tr(context, 'shifts_config_equipe').replaceAll('%s', '${i + 1}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(_positionHintKey(i), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  );
                },
              ),
              SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedIds[i]?.isEmpty ?? true ? null : _selectedIds[i],
                decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [
                  DropdownMenuItem(value: null, child: Text('—')),
                  ...equipes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nom))),
                ],
                onChanged: (v) => setState(() {
                  _dirty = true;
                  _selectedIds[i] = v ?? '';
                }),
              ),
              SizedBox(height: 12),
            ],
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final ids = _selectedIds.map((v) => v ?? '').toList();
                if (ids.length != 4) return;
                await context.read<ShiftsProvider>().setConfig(RotationConfig(startDate: _startDate, equipeIds: ids));
                if (mounted) {
                  setState(() => _dirty = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'shifts_save')), backgroundColor: Colors.green));
                }
              },
              icon: Icon(Icons.save),
              label: Text(tr(context, 'shifts_save')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Jours ×2 ────────────────────────────────────────────────────────

class _DoubleDaysSection extends StatefulWidget {
  final bool isAdmin;
  const _DoubleDaysSection({required this.isAdmin});

  @override
  State<_DoubleDaysSection> createState() => _DoubleDaysSectionState();
}

class _DoubleDaysSectionState extends State<_DoubleDaysSection> {
  int _filterYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final shifts = context.watch<ShiftsProvider>();
    final allDays = shifts.doubleDays;
    final years = <int>{};
    for (final d in allDays) years.add(d.date.year);
    years.add(_filterYear);
    final sortedYears = years.toList()..sort();

    final filtered = allDays.where((d) => d.date.year == _filterYear).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête ──
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            if (!compact) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('×2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Jours ×2',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _filterYear,
                    underline: const SizedBox(),
                    items: sortedYears.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) => setState(() => _filterYear = v ?? _filterYear),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _showAddDoubleDayDialog(context, shifts),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text('×2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Jours ×2',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      DropdownButton<int>(
                        value: _filterYear,
                        underline: const SizedBox(),
                        items: sortedYears.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (v) => setState(() => _filterYear = v ?? _filterYear),
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showAddDoubleDayDialog(context, shifts),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Ajouter', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        Text(
          'Jours de travail doublé (×2) — shifts comptés double.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 14),

        // ── Contenu ──
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'Aucun jour ×2 pour $_filterYear',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          )
        else
          _DoubleDaysCalendarView(
            days: filtered,
            year: _filterYear,
            isAdmin: widget.isAdmin,
            onRemove: (d) => shifts.removeDoubleDay(d.date),
          ),
      ],
    );
  }

  Future<void> _showAddDoubleDayDialog(BuildContext context, ShiftsProvider shifts) async {
    final now = DateTime.now();
    DateTime? pickedDate;
    final labelCtrl = TextEditingController();
    bool useRange = false;
    DateTime? rangeStart;
    DateTime? rangeEnd;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              const Text('Ajouter jour(s) ×2'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Date unique'),
                      selected: !useRange,
                      onSelected: (_) => setS(() { useRange = false; rangeStart = null; rangeEnd = null; }),
                    ),
                    ChoiceChip(
                      label: const Text('Plage de dates'),
                      selected: useRange,
                      onSelected: (_) => setS(() { useRange = true; pickedDate = null; }),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!useRange) ...[
                  const Text('Date :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: pickedDate ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (d != null) setS(() => pickedDate = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(pickedDate != null
                        ? '${pickedDate!.day.toString().padLeft(2, '0')}/${pickedDate!.month.toString().padLeft(2, '0')}/${pickedDate!.year}'
                        : 'Choisir une date'),
                  ),
                ] else ...[
                  const Text('Plage de dates :', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDateRange: rangeStart != null && rangeEnd != null
                            ? DateTimeRange(start: rangeStart!, end: rangeEnd!)
                            : null,
                      );
                      if (range != null) setS(() { rangeStart = range.start; rangeEnd = range.end; });
                    },
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(rangeStart != null && rangeEnd != null
                        ? '${rangeStart!.day}/${rangeStart!.month}/${rangeStart!.year}  →  ${rangeEnd!.day}/${rangeEnd!.month}/${rangeEnd!.year}'
                        : 'Choisir une plage'),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Libellé (optionnel) :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Aïd El Fitr, Fête du travail…',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
              onPressed: () async {
                final label = labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim();
                if (!useRange && pickedDate != null) {
                  await shifts.setDoubleDay(pickedDate!, label: label);
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _filterYear = pickedDate!.year);
                } else if (useRange && rangeStart != null && rangeEnd != null) {
                  final totalDays = rangeEnd!.difference(rangeStart!).inDays + 1;
                  for (var i = 0; i < totalDays; i++) {
                    await shifts.setDoubleDay(rangeStart!.add(Duration(days: i)), label: label);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() => _filterYear = rangeStart!.year);
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
  }
}

class _DoubleDaysCalendarView extends StatelessWidget {
  final List<DoubleDay> days;
  final int year;
  final bool isAdmin;
  final void Function(DoubleDay) onRemove;

  const _DoubleDaysCalendarView({
    required this.days,
    required this.year,
    required this.isAdmin,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final byMonth = <int, List<DoubleDay>>{};
    for (final d in days) {
      byMonth.putIfAbsent(d.date.month, () => []).add(d);
    }
    final months = byMonth.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.orange.shade700, size: 18),
              const SizedBox(width: 8),
              Text(
                '${days.length} jour(s) ×2 en $year',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade800, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final month in months) ...[
          _MonthDoubleDaysCard(
            year: year,
            month: month,
            days: byMonth[month]!,
            isAdmin: isAdmin,
            onRemove: onRemove,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MonthDoubleDaysCard extends StatelessWidget {
  final int year;
  final int month;
  final List<DoubleDay> days;
  final bool isAdmin;
  final void Function(DoubleDay) onRemove;

  const _MonthDoubleDaysCard({
    required this.year,
    required this.month,
    required this.days,
    required this.isAdmin,
    required this.onRemove,
  });

  static const _monthNames = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  _monthNames[month],
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.orange.shade900),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${sorted.length} jour(s)',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sorted.map((d) {
                final dayStr = d.date.day.toString().padLeft(2, '0');
                final label = d.label?.isNotEmpty == true ? d.label! : null;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.orange.shade700,
                    child: Text(dayStr, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  label: Text(
                    label != null ? '$dayStr — $label' : dayStr,
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.orange.shade300),
                  deleteIcon: isAdmin ? Icon(Icons.close, size: 16, color: Colors.red.shade400) : null,
                  onDeleted: isAdmin
                      ? () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Supprimer ce jour ×2 ?'),
                              content: Text(
                                '${dayStr}/${month.toString().padLeft(2, '0')}/$year${label != null ? ' — $label' : ''}',
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) onRemove(d);
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
