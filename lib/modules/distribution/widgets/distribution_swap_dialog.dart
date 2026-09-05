import 'package:flutter/material.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import '../../employees/employees_provider.dart';
import '../../employees/models/employe_model.dart';
import '../../employees/models/equipe_model.dart';
import '../../../core/auth/auth_provider.dart';
import '../distribution_groups_provider.dart';
import '../distribution_shifts_provider.dart';
import '../distribution_swaps_provider.dart';
import '../models/distribution_group_model.dart';
import '../models/distribution_swap_model.dart';
import '../services/distribution_swap_service.dart';
import '../../pointage/pointage_provider.dart';

// ── Abstraction légère pour unifier DistributionGroup et Equipe ──────────────
class _SwapGroupItem {
  final String id;
  final String nom;
  final List<String> membreIds;

  _SwapGroupItem({required this.id, required this.nom, required this.membreIds});

  factory _SwapGroupItem.fromDistribution(DistributionGroup g) =>
      _SwapGroupItem(id: g.id, nom: g.nom, membreIds: g.membreIds);

  factory _SwapGroupItem.fromEquipe(Equipe e) =>
      _SwapGroupItem(id: e.id, nom: e.nom, membreIds: e.membreIds);
}

/// Dialogues d'échange entre membres d'équipes (Distribution ou Dessalement).
class DistributionSwapDialogs {
  static bool canOpen(AuthProvider auth) => DistributionSwapService.canManageSwaps(
        isDistributionResponsable: auth.isDistributionResponsable,
        isChefZoneAdmin: auth.isChefZoneAdmin,
      );

