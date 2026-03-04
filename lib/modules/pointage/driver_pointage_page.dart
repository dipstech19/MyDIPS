import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../modules/employees/models/employe_model.dart';
import '../../modules/employees/employees_provider.dart';
import 'pointage_data.dart';

/// Pointage chauffeur: liste des chefs à gauche, ouvriers du chef sélectionné à droite (présent / absent / pas dans le véhicule)
class DriverPointagePage extends StatefulWidget {
  const DriverPointagePage({super.key});

  @override
  State<DriverPointagePage> createState() => _DriverPointagePageState();
}

class _DriverPointagePageState extends State<DriverPointagePage> {
  final Map<String, AttendanceState> _attendance = {};
  String? _selectedEquipeId;

  String _key(String equipeId, String employeId) => '${equipeId}_$employeId';

  AttendanceState _getState(String equipeId, String employeId) =>
      _attendance[_key(equipeId, employeId)] ?? AttendanceState.unmarked;

  void _setState(String equipeId, String employeId, AttendanceState state) {
    setState(() => _attendance[_key(equipeId, employeId)] = state);
  }

  void _sendReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'report_sent')),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final isRtl = locale.isArabic;
    final mobile = isMobile(context);
    final teams = getAllTeamsWithWorkers(emp.equipes, emp.employes);
    final selectedTeam = teams.where((t) => t.equipeId == _selectedEquipeId).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'pointage_title'),
              style: TextStyle(fontSize: mobile ? 18 : 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              tr(context, 'select_chef'),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (mobile) _buildMobileChefSelector(context, teams),
            if (mobile) const SizedBox(height: 12),
            Expanded(
              child: mobile
                  ? _buildMobileWorkersSection(context, team, workers, borderColor)
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
                          child: Text(
                            tr(context, 'chefs_side_title'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const Divider(height: 1),
                        if (teams.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: teams.length,
                              itemBuilder: (context, i) {
                                final t = teams[i];
                                final isSelected = _selectedEquipeId == t.equipeId;
                                return Material(
                                  color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.15) : null,
                                  child: ListTile(
                                    leading: const Icon(Icons.person, size: 20),
                                    title: Text(t.chefName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(12)),
                                      child: Text('${t.workers.length}', style: const TextStyle(fontSize: 12)),
                                    ),
                                    onTap: () => setState(() => _selectedEquipeId = t.equipeId),
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
                    child: _buildMobileWorkersSection(context, team, workers, borderColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SafeArea(
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: PrimaryButton(label: tr(context, 'send_report_btn'), onTap: _sendReport),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileChefSelector(BuildContext context, List<({String equipeId, String chefName, List<Employe> workers})> teams) {
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
          final isSelected = _selectedEquipeId == t.equipeId;
          return FilterChip(
            label: Text(t.chefName, style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedEquipeId = t.equipeId),
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.25),
          );
        },
      ),
    );
  }

  Widget _buildMobileWorkersSection(BuildContext context, ({String equipeId, String chefName, List<Employe> workers})? team, List<Employe> workers, Color borderColor) {
    if (team == null) {
      return Center(child: Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    if (workers.isEmpty) {
      return Center(child: Text(tr(context, 'no_workers'), style: TextStyle(fontSize: 14, color: Colors.grey[600])));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('${tr(context, 'workers_of')} ${team.chefName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...workers.map((e) {
            final state = _getState(team.equipeId, e.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 380;
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              AvatarCircle(letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?', color: AppColors.accent, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${tr(context, 'cin_label')}: ${e.cin}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DriverStatusChips(
                            current: state,
                            onSelect: (s) => _setState(team.equipeId, e.id, s),
                            presentLabel: tr(context, 'present'),
                            absentLabel: tr(context, 'absent'),
                            notInVehicleLabel: tr(context, 'not_in_vehicle'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        AvatarCircle(letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?', color: AppColors.accent, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${tr(context, 'cin_label')}: ${e.cin}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        DriverStatusChips(
                          current: state,
                          onSelect: (s) => _setState(team.equipeId, e.id, s),
                          presentLabel: tr(context, 'present'),
                          absentLabel: tr(context, 'absent'),
                          notInVehicleLabel: tr(context, 'not_in_vehicle'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
