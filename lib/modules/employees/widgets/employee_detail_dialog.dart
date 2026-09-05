import 'package:flutter/material.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/app_locale.dart';
import '../../../shared/widgets/smart_avatar.dart';
import '../../pointage/pointage_provider.dart';
import '../models/employe_model.dart';
import '../../magasin/magasin_provider.dart';
import '../services/pdf_service.dart';
import '../employees_provider.dart';
import '../conges_provider.dart';
import '../utils/leave_days_utils.dart';
import 'documents_tab.dart';
import 'employee_edit_dialog.dart';

class EmployeeDetailDialog extends StatelessWidget {
  final Employe employe;
  final List<Employe> allEmployes;
  final bool isDirecteur;

  const EmployeeDetailDialog({
    super.key,
    required this.employe,
    required this.allEmployes,
    this.isDirecteur = true,
  });

  String _getChefNom(String chefId) {
    if (chefId.isEmpty) return '—';
    final chef = allEmployes.where((e) => e.id == chefId).toList();
    return chef.isNotEmpty ? chef.first.nom : '—';
  }

  @override
  Widget build(BuildContext context) {
    final e = employe;
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;
    final mobile = sw < 600;
    final magasin = context.watch<MagasinProvider>();
    final nomKey = e.nom.trim().toLowerCase();
    // Strictement les sorties du site du collaborateur.
    final equipementsSortis = magasin.loading
        ? <Mouvement>[]
        : magasin.sorties
            .where((m) =>
                (m.preneurNom ?? '').trim().toLowerCase() == nomKey &&
                m.siteId == e.siteId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    final dialogWidth = (sw * (mobile ? 0.97 : 0.9)).clamp(0.0, 640.0);
    final dialogMaxHeight = sh * (mobile ? 0.92 : 0.88);
    final hPad = mobile ? 16.0 : 28.0;

    // ── Vue simplifiée (non-directeur) ──────────────────────────────────────
    if (!isDirecteur) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(hPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileHeader(
                e: e,
                mobile: mobile,
                showActions: false,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    // ── Vue directeur (avec onglets) ─────────────────────────────────────────
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 6 : 40, vertical: mobile ? 16 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogMaxHeight),
        child: Padding(
          padding: EdgeInsets.all(hPad),
          child: DefaultTabController(
            length: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────────
                _MobileHeader(
                  e: e,
                  mobile: mobile,
                  showActions: true,
                  onClose: () => Navigator.pop(context),
                  onEdit: () => _editEmployee(context),
                  onPdf: () => _downloadPdf(context),
                ),
                const SizedBox(height: 14),
                // ── Tab bar ─────────────────────────────────────────────────
                TabBar(
                  labelColor: const Color(0xFF000966),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF000966),
                  isScrollable: mobile,
                  tabAlignment: mobile ? TabAlignment.start : TabAlignment.fill,
                  tabs: mobile
                      ? const [
                          Tab(icon: Icon(Icons.person, size: 18)),
                          Tab(icon: Icon(Icons.work, size: 18)),
                          Tab(icon: Icon(Icons.assignment, size: 18)),
                          Tab(icon: Icon(Icons.folder, size: 18)),
                        ]
                      : const [
                          Tab(icon: Icon(Icons.person, size: 18), text: 'Identité'),
                          Tab(icon: Icon(Icons.work, size: 18), text: 'Contrat'),
                          Tab(icon: Icon(Icons.assignment, size: 18), text: 'CNSS'),
                          Tab(icon: Icon(Icons.folder, size: 18), text: 'Documents'),
                        ],
                ),
                const SizedBox(height: 12),
                // ── Tab content ─────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    children: [
                      // Onglet Identité
                      SingleChildScrollView(
                        child: Column(children: [
                          _infoCard(children: [
                            _infoRow('Nom complet', e.nom, mobile),
                            _infoRow('CIN', e.cin, mobile),
                            _infoRow('Date de naissance', e.dateNaissance, mobile),
                            _infoRow('Adresse', e.adresse, mobile),
                          ]),
                          const SizedBox(height: 12),
                          _infoCard(children: [
                            _infoRow('Téléphone', e.telephone, mobile),
                            if (e.telephone2.isNotEmpty)
                              _infoRow('Téléphone 2', e.telephone2, mobile),
                            _infoRow('Email', e.email, mobile),
                          ]),
                          const SizedBox(height: 12),
                          _infoCard(children: [
                            Text(
                              'Équipements / Matériel sortis',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 10),
                            if (!magasin.firebaseAvailable)
                              Text('Magasin non disponible', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600))
                            else if (magasin.loading)
                              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator(strokeWidth: 2)))
                            else if (equipementsSortis.isEmpty)
                              Text('Aucune sortie enregistrée pour ce collaborateur.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600))
                            else
                              ...equipementsSortis.take(15).map((m) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(fmtDate(m.date), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                                  const SizedBox(height: 4),
                                  Text('${m.nomProduit} · ${m.categorie}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  const SizedBox(height: 3),
                                  Text('Réf: ${m.reference.isNotEmpty ? m.reference : "—"}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  const SizedBox(height: 3),
                                  Text('Qté: ${m.totalQte}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
                                ]),
                              )),
                          ]),
                        ]),
                      ),
                      // Onglet Contrat
                      SingleChildScrollView(
                        child: Column(children: [
                          _infoCard(children: [
                            _infoRow('Poste', e.poste, mobile),
                            _infoRow('Site', e.siteId, mobile),
                            _infoRow('Département', e.departement, mobile),
                            _infoRow('Chef direct', _getChefNom(e.chefDirectId), mobile),
                            _infoRow('Badge accès', e.badgeActif ? 'Actif' : 'Inactif', mobile),
                            if (e.badgeExpiration.isNotEmpty)
                              _infoRow('Expiration badge', e.badgeExpiration, mobile),
                          ]),
                          const SizedBox(height: 12),
                          _infoCard(children: [
                            _infoRow('Type contrat', e.typeContrat, mobile),
                            _infoRow('Date début', e.dateDebut, mobile),
                            if (e.finContrat.isNotEmpty)
                              _infoRow('Fin contrat', e.finContrat, mobile),
                            _infoRow('Salaire base', '${e.salaireBase.toInt()} DH', mobile),
                          ]),
                          const SizedBox(height: 12),
                          _PresenceLeaveCard(employe: e, isDirecteur: true, mobile: mobile),
                        ]),
                      ),
                      // Onglet CNSS
                      SingleChildScrollView(
                        child: _infoCard(children: [
                          _infoRow('Numéro CNSS', e.cnss, mobile),
                          _infoRow('Date inscription', e.dateCnss, mobile),
                        ]),
                      ),
                      // Onglet Documents
                      DocumentsTab(employe: e),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _infoCard({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  static Widget _infoRow(String label, String value, bool mobile) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ])
        : Row(children: [
            SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ]),
  );

  void _downloadPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Génération du PDF en cours...'), duration: Duration(seconds: 1)),
    );
    try {
      await PdfService.shareEmployeePdf(employe, chefNom: _getChefNom(employe.chefDirectId));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur lors de la génération du PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _editEmployee(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => EmployeeEditDialog(
        employe: employe,
        allEmployes: allEmployes,
        onSave: (updated) async {
          await context.read<EmployeesProvider>().updateEmploye(updated);
        },
      ),
    );
  }
}

// ── Header responsive ────────────────────────────────────────────────────────
class _MobileHeader extends StatelessWidget {
  final Employe e;
  final bool mobile;
  final bool showActions;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onPdf;

