import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../employees/employees_provider.dart';
import '../../employees/models/employe_model.dart';
import '../../../core/auth/auth_provider.dart';
import '../distribution_groups_provider.dart';
import '../distribution_shifts_provider.dart';
import '../distribution_swaps_provider.dart';
import '../models/distribution_group_model.dart';
import '../models/distribution_swap_model.dart';
import '../services/distribution_swap_service.dart';
import '../../pointage/pointage_provider.dart';

/// Dialogues d'échange entre membres de groupes Distribution (même mois).
class DistributionSwapDialogs {
  static bool canOpen(AuthProvider auth) => DistributionSwapService.canManageSwaps(
        isDistributionResponsable: auth.isDistributionResponsable,
        isChefZoneAdmin: auth.isChefZoneAdmin,
      );

  static Future<void> showManageSheet(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!canOpen(auth)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _SwapListSheet(),
    );
  }

  static Future<void> showCreateDialog(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!canOpen(auth)) return;

    final groupsProv = context.read<DistributionGroupsProvider>();
    final shiftsProv = context.read<DistributionShiftsProvider>();
    final empsProv = context.read<EmployeesProvider>();
    final swapsProv = context.read<DistributionSwapsProvider>();
    final allowed = auth.distributionGroupIds;
    var allGroups = groupsProv.groups.where((g) => g.membreIds.isNotEmpty).toList();
    if (allowed.isNotEmpty) {
      allGroups = allGroups.where((g) => allowed.contains(g.id)).toList();
    }

    final now = DateTime.now();
    DateTime dateA = DateTime(now.year, now.month, now.day);
    DistributionGroup? groupA;
    DistributionGroup? groupB;
    Employe? empA;
    Employe? empB;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final groupsOnDate = DistributionSwapService.groupsOnDutyOnDate(
            groups: allGroups,
            date: dateA,
            shiftsProv: shiftsProv,
          );

          void resetGroupsIfNeeded() {
            if (groupA != null && !groupsOnDate.any((g) => g.id == groupA!.id)) {
              groupA = null;
              empA = null;
            }
            if (groupB != null && !groupsOnDate.any((g) => g.id == groupB!.id)) {
              groupB = null;
              empB = null;
            }
            groupA ??= groupsOnDate.isNotEmpty ? groupsOnDate.first : null;
            if (groupB == null || groupB!.id == groupA?.id) {
              final othersB = groupsOnDate.where((g) => g.id != groupA?.id).toList();
              groupB = othersB.isNotEmpty ? othersB.first : null;
            }
          }

          resetGroupsIfNeeded();

          List<Employe> membersOf(DistributionGroup g) => empsProv.employes
              .where((e) => g.membreIds.contains(e.id) && e.statut == EmployeStatut.enService)
              .toList()
            ..sort((a, b) => a.nom.compareTo(b.nom));

          final membersA = groupA != null ? membersOf(groupA!) : <Employe>[];
          final membersB = groupB != null ? membersOf(groupB!) : <Employe>[];
          if (empA != null && !membersA.contains(empA)) empA = null;
          if (empB != null && !membersB.contains(empB)) empB = null;
          empA ??= membersA.isNotEmpty ? membersA.first : null;
          empB ??= membersB.isNotEmpty ? membersB.first : null;

          Future<void> pickDate() async {
            final monthStart = DateTime(dateA.year, dateA.month, 1);
            final monthEnd = DateTime(dateA.year, dateA.month + 1, 0);
            final picked = await showDatePicker(
              context: ctx,
              initialDate: dateA,
              firstDate: monthStart.subtract(const Duration(days: 90)),
              lastDate: monthEnd.isAfter(now) ? monthEnd : now,
            );
            if (picked != null) {
              setD(() {
                dateA = DateTime(picked.year, picked.month, picked.day);
                groupA = null;
                groupB = null;
                empA = null;
                empB = null;
              });
            }
          }

          String groupLabel(DistributionGroup g) =>
              '${g.nom}${DistributionSwapService.shiftLabelForGroup(groupId: g.id, date: dateA, shiftsProv: shiftsProv)}';

          return AlertDialog(
            title: const Text('Nouvel échange Distribution'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choisissez d\'abord la date, puis les groupes en service ce jour-là uniquement.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Date de manœuvre : ${dateA.day}/${dateA.month}/${dateA.year}'),
                    ),
                    const SizedBox(height: 10),
                    if (groupsOnDate.length < 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          groupsOnDate.isEmpty
                              ? 'Aucun groupe Distribution en service à cette date.'
                              : 'Un seul groupe en service : impossible de créer un échange.',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<DistributionGroup>(
                        value: groupA != null && groupsOnDate.any((g) => g.id == groupA!.id) ? groupA : null,
                        decoration: const InputDecoration(
                          labelText: 'Groupe d\'origine (A) — en service',
                          border: OutlineInputBorder(),
                        ),
                        items: groupsOnDate
                            .map((g) => DropdownMenuItem(value: g, child: Text(groupLabel(g))))
                            .toList(),
                        onChanged: (v) => setD(() {
                          groupA = v;
                          empA = null;
                          if (groupB?.id == v?.id) {
                            final ob = groupsOnDate.where((g) => g.id != v?.id).toList();
                            groupB = ob.isNotEmpty ? ob.first : null;
                            empB = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Employe>(
                        value: membersA.contains(empA) ? empA : null,
                        decoration: const InputDecoration(labelText: 'Employé A (part chez B)', border: OutlineInputBorder()),
                        items: membersA.map((e) => DropdownMenuItem(value: e, child: Text(e.nom))).toList(),
                        onChanged: (v) => setD(() => empA = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<DistributionGroup>(
                        value: groupB != null && groupsOnDate.any((g) => g.id == groupB!.id) ? groupB : null,
                        decoration: const InputDecoration(
                          labelText: 'Groupe cible (B) — en service',
                          border: OutlineInputBorder(),
                        ),
                        items: groupsOnDate
                            .where((g) => g.id != groupA?.id)
                            .map((g) => DropdownMenuItem(value: g, child: Text(groupLabel(g))))
                            .toList(),
                        onChanged: (v) => setD(() {
                          groupB = v;
                          empB = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Employe>(
                        value: membersB.contains(empB) ? empB : null,
                        decoration: const InputDecoration(
                          labelText: 'Employé B (retour plus tard)',
                          border: OutlineInputBorder(),
                        ),
                        items: membersB.map((e) => DropdownMenuItem(value: e, child: Text(e.nom))).toList(),
                        onChanged: (v) => setD(() => empB = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: groupsOnDate.length < 2
                    ? null
                    : () async {
                  if (empA == null || empB == null || groupA == null || groupB == null) return;
                  if (empA!.id == empB!.id) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Choisissez deux employés différents.')),
                    );
                    return;
                  }
                  final repo = swapsProv.repo;
                  if (repo == null) return;
                  final swap = DistributionSwap(
                    id: '',
                    employeAId: empA!.id,
                    employeBId: empB!.id,
                    groupAId: groupA!.id,
                    groupBId: groupB!.id,
                    dateAInGroupB: dateA,
                    monthKey: DistributionSwap.monthKeyFor(dateA),
                    status: DistributionSwapStatus.awaitingReturnDate,
                    createdById: auth.userId ?? '',
                    createdByName: auth.currentUser?.nom ?? '',
                    createdAt: DateTime.now(),
                  );
                  await repo.createSwap(swap);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Échange créé. Définissez la date de retour pour l\'employé B.')),
                    );
                  }
                },
                child: const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<void> showSetReturnDateDialog(
    BuildContext context,
    DistributionSwap swap,
  ) async {
    final empsProv = context.read<EmployeesProvider>();
    final groupsProv = context.read<DistributionGroupsProvider>();
    final shiftsProv = context.read<DistributionShiftsProvider>();
    final swapsProv = context.read<DistributionSwapsProvider>();
    final pointageProv = context.read<PointageProvider>();

    final empA = empsProv.employes.where((e) => e.id == swap.employeAId).toList();
    final empB = empsProv.employes.where((e) => e.id == swap.employeBId).toList();
    final nameA = empA.isNotEmpty ? empA.first.nom : swap.employeAId;
    final nameB = empB.isNotEmpty ? empB.first.nom : swap.employeBId;

    DateTime dateB = swap.dateAInGroupB;
    final monthStart = DateTime(swap.dateAInGroupB.year, swap.dateAInGroupB.month, 1);
    final monthEnd = DateTime(swap.dateAInGroupB.year, swap.dateAInGroupB.month + 1, 0);
    final now = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: dateB,
              firstDate: swap.dateAInGroupB.isBefore(monthStart) ? monthStart : swap.dateAInGroupB,
              lastDate: monthEnd.isAfter(now) ? monthEnd : now,
            );
            if (picked != null) setD(() => dateB = DateTime(picked.year, picked.month, picked.day));
          }

          var err = DistributionSwapService.validateReturnDate(dateA: swap.dateAInGroupB, dateB: dateB);
          if (err == null &&
              !DistributionSwapService.isGroupOnDutyOnDate(
                groupId: swap.groupAId,
                date: dateB,
                shiftsProv: shiftsProv,
              )) {
            err = 'Le groupe d\'origine (A) n\'est pas en service à cette date de retour.';
          }

          return AlertDialog(
            title: const Text('Date de retour (employé B)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nameA → groupe B le ${swap.dateAInGroupB.day}/${swap.dateAInGroupB.month}'),
                const SizedBox(height: 8),
                Text('Date où $nameB travaillera chez A :'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${dateB.day}/${dateB.month}/${dateB.year}'),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err, style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Le « E » (8h) de chaque employé au groupe d\'origine sera confirmé automatiquement '
                  'après que l\'autre ait terminé sa journée de manœuvre.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: err != null
                    ? null
                    : () async {
                        final repo = swapsProv.repo;
                        final pRepo = pointageProv.repository;
                        if (repo == null || pRepo == null) return;
                        await repo.updateSwap(swap.id, {
                          'dateBInGroupA': DistributionSwap.dayOnly(dateB).toIso8601String(),
                          'status': DistributionSwapStatus.scheduled.name,
                        });
                        final updated = swap.copyWith(
                          dateBInGroupA: dateB,
                          status: DistributionSwapStatus.scheduled,
                        );
                        final groupsById = {for (final g in groupsProv.groups) g.id: g};
                        final employesById = {for (final e in empsProv.employes) e.id: e};
                        await DistributionSwapService.applyScheduledSwap(
                          swap: updated,
                          pointageRepo: pRepo,
                          employesById: employesById,
                          groupsById: groupsById,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Échange planifié. Pointage renfort et E créés.')),
                          );
                        }
                      },
                child: const Text('Planifier'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwapListSheet extends StatelessWidget {
  const _SwapListSheet();

  @override
  Widget build(BuildContext context) {
    final swapsProv = context.watch<DistributionSwapsProvider>();
    final emps = context.watch<EmployeesProvider>();
    final groups = context.watch<DistributionGroupsProvider>();
    final auth = context.watch<AuthProvider>();

    String name(String id) {
      final list = emps.employes.where((e) => e.id == id).toList();
      return list.isNotEmpty ? list.first.nom : id;
    }

    String gName(String id) {
      final list = groups.groups.where((g) => g.id == id).toList();
      return list.isNotEmpty ? list.first.nom : id;
    }

    final allowed = auth.distributionGroupIds;
    var list = swapsProv.swaps
        .where((s) => s.status != DistributionSwapStatus.cancelled)
        .toList();
    if (allowed.isNotEmpty) {
      list = list
          .where((s) => allowed.contains(s.groupAId) || allowed.contains(s.groupBId))
          .toList();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Échanges Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(ctx);
                    DistributionSwapDialogs.showCreateDialog(context);
                  },
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('Aucun échange en cours.'))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final s = list[i];
                        final statusLabel = switch (s.status) {
                          DistributionSwapStatus.awaitingReturnDate => 'En attente date retour',
                          DistributionSwapStatus.scheduled => 'Planifié',
                          DistributionSwapStatus.completed => 'Terminé',
                          DistributionSwapStatus.cancelled => 'Annulé',
                        };
                        return Card(
                          child: ListTile(
                            title: Text('${name(s.employeAId)} ↔ ${name(s.employeBId)}'),
                            subtitle: Text(
                              '${gName(s.groupAId)} / ${gName(s.groupBId)}\n'
                              'A → B : ${s.dateAInGroupB.day}/${s.dateAInGroupB.month}'
                              '${s.dateBInGroupA != null ? '  •  B → A : ${s.dateBInGroupA!.day}/${s.dateBInGroupA!.month}' : ''}\n'
                              '$statusLabel',
                            ),
                            isThreeLine: true,
                            trailing: s.status == DistributionSwapStatus.awaitingReturnDate
                                ? TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      DistributionSwapDialogs.showSetReturnDateDialog(context, s);
                                    },
                                    child: const Text('Retour'),
                                  )
                                : null,
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
