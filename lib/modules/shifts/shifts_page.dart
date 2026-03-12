import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../modules/employees/employees_provider.dart';
import '../../modules/employees/models/equipe_model.dart';
import 'models/shift_models.dart';
import 'shifts_provider.dart';

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
    final emp = context.watch<EmployeesProvider>();
    final shifts = context.watch<ShiftsProvider>();
    final isRtl = locale.isArabic;
    final isAdmin = auth.isDirecteur;
    final equipes = emp.equipes;

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
              Text(tr(context, 'shifts_schedule'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 280),
                child: _ScheduleTable(equipes: equipes),
              ),
            ],
          ],
        ),
      ),
    );
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

class _ScheduleTable extends StatelessWidget {
  final List<Equipe> equipes;

  const _ScheduleTable({required this.equipes});

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
    final startDay = DateTime(today.year, today.month, today.day);
    final schedule = shifts.getScheduleForDays(startDay, 14);
    final mobile = isMobile(context);

    if (schedule.isEmpty) return SizedBox.shrink();

    final equipeNames = config.equipeIds.map((id) {
      final eqList = equipes.where((e) => e.id == id).toList();
      return eqList.isEmpty ? id : eqList.first.nom;
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: [
            DataColumn(label: Text(tr(context, 'shifts_schedule'), style: TextStyle(fontWeight: FontWeight.bold))),
            ...schedule.map((s) => DataColumn(label: Text('${s.date.day}/${s.date.month}', style: TextStyle(fontSize: mobile ? 10 : 12)))),
          ],
          rows: [
            for (var row = 0; row < equipeNames.length; row++)
              DataRow(
                cells: [
                  DataCell(Text(equipeNames[row], style: TextStyle(fontWeight: FontWeight.w500))),
                  ...schedule.map((s) {
                    final shift = s.perEquipe.length > row ? s.perEquipe[row].shift : ShiftType.rest;
                    return DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: _shiftColor(shift).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_shiftLabel(context, shift), style: TextStyle(fontSize: mobile ? 10 : 12)),
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
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
            SizedBox(height: 20),
            for (var i = 0; i < 4; i++) ...[
              Text(tr(context, 'shifts_config_equipe').replaceAll('%s', '${i + 1}')),
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