  const _MobileHeader({
    required this.e,
    required this.mobile,
    required this.showActions,
    required this.onClose,
    this.onEdit,
    this.onPdf,
  });

  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: e.statut.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: e.statut.color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(e.statut.icon, color: e.statut.color, size: 13),
      const SizedBox(width: 5),
      Text(e.statut.label, style: TextStyle(color: e.statut.color, fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final closeBtn = IconButton(
      onPressed: onClose,
      icon: const Icon(Icons.close, size: 20),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );

    if (mobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ligne 1 : avatar + nom/poste + fermer
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
              if (showActions)
                Text('${e.poste} · ${e.magasin}', style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 1)
              else
                Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ]),
          ),
          closeBtn,
        ]),
        const SizedBox(height: 10),
        // Ligne 2 : statut + boutons d'action
        Row(children: [
          _statusBadge(),
          const Spacer(),
          if (showActions && onEdit != null) ...[
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, color: Colors.green, size: 20),
              tooltip: 'Modifier',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
          if (showActions && onPdf != null)
            IconButton(
              onPressed: onPdf,
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
              tooltip: 'Télécharger PDF',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
        ]),
      ]);
    }

    // Desktop : tout en une ligne
    return Row(children: [
      SmartAvatar(imageUrl: e.photoUrl, fallbackText: e.nom, radius: 28),
      const SizedBox(width: 16),
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
          if (showActions)
            Text('${e.poste} - ${e.magasin}', style: TextStyle(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1)
          else
            Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ]),
      ),
      const SizedBox(width: 8),
      _statusBadge(),
      if (showActions && onEdit != null) ...[
        const SizedBox(width: 4),
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit, color: Colors.green, size: 22), tooltip: 'Modifier', padding: const EdgeInsets.all(6), constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
      ],
      if (showActions && onPdf != null) ...[
        IconButton(onPressed: onPdf, icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22), tooltip: 'Télécharger PDF', padding: const EdgeInsets.all(6), constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
      ],
      IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 22), padding: const EdgeInsets.all(6), constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
    ]);
  }
}

// ── Carte Présence / Congés ──────────────────────────────────────────────────
class _PresenceLeaveCard extends StatefulWidget {
  final Employe employe;
  final bool isDirecteur;
  final bool mobile;

  const _PresenceLeaveCard({required this.employe, required this.isDirecteur, this.mobile = false});

  @override
  State<_PresenceLeaveCard> createState() => _PresenceLeaveCardState();
}

class _PresenceLeaveCardState extends State<_PresenceLeaveCard> {
  final _deductDaysController = TextEditingController();
  double? _leaveExtraOverride;

