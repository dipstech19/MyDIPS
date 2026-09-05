import 'package:flutter/material.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/locale/app_locale.dart';
import '../../core/utils/responsive.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';
import '../pointage/absence_reasons_provider.dart';
import '../pointage/models/pointage_model.dart';
import '../pointage/pointage_hours_config.dart';
import '../pointage/pointage_provider.dart';
import '../pointage/services/pointage_export_service.dart';
import '../pointage/widgets/absence_reason_picker.dart';
import '../pointage/widgets/feuille_pointage_share.dart';
import 'groupes_provider.dart';

/// Pointage pour un "Groupe" مستقل (خارج نظام équipes / shifts).
/// يُخزّن السجلات باستعمال equipeId = "groupe:<groupeId>".
///
/// Le responsable pointe présent/absent puis confirme ; la sortie est
/// enregistrée automatiquement à la confirmation (pas de saisie manuelle).
class GroupePointagePage extends StatelessWidget {
  const GroupePointagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final gid = auth.groupeId;
    final groupesProv = context.watch<GroupesProvider>();
    final empsProv = context.watch<EmployeesProvider>();
    final pointageProv = context.watch<PointageProvider>();
    final reasonConfigs = context.watch<AbsenceReasonsProvider>().reasons;
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

    final members = empsProv.employes.where((e) => g.membreIds.contains(e.id) && e.statut == EmployeStatut.enService).toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));

    PointageRecord? recordFor(String employeId) => pointageProv.getRecordForEmployee(employeId);

    final equipeId = 'groupe:${g.id}';
    final equipeName = 'Groupe: ${g.nom}';
    final chefName = auth.currentUser?.nom ?? 'Responsable';
    final pointageDate = getPointageDateForConfig(config, now);

    // Confirmé dès que tous les membres portent la marque d'envoi du responsable.
    final reportConfirmed = members.isNotEmpty &&
        members.every((e) => recordFor(e.id)?.submittedByChefAt != null);

    // Le responsable du groupe signe la feuille : sa ligne passe en tête.
    final chefEmployeId = auth.currentUser?.chefEmployeId ?? '';
    final membersForFeuille = () {
      final ordered = List<Employe>.from(members);
      final index = ordered.indexWhere((e) => e.id == chefEmployeId);
      if (index > 0) ordered.insert(0, ordered.removeAt(index));
      return ordered;
    }();

    /// Lignes de la feuille de pointage PDF (les non-saisis deviennent absents
    /// à la confirmation, la feuille les affiche donc ainsi).
    List<FeuillePointageLine> buildLines() => [
          for (final e in membersForFeuille)
            () {
              final r = recordFor(e.id);
              final present = r?.chefStatus == ChefPointageStatus.present;
              return feuillePointageLine(
                nomComplet: e.nom,
                statut: present ? feuilleStatutPresent : feuilleStatutAbsent,
                commentaire: present
                    ? ''
                    : getAbsenceReasonLabel(r?.absenceReason, reasonConfigs),
              );
            }(),
        ];

    Future<void> confirmerPointage() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr(ctx, 'pointage_confirm_title')),
          content: Text(tr(ctx, 'pointage_confirm_send_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(ctx, 'pointage_confirm_short')),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        for (final e in members) {
          final r = recordFor(e.id);
          // Non saisi → absent, comme pour le pointage d'équipe.
          if (r == null || r.chefStatus == ChefPointageStatus.unset) {
            await pointageProv.markChefAttendance(
              employeId: e.id,
              employeNom: e.nom,
              employeCin: e.cin,
              equipeId: equipeId,
              equipeName: equipeName,
              chefName: chefName,
              chefStatus: ChefPointageStatus.absent,
              chefId: auth.currentUser?.id,
              configOverride: config,
              bypassTimeWindows: true,
            );
            continue;
          }
          // Sortie enregistrée automatiquement pour les présents.
          if (r.chefStatus == ChefPointageStatus.present &&
              r.departureStatus == DepartureStatus.unset) {
            await pointageProv.setDepartureStatus(
              record: r,
              status: DepartureStatus.finished,
              overtimeMinutes: 0,
              configOverride: config,
              bypassTimeWindows: true,
            );
          }
        }
        await pointageProv.submitChefReportForDateManual(
          equipeId,
          pointageDate,
          equipeName: equipeName,
          chefName: chefName,
        );
        if (!context.mounted) return;
        await showPointageConfirmedDialog(
          context,
          date: pointageDate,
          equipeLabel: g.nom,
          posteLabel: '',
          chefName: chefName,
          lines: buildLines(),
        );
      } catch (err) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur : $err'), backgroundColor: Colors.red),
        );
      }
    }

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
              final canMark = !locked && !reportConfirmed && canArrival;

              final chips = <Widget>[
                FilterChip(
                  label: Text(tr(context, 'present')),
                  selected: present,
                  onSelected: canMark
                      ? (_) async {
                          if (absent &&
                              !await confirmUpdate(context,
                                  message:
                                      "Modifier le pointage de « ${e.nom} » en « présent » ?")) {
                            return;
                          }
                          if (!context.mounted) return;
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
                FilterChip(
                  label: Text(tr(context, 'absent')),
                  selected: absent,
                  onSelected: canMark
                      ? (_) async {
                          // Toute absence doit porter une raison choisie par le responsable.
                          final reasonId = await showAbsenceReasonPicker(
                            context,
                            reasons: reasonConfigs,
                            currentReason: r?.absenceReason,
                          );
                          if (reasonId == null || !context.mounted) return;
                          if (present &&
                              !await confirmUpdate(context,
                                  message:
                                      "Modifier le pointage de « ${e.nom} » en « absent » ?")) {
                            return;
                          }
                          if (!context.mounted) return;
                          final ok = await pointageProv.markChefAttendance(
                            employeId: e.id,
                            employeNom: e.nom,
                            employeCin: e.cin,
                            equipeId: equipeId,
                            equipeName: equipeName,
                            chefName: chefName,
                            chefStatus: ChefPointageStatus.absent,
                            chefId: auth.currentUser?.id,
                            absenceReason: reasonId,
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
              ];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: isMobile(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(child: Text(e.nom.isNotEmpty ? e.nom[0] : 'E')),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.nom,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: chips,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(child: Text(e.nom.isNotEmpty ? e.nom[0] : 'E')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                e.nom,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (locked) Icon(Icons.lock, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: chips,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            }),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (reportConfirmed)
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${tr(context, 'pointage_confirmed')} ✓',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              )
            else
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: confirmerPointage,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr(context, 'pointage_confirm_btn')),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            // Partage / téléchargement du PDF : uniquement après confirmation.
            if (reportConfirmed) ...[
              const SizedBox(height: 12),
              FeuillePointageShareSection(
                date: pointageDate,
                equipeLabel: g.nom,
                posteLabel: '',
                chefName: chefName,
                linesBuilder: buildLines,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

