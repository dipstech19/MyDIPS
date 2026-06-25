import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/site/site_model.dart';
import '../../../core/site/site_provider.dart';
import '../../groupes/groupes_provider.dart';
import '../departements_provider.dart';
import '../postes_provider.dart';
import '../models/equipe_model.dart';
import '../models/employe_model.dart';

class EquipesTab extends StatefulWidget {
  final List<Equipe> equipes;
  final List<Employe> employes;
  final bool isDirecteur;
  final bool canManageTeams;
  final bool canManageMembers;
  final Function(Equipe) onAddEquipe;
  final Function(Equipe) onDeleteEquipe;
  final bool internalScroll;

  const EquipesTab({
    super.key,
    required this.equipes,
    required this.employes,
    required this.isDirecteur,
    required this.canManageTeams,
    required this.canManageMembers,
    required this.onAddEquipe,
    required this.onDeleteEquipe,
    this.internalScroll = true,
  });

  @override
  State<EquipesTab> createState() => _EquipesTabState();
}

class _EquipesTabState extends State<EquipesTab> {
  String? _expandedId;

  List<Employe> _unassignedOperateurs() {
    final used = _usedEmployeeIds();
    final list = widget.employes
        .where((e) =>
            !used.contains(e.id) &&
            !_isChefEquipePoste(e.poste) &&
            _isOperateurProcessPoste(e.poste))
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
    return list;
  }

  void _showAssignUnassignedDialog(BuildContext context) {
    final unassigned = _unassignedOperateurs();
    if (unassigned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun Operateur Process sans équipe.')),
      );
      return;
    }
    if (widget.equipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Créez une équipe d\'abord.')),
      );
      return;
    }

    String selectedEquipeId = widget.equipes.first.id;
    final selectedIds = <String>{for (final e in unassigned) e.id};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.group_add, color: Color(0xFF000966)),
              SizedBox(width: 10),
              Text('Affecter des collaborateurs sans équipe'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedEquipeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Équipe cible *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: widget.equipes
                      .map((eq) => DropdownMenuItem(
                            value: eq.id,
                            child: Text(eq.nom, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedEquipeId = v ?? widget.equipes.first.id),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${unassigned.length} Operateur Process sans équipe',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setStateD(() {
                        selectedIds
                          ..clear()
                          ..addAll(unassigned.map((e) => e.id));
                      }),
                      child: const Text('Tout sélectionner'),
                    ),
                    TextButton(
                      onPressed: () => setStateD(() => selectedIds.clear()),
                      child: const Text('Tout désélectionner'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: unassigned.length,
                    itemBuilder: (context, i) {
                      final e = unassigned[i];
                      final checked = selectedIds.contains(e.id);
                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(e.nom, overflow: TextOverflow.ellipsis),
                        subtitle: Text(e.poste, overflow: TextOverflow.ellipsis),
                        onChanged: (v) => setStateD(() {
                          if (v == true) {
                            selectedIds.add(e.id);
                          } else {
                            selectedIds.remove(e.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000966), foregroundColor: Colors.white),
              onPressed: () {
                if (selectedIds.isEmpty) return;
                final target = widget.equipes.where((e) => e.id == selectedEquipeId).toList();
                if (target.isEmpty) return;
                final eq = target.first;
                final merged = {...eq.membreIds, ...selectedIds}.toList();
                widget.onAddEquipe(eq.copyWith(membreIds: merged));
                Navigator.pop(ctx);
              },
              child: const Text('Affecter'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isChefEquipePoste(String poste) {
    final p = poste.trim().toLowerCase();
    // Accept common variants (with/without apostrophe/accents).
    return p == "chef d'équipe" || p == "chef d’equipe" || p == "chef d'equipe" || p == "chef d equipe";
  }

  bool _isOperateurProcessPoste(String poste) {
    final p = poste.trim().toLowerCase();
    // Matches: "Operateur Process" (with/without accents / extra spaces).
    return p == 'operateur process' ||
        p == 'opérateur process' ||
        p == 'operateur  process' ||
        p == 'opérateur  process';
  }

  String _getNom(String id) {
    final e = widget.employes.where((e) => e.id == id).toList();
    return e.isNotEmpty ? e.first.nom : '—';
  }
  String _getCurrentUserId() {
    final auth = context.read<AuthProvider>();
    return auth.currentUser?.id ?? '';
  }

  String _getPoste(String id) {
    final e = widget.employes.where((e) => e.id == id).toList();
    return e.isNotEmpty ? e.first.poste : '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
// ===== HEADER - بدل هاد الجزء =====
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${widget.equipes.length} équipe(s)',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            // ✅ زر Nouvelle Équipe فقط للـ Directeur
            if (widget.canManageTeams)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showAssignUnassignedDialog(context),
                    icon: const Icon(Icons.group_work_outlined, size: 18),
                    label: const Text('Affecter sans équipe'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEquipeDialog(context),
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Nouvelle Équipe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF000966),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),

        // LISTE ÉQUIPES
        Expanded(
          child: widget.equipes.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups, size: 52, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Aucune équipe',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15)),
              ],
            ),
          )
              : ListView.separated(
            itemCount: widget.equipes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final eq = widget.equipes[i];
              final isExpanded = _expandedId == eq.id;
              final membres = widget.employes
                  .where((e) => eq.membreIds.contains(e.id))
                  .toList();

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpanded
                        ? const Color(0xFF000966).withOpacity(0.4)
                        : Colors.grey.shade200,
                    width: isExpanded ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // HEADER DE L'ÉQUIPE
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() =>
                      _expandedId = isExpanded ? null : eq.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon équipe
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF000966).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.groups,
                                  color: Color(0xFF000966), size: 24),
                            ),
                            const SizedBox(width: 14),
                            // Info équipe
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(eq.nom,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.store, size: 13, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            eq.magasin,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person, size: 13, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Chef: ${_getNom(eq.chefId)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Badge membres
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${membres.length} membre(s)',
                                style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Actions — Modifier/Supprimer pour le Directeur
                            if (widget.canManageTeams) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: const Color(0xFF000966),
                                tooltip: 'Renommer',
                                onPressed: () => _showRenameEquipeDialog(context, eq),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: Colors.red,
                                tooltip: 'Supprimer',
                                onPressed: () => widget.onDeleteEquipe(eq),
                              ),
                            ],
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // MEMBRES (expandable)
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chef
                            const Text('Chef d\'équipe',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF000966))),
                            const SizedBox(height: 8),
                            _membreCard(
                              equipe: eq,
                              employeId: eq.chefId,
                              nom: _getNom(eq.chefId),
                              poste: _getPoste(eq.chefId),
                              isChef: true,
                            ),
                            const SizedBox(height: 12),
                            // Membres
