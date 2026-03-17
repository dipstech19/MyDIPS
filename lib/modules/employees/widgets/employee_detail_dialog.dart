import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/locale/app_locale.dart';
import '../../../shared/widgets/smart_avatar.dart';
import '../../pointage/pointage_provider.dart';
import '../models/employe_model.dart';
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
    final maxWidth = MediaQuery.sizeOf(context).width * 0.95;
    final dialogWidth = (640 > maxWidth) ? maxWidth : 640.0;
    if (!isDirecteur) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SmartAvatar(
                    imageUrl: e.photoUrl,
                    fallbackText: e.nom,
                    radius: 32,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                        const SizedBox(height: 4),
                        Text('CIN: ${e.cin}', style: TextStyle(color: Colors.grey[600], fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: e.statut.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(e.statut.icon, color: e.statut.color, size: 14),
                              const SizedBox(width: 6),
                              Text(e.statut.label, style: TextStyle(color: e.statut.color, fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: 560,
        padding: const EdgeInsets.all(28),
        child: DefaultTabController(
          length: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SmartAvatar(
                    imageUrl: e.photoUrl,
                    fallbackText: e.nom,
                    radius: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.nom,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                        Text('${e.poste} - ${e.magasin}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: e.statut.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(e.statut.icon, color: e.statut.color, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(e.statut.label,
                                style: TextStyle(
                                    color: e.statut.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _editEmployee(context),
                    icon: const Icon(Icons.edit, color: Colors.green, size: 22),
                    tooltip: 'Modifier',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () => _downloadPdf(context),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
                    tooltip: 'Télécharger PDF',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                labelColor: const Color(0xFF1565C0),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF1565C0),
                tabs: const [
                  Tab(icon: Icon(Icons.person, size: 18), text: 'Identité'),
                  Tab(icon: Icon(Icons.work, size: 18), text: 'Contrat'),
                  Tab(icon: Icon(Icons.assignment, size: 18), text: 'CNSS'),
                  Tab(icon: Icon(Icons.folder, size: 18), text: 'Documents'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: Column(children: [
                        _card(children: [
                          _row('Nom complet', e.nom),
                          _row('CIN', e.cin),
                          _row('Date de naissance', e.dateNaissance),
                          _row('Adresse', e.adresse),
                        ]),
                        const SizedBox(height: 12),
                        _card(children: [
                          _row('Téléphone', e.telephone),
                          if (e.telephone2.isNotEmpty)
                            _row('Téléphone 2', e.telephone2),
                          _row('Email', e.email),
                        ]),
                      ]),
                    ),
                    SingleChildScrollView(
                      child: Column(children: [
                        _card(children: [
                          _row('Poste', e.poste),
                          _row('Site', e.siteId),
                          _row('Département', e.departement),
                          _row('Chef direct', _getChefNom(e.chefDirectId)),
                          _row('Badge accès', e.badgeActif ? 'Actif' : 'Inactif'),
                          if (e.badgeExpiration.isNotEmpty)
                            _row('Expiration badge', e.badgeExpiration),
                        ]),
                        const SizedBox(height: 12),
                        _card(children: [
                          _row('Type contrat', e.typeContrat),
                          _row('Date début', e.dateDebut),
                          if (e.finContrat.isNotEmpty)
                            _row('Fin contrat', e.finContrat),
                          _row('Salaire base', '${e.salaireBase.toInt()} DH'),
                        ]),
                        const SizedBox(height: 12),
                        _PresenceLeaveCard(employe: e, isDirecteur: true),
                      ]),
                    ),
                    SingleChildScrollView(
                      child: _card(children: [
                        _row('Numéro CNSS', e.cnss),
                        _row('Date inscription', e.dateCnss),
                      ]),
                    ),
                    DocumentsTab(employe: e),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(
          width: 130,
          child: Text(label,
              style:
              TextStyle(color: Colors.grey[600], fontSize: 13))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
  
  void _downloadPdf(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Génération du PDF en cours...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      await PdfService.shareEmployeePdf(
        employe,
        chefNom: _getChefNom(employe.chefDirectId),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du PDF: $e'),
          backgroundColor: Colors.red,
        ),
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

/// بطاقة عرض أيام الحضور، المستحق، المستخدم، والمتاحة.
class _PresenceLeaveCard extends StatefulWidget {
  final Employe employe;
  final bool isDirecteur;

  const _PresenceLeaveCard({required this.employe, required this.isDirecteur});

  @override
  State<_PresenceLeaveCard> createState() => _PresenceLeaveCardState();
}

class _PresenceLeaveCardState extends State<_PresenceLeaveCard> {
  final _deductDaysController = TextEditingController();

  @override
  void dispose() {
    _deductDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employe = widget.employe;
    final isDirecteur = widget.isDirecteur;
    final start = parseDateDebut(employe.dateDebut);
    final leaveAcquired = leaveDaysAcquired(employe.dateDebut);
    final hasStart = start != null && !start.isAfter(DateTime.now());

    return Consumer<CongesProvider>(
      builder: (context, conges, _) {
        final taken = conges.getCachedDaysTaken(employe.id);
        if (taken == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            conges.loadDaysTaken(employe.id);
          });
          return _cardShell(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, 'employee_presence_leave_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                const SizedBox(height: 12),
                const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              ],
            ),
          );
        }
        final available = (leaveAcquired - taken).clamp(0.0, double.infinity);

        return _cardShell(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, 'employee_presence_leave_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              const SizedBox(height: 10),
              _row(
                context,
                tr(context, 'employee_leave_initial'),
                Text(
                  hasStart ? _formatLeave(leaveAcquired) : '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              _row(
                context,
                tr(context, 'employee_leave_days_taken'),
                Text(
                  _formatLeave(taken),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              _row(
                context,
                tr(context, 'employee_leave_days_available'),
                Text(
                  hasStart ? _formatLeave(available) : '—',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ),
              if (isDirecteur && hasStart) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(tr(context, 'employee_leave_deduct'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 6),
                Row(
                  children: [
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
                      onPressed: () async {
                        final text = _deductDaysController.text.trim();
                        final days = double.tryParse(text.replaceFirst(',', '.'));
                        if (days == null || days <= 0) return;
                        await conges.addDaysTaken(employe.id, days);
                        _deductDaysController.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${tr(context, 'employee_leave_days_taken')}: +${_formatLeave(days)}'), behavior: SnackBarBehavior.fixed),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: Text(tr(context, 'employee_leave_deduct_btn')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cardShell(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _row(BuildContext context, String label, Widget value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 180, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            Expanded(child: value),
          ],
        ),
      );

  String _formatLeave(double days) {
    if (days == days.roundToDouble()) return '${days.toInt()}';
    return days.toStringAsFixed(1).replaceAll('.', ',');
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
          return SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[600]),
          );
        }
        if (snap.hasError) return Text('—', style: TextStyle(fontSize: 13, color: Colors.red[700]));
        return Text('${snap.data ?? 0}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500));
      },
    );
  }
}