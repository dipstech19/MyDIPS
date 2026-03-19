import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/site/site_model.dart';
import '../../../core/site/site_provider.dart';
import '../models/equipe_model.dart';
import '../models/employe_model.dart';

class EquipesTab extends StatefulWidget {
  final List<Equipe> equipes;
  final List<Employe> employes;
  final bool isDirecteur; // ← زيد
  final Function(Equipe) onAddEquipe;
  final Function(Equipe) onDeleteEquipe;

  const EquipesTab({
    super.key,
    required this.equipes,
    required this.employes,
    required this.isDirecteur, // ← زيد
    required this.onAddEquipe,
    required this.onDeleteEquipe,
  });

  @override
  State<EquipesTab> createState() => _EquipesTabState();
}

class _EquipesTabState extends State<EquipesTab> {
  String? _expandedId;

  /// جميع الموظفين المستعملين حالياً في أي فريق (كشاف أو كعضو)
  Set<String> _usedEmployeeIds() {
    final set = <String>{};
    for (final eq in widget.equipes) {
      if (eq.chefId.isNotEmpty) set.add(eq.chefId);
      set.addAll(eq.membreIds);
    }
    return set;
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
            if (widget.isDirecteur)
              ElevatedButton.icon(
                onPressed: () => _showAddEquipeDialog(context),
                icon: const Icon(Icons.group_add, size: 18),
                label: const Text('Nouvelle Équipe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
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
                        ? const Color(0xFF1565C0).withOpacity(0.4)
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
                                color: const Color(0xFF1565C0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.groups,
                                  color: Color(0xFF1565C0), size: 24),
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
                                  Row(children: [
                                    const Icon(Icons.store,
                                        size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(eq.magasin,
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.person,
                                        size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('Chef: ${_getNom(eq.chefId)}',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12)),
                                  ]),
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
                            // Actions — Supprimer uniquement pour le Directeur, pas pour le Chef d'équipe
                            if (widget.isDirecteur)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                color: Colors.red,
                                tooltip: 'Supprimer',
                                onPressed: () =>
                                    widget.onDeleteEquipe(eq),
                              ),
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
                                    color: Color(0xFF1565C0))),
                            const SizedBox(height: 8),
                            _membreCard(
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
                                        color: Color(0xFF1565C0))),
                                // ✅ Directeur أو Chef ديال هاد الفريق
                                if (widget.isDirecteur || eq.chefId == _getCurrentUserId())
                                  TextButton.icon(
                                    onPressed: () => _showAddMembreDialog(context, eq),
                                    icon: const Icon(Icons.person_add, size: 16),
                                    label: const Text('Ajouter membre'),
                                    style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF1565C0)),
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

  Widget _membreCard({
    required String nom,
    required String poste,
    required bool isChef,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isChef
            ? const Color(0xFF1565C0).withOpacity(0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChef
              ? const Color(0xFF1565C0).withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isChef
                ? const Color(0xFF1565C0).withOpacity(0.15)
                : Colors.grey.shade200,
            child: Text(
              nom.isNotEmpty ? nom[0] : '?',
              style: TextStyle(
                color: isChef ? const Color(0xFF1565C0) : Colors.grey[600],
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
          if (isChef)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Chef',
                  style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // DIALOG - Ajouter Équipe
  void _showAddEquipeDialog(BuildContext context) {
    final nomCtrl = TextEditingController();
    final auth = context.read<AuthProvider>();
    final site = context.read<SiteProvider>();
    final usedIds = _usedEmployeeIds();
    final availableChefs = widget.employes.where((e) => !usedIds.contains(e.id)).toList();

    if (availableChefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun employé disponible pour être chef (tous déjà dans une équipe).')),
      );
      return;
    }

    String selectedSiteId = auth.currentUser?.allowedSiteIds != null &&
            auth.currentUser!.allowedSiteIds!.isNotEmpty &&
            auth.currentUser!.allowedSiteIds!.first != SiteId.all
        ? auth.currentUser!.allowedSiteIds!.first
        : (site.selectedSiteId ?? SiteId.jadida);
    if (selectedSiteId == SiteId.all) selectedSiteId = SiteId.jadida;
    String selectedMagasin = 'El Jadida #1';
    String selectedChefId = availableChefs.first.id;
    final magasins = ['El Jadida #1', 'El Jadida #2', 'Entrepôt'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.group_add, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('Nouvelle Équipe'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom
                TextFormField(
                  controller: nomCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom de l\'équipe *',
                    hintText: 'Ex: Équipe Ventes',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                // Magasin
                DropdownButtonFormField<String>(
                  value: selectedMagasin,
                  decoration: InputDecoration(
                    labelText: 'Magasin *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: magasins
                      .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) =>
                      setStateD(() => selectedMagasin = v!),
                ),
                const SizedBox(height: 14),
                // Zone
                DropdownButtonFormField<String>(
                  value: selectedSiteId,
                  decoration: InputDecoration(
                    labelText: 'Zone (الموقع) *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida))),
                    DropdownMenuItem(value: SiteId.safi, child: Text(SiteId.labelFr(SiteId.safi))),
                  ],
                  onChanged: (v) => setStateD(() => selectedSiteId = v ?? SiteId.jadida),
                ),
                const SizedBox(height: 14),
                // Chef
                DropdownButtonFormField<String>(
                  value: selectedChefId,
                  decoration: InputDecoration(
                    labelText: 'Chef d\'équipe *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  items: availableChefs
                      .map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text('${e.nom} (${e.poste})')))
                      .toList(),
                  onChanged: (v) =>
                      setStateD(() => selectedChefId = v!),
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
                    nom: nomCtrl.text,
                    magasin: selectedMagasin,
                    chefId: selectedChefId,
                    siteId: selectedSiteId,
                  ));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG - Ajouter Membre
  void _showAddMembreDialog(BuildContext context, Equipe eq) {
    // فقط الموظفين اللي ليسوا في أي فريق آخر (لا كشيف ولا كعضو)
    final usedIds = _usedEmployeeIds();
    final disponibles = widget.employes
        .where((e) {
          if (usedIds.contains(e.id)) return false;
          final posteLower = e.poste.toLowerCase();
          // لا نسمح للـ Chef d'équipe أن يكون تحت Chef آخر
          if (posteLower.contains('chef')) return false;
          // نسمح فقط بالـ Operateur Process كأعضاء تحت الشاف (حسب طلبك)
          return posteLower.contains('operateur process');
        })
        .toList();

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les employés sont déjà dans une équipe')),
      );
      return;
    }

    String selectedId = disponibles.first.id;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setStateD) => AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('Ajouter un membre'),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: DropdownButtonFormField<String>(
              value: selectedId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Choisir un employé',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: disponibles
                  .map((e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(
                    '${e.nom} (${e.poste})',
                    overflow: TextOverflow.ellipsis,
                  )))
                  .toList(),
              onChanged: (v) => setStateD(() => selectedId = v!),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = eq.copyWith(
                  membreIds: [...eq.membreIds, selectedId],
                );
                widget.onAddEquipe(updated);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
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