// بدل Row ديال "Membres"
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Membres',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Color(0xFF000966))),
                                // ✅ Directeur أو Chef ديال هاد الفريق
                                if (widget.canManageMembers || eq.chefId == _getCurrentUserId())
                                  TextButton.icon(
                                    onPressed: () => _showAddMembreDialog(context, eq),
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Ajouter membre'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF000966)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            membres.isEmpty
                                ? Text('Aucun membre',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13))
                                : Column(
                            children: membres
                                .map((m) => _membreCard(
                                      equipe: eq,
                                      employeId: m.id,
                                      nom: m.nom,
                                      poste: m.poste,
                                      isChef: false,
                                    ))
                                .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _removeMembre(Equipe equipe, String employeId) {
    final updated = equipe.copyWith(
      membreIds: equipe.membreIds.where((id) => id != employeId).toList(),
    );
    widget.onAddEquipe(updated);
  }

  Widget _membreCard({
    required Equipe equipe,
    required String employeId,
    required String nom,
    required String poste,
    required bool isChef,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isChef
            ? const Color(0xFF000966).withOpacity(0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChef
              ? const Color(0xFF000966).withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isChef
                ? const Color(0xFF000966).withOpacity(0.15)
                : Colors.grey.shade200,
            child: Text(
              nom.isNotEmpty ? nom[0] : '?',
              style: TextStyle(
                color: isChef ? const Color(0xFF000966) : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(poste,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          if (!isChef && widget.canManageMembers)
            IconButton(
              tooltip: 'Retirer',
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[400], size: 20),
              onPressed: () => _removeMembre(equipe, employeId),
            ),
          if (isChef) ...[
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF000966).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Chef',
                  style: TextStyle(
                      color: Color(0xFF000966),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            if (widget.canManageTeams)
              IconButton(
                tooltip: 'Changer le chef d\'équipe',
                icon: const Icon(Icons.swap_horiz, size: 20),
                color: const Color(0xFF000966),
                onPressed: () => _showChangeChefDialog(context, equipe),
              ),
          ],
        ],
      ),
    );
  }

  // DIALOG - Ajouter Équipe
  Set<String> _usedEmployeeIds() {
    final set = <String>{};
    for (final eq in widget.equipes) {
      if (eq.chefId.isNotEmpty) set.add(eq.chefId);
      set.addAll(eq.membreIds);
    }
    // Also exclude employees already in any Groupe.
    final groupes = context.read<GroupesProvider>().groupes;
    for (final g in groupes) {
      set.addAll(g.membreIds);
    }
    return set;
  }

  void _showAddEquipeDialog(BuildContext context) {
    final nomCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    final site = context.read<SiteProvider>();
    final deptNames = context.read<DepartementsProvider>().departements.map((d) => d.nom).toList();
    final usedIds = _usedEmployeeIds();
    final availableChefs = widget.employes
        .where((e) => !usedIds.contains(e.id) && _isChefEquipePoste(e.poste))
        .toList();

    if (availableChefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucun "Chef d\'équipe" disponible (ou tous déjà dans une équipe).')),
      );
      return;
    }

    String selectedSiteId = auth.currentUser?.allowedSiteIds != null &&
            auth.currentUser!.allowedSiteIds!.isNotEmpty &&
            auth.currentUser!.allowedSiteIds!.first != SiteId.all
        ? auth.currentUser!.allowedSiteIds!.first
        : (site.selectedSiteId ?? SiteId.jadida);
    if (selectedSiteId == SiteId.all) selectedSiteId = SiteId.jadida;
    String selectedDepartement = deptNames.isNotEmpty ? deptNames.first : '';
    String selectedChefId = availableChefs.first.id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.group_add, color: Color(0xFF000966)),
              SizedBox(width: 10),
              Text('Nouvelle Équipe'),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'équipe *',
                    hintText: 'Ex: Équipe Ventes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Site *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setStateD(() => selectedSiteId = v ?? SiteId.jadida),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: deptNames.isEmpty ? '' : selectedDepartement,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Département *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: (deptNames.isEmpty ? <String>[''] : deptNames)
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.isEmpty ? '—' : d, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedDepartement = v ?? ''),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedChefId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Chef d\'équipe *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: availableChefs
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.nom} (${e.poste})', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedChefId = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nomCtrl.text.isNotEmpty && selectedChefId.isNotEmpty) {
                  widget.onAddEquipe(Equipe(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nom: nomCtrl.text.trim(),
                    magasin: selectedDepartement,
                    chefId: selectedChefId,
                    siteId: selectedSiteId,
                  ));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000966),
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG - Renommer Équipe
  void _showRenameEquipeDialog(BuildContext context, Equipe eq) {
    final ctrl = TextEditingController(text: eq.nom);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit_outlined, color: Color(0xFF000966)),
            SizedBox(width: 10),
            Text('Renommer l\'équipe'),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nouveau nom *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty && newName != eq.nom) {
                widget.onAddEquipe(eq.copyWith(nom: newName));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF000966),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // DIALOG - Changer Chef d'Équipe
  void _showChangeChefDialog(BuildContext context, Equipe eq) {
    final dept = eq.magasin.trim().toLowerCase();
    final availableChefs = widget.employes
        .where((e) =>
            _isChefEquipePoste(e.poste) &&
            e.departement.trim().toLowerCase() == dept)
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));

    if (availableChefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun "Chef d\'équipe" dans le département "${eq.magasin}".')),
      );
      return;
    }

    String selectedChefId = availableChefs.any((e) => e.id == eq.chefId)
        ? eq.chefId
        : availableChefs.first.id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF000966)),
              SizedBox(width: 10),
              Text('Changer le chef d\'équipe'),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: DropdownButtonFormField<String>(
              value: selectedChefId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Nouveau chef d\'équipe *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: availableChefs
                  .map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          e.id == eq.chefId ? '${e.nom} (actuel)' : e.nom,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setStateD(() => selectedChefId = v ?? selectedChefId),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000966),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (selectedChefId != eq.chefId) {
                  widget.onAddEquipe(eq.copyWith(chefId: selectedChefId));
                }
                Navigator.pop(ctx);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG - Ajouter Membre
  void _showAddMembreDialog(BuildContext context, Equipe eq) {
    // كل عامل في équipe واحدة فقط:
    // - لا يظهر إذا كان chef أو عضو في أي équipe
    // - عند إضافة عضو: نسمح باختيار poste ثم نعرض فقط هذا poste
    final usedIds = _usedEmployeeIds();
    // Prefer postes from Paramètres (Firestore). If empty, fallback to distinct postes from employees.
    // IMPORTANT: do not use context.watch here (outside build); it can break dialog interaction.
    final postesProv = context.read<PostesProvider>();
    final posteNamesFromConfig = postesProv.postes.map((p) => p.nom).where((p) => p.trim().isNotEmpty).toList()..sort();
    final posteNamesFallback = widget.employes
        .map((e) => e.poste.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final posteNames = posteNamesFromConfig.isNotEmpty ? posteNamesFromConfig : posteNamesFallback;
    String? selectedPoste = posteNames.isNotEmpty ? posteNames.first : null;
    List<Employe> disponiblesFor(String? poste) {
      final p = (poste ?? '').trim().toLowerCase();
      final list = widget.employes
          .where((e) => !usedIds.contains(e.id) && e.poste.trim().toLowerCase() == p)
          .toList()
        ..sort((a, b) => a.nom.compareTo(b.nom));
      return list;
    }
    var disponibles = disponiblesFor(selectedPoste);
    String? selectedId = disponibles.isNotEmpty ? disponibles.first.id : null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF000966)),
              SizedBox(width: 10),
              Text('Ajouter un membre'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPoste,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Poste',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: posteNames
                      .map((p) => DropdownMenuItem<String>(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    setStateD(() {
                      selectedPoste = v;
                      disponibles = disponiblesFor(selectedPoste);
                      selectedId = disponibles.isNotEmpty ? disponibles.first.id : null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Choisir un collaborateur',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: disponibles
                      .map((e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text('${e.nom} (${e.poste})', overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setStateD(() => selectedId = v),
                ),
                if (disponibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('Aucun collaborateur disponible pour ce poste.', style: TextStyle(color: Colors.grey[700])),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: selectedId == null
                  ? null
                  : () {
                final updated = eq.copyWith(
                  membreIds: [...eq.membreIds, selectedId!],
                );
                widget.onAddEquipe(updated);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000966),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}