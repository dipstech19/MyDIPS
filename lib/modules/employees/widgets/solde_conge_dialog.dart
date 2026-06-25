import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/smart_avatar.dart';
import '../models/employe_model.dart';
import '../utils/leave_days_utils.dart';

enum _ResetMode { takenOnly, full }

// ─────────────────────────────────────────────
// Local state for one employee's leave data
// ─────────────────────────────────────────────
class _LeaveData {
  final Employe original;
  double localTaken;
  double localExtra;
  late TextEditingController ctrl;
  bool modified = false;

  _LeaveData(this.original)
      : localTaken = original.leaveDaysTaken,
        localExtra = original.leaveDaysExtra {
    ctrl = TextEditingController(text: _currentSolde.toStringAsFixed(1));
  }

  double get acquired => leaveDaysAcquired(original.dateDebut);
  double get _currentSolde => acquired + localExtra - localTaken;

  /// Met à jour localExtra depuis une valeur de solde saisie par l'utilisateur.
  void applySoldeText(String text) {
    final val = double.tryParse(text.replaceAll(',', '.'));
    if (val == null) return;
    final newExtra = val - acquired + localTaken;
    if ((newExtra - localExtra).abs() > 0.001) {
      localExtra = newExtra;
      modified = true;
    }
  }

  void resetTaken() {
    localTaken = 0;
    modified = true;
    ctrl.text = _currentSolde.toStringAsFixed(1);
  }

  void resetFull() {
    localTaken = 0;
    localExtra = 0;
    modified = true;
    ctrl.text = _currentSolde.toStringAsFixed(1);
  }

  void dispose() => ctrl.dispose();
}

// ─────────────────────────────────────────────
// Main Dialog
// ─────────────────────────────────────────────
class SoldeCongeDialog extends StatefulWidget {
  final List<Employe> employes;
  final VoidCallback? onSaved;

  const SoldeCongeDialog({
    super.key,
    required this.employes,
    this.onSaved,
  });

  @override
  State<SoldeCongeDialog> createState() => _SoldeCongeDialogState();
}

