import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import 'distribution_groups_provider.dart';
import '../pointage/models/pointage_model.dart';
import '../pointage/pointage_provider.dart';
import '../pointage/services/pointage_export_service.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/async_busy.dart';

class DistributionPointagePage extends StatefulWidget {
  final bool reviewOnly;
  const DistributionPointagePage({super.key, this.reviewOnly = false});

  @override
  State<DistributionPointagePage> createState() => _DistributionPointagePageState();
}

class _DistributionPointagePageState extends State<DistributionPointagePage> {
  String? _selectedGroupId;
  int _reloadCounter = 0;

  DateTime _yesterday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allowedIds = auth.distributionGroupIds;
    final groupsProv = context.watch<DistributionGroupsProvider>();
    final empsProv = context.watch<EmployeesProvider>();
    final pointageProv = context.watch<PointageProvider>();
    final day = _yesterday();

    final isReviewer = widget.reviewOnly;
    final reviewerCanSeeAll = isReviewer && (auth.isChefAtelierAdmin || auth.isDirecteur);
    if (allowedIds.isEmpty && !reviewerCanSeeAll) {
      return const Center(child: Text('Compte non lié à un groupe Distribution.'));
    }
    final availableGroups = reviewerCanSeeAll
        ? groupsProv.groups
        : groupsProv.groups.where((g) => allowedIds.contains(g.id)).toList();
    if (availableGroups.isEmpty) {
      return const Center(child: Text('Groupe Distribution introuvable.'));
    }
    _selectedGroupId ??= availableGroups.first.id;
    if (!availableGroups.any((e) => e.id == _selectedGroupId)) {
      _selectedGroupId = availableGroups.first.id;
    }
    final g = availableGroups.firstWhere((e) => e.id == _selectedGroupId);
    final members = empsProv.employes
        .where((e) => g.membreIds.contains(e.id) && e.statut == EmployeStatut.enService)
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));

    return FutureBuilder<List<PointageRecord>>(
      future: pointageProv.getPointageRecordsForDate(day),
      builder: (context, snap) {
        final records = snap.data ?? const <PointageRecord>[];
        // Force refetch when actions happen.
        if (_reloadCounter < 0) {
          return const SizedBox.shrink();
        }
        PointageRecord? recFor(String id) {
          try {
            return records.firstWhere((r) => r.employeId == id);
          } catch (_) {
            return null;
          }
        }
        final currentEquipeId = 'distribution:${g.id}';
        final reportConfirmed = records.any(
          (r) => r.equipeId == currentEquipeId && r.submittedByChefAt != null,
        );
        final sentIds = records
            .where((r) => r.equipeId == currentEquipeId && r.submittedByChefAt != null)
            .map((r) => r.employeId)
            .toSet();
        final filteredMembers = isReviewer
            ? members.where((m) => sentIds.contains(m.id)).toList()
            : members;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pointage Distribution — ${g.nom}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Le pointage est enregistré pour: ${day.day}/${day.month}/${day.year}',
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 10),
              if (availableGroups.length > 1)
                DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: 'Groupe Distribution',
                    border: OutlineInputBorder(),
                  ),
                  items: availableGroups
                      .map((x) => DropdownMenuItem<String>(value: x.id, child: Text(x.nom)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
              const SizedBox(height: 12),
              if (filteredMembers.isEmpty)
                Text('Aucun membre dans ce groupe.', style: TextStyle(color: Colors.grey[700]))
              else
                ...filteredMembers.map((Employe e) {
                  final r = recFor(e.id);
                  final chefStatus = r?.chefStatus ?? ChefPointageStatus.unset;
                  final present = chefStatus == ChefPointageStatus.present;
                  final absent = chefStatus == ChefPointageStatus.absent;
                  final arrival = r?.arrivalMarkedAt;
                  final departure = r?.departureMarkedAt;
                  final equipeId = currentEquipeId;
                  final equipeName = 'Distribution: ${g.nom}';
                  final chefName = auth.currentUser?.nom ?? 'Responsable Distribution';

                  Future<void> setPresent() async {
                    if (isReviewer) return;
                    await pointageProv.markDistributionAttendanceForDate(
                      employeId: e.id,
                      employeNom: e.nom,
                      employeCin: e.cin,
                      equipeId: equipeId,
                      equipeName: equipeName,
                      chefName: chefName,
                      chefStatus: ChefPointageStatus.present,
                      pointageDate: day,
                      chefId: auth.currentUser?.id,
                    );
                    if (mounted) setState(() => _reloadCounter++);
                  }

                  Future<void> setAbsent() async {
                    if (isReviewer) return;
                    await pointageProv.markDistributionAttendanceForDate(
                      employeId: e.id,
                      employeNom: e.nom,
                      employeCin: e.cin,
                      equipeId: equipeId,
                      equipeName: equipeName,
                      chefName: chefName,
                      chefStatus: ChefPointageStatus.absent,
                      pointageDate: day,
                      chefId: auth.currentUser?.id,
                    );
                    if (mounted) setState(() => _reloadCounter++);
                  }

                  Future<void> markFinished() async {
                    if (isReviewer) return;
                    final record = r ??
                        PointageRecord(
                          id: '',
                          employeId: e.id,
                          employeNom: e.nom,
                          employeCin: e.cin,
                          equipeId: equipeId,
                          equipeName: equipeName,
                          chefName: chefName,
                          status: AttendanceStatus.unmarked,
                          date: day,
                          createdAt: DateTime.now(),
                          chefStatus: ChefPointageStatus.present,
                        );
                    await pointageProv.setDepartureStatus(
                      record: record,
                      status: DepartureStatus.finished,
                      overtimeMinutes: 0,
                      bypassTimeWindows: true,
                    );
                    if (mounted) setState(() => _reloadCounter++);
                  }

                  Future<void> markNotCompleted() async {
                    if (isReviewer) return;
                    final record = r ??
                        PointageRecord(
                          id: '',
                          employeId: e.id,
                          employeNom: e.nom,
                          employeCin: e.cin,
                          equipeId: equipeId,
                          equipeName: equipeName,
                          chefName: chefName,
                          status: AttendanceStatus.unmarked,
                          date: day,
                          createdAt: DateTime.now(),
                          chefStatus: ChefPointageStatus.present,
                        );
                    final reasonCtrl = TextEditingController();
                    final workedCtrl = TextEditingController();
                    final payload = await showDialog<({String? reason, int? workedMinutes})>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("N'a pas terminé"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: workedCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Heures travaillées',
                                hintText: 'Ex: 5.5',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: reasonCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Raison (optionnel)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                          ),
                          TextButton(
                            onPressed: () {
                              final hours = double.tryParse(workedCtrl.text.trim().replaceAll(',', '.'));
                              final mins = (hours != null && hours >= 0) ? (hours * 60).round() : null;
                              final reason = reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();
                              Navigator.pop(ctx, (reason: reason, workedMinutes: mins));
                            },
                            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                          ),
                        ],
                      ),
                    );
                    await pointageProv.setDepartureStatus(
                      record: record,
                      status: DepartureStatus.stillWorking,
                      workedMinutesBeforeStop: payload?.workedMinutes,
                      incompleteShiftReason: payload?.reason,
                      bypassTimeWindows: true,
                    );
                    if (mounted) setState(() => _reloadCounter++);
                  }

                  Future<void> adminConfirm() async {
                    if (!isReviewer || r == null || r.id.isEmpty) return;
                    final status = r.chefStatus == ChefPointageStatus.present
                        ? AttendanceStatus.present
                        : AttendanceStatus.absent;
                    await pointageProv.setAdminOverride(r.id, status);
                    if (mounted) setState(() => _reloadCounter++);
                  }

                  String fmt(DateTime? d) => d == null
                      ? '--:--'
                      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                  final actionChips = <Widget>[
                    if (!isReviewer)
                      FilterChip(
                        label: const Text('Présent'),
                        selected: present,
                        onSelected: (_) => setPresent(),
                      ),
                    if (!isReviewer)
                      FilterChip(
                        label: const Text('Absent'),
                        selected: absent,
                        onSelected: (_) => setAbsent(),
                      ),
                    if (reportConfirmed && present)
                      FilterChip(
                        label: const Text('Terminé'),
                        selected: r?.departureStatus == DepartureStatus.finished,
                        onSelected: (_) => markFinished(),
                      ),
                    if (reportConfirmed && present)
                      FilterChip(
                        label: const Text("N'a pas terminé"),
                        selected: r?.departureStatus == DepartureStatus.stillWorking,
                        onSelected: (_) => markNotCompleted(),
                      ),
                    if (isReviewer && r != null)
                      FilterChip(
                        label: Text(
                          r.adminFinalStatus == null ? 'Confirmer' : 'Confirmé',
                        ),
                        selected: r.adminFinalStatus != null,
                        onSelected: (_) => adminConfirm(),
                      ),
                  ];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: isMobile(context)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  e.nom,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Entrée: ${fmt(arrival)}  •  Sortie: ${fmt(departure)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: actionChips,
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.nom,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Entrée: ${fmt(arrival)}  •  Sortie: ${fmt(departure)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.end,
                                    children: actionChips,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }),
              if (!isReviewer) const SizedBox(height: 12),
              if (!isReviewer)
                OutlinedButton.icon(
                onPressed: () async {
                  final present = <String>[];
                  final absent = <String>[];
                  final absentReasons = <String?>[];
                  for (final e in members) {
                    final r = recFor(e.id);
                    if (r?.chefStatus == ChefPointageStatus.present) {
                      present.add(e.nom);
                    } else if (r?.chefStatus == ChefPointageStatus.absent) {
                      absent.add(e.nom);
                      absentReasons.add(r?.absenceReason);
                    }
                  }
                  final path = await PointageExportService.shareDailyReportPdfForDriver(
                    date: day,
                    title: 'Rapport Distribution',
                    signatureLabel: 'Responsable Distribution',
                    personName: auth.currentUser?.nom ?? '',
                    equipes: [
                      (
                        equipeName: g.nom,
                        chefName: auth.currentUser?.nom,
                        presentNames: present,
                        presentNoDepartureNames: const <String>[],
                        absentNames: absent,
                        absentReasons: absentReasons,
                      )
                    ],
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PDF généré: $path')),
                  );
                },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Télécharger PDF (hier)'),
                ),
              if (!isReviewer) const SizedBox(height: 8),
              if (!isReviewer)
                ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await withLoadingDialog<void>(
                      context,
                      (() async {
                        await pointageProv.submitChefReportForDateManual('distribution:${g.id}', day);
                        if (!context.mounted) return;
                        setState(() => _reloadCounter++);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rapport Distribution confirmé pour hier.')),
                        );
                      })(),
                      message: 'Envoi en cours...',
                    );
                  } catch (_) {}
                },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirmer pointage (hier)'),
                ),
            ],
          ),
        );
      },
    );
  }
}

