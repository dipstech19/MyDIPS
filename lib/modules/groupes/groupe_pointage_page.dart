import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../pointage/models/pointage_model.dart';
import '../pointage/pointage_hours_config.dart';
import '../pointage/pointage_provider.dart';
import 'groupes_provider.dart';
import 'models/groupe_model.dart';

/// Pointage pour un "Groupe" مستقل (خارج نظام équipes / shifts).
/// يُخزّن السجلات باستعمال equipeId = "groupe:<groupeId>".
class GroupePointagePage extends StatelessWidget {
  const GroupePointagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final gid = auth.groupeId;
    final groupesProv = context.watch<GroupesProvider>();
    final empsProv = context.watch<EmployeesProvider>();
    final pointageProv = context.watch<PointageProvider>();
    final now = DateTime.now();

    if (gid == null || gid.isEmpty) {
      return Center(child: Text('Compte non lié à un groupe.', style: TextStyle(color: Colors.grey[700])));
    }
    final gList = groupesProv.groupes.where((g) => g.id == gid).toList();
    final g = gList.isEmpty ? null : gList.first;
    if (g == null) {
      return Center(child: Text('Groupe introuvable.', style: TextStyle(color: Colors.grey[700])));
    }
    final config = PointageHoursConfig(
      startHour: g.startHour,
      startMinute: g.startMinute,
      endHour: g.endHour,
      endMinute: g.endMinute,
    );
    final ignoreTime = pointageProv.ignoreTimeWindowsForTest;
    final canArrival = ignoreTime || config.canMarkArrivalNow(now);
    final canDeparture = ignoreTime || config.canMarkDepartureNow(now);

    final members = empsProv.employes.where((e) => g.membreIds.contains(e.id) && e.statut == EmployeStatut.enService).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));

    PointageRecord? recordFor(String employeId) => pointageProv.getRecordForEmployee(employeId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pointage — Groupe', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(g.nom, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                Text('${config.startTimeFormatted()} → ${config.endTimeFormatted()}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Text('Aucun membre dans ce groupe.', style: TextStyle(color: Colors.grey[700]))
          else
            ...members.map((Employe e) {
              final r = recordFor(e.id);
              final locked = pointageProv.isChefLockedForEmployee(e.id);
              final present = r?.chefStatus == ChefPointageStatus.present;
              final absent = r?.chefStatus == ChefPointageStatus.absent;
              final canMark = !locked && canArrival;
              final equipeId = 'groupe:${g.id}';
              final equipeName = 'Groupe: ${g.nom}';
              final chefName = auth.currentUser?.nom ?? 'Responsable';
              final recordOrPlaceholder = r ??
                  PointageRecord(
                    id: '',
                    employeId: e.id,
                    employeNom: e.nom,
                    employeCin: e.cin,
                    equipeId: equipeId,
                    equipeName: equipeName,
                    chefName: chefName,
                    status: AttendanceStatus.unmarked,
                    date: getPointageDateForConfig(config, now),
                    createdAt: now,
                  );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(child: Text(e.nom.isNotEmpty ? e.nom[0] : 'E')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(tr(context, 'present')),
                        selected: present,
                        onSelected: canMark
                            ? (_) async {
                                final ok = await pointageProv.markChefAttendance(
                                  employeId: e.id,
                                  employeNom: e.nom,
                                  employeCin: e.cin,
                                  equipeId: equipeId,
                                  equipeName: equipeName,
                                  chefName: chefName,
                                  chefStatus: ChefPointageStatus.present,
                                  chefId: auth.currentUser?.id,
                                  configOverride: config,
                                );
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange),
                                  );
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 6),
                      FilterChip(
                        label: Text(tr(context, 'absent')),
                        selected: absent,
                        onSelected: canMark
                            ? (_) async {
                                final ok = await pointageProv.markChefAttendance(
                                  employeId: e.id,
                                  employeNom: e.nom,
                                  employeCin: e.cin,
                                  equipeId: equipeId,
                                  equipeName: equipeName,
                                  chefName: chefName,
                                  chefStatus: ChefPointageStatus.absent,
                                  chefId: auth.currentUser?.id,
                                  configOverride: config,
                                );
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(trOf(context, 'pointage_hours_cannot_mark')), backgroundColor: Colors.orange),
                                  );
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 6),
                      if (canDeparture)
                        FilterChip(
                          label: Text(tr(context, 'departure_finished')),
                          selected: recordOrPlaceholder.departureStatus == DepartureStatus.finished,
                          onSelected: (_) async {
                            await pointageProv.setDepartureStatus(
                              record: recordOrPlaceholder,
                              status: DepartureStatus.finished,
                              overtimeMinutes: 0,
                              configOverride: config,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