  static Future<void> showManageSheet(BuildContext context, {String sectionType = 'distribution'}) async {
    final auth = context.read<AuthProvider>();
    if (!canOpen(auth)) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SwapListSheet(initialSection: sectionType),
    );
  }

  static Future<void> showCreateDialog(BuildContext context, {String initialSection = 'distribution'}) async {
    final auth = context.read<AuthProvider>();
    if (!canOpen(auth)) return;

    final groupsProv = context.read<DistributionGroupsProvider>();
    final shiftsProv = context.read<DistributionShiftsProvider>();
    final empsProv = context.read<EmployeesProvider>();
    final swapsProv = context.read<DistributionSwapsProvider>();
    final pointageProv = context.read<PointageProvider>();
    final allowed = auth.distributionGroupIds;

    final now = DateTime.now();
    DateTime dateA = DateTime(now.year, now.month, now.day);
    String sectionType = initialSection;
    _SwapGroupItem? groupA;
    _SwapGroupItem? groupB;
    Employe? empA;
    Employe? empB;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {

          // ── Liste des groupes selon la section ──────────────────────────
          List<_SwapGroupItem> allGroups() {
            if (sectionType == 'dessalement') {
              return empsProv.equipes
                  .where((e) => e.membreIds.isNotEmpty)
                  .map(_SwapGroupItem.fromEquipe)
                  .toList()
                ..sort((a, b) => a.nom.compareTo(b.nom));
            }
            var dGroups = groupsProv.groups.where((g) => g.membreIds.isNotEmpty).toList();
            if (allowed.isNotEmpty) {
              dGroups = dGroups.where((g) => allowed.contains(g.id)).toList();
            }
            return dGroups.map(_SwapGroupItem.fromDistribution).toList();
          }

          void resetGroups() {
            final groups = allGroups();
            if (groupA != null && !groups.any((g) => g.id == groupA!.id)) {
              groupA = null;
              empA = null;
            }
            if (groupB != null && !groups.any((g) => g.id == groupB!.id)) {
              groupB = null;
              empB = null;
            }
            groupA ??= groups.isNotEmpty ? groups.first : null;
            if (groupB == null || groupB!.id == groupA?.id) {
              final others = groups.where((g) => g.id != groupA?.id).toList();
              groupB = others.isNotEmpty ? others.first : null;
            }
          }

          resetGroups();
          final groups = allGroups();

          List<Employe> membersOf(_SwapGroupItem g) => empsProv.employes
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

          String groupLabel(_SwapGroupItem g) {
            if (sectionType == 'distribution') {
              return '${g.nom}${DistributionSwapService.shiftLabelForGroup(groupId: g.id, date: dateA, shiftsProv: shiftsProv)}';
            }
            return g.nom;
          }

          final teamLabel = sectionType == 'dessalement' ? 'Équipe' : 'Groupe';

          return AlertDialog(
            title: Text('Nouvel échange ${sectionType == 'dessalement' ? 'Dessalement' : 'Distribution'}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Sélecteur de section ────────────────────────────────
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'distribution', label: Text('Distribution')),
                        ButtonSegment(value: 'dessalement', label: Text('Dessalement')),
                      ],
                      selected: {sectionType},
                      onSelectionChanged: (s) => setD(() {
                        sectionType = s.first;
                        groupA = null;
                        groupB = null;
                        empA = null;
                        empB = null;
                      }),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      sectionType == 'dessalement'
                          ? 'Choisissez les équipes Dessalement et les collaborateurs à échanger.'
                          : 'Choisissez la date et les groupes (tous les groupes sont disponibles, y compris ceux en repos).',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text("Date d'échange : ${dateA.day}/${dateA.month}/${dateA.year}"),
                    ),
                    const SizedBox(height: 10),
                    if (groups.length < 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          groups.isEmpty
                              ? 'Aucune ${teamLabel.toLowerCase()} disponible.'
                              : 'Un seul $teamLabel disponible : impossible de créer un échange.',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<_SwapGroupItem>(
                        value: groupA != null && groups.any((g) => g.id == groupA!.id) ? groupA : null,
                        decoration: InputDecoration(
                          labelText: '$teamLabel d\'origine (A)',
                          border: const OutlineInputBorder(),
                        ),
                        items: groups
                            .map((g) => DropdownMenuItem(value: g, child: Text(groupLabel(g))))
                            .toList(),
                        onChanged: (v) => setD(() {
                          groupA = v;
                          empA = null;
                          if (groupB?.id == v?.id) {
                            final ob = groups.where((g) => g.id != v?.id).toList();
                            groupB = ob.isNotEmpty ? ob.first : null;
                            empB = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<Employe>(
                        value: membersA.contains(empA) ? empA : null,
                        decoration: InputDecoration(
                          labelText: 'Collaborateur remplacé (quitte $teamLabel A)',
                          border: const OutlineInputBorder(),
                        ),
                        items: membersA.map((e) => DropdownMenuItem(value: e, child: Text(e.nom))).toList(),
                        onChanged: (v) => setD(() => empA = v),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<_SwapGroupItem>(
                        value: groupB != null && groups.any((g) => g.id == groupB!.id) ? groupB : null,
                        decoration: InputDecoration(
                          labelText: '$teamLabel cible (B)',
                          border: const OutlineInputBorder(),
                        ),
                        items: groups
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
                        decoration: InputDecoration(
                          labelText: 'Collaborateur remplaçant (vient dans $teamLabel A)',
                          border: const OutlineInputBorder(),
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
                onPressed: groups.length < 2
                    ? null
                    : () async {
                        if (empA == null || empB == null || groupA == null || groupB == null) return;
                        if (empA!.id == empB!.id) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Choisissez deux collaborateurs différents.')),
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
                          dateBInGroupA: dateA,
                          monthKey: DistributionSwap.monthKeyFor(dateA),
                          status: DistributionSwapStatus.scheduled,
                          createdById: auth.userId ?? '',
                          createdByName: auth.currentUser?.nom ?? '',
                          createdAt: DateTime.now(),
                          sectionType: sectionType,
                        );
                        final newId = await repo.createSwap(swap);
                        final pRepo = pointageProv.repository;
                        if (pRepo != null) {
                          final createdSwap = DistributionSwap(
                            id: newId,
                            employeAId: empA!.id,
                            employeBId: empB!.id,
                            groupAId: groupA!.id,
                            groupBId: groupB!.id,
                            dateAInGroupB: dateA,
                            dateBInGroupA: dateA,
                            monthKey: DistributionSwap.monthKeyFor(dateA),
                            status: DistributionSwapStatus.scheduled,
                            createdById: auth.userId ?? '',
                            createdByName: auth.currentUser?.nom ?? '',
                            createdAt: DateTime.now(),
                            sectionType: sectionType,
                          );
                          final groupsById = {for (final g in groupsProv.groups) g.id: g};
                          final employesById = {for (final e in empsProv.employes) e.id: e};
                          final equipesById = {for (final e in empsProv.equipes) e.id: e};
                          await DistributionSwapService.applyScheduledSwap(
                            swap: createdSwap,
                            pointageRepo: pRepo,
                            employesById: employesById,
                            groupsById: groupsById,
                            equipesById: equipesById,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Échange créé. Le pointage est mis à jour.')),
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
          // Pour Distribution seulement : vérifier que le groupe A est en service à dateB
          if (err == null && swap.sectionType == 'distribution') {
            if (!DistributionSwapService.isGroupOnDutyOnDate(
              groupId: swap.groupAId,
              date: dateB,
              shiftsProv: shiftsProv,
            )) {
              err = 'Le groupe d\'origine (A) n\'est pas en service à cette date de retour.';
            }
          }

          return AlertDialog(
            title: const Text('Date de retour (collaborateur B)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nameA → ${swap.sectionType == 'dessalement' ? 'Équipe' : 'Groupe'} B le ${swap.dateAInGroupB.day}/${swap.dateAInGroupB.month}'),
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
                  'Le « E » (8h) de chaque collaborateur au groupe d\'origine sera confirmé automatiquement '
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
                        if (!await confirmUpdate(ctx,
                            message: "Enregistrer cette modification de l'échange ?")) {
                          return;
                        }
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
                        final equipesById = {for (final e in empsProv.equipes) e.id: e};
                        await DistributionSwapService.applyScheduledSwap(
                          swap: updated,
                          pointageRepo: pRepo,
                          employesById: employesById,
                          groupsById: groupsById,
                          equipesById: equipesById,
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

class _SwapListSheet extends StatefulWidget {
  final String initialSection;
  const _SwapListSheet({this.initialSection = 'distribution'});

  @override
  State<_SwapListSheet> createState() => _SwapListSheetState();
}

class _SwapListSheetState extends State<_SwapListSheet> {
  late String _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

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

    String gName(DistributionSwap s, String groupId) {
      if (s.sectionType == 'dessalement') {
        final eq = emps.equipes.where((e) => e.id == groupId).toList();
        return eq.isNotEmpty ? eq.first.nom : groupId;
      }
      final list = groups.groups.where((g) => g.id == groupId).toList();
      return list.isNotEmpty ? list.first.nom : groupId;
    }

    final allowed = auth.distributionGroupIds;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    var list = swapsProv.swaps
        .where((s) =>
            s.sectionType == _section &&
            s.status != DistributionSwapStatus.cancelled &&
            s.status != DistributionSwapStatus.completed &&
            !s.dateAInGroupB.isAfter(todayDay))
        .toList();
    if (allowed.isNotEmpty && _section == 'distribution') {
      list = list
          .where((s) => allowed.contains(s.groupAId) || allowed.contains(s.groupBId))
          .toList();
    }

    final sectionTitle = _section == 'dessalement' ? 'Dessalement' : 'Distribution';

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
                Expanded(
                  child: Text('Échanges $sectionTitle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(ctx);
                    DistributionSwapDialogs.showCreateDialog(context, initialSection: _section);
                  },
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            // ── Sélecteur de section ──────────────────────────────────────
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'distribution', label: Text('Distribution')),
                ButtonSegment(value: 'dessalement', label: Text('Dessalement')),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 8),
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
                              '${gName(s, s.groupAId)} / ${gName(s, s.groupBId)}\n'
                              'A → B : ${s.dateAInGroupB.day}/${s.dateAInGroupB.month}'
                              '${s.dateBInGroupA != null ? '  •  B → A : ${s.dateBInGroupA!.day}/${s.dateBInGroupA!.month}' : ''}\n'
                              '$statusLabel',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (s.status == DistributionSwapStatus.awaitingReturnDate)
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      DistributionSwapDialogs.showSetReturnDateDialog(context, s);
                                    },
                                    child: const Text('Retour'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'Supprimer',
                                  onPressed: () async {
                                    final swapsProv = context.read<DistributionSwapsProvider>();
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (d) => AlertDialog(
                                        title: const Text('Supprimer l\'échange ?'),
                                        content: Text(
                                          'Supprimer l\'échange entre ${name(s.employeAId)} et ${name(s.employeBId)} ?',
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(d, true),
                                            child: const Text('Supprimer'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await swapsProv.deleteSwap(s.id);
                                    }
                                  },
                                ),
                              ],
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
