import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/locale/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../modules/employees/employees_provider.dart';
import '../../../modules/pointage/pointage_data.dart';

/// يعرض فقط عمال فريق الشاف المتصل (نفس العمال الظاهرين في Employés لفريقه)
class ChefHomeScreen extends StatefulWidget {
  const ChefHomeScreen({super.key});

  @override
  State<ChefHomeScreen> createState() => _ChefHomeScreenState();
}

class _ChefHomeScreenState extends State<ChefHomeScreen> {
  final Map<String, AttendanceState> _attendance = {};

  AttendanceState _getState(String id) => _attendance[id] ?? AttendanceState.unmarked;

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
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final emp = context.watch<EmployeesProvider>();
    final workers = getWorkersForEquipe(
        emp.equipes, emp.employes, auth.equipeId);

    return Directionality(
      textDirection: locale.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'my_team')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: RoleBadge(label: tr(context, 'badge_chef'), color: AppColors.accentPurple),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(pagePadding(context)),
          children: [
            Text(
              '${tr(context, 'workers_of')} ${auth.currentUser?.nom ?? ''}',
              style: TextStyle(
                fontSize: isMobile(context) ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (workers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    tr(context, 'no_workers'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ),
              )
            else
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
                                    AvatarCircle(
                                      letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?',
                                      color: AppColors.accent,
                                      size: 36,
                                    ),
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
                                ChefStatusChips(
                                  current: _getState(e.id),
                                  onSelect: (s) => setState(() => _attendance[e.id] = s),
                                  presentLabel: tr(context, 'present'),
                                  absentLabel: tr(context, 'absent'),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              AvatarCircle(
                                letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?',
                                color: AppColors.accent,
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
                          );
                        },
                      ),
                    ),
                  )),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(pagePadding(context)),
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
