import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import '../../modules/employees/employees_provider.dart';
import '../../modules/employees/models/employe_model.dart';
import '../../modules/employees/models/equipe_model.dart';
import 'pointage_provider.dart';
import 'models/pointage_model.dart';

class FormationPage extends StatefulWidget {
  const FormationPage({super.key});

  @override
  State<FormationPage> createState() => _FormationPageState();
}

class _FormationPageState extends State<FormationPage> {
  String? _selectedEquipeId; // null = toutes les équipes
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final Set<String> _selectedEmployeIds = {};
  bool _saving = false;

  // Pour chaque équipe sélectionnée, IDs déjà en formation
  Map<String, Set<String>> _alreadyInFormationByEquipe = {};
  bool _loadingFormation = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = _startDate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFormationStatus());
  }

  List<({String equipeId, String equipeName, String chefName, List<Employe> workers})> _buildAllTeams(
    BuildContext context,
  ) {
    final auth = context.read<AuthProvider>();
    final site = context.read<SiteProvider>();
    final emp = context.read<EmployeesProvider>();
    final pointage = context.read<PointageProvider>();

    final filteredEmployes = SiteId.filterBySite(
      emp.employes,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (e) => e.siteId,
    );

    final equipes = emp.equipes.where((eq) {
      return filteredEmployes.any((e) => eq.membreIds.contains(e.id) || eq.chefId == e.id);
    }).toList();

    final results = <({String equipeId, String equipeName, String chefName, List<Employe> workers})>[];

    for (final eq in equipes) {
      final chefEmp = filteredEmployes.where((e) => e.id == eq.chefId).toList();
      final chefName = chefEmp.isNotEmpty ? chefEmp.first.nom : '';
      final workers = _getWorkersForEquipe(eq, filteredEmployes, pointage);
      results.add((
        equipeId: eq.id,
        equipeName: eq.nom,
        chefName: chefName,
        workers: workers,
      ));
    }

    return results;
  }

  List<Employe> _getWorkersForEquipe(Equipe equipe, List<Employe> allEmployes, PointageProvider pointage) {
    final result = <Employe>[];
    final seen = <String>{};

    void addIfValid(String id) {
      if (seen.contains(id)) return;
      final empList = allEmployes.where((e) => e.id == id).toList();
      if (empList.isNotEmpty) {
        result.add(empList.first);
        seen.add(id);
      }
    }

    if (equipe.chefId.isNotEmpty) addIfValid(equipe.chefId);
    for (final id in equipe.membreIds) {
      addIfValid(id);
    }

    return result;
  }

  Future<void> _loadFormationStatus() async {
    if (!mounted) return;
    setState(() => _loadingFormation = true);
    final pointage = context.read<PointageProvider>();
    final allTeams = _buildAllTeams(context);
    final newMap = <String, Set<String>>{};

    final teamsToCheck = _selectedEquipeId == null
        ? allTeams
        : allTeams.where((t) => t.equipeId == _selectedEquipeId).toList();

    for (final t in teamsToCheck) {
      final ids = <String>{};
      for (final e in t.workers) {
        final r = await pointage.getRecordForEmployeeForDate(e.id, _startDate);
        if (r?.adminFinalStatus == AttendanceStatus.training) ids.add(e.id);
      }
      newMap[t.equipeId] = ids;
    }

    if (mounted) {
      setState(() {
        _alreadyInFormationByEquipe = newMap;
        _loadingFormation = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedEmployeIds.isEmpty) return;
    final pointage = context.read<PointageProvider>();
    final allTeams = _buildAllTeams(context);
    setState(() => _saving = true);

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    for (final t in allTeams) {
      for (final e in t.workers) {
        if (!_selectedEmployeIds.contains(e.id)) continue;
        for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
          await pointage.setAdminOverrideForEmployee(
            employeId: e.id,
            employeNom: e.nom,
            employeCin: e.cin,
            equipeId: t.equipeId,
            equipeName: t.equipeName,
            chefName: t.chefName,
            status: AttendanceStatus.training,
            viewDate: d,
            trainingStartAt: start,
            trainingEndAt: DateTime(end.year, end.month, end.day, 23, 59, 59),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _selectedEmployeIds.clear();
      });
      await _loadFormationStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formation planifiée avec succès'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final padding = pagePadding(context);
    final allTeams = _buildAllTeams(context);

    final displayedTeams = _selectedEquipeId == null
        ? allTeams
        : allTeams.where((t) => t.equipeId == _selectedEquipeId).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school, color: Colors.blue.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Formations',
                    style: TextStyle(
                      fontSize: mobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Planifier des formations pour les employés',
                    style: TextStyle(fontSize: mobile ? 11 : 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Filtres ────────────────────────────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: EdgeInsets.all(mobile ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paramètres',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 15, color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 14),

                  // Filtre équipe
                  Text('Équipe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: _selectedEquipeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes les équipes'),
                      ),
                      ...allTeams.map((t) => DropdownMenuItem<String?>(
                            value: t.equipeId,
                            child: Text('${t.equipeName} — ${t.chefName}', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedEquipeId = v;
                        _selectedEmployeIds.clear();
                      });
                      _loadFormationStatus();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Période
                  Text('Période de formation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: mobile ? 12 : 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          label: 'Du',
                          date: _startDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _startDate = DateTime(picked.year, picked.month, picked.day);
                                if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                                _selectedEmployeIds.clear();
                              });
                              _loadFormationStatus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DateButton(
                          label: 'Au',
                          date: _endDate,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null && mounted) {
                              setState(() => _endDate = DateTime(picked.year, picked.month, picked.day));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bouton planifier
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_selectedEmployeIds.isEmpty || _saving) ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.school, size: 18),
                      label: Text(
                        _saving
                            ? 'Enregistrement...'
                            : 'Planifier (${_fmtDate(_startDate)} → ${_fmtDate(_endDate)}) — ${_selectedEmployeIds.length} employé(s)',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Liste des équipes ──────────────────────────────────────────────
          if (_loadingFormation)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ))
          else ...[
            Text(
              _selectedEquipeId == null
                  ? 'Toutes les équipes (${allTeams.length})'
                  : 'Équipe sélectionnée',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: mobile ? 13 : 15),
            ),
            const SizedBox(height: 10),
            ...displayedTeams.map((t) {
              final alreadyIn = _alreadyInFormationByEquipe[t.equipeId] ?? {};
              final teamSelected = t.workers
                  .where((w) => _selectedEmployeIds.contains(w.id))
                  .length;
              return _TeamCard(
                team: t,
                alreadyInFormationIds: alreadyIn,
                selectedIds: _selectedEmployeIds,
                selectedCount: teamSelected,
                fmtDate: _fmtDate,
                startDate: _startDate,
                onToggleEmployee: (id, selected) {
                  setState(() {
                    if (selected) {
                      _selectedEmployeIds.add(id);
                    } else {
                      _selectedEmployeIds.remove(id);
                    }
                  });
                },
                onSelectAll: (workerIds) {
                  setState(() {
                    for (final id in workerIds) {
                      if (!alreadyIn.contains(id)) {
                        _selectedEmployeIds.add(id);
                      }
                    }
                  });
                },
                onDeselectAll: (workerIds) {
                  setState(() {
                    for (final id in workerIds) {
                      _selectedEmployeIds.remove(id);
                    }
                  });
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte d'équipe
// ─────────────────────────────────────────────────────────────────────────────
class _TeamCard extends StatelessWidget {
  final ({String equipeId, String equipeName, String chefName, List<Employe> workers}) team;
  final Set<String> alreadyInFormationIds;
  final Set<String> selectedIds;
  final int selectedCount;
  final String Function(DateTime) fmtDate;
  final DateTime startDate;
  final void Function(String id, bool selected) onToggleEmployee;
  final void Function(List<String> ids) onSelectAll;
  final void Function(List<String> ids) onDeselectAll;

  const _TeamCard({
    required this.team,
    required this.alreadyInFormationIds,
    required this.selectedIds,
    required this.selectedCount,
    required this.fmtDate,
    required this.startDate,
    required this.onToggleEmployee,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    final availableWorkerIds = team.workers
        .where((w) => !alreadyInFormationIds.contains(w.id))
        .map((w) => w.id)
        .toList();
    final allAvailableSelected = availableWorkerIds.isNotEmpty &&
        availableWorkerIds.every((id) => selectedIds.contains(id));
    final inFormationCount = alreadyInFormationIds.length;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.group, color: Colors.blue.shade700, size: 20),
        ),
        title: Text(
          team.equipeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(
              'Chef: ${team.chefName}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            if (inFormationCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$inFormationCount en formation',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (selectedCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$selectedCount sélectionné(s)',
                  style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Actions rapides
                if (availableWorkerIds.isNotEmpty)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: allAvailableSelected
                            ? () => onDeselectAll(availableWorkerIds)
                            : () => onSelectAll(availableWorkerIds),
                        icon: Icon(
                          allAvailableSelected ? Icons.deselect : Icons.select_all,
                          size: 16,
                        ),
                        label: Text(
                          allAvailableSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 8),

                // Liste des employés
                ...team.workers.map((e) {
                  final alreadyIn = alreadyInFormationIds.contains(e.id);
                  final selected = selectedIds.contains(e.id);
                  return CheckboxListTile(
                    dense: true,
                    value: selected,
                    onChanged: alreadyIn
                        ? null
                        : (v) => onToggleEmployee(e.id, v == true),
                    title: Text(
                      e.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: alreadyIn ? Colors.grey : null,
                      ),
                    ),
                    subtitle: alreadyIn
                        ? Text(
                            'Déjà en formation — ${fmtDate(startDate)}',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                          )
                        : null,
                    secondary: alreadyIn
                        ? Icon(Icons.school, size: 18, color: Colors.blue.shade400)
                        : null,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton de date
// ─────────────────────────────────────────────────────────────────────────────
class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Colors.blue.shade700;
    final fmt =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: color),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text(fmt,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
