import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/locale/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../modules/employees/employees_provider.dart';
import '../../../modules/pointage/pointage_data.dart';

/// عمال الفرق الأخرى فقط (نفس البيانات كـ Employés)
class ChefAddWorkerScreen extends StatefulWidget {
  const ChefAddWorkerScreen({super.key});

  @override
  State<ChefAddWorkerScreen> createState() => _ChefAddWorkerScreenState();
}

class _ChefAddWorkerScreenState extends State<ChefAddWorkerScreen> {
  final Set<String> _addedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final emp = context.watch<EmployeesProvider>();
    final otherWorkers = getOtherTeamsWorkers(
        emp.equipes, emp.employes, auth.equipeId);
    final filtered = _searchQuery.trim().isEmpty
        ? otherWorkers
        : otherWorkers.where((w) {
            final q = _searchQuery.trim().toLowerCase();
            return w.e.nom.toLowerCase().contains(q) ||
                w.e.cin.toLowerCase().contains(q);
          }).toList();

    final locale = context.watch<LocaleProvider>();
    return Directionality(
      textDirection: locale.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'add_worker')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: RoleBadge(label: tr(context, 'badge_chef'), color: AppColors.accentPurple),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: tr(context, 'search_name_cin'),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InfoBanner(
                text: tr(context, 'other_teams_info'),
                color: AppColors.accent,
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final w = filtered[i];
                final e = w.e;
                final chefName = w.chefName;
                final isAdded = _addedIds.contains(e.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: AvatarCircle(
                        letter: e.nom.isNotEmpty ? e.nom.substring(0, 1) : '?',
                        color: AppColors.accent),
                    title: Text(e.nom, style: const TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text(
                      '${tr(context, 'cin_label')}: ${e.cin} — ${tr(context, 'chef_label')}: $chefName',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    trailing: Material(
                      color: isAdded ? AppColors.green : AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => setState(() {
                          if (isAdded) {
                            _addedIds.remove(e.id);
                          } else {
                            _addedIds.add(e.id);
                          }
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isAdded ? Icons.check : Icons.add,
                                  color: isAdded ? Colors.white : AppColors.textMuted, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                isAdded ? tr(context, 'added') : tr(context, 'add'),
                                style: TextStyle(
                                    color: isAdded ? Colors.white : AppColors.textMuted,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
