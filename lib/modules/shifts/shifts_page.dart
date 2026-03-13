import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../modules/employees/employees_provider.dart';
import '../../modules/employees/models/equipe_model.dart';
import 'models/shift_models.dart';
import 'shifts_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import 'services/shifts_export_service.dart';

class ShiftsPage extends StatefulWidget {
  const ShiftsPage({super.key});

  @override
  State<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends State<ShiftsPage> {
  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final emp = context.watch<EmployeesProvider>();
    final shifts = context.watch<ShiftsProvider>();
    final isRtl = locale.isArabic;
    final isAdmin = auth.isDirecteur;
    final equipes = SiteId.filterBySite(
      emp.equipes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(pagePadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.rotate_right, color: Colors.grey[700], size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(tr(context, 'shifts_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(tr(context, 'shifts_subtitle'), style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            if (shifts.loading)
              Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr(context, 'shifts_schedule'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(tr(context, 'shifts_export_excel')),
                          onPressed: () => _showShiftsExportDialog(context, shifts, equipes),
                        ),
                        SizedBox(width: 8),
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
                            overrides: {},
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
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr(context, 'shifts_schedule'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(tr(context, 'shifts_export_excel')),
                      onPressed: () => _showShiftsExportDialog(context, shifts, equipes),
                    ),
                  ],
                ),
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 280),
                child: _ScheduleTable(equipes: equipes, isAdmin: isAdmin),
              ),
            ],
          ],
        ),
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
                      for (final s in schedule)
                        DataRow(
                          cells: [
                            DataCell(Text('${s.date.day}/${s.date.month}', style: TextStyle(fontWeight: FontWeight.w500, fontSize: mobile ? 11 : 12))),
                            for (var pos = 0; pos < 4; pos++) ...[
                              DataCell(
                                _buildShiftCell(context, shifts, s, pos, config, mobile),
                              ),
                            ],
                          ],
                        ),
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

  Widget _buildShiftCell(BuildContext context, ShiftsProvider shifts, ({DateTime date, List<({String equipeId, ShiftType shift})> perEquipe}) s, int pos, RotationConfig config, bool mobile) {
    final shift = s.perEquipe.length > pos ? s.perEquipe[pos].shift : ShiftType.rest;
    final equipeId = config.equipeIds.length > pos ? config.equipeIds[pos] : '';
    return InkWell(
      onTap: widget.isAdmin && equipeId.isNotEmpty
          ? () => _showEditShiftDialog(context, shifts, s.date, equipeId, shift)
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: _shiftColor(shift).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(_shiftLabel(context, shift), style: TextStyle(fontSize: mobile ? 10 : 12)),
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
    final config = context.read<ShiftsProvider>().config;
    if (config != null) {
      _startDate = config.startDay;
      for (var i = 0; i < 4 && i < config.equipeIds.length; i++) _selectedIds[i] = config.equipeIds[i].isEmpty ? '' : config.equipeIds[i];
    }
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
                if (picked != null) setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
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
              Row(
                children: [
                  Expanded(
                    child: Text(tr(context, 'shifts_config_equipe').replaceAll('%s', '${i + 1}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(_positionHintKey(i), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _selectedIds[i]?.isEmpty ?? true ? null : _selectedIds[i],
                decoration: InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: [
                  DropdownMenuItem(value: null, child: Text('—')),
                  ...equipes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.nom))),
                ],
                onChanged: (v) => setState(() => _selectedIds[i] = v ?? ''),
              ),
              SizedBox(height: 12),
            ],
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final ids = _selectedIds.map((v) => v ?? '').toList();
                if (ids.length != 4) return;
                await context.read<ShiftsProvider>().setConfig(RotationConfig(startDate: _startDate, equipeIds: ids));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'shifts_save')), backgroundColor: Colors.green));
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
