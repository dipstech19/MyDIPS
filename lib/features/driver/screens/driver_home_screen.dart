import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../modules/employees/employees_provider.dart';
import '../../../modules/pointage/pointage_data.dart';

/// قائمة اليوم: كل الفرق والعمال (نفس البيانات كـ Employés)
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final Map<String, AttendanceState> _attendance = {};

  String _key(String equipeId, String employeId) => '${equipeId}_$employeId';

  AttendanceState _getState(String equipeId, String employeId) =>
      _attendance[_key(equipeId, employeId)] ?? AttendanceState.unmarked;

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
    final teams = getAllTeamsWithWorkers(emp.equipes, emp.employes);

    return Directionality(
      textDirection: locale.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'today_list')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: RoleBadge(label: tr(context, 'badge_driver'), color: AppColors.accent),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(pagePadding(context)),
          children: [
            SectionLabel(text: tr(context, 'section_by_chef')),
            if (teams.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    tr(context, 'no_teams'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
              )
          else
            ...teams.map((t) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('👷', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                          child: Text(
                            '${tr(context, 'chef_label')} — ${t.chefName}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${t.workers.length}',
                              style: const TextStyle(
                                  color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...t.workers.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              AvatarCircle(
                                  letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?',
                                  color: AppColors.accent,
                                  size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.nom,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500)),
                                    Text('${tr(context, 'cin_label')}: ${e.cin}',
                                        style: const TextStyle(
                                            color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              DriverStatusChips(
                                current: _getState(t.equipeId, e.id),
                                onSelect: (s) => setState(() => _attendance[_key(t.equipeId, e.id)] = s),
                                presentLabel: tr(context, 'present'),
                                absentLabel: tr(context, 'absent'),
                                notInVehicleLabel: tr(context, 'not_in_vehicle'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: PrimaryButton(label: tr(context, 'send_report_btn'), onTap: _sendReport),
          ),
        ),
      ),
    ),
    );
  }
}
