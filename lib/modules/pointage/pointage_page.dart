import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../features/chef/screens/chef_home_screen.dart';
import '../../features/driver/screens/driver_home_screen.dart';
import '../../modules/employees/models/employe_model.dart';
import '../../modules/employees/models/equipe_model.dart';
import '../../modules/employees/employees_provider.dart';
import 'pointage_data.dart';

/// Pointage: للشاف — عماله مباشرة. للأدمن — نفس تنظيم السائق + تقرير الحضور أسفل.
class PointagePage extends StatefulWidget {
  const PointagePage({super.key});

  @override
  State<PointagePage> createState() => _PointagePageState();
}

class _PointagePageState extends State<PointagePage> {
  final Map<String, AttendanceState> _attendance = {};
  final Map<String, AttendanceState> _attendanceAdmin = {};
  String? _selectedEquipeIdAdmin;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final isDirecteur = auth.isDirecteur;
    final isChefEquipe = auth.isChefEquipe;
    final isRtl = locale.isArabic;

    final showDriverList = isDirecteur;
    final isChefOnly = isChefEquipe && !isDirecteur;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: isChefOnly
          ? _buildChefContent(context, auth, emp.equipes, emp.employes)
          : isDirecteur
              ? _buildAdminContent(context, emp.equipes, emp.employes)
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

  String _adminKey(String equipeId, String employeId) => '${equipeId}_$employeId';

  AttendanceState _adminGetState(String equipeId, String employeId) =>
      _attendanceAdmin[_adminKey(equipeId, employeId)] ?? AttendanceState.unmarked;