  @override
  void dispose() {
    _deductDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employe = widget.employe;
    final isDirecteur = widget.isDirecteur;
    final mobile = widget.mobile;
    final start = parseDateDebut(employe.dateDebut);
    final leaveAcquired = leaveDaysAcquired(employe.dateDebut);
    final leaveExtra = _leaveExtraOverride ?? employe.leaveDaysExtra;
    final hasStart = start != null && !start.isAfter(DateTime.now());

    return Consumer<CongesProvider>(
      builder: (context, conges, _) {
        final taken = conges.getCachedDaysTaken(employe.id);
        if (taken == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            conges.loadDaysTaken(employe.id);
          });
          return _cardShell(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'employee_presence_leave_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const SizedBox(height: 12),
              const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            ]),
          );
        }
        final available = (leaveAcquired + leaveExtra - taken).clamp(0.0, double.infinity);

        return _cardShell(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'employee_presence_leave_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const SizedBox(height: 10),
            _leaveRow(context, tr(context, 'employee_days_present'), mobile,
                hasStart
                    ? _PresentDaysFuture(employeId: employe.id, start: start)
                    : const Text('—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _leaveRow(context, tr(context, 'employee_leave_days_acquired'), mobile,
                Text(hasStart ? _formatLeave(leaveAcquired) : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _leaveRow(context, 'Congé additionnel/reporté', mobile,
                Text(_formatLeave(leaveExtra), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _leaveRow(context, tr(context, 'employee_leave_days_taken'), mobile,
                Text(_formatLeave(taken), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            _leaveRow(context, tr(context, 'employee_leave_days_available'), mobile,
                Text(hasStart ? _formatLeave(available) : '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700))),
            if (isDirecteur) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showAddReportedLeaveDialog(context, employe, leaveExtra),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Ajouter solde reporté'),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(tr(context, 'employee_leave_rule'), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (isDirecteur && hasStart) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(tr(context, 'employee_leave_deduct'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 6),
              // Sur mobile : champ + bouton en colonne
              if (mobile)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _deductDaysController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: tr(context, 'employee_leave_days_hint'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _deduct(context, conges, employe),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(tr(context, 'employee_leave_deduct_btn')),
                  ),
                ])
              else
                Row(children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _deductDaysController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: tr(context, 'employee_leave_days_hint'),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deduct(context, conges, employe),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: Text(tr(context, 'employee_leave_deduct_btn')),
                  ),
                ]),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _deduct(BuildContext context, CongesProvider conges, Employe employe) async {
    final text = _deductDaysController.text.trim();
    final days = double.tryParse(text.replaceFirst(',', '.'));
    if (days == null || days <= 0) return;
    final label = tr(context, 'employee_leave_days_taken');
    final messenger = ScaffoldMessenger.of(context);
    await conges.addDaysTaken(employe.id, days);
    _deductDaysController.clear();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('$label: +${_formatLeave(days)}'), behavior: SnackBarBehavior.fixed),
    );
  }

  Widget _cardShell({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );

  Widget _leaveRow(BuildContext context, String label, bool mobile, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            value,
          ])
        : Row(children: [
            SizedBox(width: 180, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            Expanded(child: value),
          ]),
  );

  String _formatLeave(double days) {
    if (days == days.roundToDouble()) return '${days.toInt()}';
    return days.toStringAsFixed(1).replaceAll('.', ',');
  }

  Future<void> _showAddReportedLeaveDialog(BuildContext context, Employe employe, double currentExtra) async {
    final messenger = ScaffoldMessenger.of(context);
    final prov = context.read<EmployeesProvider>();
    final ctrl = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Ajouter solde reporté'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Jours à ajouter',
            hintText: 'Ex: 12',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim().replaceFirst(',', '.'));
              if (parsed == null || parsed <= 0) return;
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (value == null || value <= 0) return;
    final next = (currentExtra + value).clamp(0.0, double.infinity).toDouble();
    if (!context.mounted) return;
    if (!await confirmUpdate(context,
        message:
            "Ajouter ${_formatLeave(value)} jour(s) au solde reporté de « ${employe.nom} » ?")) {
      return;
    }
    await prov.updateEmploye(employe.copyWith(leaveDaysExtra: next));
    if (!mounted) return;
    setState(() => _leaveExtraOverride = next);
    messenger.showSnackBar(
      SnackBar(content: Text('Solde reporté mis à jour: ${_formatLeave(next)} jour(s).')),
    );
  }
}

class _PresentDaysFuture extends StatelessWidget {
  final String employeId;
  final DateTime start;

  const _PresentDaysFuture({required this.employeId, required this.start});

  @override
  Widget build(BuildContext context) {
    final end = DateTime.now();
    final pointage = context.read<PointageProvider>();
    return FutureBuilder<int>(
      future: pointage.getPresentDaysCountForEmployee(employeId, start, end),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[600]));
        }
        if (snap.hasError) return Text('—', style: TextStyle(fontSize: 13, color: Colors.red[700]));
        return Text('${snap.data ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500));
      },
    );
  }
}