class _SoldeCongeDialogState extends State<SoldeCongeDialog> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Map<String, _LeaveData> _dataMap;
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dataMap = {
      for (final e in widget.employes.where((e) => e.statut != EmployeStatut.quitte))
        e.id: _LeaveData(e),
    };
  }

  @override
  void dispose() {
    for (final d in _dataMap.values) { d.dispose(); }
    super.dispose();
  }

  List<_LeaveData> get _filtered {
    final list = _dataMap.values.toList()
      ..sort((a, b) => a.original.nom.compareTo(b.original.nom));
    final q = _search.toLowerCase().trim();
    if (q.isEmpty) return list;
    return list.where((d) {
      final e = d.original;
      return e.nom.toLowerCase().contains(q) ||
          e.poste.toLowerCase().contains(q) ||
          e.departement.toLowerCase().contains(q);
    }).toList();
  }

  // ─── Save ───
  Future<void> _save() async {
    // Flush all controller values into local state first
    for (final d in _dataMap.values) {
      d.applySoldeText(d.ctrl.text);
    }
    final toUpdate = _dataMap.values.where((d) => d.modified).toList();
    if (toUpdate.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    try {
      for (var i = 0; i < toUpdate.length; i += 500) {
        final chunk = toUpdate.sublist(i, (i + 500).clamp(0, toUpdate.length));
        final batch = _db.batch();
        for (final d in chunk) {
          batch.update(_db.collection('employes').doc(d.original.id), {
            'leaveDaysExtra': d.localExtra,
            'leaveDaysTaken': d.localTaken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
      widget.onSaved?.call();
      if (mounted) {
        _showSnack('${toUpdate.length} solde(s) enregistré(s)', success: true);
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) _showSnack('Erreur: $err', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Reset flow ───
  Future<void> _startReset() async {
    final mode = await showDialog<_ResetMode>(
      context: context,
      builder: (_) => _ResetChoiceDialog(employeCount: _dataMap.length),
    );
    if (mode == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(mode == _ResetMode.takenOnly
            ? 'Réinitialiser les jours pris ?'
            : 'Réinitialisation complète ?'),
        content: Text(mode == _ResetMode.takenOnly
            ? 'Les jours pris de tous les ${_dataMap.length} collaborateurs actifs seront remis à 0.\n\nLes jours extra/reportés seront conservés.'
            : 'Les jours pris ET les jours extra de tous les ${_dataMap.length} collaborateurs actifs seront remis à 0.\n\nLe solde sera réduit aux seuls jours acquis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      for (final d in _dataMap.values) {
        if (mode == _ResetMode.full) {
          d.resetFull();
        } else {
          d.resetTaken();
        }
      }
    });

    setState(() => _saving = true);
    try {
      final all = _dataMap.values.toList();
      for (var i = 0; i < all.length; i += 500) {
        final chunk = all.sublist(i, (i + 500).clamp(0, all.length));
        final batch = _db.batch();
        for (final d in chunk) {
          final update = <String, dynamic>{
            'leaveDaysTaken': 0.0,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (mode == _ResetMode.full) update['leaveDaysExtra'] = 0.0;
          batch.update(_db.collection('employes').doc(d.original.id), update);
        }
        await batch.commit();
      }
      widget.onSaved?.call();
      if (mounted) {
        _showSnack(
          mode == _ResetMode.takenOnly
              ? 'Jours pris réinitialisés pour ${_dataMap.length} collaborateurs'
              : 'Soldes réinitialisés pour ${_dataMap.length} collaborateurs',
          success: true,
        );
      }
    } catch (err) {
      if (mounted) _showSnack('Erreur: $err', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final screenW = MediaQuery.of(context).size.width;
    final mobile = screenW < 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 32,
        vertical: mobile ? 20 : 40,
      ),
      child: Container(
        width: 880,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 8),
            _buildTableHeader(mobile),
            const SizedBox(height: 4),
            Expanded(child: _buildList(filtered)),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestion des Soldes de Congé',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_dataMap.length} collaborateurs actifs',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un collaborateur...',
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide(color: AppColors.brand),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : _startReset,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Réinitialiser'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade400),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool mobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Collaborateur',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          if (!mobile) _headerCol('Acquis (j)', flex: 2),
          if (!mobile) _headerCol('Pris (j)', flex: 2),
          _headerCol('Solde restant', flex: 2, highlight: true),
        ],
      ),
    );
  }

  Widget _headerCol(String text, {int flex = 2, bool highlight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: highlight ? AppColors.brand : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildList(List<_LeaveData> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _search.isEmpty ? 'Aucun collaborateur actif' : 'Aucun résultat pour "$_search"',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (_, idx) {
        final d = filtered[idx];
        return _EmployeeRow(
          data: d,
          showAcquisPris: MediaQuery.of(context).size.width >= 700,
          onChanged: (_) => setState(() {}),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Solde = Jours acquis (1,5 j/mois) + Jours extra − Jours pris',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save, size: 18),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Single employee row
// ─────────────────────────────────────────────
class _EmployeeRow extends StatelessWidget {
  final _LeaveData data;
  final bool showAcquisPris;
  final ValueChanged<String> onChanged;

  const _EmployeeRow({
    required this.data,
    required this.showAcquisPris,
    required this.onChanged,
  });

  Color _soldeColor(double v) {
    if (v < 0) return Colors.red;
    if (v < 5) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final e = data.original;
    final solde = data.acquired + data.localExtra - data.localTaken;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: data.modified ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: data.modified ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // ── Nom + poste ──
          Expanded(
            flex: 3,
            child: Row(
              children: [
                SmartAvatar(
                  imageUrl: e.photoUrl.isEmpty ? null : e.photoUrl,
                  fallbackText: e.nom,
                  radius: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        e.poste.isEmpty ? e.departement : e.poste,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Acquis ──
          if (showAcquisPris)
            Expanded(
              flex: 2,
              child: Text(
                data.acquired.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          // ── Pris ──
          if (showAcquisPris)
            Expanded(
              flex: 2,
              child: Text(
                data.localTaken.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: data.localTaken > 0
                      ? Colors.orange.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ),
          // ── Solde (éditable) ──
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: data.ctrl,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _soldeColor(solde),
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                isDense: true,
                suffix: Text('j', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(color: AppColors.brand, width: 1.5),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reset choice dialog
// ─────────────────────────────────────────────
class _ResetChoiceDialog extends StatefulWidget {
  final int employeCount;
  const _ResetChoiceDialog({required this.employeCount});

  @override
  State<_ResetChoiceDialog> createState() => _ResetChoiceDialogState();
}

class _ResetChoiceDialogState extends State<_ResetChoiceDialog> {
  _ResetMode _selected = _ResetMode.takenOnly;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.restore, color: Colors.orange),
          SizedBox(width: 8),
          Text('Réinitialiser les soldes'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez le type de réinitialisation pour ${widget.employeCount} collaborateurs actifs :',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            _ResetTile(
              selected: _selected == _ResetMode.takenOnly,
              title: 'Réinitialiser les jours pris uniquement',
              subtitle:
                  'Remet à 0 les jours consommés.\nConserve les jours extra/reportés.',
              icon: Icons.refresh,
              onTap: () => setState(() => _selected = _ResetMode.takenOnly),
            ),
            const SizedBox(height: 10),
            _ResetTile(
              selected: _selected == _ResetMode.full,
              title: 'Réinitialisation complète',
              subtitle:
                  'Remet à 0 les jours pris ET les jours extra.\nSolde = jours acquis uniquement.',
              icon: Icons.restore_page,
              onTap: () => setState(() => _selected = _ResetMode.full),
              danger: true,
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
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _selected == _ResetMode.full ? Colors.red : AppColors.brand,
            foregroundColor: Colors.white,
          ),
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}

class _ResetTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ResetTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : AppColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey.shade500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: selected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}