  Widget _buildAdminContent(
    BuildContext context,
    List<Equipe> equipes,
    List<Employe> employes,
  ) {
    final mobile = isMobile(context);
    final teams = getAllTeamsWithWorkers(equipes, employes);
    final selectedTeam = teams.where((t) => t.equipeId == _selectedEquipeIdAdmin).toList();
    final team = selectedTeam.isEmpty ? null : selectedTeam.first;
    final workers = team?.workers ?? <Employe>[];
    final borderColor = Colors.grey.shade300;
    final padding = pagePadding(context);

    final presentByChef = <String, List<Employe>>{};
    final absentByChef = <String, List<Employe>>{};
    final notInVehicleByChef = <String, List<Employe>>{};
    for (final t in teams) {
      for (final e in t.workers) {
        final s = _adminGetState(t.equipeId, e.id);
        if (s == AttendanceState.present) presentByChef.putIfAbsent(t.chefName, () => []).add(e);
        else if (s == AttendanceState.absent) absentByChef.putIfAbsent(t.chefName, () => []).add(e);
        else if (s == AttendanceState.notInVehicle) notInVehicleByChef.putIfAbsent(t.chefName, () => []).add(e);
      }
    }

    void sendReport() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'report_sent')), backgroundColor: Colors.green, behavior: SnackBarBehavior.fixed),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'pointage_title'), style: TextStyle(fontSize: mobile ? 18 : 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(tr(context, 'select_chef'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 12),
          if (mobile) _buildAdminMobileChefSelector(context, teams),
          if (mobile) const SizedBox(height: 12),
          Expanded(
            flex: 5,
            child: mobile
                ? _buildAdminWorkersColumn(context, team, workers, borderColor)
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
                              child: Text(tr(context, 'chefs_side_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            const Divider(height: 1),
                            if (teams.isEmpty)
                              Padding(padding: const EdgeInsets.all(16), child: Text(tr(context, 'no_teams'), style: TextStyle(fontSize: 13, color: Colors.grey[600])))
                            else
                              Expanded(
                                child: ListView.builder(
                                  itemCount: teams.length,
                                  itemBuilder: (context, i) {
                                    final t = teams[i];
                                    final isSelected = _selectedEquipeIdAdmin == t.equipeId;
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
                                        onTap: () => setState(() => _selectedEquipeIdAdmin = t.equipeId),
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
                        child: _buildAdminWorkersColumn(context, team, workers, borderColor),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: PrimaryButton(label: tr(context, 'send_report_btn'), onTap: sendReport),
          ),
          const SizedBox(height: 16),
          Divider(thickness: 1, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(tr(context, 'report_presence_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReportSection(title: tr(context, 'report_presents'), color: Colors.green, byChef: presentByChef),
                  const SizedBox(height: 16),
                  _ReportSection(title: tr(context, 'report_absents'), color: Colors.red, byChef: absentByChef),
                  const SizedBox(height: 16),
                  _ReportSection(title: tr(context, 'report_not_in_vehicle_list'), color: Colors.orange, byChef: notInVehicleByChef),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMobileChefSelector(BuildContext context, List<({String equipeId, String chefName, List<Employe> workers})> teams) {
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
            label: Text(t.chefName, style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onSelected: (_) => setState(() => _selectedEquipeIdAdmin = t.equipeId),
            showCheckmark: false,
            selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.25),
          );
        },
      ),
    );
  }

  Widget _buildAdminWorkersColumn(BuildContext context, ({String equipeId, String chefName, List<Employe> workers})? team, List<Employe> workers, Color borderColor) {
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
          ...workers.map((e) => Card(
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
                                AvatarCircle(letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?', color: const Color(0xFF4F8EF7), size: 36),
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
                              current: _adminGetState(team.equipeId, e.id),
                              onSelect: (s) => setState(() => _attendanceAdmin[_adminKey(team.equipeId, e.id)] = s),
                              presentLabel: tr(context, 'present'),
                              absentLabel: tr(context, 'absent'),
                              notInVehicleLabel: tr(context, 'not_in_vehicle'),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          AvatarCircle(letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?', color: const Color(0xFF4F8EF7), size: 36),
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
                            current: _adminGetState(team.equipeId, e.id),
                            onSelect: (s) => setState(() => _attendanceAdmin[_adminKey(team.equipeId, e.id)] = s),
                            presentLabel: tr(context, 'present'),
                            absentLabel: tr(context, 'absent'),
                            notInVehicleLabel: tr(context, 'not_in_vehicle'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildChefContent(
    BuildContext context,
    AuthProvider auth,
    List<Equipe> equipes,
    List<Employe> employes,
  ) {
    final workers = getWorkersForEquipe(equipes, employes, auth.equipeId);
    AttendanceState _getState(String id) => _attendance[id] ?? AttendanceState.unmarked;

    void sendReport() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'report_sent')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }

    final padding = pagePadding(context);
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
                style: TextStyle(fontSize: isMobile(context) ? 18 : 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, 'pointage_subtitle_chef'),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          Text(
            '${tr(context, 'workers_of')} ${auth.currentUser?.nom ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (workers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  tr(context, 'no_workers'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            )
          else
            ...workers.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        AvatarCircle(
                          letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?',
                          color: const Color(0xFF4F8EF7),
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                '${tr(context, 'cin_label')}: ${e.cin}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        ChefStatusChips(
                          current: _getState(e.id),
                          onSelect: (s) => setState(() => _attendance[e.id] = s),
                          presentLabel: tr(context, 'present'),
                          absentLabel: tr(context, 'absent'),
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: PrimaryButton(label: tr(context, 'send_report_btn'), onTap: sendReport),
          ),
          const SizedBox(height: 24),
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

class _ReportSection extends StatelessWidget {
  final String title;
  final Color color;
  final Map<String, List<Employe>> byChef;

  const _ReportSection({required this.title, required this.color, required this.byChef});

  @override
  Widget build(BuildContext context) {
    if (byChef.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(tr(context, 'report_no_data'), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        ...byChef.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tr(context, 'chef_label')} — ${e.key}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ...e.value.map((emp) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 2),
                        child: Text('• ${emp.nom} (${tr(context, 'cin_label')}: ${emp.cin})', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      )),
                ],
              ),
            )),
      ],
    );
  }
}
