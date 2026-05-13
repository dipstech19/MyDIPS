// ─────────────────────────────────────────────────────────────────────────────
//  logistique_page.dart  (version Firebase)
//  Connecté à Firestore via LogistiqueService
//  Tous les modèles sont importés depuis vehicule_model.dart
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import 'vehicule_model.dart';
import 'logistique_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _cBlue       = Color(0xFF1565C0);
const _cBlueDark   = Color(0xFF0D47A1);
const _cBlueMid    = Color(0xFF1976D2);
const _cBlueSoft   = Color(0xFF42A5F5);
const _cBlueFaint  = Color(0xFFE3F2FD);
const _cBlueBorder = Color(0xFFBBDEFB);
const _cSurface    = Color(0xFFFFFFFF);
const _cBg         = Color(0xFFF0F4FA);
const _cCard       = Color(0xFFFFFFFF);
const _cText       = Color(0xFF0D1B2A);
const _cSub        = Color(0xFF607B96);
const _cBorder     = Color(0xFFE2EAF4);
const _cSuccess    = Color(0xFF16A34A);
const _cSuccessBg  = Color(0xFFDCFCE7);
const _cWarning    = Color(0xFFD97706);
const _cWarningBg  = Color(0xFFFEF3C7);
const _cDanger     = Color(0xFFDC2626);
const _cDangerBg   = Color(0xFFFEE2E2);
const _cOrange     = Color(0xFFEA580C);
const _cOrangeBg   = Color(0xFFFFEDD5);

// ─── Raccourci service ────────────────────────────────────────────────────────
final _svc = LogistiqueService.instance;

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE PRINCIPALE
// ═════════════════════════════════════════════════════════════════════════════
class LogistiquePage extends StatefulWidget {
  const LogistiquePage({super.key});
  @override State<LogistiquePage> createState() => _LogistiquePageState();
}

class _LogistiquePageState extends State<LogistiquePage> {
  bool _showForm = false;
  bool _showAlertes = false;

  void _openDetail(Vehicule v) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DetailPage(vehicule: v),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    final mobile = isMobile(context);
    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();

    return Scaffold(
      backgroundColor: _cBg,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_cBlueDark, _cBlueMid],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(p, MediaQuery.of(context).padding.top + 16, p, 20),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Logistique', style: TextStyle(
                    color: Colors.white, fontSize: mobile ? 18 : 22,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const Text('Gestion du parc véhicules',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )),
            // Bouton alertes
            StreamBuilder<List<AlerteDocument>>(
              stream: _svc.streamAlertes(),
              builder: (_, snap) {
                final count = snap.data?.length ?? 0;
                return GestureDetector(
                  onTap: () => setState(() => _showAlertes = !_showAlertes),
                  child: Stack(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
                    ),
                    if (count > 0)
                      Positioned(top: 0, right: 0,
                        child: Container(
                          width: 16, height: 16,
                          decoration: const BoxDecoration(color: _cDanger, shape: BoxShape.circle),
                          child: Center(child: Text('$count',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                        ),
                      ),
                  ]),
                );
              },
            ),
            const SizedBox(width: 8),
            // Compteur véhicules
            StreamBuilder<List<Vehicule>>(
              stream: _svc.streamVehicules(),
              builder: (_, snap) {
                final count = snap.data?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.directions_car_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text('$count véh.',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                );
              },
            ),
          ]),
        ),

        // ── Corps ────────────────────────────────────────────────────────────
        Expanded(child: StreamBuilder<List<Vehicule>>(
          stream: _svc.streamVehicules(),
          builder: (context, snapshot) {
            // ── États de chargement ──────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _cBlue));
            }
            if (snapshot.hasError) {
              return Center(child: _ErrorState(message: snapshot.error.toString()));
            }

            final vehicules = SiteId.filterBySite(
              snapshot.data ?? [],
              auth.currentUser?.allowedSiteIds,
              auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
              (v) => v.siteId,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.all(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Bandeau alertes ────────────────────────────────────────
                  if (_showAlertes)
                    _AlertesBandeau(
                      onClose: () => setState(() => _showAlertes = false),
                    ),

                  if (!_showForm) ...[
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _PrimaryBtn(
                        icon: Icons.add_rounded,
                        label: mobile ? 'Ajouter' : 'Ajouter un véhicule',
                        onTap: () => setState(() => _showForm = true),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  if (_showForm) ...[
                    _VehiculeForm(
                      onSaved: (v) async {
                        try {
                          await _svc.addVehicule(v);
                          setState(() => _showForm = false);
                          _toast('✓  Véhicule ajouté');
                        } catch (e) {
                          _toast('⚠  Erreur : $e');
                        }
                      },
                      onCancel: () => setState(() => _showForm = false),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (vehicules.isEmpty)
                    _EmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'Aucun véhicule',
                      sub: 'Commencez par ajouter un véhicule',
                    )
                  else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: vehicules.map((v) => _VehiculeCard(
                        vehicule: v,
                        onTap: () => _openDetail(v),
                        onEdit: () => _openDetail(v),
                        onDelete: () async {
                          final ok = await _confirmDlg(context,
                              title: 'Supprimer le véhicule',
                              msg: 'Cette action est irréversible.', danger: true);
                          if (ok == true && v.id != null) {
                            try {
                              await _svc.deleteVehicule(v.id!);
                              _toast('✓  Véhicule supprimé');
                            } catch (e) {
                              _toast('⚠  Erreur : $e');
                            }
                          }
                        },
                      )).toList(),
                    ),
                ],
              ),
            );
          },
        )),
      ]),
    );
  }

  void _toast(String m) => _showToast(context, m);
}

// ═════════════════════════════════════════════════════════════════════════════
//  BANDEAU ALERTES
// ═════════════════════════════════════════════════════════════════════════════
class _AlertesBandeau extends StatelessWidget {
  final VoidCallback onClose;
  const _AlertesBandeau({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlerteDocument>>(
      stream: _svc.streamAlertes(),
      builder: (_, snap) {
        final alertes = snap.data ?? [];
        if (alertes.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cSuccessBg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cSuccess.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: _cSuccess, size: 18),
              const SizedBox(width: 10),
              const Expanded(child: Text('Tous les documents sont à jour',
                  style: TextStyle(fontSize: 13, color: _cSuccess, fontWeight: FontWeight.w600))),
              GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: _cSuccess, size: 16)),
            ]),
          );
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _cCard, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cDangerBg),
            boxShadow: [BoxShadow(color: _cDanger.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                color: _cDangerBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: _cDanger, size: 17),
                const SizedBox(width: 8),
                Expanded(child: Text('${alertes.length} alerte${alertes.length > 1 ? 's' : ''} en attente',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _cDanger))),
                GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: _cDanger, size: 16)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min,
                children: alertes.take(5).map((a) => _AlerteRow(alerte: a)).toList()),
            ),
          ]),
        );
      },
    );
  }
}

class _AlerteRow extends StatelessWidget {
  final AlerteDocument alerte;
  const _AlerteRow({required this.alerte});

  @override
  Widget build(BuildContext context) {
    final color = alerte.estExpire ? _cDanger : alerte.estUrgent ? _cOrange : _cWarning;
    final bg = alerte.estExpire ? _cDangerBg : alerte.estUrgent ? _cOrangeBg : _cWarningBg;
    final label = alerte.kmRestants != null
        ? '${alerte.kmRestants!.toStringAsFixed(0)} km restants'
        : alerte.estExpire
            ? 'Expiré'
            : '${alerte.joursRestants} j restants';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(alerte.vehiculeMatricule,
              style: const TextStyle(fontSize: 11, color: _cSub, fontWeight: FontWeight.w600)),
          Text(alerte.label, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  CARTE VÉHICULE
// ═════════════════════════════════════════════════════════════════════════════
class _VehiculeCard extends StatelessWidget {
  final Vehicule vehicule;
  final VoidCallback onTap, onEdit, onDelete;
  const _VehiculeCard({required this.vehicule, required this.onTap,
    required this.onEdit, required this.onDelete});

  Color _statusColor(Vehicule v) {
    final dates = [v.expirationAssurance, v.expirationVisite,
      v.expirationCarteGrise, v.expirationAutorisationTransport, v.expirationBadge];
    int minDays = 999;
    for (final d in dates) {
      if (d != null) {
        final diff = d.difference(DateTime.now()).inDays;
        if (diff < minDays) minDays = diff;
      }
    }
    if (minDays < 0)  return _cDanger;
    if (minDays < 30) return _cWarning;
    return _cSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final v = vehicule;
    final mobile = isMobile(context);
    final statusColor = _statusColor(v);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(mobile ? 12 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stack(children: [
                    Container(
                      width: mobile ? 46 : 54, height: mobile ? 46 : 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_cBlue, _cBlueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: mobile ? 22 : 26),
                    ),
                    Positioned(right: 0, top: 0,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Flexible(child: Text(v.matricule,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: mobile ? 13.5 : 15, color: _cText),
                          overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      _Tag(label: v.marque, color: _cBlueFaint, textColor: _cBlue),
                    ]),
                    const SizedBox(height: 3),
                    Text(v.modele, style: TextStyle(fontSize: mobile ? 12 : 13, color: _cSub, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.speed_rounded, size: 12, color: _cSub),
                        const SizedBox(width: 3),
                        Text('${_fmtKm(v.kilometrage)} km', style: const TextStyle(fontSize: 11, color: _cSub)),
                      ]),
                    ]),
                  ])),
                ]),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue, tooltip: 'Détails', onTap: onTap),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.edit_outlined, color: _cOrange, tooltip: 'Modifier', onTap: onEdit),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger, tooltip: 'Supprimer', onTap: onDelete),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE VÉHICULE
// ═════════════════════════════════════════════════════════════════════════════
class _VehiculeForm extends StatefulWidget {
  final Vehicule? editing;
  final void Function(Vehicule) onSaved;
  final VoidCallback onCancel;
  const _VehiculeForm({this.editing, required this.onSaved, required this.onCancel});
  @override State<_VehiculeForm> createState() => _VehiculeFormState();
}

class _VehiculeFormState extends State<_VehiculeForm> {
  final _fk = GlobalKey<FormState>();
  late final TextEditingController _matricule, _marque, _modele, _km;
  DateTime? _exCG, _exAss, _exVis, _exAT, _dateTaxe, _exBadge;
  bool _loading = false;
  late String _siteId;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _matricule = TextEditingController(text: e?.matricule ?? '');
    _marque    = TextEditingController(text: e?.marque ?? '');
    _modele    = TextEditingController(text: e?.modele ?? '');
    _km        = TextEditingController(text: e != null ? e.kilometrage.toStringAsFixed(0) : '');
    _exCG = e?.expirationCarteGrise; _exAss = e?.expirationAssurance;
    _exVis = e?.expirationVisite;    _exAT  = e?.expirationAutorisationTransport;
    _dateTaxe = e?.dateTaxe;         _exBadge = e?.expirationBadge;
    _siteId = e?.siteId ?? SiteId.jadida;
  }

  @override
  void dispose() {
    _matricule.dispose(); _marque.dispose(); _modele.dispose(); _km.dispose();
    super.dispose();
  }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    final e = widget.editing;
    widget.onSaved(Vehicule(
      id: e?.id,
      matricule: _matricule.text.trim(), marque: _marque.text.trim(),
      modele: _modele.text.trim(),
      kilometrage: double.tryParse(_km.text.replaceAll(' ', '')) ?? 0,
      siteId: _siteId,
      expirationCarteGrise: _exCG, expirationAssurance: _exAss,
      expirationVisite: _exVis, expirationAutorisationTransport: _exAT,
      dateTaxe: _dateTaxe, expirationBadge: _exBadge,
      vidanges: e?.vidanges ?? [], pleins: e?.pleins ?? [], reparations: e?.reparations ?? [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _GlassCard(
      header: _FormHeader(
        icon: Icons.local_shipping_rounded,
        title: widget.editing != null ? 'Modifier le véhicule' : 'Nouveau véhicule',
        onClose: widget.onCancel,
      ),
      child: Form(key: _fk, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const _SecLabel(label: 'IDENTIFICATION'),
        const SizedBox(height: 12),
        if (mobile) ...[
          _Field(ctrl: _matricule, label: 'Matricule', icon: Icons.pin_outlined, req: true),
          const SizedBox(height: 10),
          _Field(ctrl: _marque, label: 'Marque', icon: Icons.branding_watermark_outlined, req: true),
          const SizedBox(height: 10),
          _Field(ctrl: _modele, label: 'Modèle', icon: Icons.directions_car_outlined, req: true),
        ] else
          _Row3(
            _Field(ctrl: _matricule, label: 'Matricule', icon: Icons.pin_outlined, req: true),
            _Field(ctrl: _marque,    label: 'Marque',    icon: Icons.branding_watermark_outlined, req: true),
            _Field(ctrl: _modele,    label: 'Modèle',    icon: Icons.directions_car_outlined, req: true),
          ),
        const SizedBox(height: 10),
        _Field(ctrl: _km, label: 'Kilométrage actuel (km)',
            icon: Icons.speed_outlined, type: TextInputType.number, req: true),
        const SizedBox(height: 10),
        // ── Site (compact, aligné à gauche) ─────────────────────────────────
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: mobile ? double.infinity : 200,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Site',
                labelStyle: const TextStyle(fontSize: 12.5, color: _cSub),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: _cBlue),
                filled: true,
                fillColor: _cBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _cBorder, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _cBlue, width: 1.8),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _siteId,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: _cText),
                  items: [
                    DropdownMenuItem(value: SiteId.jadida, child: Text(SiteId.labelFr(SiteId.jadida))),
                    DropdownMenuItem(value: SiteId.safi,   child: Text(SiteId.labelFr(SiteId.safi))),
                  ],
                  onChanged: (v) => setState(() => _siteId = v ?? SiteId.jadida),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SecLabel(label: 'DOCUMENTS & EXPIRATIONS'),
        const SizedBox(height: 12),
        if (mobile) ...[
          _LDateField(label: 'Carte grise (exp.)',              value: _exCG,      onPicked: (d) => setState(() => _exCG = d)),
          const SizedBox(height: 10),
          _LDateField(label: 'Assurance (exp.)',                value: _exAss,     onPicked: (d) => setState(() => _exAss = d)),
          const SizedBox(height: 10),
          _LDateField(label: 'Visite technique (exp.)',         value: _exVis,     onPicked: (d) => setState(() => _exVis = d)),
          const SizedBox(height: 10),
          _LDateField(label: 'Autorisation transport (exp.)',   value: _exAT,      onPicked: (d) => setState(() => _exAT = d)),
          const SizedBox(height: 10),
          _LDateField(label: 'Date taxe',                       value: _dateTaxe,  onPicked: (d) => setState(() => _dateTaxe = d)),
          const SizedBox(height: 10),
          _LDateField(label: 'Badge (exp.)',                    value: _exBadge,   onPicked: (d) => setState(() => _exBadge = d)),
        ] else ...[
          _Row3(
            _LDateField(label: 'Carte grise (exp.)',       value: _exCG,      onPicked: (d) => setState(() => _exCG = d)),
            _LDateField(label: 'Assurance (exp.)',         value: _exAss,     onPicked: (d) => setState(() => _exAss = d)),
            _LDateField(label: 'Visite technique (exp.)',  value: _exVis,     onPicked: (d) => setState(() => _exVis = d)),
          ),
          const SizedBox(height: 10),
          _Row3(
            _LDateField(label: 'Autorisation transport (exp.)', value: _exAT,      onPicked: (d) => setState(() => _exAT = d)),
            _LDateField(label: 'Date taxe',                     value: _dateTaxe,  onPicked: (d) => setState(() => _dateTaxe = d)),
            _LDateField(label: 'Badge (exp.)',                   value: _exBadge,   onPicked: (d) => setState(() => _exBadge = d)),
          ),
        ],
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _LGhostBtn(label: 'Annuler', onTap: widget.onCancel),
          const SizedBox(width: 10),
          _loading
              ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(color: _cBlue, strokeWidth: 2)))
              : _PrimaryBtn(
                  label: widget.editing != null ? 'Modifier' : 'Enregistrer',
                  icon: widget.editing != null ? Icons.check_rounded : Icons.save_rounded,
                  onTap: _save,
                ),
        ]),
      ])),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE DÉTAILS — connectée Firebase
// ═════════════════════════════════════════════════════════════════════════════
class _DetailPage extends StatefulWidget {
  final Vehicule vehicule;
  const _DetailPage({required this.vehicule});
  @override State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> with TickerProviderStateMixin {
  late final TabController _tc;
  final _tabLabels = ["Fiche", "Vidanges", "Gasoil", "Réparations"];
  final _tabIcons  = [Icons.info_outline_rounded, Icons.oil_barrel_outlined,
    Icons.local_gas_station_outlined, Icons.build_outlined];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final topPad = MediaQuery.of(context).padding.top;
    final vehiculeId = widget.vehicule.id!;

    return Scaffold(
      backgroundColor: _cBg,
      body: StreamBuilder<Vehicule>(
        stream: _svc.streamVehiculeComplet(vehiculeId),
        builder: (context, snap) {
          // Utilise les données Firebase si disponibles, sinon les données initiales
          final v = snap.data ?? widget.vehicule;

          return Column(children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_cBlueDark, _cBlueMid],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(v.matricule, style: TextStyle(color: Colors.white,
                            fontSize: mobile ? 17 : 20, fontWeight: FontWeight.w800)),
                        Text('${v.marque} · ${v.modele}  ·  ${_fmtKm(v.kilometrage)} km',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                      ],
                    )),
                    if (snap.connectionState == ConnectionState.waiting)
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ]),
                  const SizedBox(height: 14),
                  TabBar(
                    controller: _tc,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                    dividerColor: Colors.transparent,
                    labelColor: _cBlue,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
                    tabs: List.generate(4, (i) => Tab(
                      height: 36,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_tabIcons[i], size: 13),
                        const SizedBox(width: 5),
                        Text(_tabLabels[i]),
                      ]),
                    )),
                  ),
                ],
              ),
            ),

            Expanded(child: TabBarView(
              controller: _tc,
              children: [
                _FicheTab(vehicule: v),
                _VidangeTab(vehiculeId: vehiculeId, vidanges: v.vidanges),
                _GasoilTab(vehiculeId: vehiculeId, pleins: v.pleins),
                _AutresTab(vehiculeId: vehiculeId, reparations: v.reparations),
              ],
            )),
          ]);
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 1 — FICHE
// ═════════════════════════════════════════════════════════════════════════════
class _FicheTab extends StatefulWidget {
  final Vehicule vehicule;
  const _FicheTab({required this.vehicule});
  @override State<_FicheTab> createState() => _FicheTabState();
}

class _FicheTabState extends State<_FicheTab> {
  bool _editing = false;

  Future<void> _exportExcel(BuildContext ctx, Vehicule v) async {
    try {
      final book = xl.Excel.createExcel();

      // ── Styles ──────────────────────────────────────────────────────────────
      xl.CellStyle headerStyle() => xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
            backgroundColorHex: xl.ExcelColor.fromHexString('#1565C0'),
            horizontalAlign: xl.HorizontalAlign.Center,
            verticalAlign: xl.VerticalAlign.Center,
          );

      xl.CellStyle titleStyle() => xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#0D47A1'),
          );

      xl.CellStyle totalStyle(String hex) => xl.CellStyle(
            bold: true,
            backgroundColorHex: xl.ExcelColor.fromHexString(hex),
          );

      xl.CellStyle dataStyle(bool alt) => xl.CellStyle(
            backgroundColorHex:
                xl.ExcelColor.fromHexString(alt ? '#F0F4FA' : '#FFFFFF'),
          );

      void cell(xl.Sheet s, int row, int col, dynamic value,
          {xl.CellStyle? style}) {
        xl.CellValue cv;
        if (value is double) {
          cv = xl.DoubleCellValue(value);
        } else if (value is int) {
          cv = xl.IntCellValue(value);
        } else {
          cv = xl.TextCellValue(value.toString());
        }
        s.updateCell(
          xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
          cv,
          cellStyle: style,
        );
      }

      // ── Feuille 1 : Vidanges ─────────────────────────────────────────────
      final sv = book['Vidanges'];
      final defaultSheet = book.getDefaultSheet();
      if (defaultSheet != null && defaultSheet != 'Vidanges') {
        book.delete(defaultSheet);
      }

      cell(sv, 0, 0,
          'Historique Vidanges — ${v.matricule}  (${v.marque} ${v.modele})',
          style: titleStyle());

      final hdrsV = [
        'Date', 'Kilométrage (km)', 'Prochaine Vidange (km)',
        'Filtre Huile', 'Filtre Air', 'Filtre Gasoil', 'Montant (MAD)',
      ];
      for (var c = 0; c < hdrsV.length; c++) {
        cell(sv, 2, c, hdrsV[c], style: headerStyle());
      }
      sv.setColumnWidth(0, 14); sv.setColumnWidth(1, 20);
      sv.setColumnWidth(2, 22); sv.setColumnWidth(3, 14);
      sv.setColumnWidth(4, 14); sv.setColumnWidth(5, 16);
      sv.setColumnWidth(6, 16);

      for (var i = 0; i < v.vidanges.length; i++) {
        final vid = v.vidanges[i];
        final s = dataStyle(i.isOdd);
        cell(sv, i + 3, 0, _fmtDate(vid.date), style: s);
        cell(sv, i + 3, 1, vid.kilometrage, style: s);
        cell(sv, i + 3, 2, vid.prochaineVidange, style: s);
        cell(sv, i + 3, 3, vid.filtreHuile ? 'Oui' : 'Non', style: s);
        cell(sv, i + 3, 4, vid.filtreAir ? 'Oui' : 'Non', style: s);
        cell(sv, i + 3, 5, vid.filtreGasoil ? 'Oui' : 'Non', style: s);
        cell(sv, i + 3, 6, vid.montant, style: s);
      }
      if (v.vidanges.isNotEmpty) {
        final tr = v.vidanges.length + 3;
        final ts = totalStyle('#E3F2FD');
        cell(sv, tr, 0, 'TOTAL', style: ts);
        cell(sv, tr, 6,
            v.vidanges.fold(0.0, (sum, e) => sum + e.montant), style: ts);
      }

      // ── Feuille 2 : Gasoil ───────────────────────────────────────────────
      final sg = book['Gasoil'];

      cell(sg, 0, 0,
          'Historique Gasoil — ${v.matricule}  (${v.marque} ${v.modele})',
          style: titleStyle());

      final hdrsG = [
        'Date', 'Kilométrage (km)', 'Litres',
        'Prix/Litre (MAD)', 'Montant (MAD)',
        'Km parcourus', 'Jours depuis plein précédent',
      ];
      for (var c = 0; c < hdrsG.length; c++) {
        cell(sg, 2, c, hdrsG[c], style: headerStyle());
      }
      sg.setColumnWidth(0, 14); sg.setColumnWidth(1, 20);
      sg.setColumnWidth(2, 10); sg.setColumnWidth(3, 20);
      sg.setColumnWidth(4, 18); sg.setColumnWidth(5, 16);
      sg.setColumnWidth(6, 28);

      final pleins = v.pleins; // trié du plus récent (0) au plus ancien
      for (var i = 0; i < pleins.length; i++) {
        final p = pleins[i];
        final s = dataStyle(i.isOdd);
        // km et jours : nouveau plein (i) vs ancien plein (i+1)
        double? km;
        int? jours;
        if (i < pleins.length - 1) {
          final older = pleins[i + 1];
          final dist = p.kilometrage - older.kilometrage;
          if (dist > 0) km = dist;
          jours = p.date.difference(older.date).inDays.abs();
        }
        cell(sg, i + 3, 0, _fmtDate(p.date), style: s);
        cell(sg, i + 3, 1, p.kilometrage, style: s);
        cell(sg, i + 3, 2, p.litres, style: s);
        cell(sg, i + 3, 3, p.prixParLitre, style: s);
        cell(sg, i + 3, 4, p.montant, style: s);
        cell(sg, i + 3, 5, km != null ? '${km.toStringAsFixed(0)} km' : '—',
            style: s);
        cell(sg, i + 3, 6,
            jours != null ? '$jours jours' : 'Premier plein', style: s);
      }
      if (pleins.isNotEmpty) {
        final tr = pleins.length + 3;
        final ts = totalStyle('#FEF3C7');
        cell(sg, tr, 0, 'TOTAL', style: ts);
        cell(sg, tr, 2,
            pleins.fold(0.0, (sum, e) => sum + e.litres), style: ts);
        cell(sg, tr, 4,
            pleins.fold(0.0, (sum, e) => sum + e.montant), style: ts);
      }

      // ── Feuille 3 : Réparations ──────────────────────────────────────────
      final sr = book['Réparations'];

      cell(sr, 0, 0,
          'Historique Réparations — ${v.matricule}  (${v.marque} ${v.modele})',
          style: titleStyle());

      final hdrsR = [
        'Date', 'Description', 'Pièces Changées', 'Montant (MAD)',
      ];
      for (var c = 0; c < hdrsR.length; c++) {
        cell(sr, 2, c, hdrsR[c], style: headerStyle());
      }
      sr.setColumnWidth(0, 14); sr.setColumnWidth(1, 40);
      sr.setColumnWidth(2, 50); sr.setColumnWidth(3, 18);

      for (var i = 0; i < v.reparations.length; i++) {
        final r = v.reparations[i];
        final s = dataStyle(i.isOdd);
        cell(sr, i + 3, 0, _fmtDate(r.date), style: s);
        cell(sr, i + 3, 1,
            r.description.isEmpty ? '—' : r.description, style: s);
        cell(sr, i + 3, 2,
            r.piecesChangees.isEmpty ? '—' : r.piecesChangees.join(', '),
            style: s);
        cell(sr, i + 3, 3, r.montant, style: s);
      }
      if (v.reparations.isNotEmpty) {
        final tr = v.reparations.length + 3;
        final ts = totalStyle('#FFEDD5');
        cell(sr, tr, 0, 'TOTAL', style: ts);
        cell(sr, tr, 3,
            v.reparations.fold(0.0, (sum, e) => sum + e.montant), style: ts);
      }

      // ── Sauvegarde ───────────────────────────────────────────────────────
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ?? '';
      final sep = Platform.pathSeparator;
      final dossier = '${home}${sep}Desktop${sep}Rapports Logistique';
      final dir = Directory(dossier);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName =
          'Etat_${v.marque.replaceAll(' ', '_')}_${v.modele.replaceAll(' ', '_')}_$dateStr.xlsx';
      final file = File('$dossier$sep$fileName');

      final bytes = book.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (ctx.mounted) {
          _showToast(ctx, '✓  Exporté → Desktop/Rapports Logistique/$fileName');
        }
      }
    } catch (e) {
      if (ctx.mounted) _showToast(ctx, '⚠  Erreur export : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    if (_editing) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(p),
        child: _VehiculeForm(
          editing: widget.vehicule,
          onSaved: (v) async {
            try {
              await _svc.updateVehicule(v);
              setState(() => _editing = false);
              _showToast(context, '✓  Véhicule modifié');
            } catch (e) {
              _showToast(context, '⚠  Erreur : $e');
            }
          },
          onCancel: () => setState(() => _editing = false),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _OutlineBtn(
            icon: Icons.table_chart_outlined,
            label: 'Exporter Excel',
            color: _cSuccess,
            onTap: () => _exportExcel(context, widget.vehicule),
          ),
          const SizedBox(width: 8),
          _OutlineBtn(icon: Icons.edit_rounded, label: 'Modifier', color: _cOrange,
              onTap: () => setState(() => _editing = true)),
          const SizedBox(width: 8),
          _OutlineBtn(icon: Icons.delete_rounded, label: 'Supprimer', color: _cDanger,
              onTap: () async {
                final ok = await _confirmDlg(context,
                    title: 'Supprimer', msg: 'Cette action est irréversible.', danger: true);
                if (ok == true && widget.vehicule.id != null) {
                  await _svc.deleteVehicule(widget.vehicule.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }),
        ]),
        const SizedBox(height: 16),
        _InfoSection(title: 'Identification', icon: Icons.badge_outlined, items: [
          _IR('Matricule',   widget.vehicule.matricule),
          _IR('Marque',      widget.vehicule.marque),
          _IR('Modèle',      widget.vehicule.modele),
          _IR('Kilométrage', '${_fmtKm(widget.vehicule.kilometrage)} km'),
        ]),
        const SizedBox(height: 14),
        _InfoSection(title: 'Documents & Expirations', icon: Icons.folder_outlined, items: [
          _IR('Carte grise',            _fmtDate(widget.vehicule.expirationCarteGrise),   date: widget.vehicule.expirationCarteGrise),
          _IR('Assurance',              _fmtDate(widget.vehicule.expirationAssurance),    date: widget.vehicule.expirationAssurance),
          _IR('Visite technique',       _fmtDate(widget.vehicule.expirationVisite),       date: widget.vehicule.expirationVisite),
          _IR('Autorisation transport', _fmtDate(widget.vehicule.expirationAutorisationTransport), date: widget.vehicule.expirationAutorisationTransport),
          _IR('Taxe',                   _fmtDate(widget.vehicule.dateTaxe)),
          _IR('Badge',                  _fmtDate(widget.vehicule.expirationBadge),        date: widget.vehicule.expirationBadge),
        ]),
        const SizedBox(height: 14),
        // Statistiques
        if (widget.vehicule.id != null)
          FutureBuilder<StatistiquesVehicule>(
            future: _svc.getStats(widget.vehicule.id!),
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final s = snap.data!;
              return _StatsCard(stats: s);
            },
          ),
      ]),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final StatistiquesVehicule stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cCard, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bar_chart_rounded, color: _cBlue, size: 15)),
            const SizedBox(width: 10),
            const Text('Statistiques', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _cText)),
          ]),
        ),
        Container(height: 1, color: _cBorder),
        Padding(padding: const EdgeInsets.all(14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: _StatBox(label: 'Total gasoil', value: '${stats.totalGasoil.toStringAsFixed(0)} MAD', color: _cWarningBg, textColor: _cWarning)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: 'Total vidanges', value: '${stats.totalVidanges.toStringAsFixed(0)} MAD', color: _cBlueFaint, textColor: _cBlue)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _StatBox(label: 'Total réparations', value: '${stats.totalReparations.toStringAsFixed(0)} MAD', color: _cOrangeBg, textColor: _cOrange)),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: 'Total dépenses', value: '${stats.totalDepenses.toStringAsFixed(0)} MAD', color: _cDangerBg, textColor: _cDanger)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color, textColor;
  const _StatBox({required this.label, required this.value, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 10.5, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 2 — VIDANGES (Firebase)
// ═════════════════════════════════════════════════════════════════════════════
class _VidangeTab extends StatefulWidget {
  final String vehiculeId;
  final List<Vidange> vidanges;
  const _VidangeTab({required this.vehiculeId, required this.vidanges});
  @override State<_VidangeTab> createState() => _VidangeTabState();
}

class _VidangeTabState extends State<_VidangeTab> {
  bool _showForm = false;
  Vidange? _editing;

  void _openForm({Vidange? v}) => setState(() { _editing = v; _showForm = true; });

  Future<void> _save(Vidange v) async {
    try {
      if (_editing?.id != null) {
        await _svc.updateVidange(widget.vehiculeId, v.copyWith(id: _editing!.id));
        _showToast(context, '✓  Vidange modifiée');
      } else {
        await _svc.addVidange(widget.vehiculeId, v);
        _showToast(context, '✓  Vidange enregistrée');
      }
      setState(() { _showForm = false; _editing = null; });
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  Future<void> _delete(Vidange v) async {
    if (v.id == null) return;
    try {
      await _svc.deleteVidange(widget.vehiculeId, v.id!);
      _showToast(context, '✓  Vidange supprimée');
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    // On utilise les données passées par le StreamBuilder parent
    final vidanges = widget.vidanges;

    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!_showForm)
          Align(alignment: Alignment.centerRight,
              child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter vidange', onTap: () => _openForm())),
        if (_showForm) ...[
          _VidangeForm(
            editing: _editing,
            onSaved: _save,
            onCancel: () => setState(() { _showForm = false; _editing = null; }),
          ),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 14),
        _SectionHeader(icon: Icons.oil_barrel_outlined, title: 'Historique vidanges', count: vidanges.length),
        const SizedBox(height: 10),
        vidanges.isEmpty
            ? _EmptyState(icon: Icons.oil_barrel_outlined, title: 'Aucune vidange', sub: 'Ajoutez la première vidange')
            : Column(mainAxisSize: MainAxisSize.min,
                children: vidanges.map((v) => _VidangeCard(
                  vidange: v,
                  onEdit: () => _openForm(v: v),
                  onDelete: () async {
                    final ok = await _confirmDlg(context, title: 'Supprimer cette vidange', msg: 'Cette action est irréversible.', danger: true);
                    if (ok == true) _delete(v);
                  },
                  onDetail: () => _showVidangeDetail(context, v),
                )).toList()),
      ]),
    );
  }

  void _showVidangeDetail(BuildContext ctx, Vidange v) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _VidangeDetailSheet(vidange: v));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 3 — GASOIL (Firebase)
// ═════════════════════════════════════════════════════════════════════════════
class _GasoilTab extends StatefulWidget {
  final String vehiculeId;
  final List<PleinGasoil> pleins;
  const _GasoilTab({required this.vehiculeId, required this.pleins});
  @override State<_GasoilTab> createState() => _GasoilTabState();
}

class _GasoilTabState extends State<_GasoilTab> {
  bool _showForm = false;
  PleinGasoil? _editing;

  void _openForm({PleinGasoil? v}) => setState(() { _editing = v; _showForm = true; });

  Future<void> _save(PleinGasoil p) async {
    try {
      if (_editing?.id != null) {
        await _svc.updatePlein(widget.vehiculeId, p.copyWith(id: _editing!.id));
        _showToast(context, '✓  Plein modifié');
      } else {
        await _svc.addPlein(widget.vehiculeId, p);
        _showToast(context, '✓  Plein enregistré');
      }
      setState(() { _showForm = false; _editing = null; });
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  Future<void> _delete(PleinGasoil p) async {
    if (p.id == null) return;
    try {
      await _svc.deletePlein(widget.vehiculeId, p.id!);
      _showToast(context, '✓  Plein supprimé');
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  List<Map<String, dynamic>> _withConso() {
    final pl = widget.pleins;
    // pl[0] = plein le plus récent, pl[last] = le plus ancien
    // Le plein le plus récent (index 0) n'a pas encore de stats (en attente du prochain plein).
    // Pour chaque plein à index e.key > 0, on compare avec le plein plus récent (e.key - 1) :
    //   km    = nouveau.kilometrage - ancien.kilometrage
    //   jours = nouveau.date - ancien.date
    return pl.asMap().entries.map((e) {
      double? c100, cMAD, km;
      int? jours;
      if (e.key > 0) {
        final nouveau = pl[e.key - 1];
        final dist = nouveau.kilometrage - pl[e.key].kilometrage;
        if (dist > 0) {
          c100 = (nouveau.litres  / dist) * 100;
          cMAD = (nouveau.montant / dist) * 100;
          km   = dist;
        }
        jours = nouveau.date.difference(pl[e.key].date).inDays.abs();
      }
      return {'plein': e.value, 'c100': c100, 'cMAD': cMAD, 'km': km, 'jours': jours};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    final rows = _withConso();

    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!_showForm)
          Align(alignment: Alignment.centerRight,
              child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter plein', onTap: () => _openForm())),
        if (_showForm) ...[
          _GasoilForm(
            editing: _editing,
            onSaved: _save,
            onCancel: () => setState(() { _showForm = false; _editing = null; }),
          ),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 14),
        _SectionHeader(icon: Icons.local_gas_station_outlined, title: 'Historique gasoil', count: widget.pleins.length),
        const SizedBox(height: 10),
        widget.pleins.isEmpty
            ? _EmptyState(icon: Icons.local_gas_station_outlined, title: 'Aucun plein', sub: 'Ajoutez le premier plein de carburant')
            : Column(mainAxisSize: MainAxisSize.min,
                children: rows.map((r) => _GasoilCard(
                  plein: r['plein'] as PleinGasoil,
                  conso100km: r['c100'] as double?,
                  consoMAD: r['cMAD'] as double?,
                  kmEntrePleins: r['km'] as double?,
                  joursEntrePleins: r['jours'] as int?,
                  onEdit: () => _openForm(v: r['plein']),
                  onDelete: () async {
                    final ok = await _confirmDlg(context, title: 'Supprimer ce plein', msg: 'Cette action est irréversible.', danger: true);
                    if (ok == true) _delete(r['plein']);
                  },
                  onDetail: () => _showGasoilDetail(context, r['plein'], r['c100'], r['cMAD'], r['km'], r['jours']),
                )).toList()),
      ]),
    );
  }

  void _showGasoilDetail(BuildContext ctx, PleinGasoil p, double? c100, double? cMAD, double? km, int? jours) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _GasoilDetailSheet(plein: p, conso100km: c100, consoMAD: cMAD, kmEntrePleins: km, joursEntrePleins: jours));
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 4 — RÉPARATIONS (Firebase)
// ═════════════════════════════════════════════════════════════════════════════
class _AutresTab extends StatefulWidget {
  final String vehiculeId;
  final List<Reparation> reparations;
  const _AutresTab({required this.vehiculeId, required this.reparations});
  @override State<_AutresTab> createState() => _AutresTabState();
}

class _AutresTabState extends State<_AutresTab> {
  bool _showForm = false;
  Reparation? _editing;

  void _openForm({Reparation? r}) => setState(() { _editing = r; _showForm = true; });

  Future<void> _save(Reparation r) async {
    try {
      if (_editing?.id != null) {
        await _svc.updateReparation(widget.vehiculeId, r.copyWith(id: _editing!.id));
        _showToast(context, '✓  Réparation modifiée');
      } else {
        await _svc.addReparation(widget.vehiculeId, r);
        _showToast(context, '✓  Réparation enregistrée');
      }
      setState(() { _showForm = false; _editing = null; });
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  Future<void> _delete(Reparation r) async {
    if (r.id == null) return;
    try {
      await _svc.deleteReparation(widget.vehiculeId, r.id!);
      _showToast(context, '✓  Réparation supprimée');
    } catch (e) {
      _showToast(context, '⚠  Erreur : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!_showForm)
          Align(alignment: Alignment.centerRight,
              child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter réparation', onTap: () => _openForm())),
        if (_showForm) ...[
          _ReparationForm(
            editing: _editing,
            onSaved: _save,
            onCancel: () => setState(() { _showForm = false; _editing = null; }),
          ),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 14),
        _SectionHeader(icon: Icons.build_rounded, title: 'Historique réparations', count: widget.reparations.length),
        const SizedBox(height: 10),
        widget.reparations.isEmpty
            ? _EmptyState(icon: Icons.build_outlined, title: 'Aucune réparation', sub: 'Ajoutez la première réparation')
            : Column(mainAxisSize: MainAxisSize.min,
                children: widget.reparations.map((r) => _ReparationCard(
                  reparation: r,
                  onEdit: () => _openForm(r: r),
                  onDelete: () async {
                    final ok = await _confirmDlg(context, title: 'Supprimer cette réparation', msg: 'Cette action est irréversible.', danger: true);
                    if (ok == true) _delete(r);
                  },
                  onDetail: () => _showReparationDetail(context, r),
                )).toList()),
      ]),
    );
  }

  void _showReparationDetail(BuildContext ctx, Reparation r) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _ReparationDetailSheet(reparation: r));
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  TOUS LES WIDGETS UI (inchangés par rapport à votre version originale)
//  _VidangeForm, _VidangeCard, _VidangeDetailSheet
//  _GasoilForm, _GasoilCard, _GasoilDetailSheet
//  _ReparationForm, _ReparationCard, _ReparationDetailSheet
//  _DocPicker, _GlassCard, _FormHeader, _InfoSection, _IR
//  _SectionHeader, _SheetRow, _ConsoBox, _SecLabel
//  _Field, _LDateField, _CheckChip, _PrimaryBtn, _LGhostBtn
//  _OutlineBtn, _ActionBtn, _Row2, _Row3, _Tag, _EmptyState
//  _ErrorState, _showToast, _LToastWidget, _confirmDlg
// ═══════════════════════════════════════════════════════════════════════
// (Copiez tous les widgets UI depuis votre fichier original ici —
//  ils sont 100% compatibles, aucune modification requise)

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 56, height: 56, decoration: BoxDecoration(color: _cDangerBg, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.cloud_off_rounded, color: _cDanger, size: 26)),
    const SizedBox(height: 12),
    const Text('Erreur de connexion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cText)),
    const SizedBox(height: 4),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(message, style: const TextStyle(fontSize: 12.5, color: _cSub), textAlign: TextAlign.center)),
  ]));
}

// ── Widgets UI (identiques à votre version originale) ─────────────────────────
// [Copiez ici tous les widgets : _VidangeForm, _VidangeCard, etc.]
// [Voir commentaire ci-dessus — aucune modification n'est nécessaire]

// ─── Utilitaires ─────────────────────────────────────────────────────────────
String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _fmtKm(double km) {
  final s = km.toInt().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─── Toast ────────────────────────────────────────────────────────────────────
void _showToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _LToastWidget(message: msg, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _LToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDone;
  const _LToastWidget({required this.message, required this.onDone});
  @override State<_LToastWidget> createState() => _LToastWidgetState();
}

class _LToastWidgetState extends State<_LToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2400),
        () { if (mounted) _c.reverse().then((_) => widget.onDone()); });
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 28 + MediaQuery.of(context).padding.bottom,
    left: 24, right: 24,
    child: AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 30 * (1 - _a.value)),
        child: Opacity(opacity: _a.value.clamp(0.0, 1.0), child: child),
      ),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_cBlueDark, _cBlueMid]),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      )),
    ),
  );
}

Future<bool?> _confirmDlg(BuildContext context,
    {required String title, required String msg, bool danger = false}) {
  return showGeneralDialog<bool>(
    context: context, barrierDismissible: true, barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, a, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: a, child: child)),
    pageBuilder: (ctx, _, __) => Center(child: Material(
      color: Colors.transparent,
      child: Container(
        width: 300, margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: _cSurface, borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 10))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: danger ? _cDangerBg : _cBlueFaint, shape: BoxShape.circle),
            child: Icon(danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                color: danger ? _cDanger : _cBlue, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(msg, style: const TextStyle(fontSize: 12.5, color: _cSub, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _cSub, side: const BorderSide(color: _cBorder),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? _cDanger : _cBlue, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(danger ? 'Supprimer' : 'Confirmer', style: const TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    )),
  );
}

// ─── Widgets communs ──────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget header, child;
  const _GlassCard({required this.header, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _cCard, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: _cBlueBorder, width: 1.5),
      boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.08), blurRadius: 32, offset: const Offset(0, 8))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [header, Padding(padding: const EdgeInsets.all(16), child: child)]),
  );
}

class _FormHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onClose;
  const _FormHeader({required this.icon, required this.title, required this.onClose});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_cBlue.withOpacity(0.06), _cBlueFaint], begin: Alignment.centerLeft, end: Alignment.centerRight),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
    ),
    child: Row(children: [
      Container(width: 34, height: 34,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cBlue, _cBlueMid], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 17)),
      const SizedBox(width: 10),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cText))),
      IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, color: _cSub, size: 20),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
    ]),
  );
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_IR> items;
  const _InfoSection({required this.title, required this.icon, required this.items});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: _cCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: _cBlue, size: 15)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _cText)),
            ]),
          ),
          Container(height: 1, color: _cBorder),
          ...items.map((r) => r._build()),
        ]),
  );
}

class _IR {
  final String label, value;
  final DateTime? date;
  const _IR(this.label, this.value, {this.date});
  Widget _build() {
    Color valueColor = _cText;
    Color? bgColor;
    String? badge;
    if (date != null) {
      final diff = date!.difference(DateTime.now()).inDays;
      if (diff < 0)       { valueColor = _cDanger;  bgColor = _cDangerBg;  badge = 'Expiré'; }
      else if (diff < 30) { valueColor = _cWarning; bgColor = _cWarningBg; badge = '$diff j restants'; }
      else                { valueColor = _cSuccess;  bgColor = _cSuccessBg; badge = 'Valide'; }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F4F8)))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _cSub))),
        Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: valueColor))),
        if (badge != null)
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
              child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: valueColor))),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  const _SectionHeader({required this.icon, required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 30, height: 30,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cBlue, _cBlueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 14)),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _cText)),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cBlue))),
  ]);
}

class _SecLabel extends StatelessWidget {
  final String label;
  const _SecLabel({required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 3, height: 13, decoration: BoxDecoration(color: _cBlue, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cSub, letterSpacing: 0.8)),
  ]);
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool req;
  final TextInputType? type;
  final ValueChanged<String>? onChanged;
  const _Field({required this.ctrl, required this.label, required this.icon, this.req = false, this.type, this.onChanged});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, keyboardType: type, onChanged: onChanged,
    style: const TextStyle(fontSize: 13, color: _cText),
    validator: req ? (v) => (v == null || v.isEmpty) ? 'Requis' : null : null,
    decoration: InputDecoration(
      labelText: label, labelStyle: const TextStyle(fontSize: 12.5, color: _cSub),
      prefixIcon: Icon(icon, size: 17, color: _cBlue),
      filled: true, fillColor: _cBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cBorder, width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cBlue, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cDanger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _cDanger, width: 1.8)),
    ),
  );
}

class _LDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  const _LDateField({required this.label, required this.value, required this.onPicked});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final p = await showDatePicker(
        context: context, initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2000), lastDate: DateTime(2040),
        builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _cBlue)), child: child!),
      );
      if (p != null) onPicked(p);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBorder, width: 1.2)),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, color: _cBlue, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(value != null ? _fmtDate(value) : label,
            style: TextStyle(fontSize: 13, color: value != null ? _cText : _cSub), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

class _CheckChip extends StatelessWidget {
  final String label;
  final bool val;
  final ValueChanged<bool?> onChanged;
  const _CheckChip({required this.label, required this.val, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!val),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: val ? _cBlue : _cBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: val ? _cBlue : _cBorder, width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(val ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: val ? Colors.white : _cSub, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: val ? Colors.white : _cSub)),
      ]),
    ),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon ?? Icons.add_rounded, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    style: ElevatedButton.styleFrom(backgroundColor: _cBlue, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}

class _LGhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LGhostBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: _cSub,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _cBorder))),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 34, height: 34, child: Icon(icon, color: color, size: 17))),
    ),
  );
}

class _Row2 extends StatelessWidget {
  final Widget a, b;
  const _Row2(this.a, this.b);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
}

class _Row3 extends StatelessWidget {
  final Widget a, b, c;
  const _Row3(this.a, this.b, this.c);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b), const SizedBox(width: 12), Expanded(child: c)]);
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color, textColor;
  const _Tag({required this.label, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10.5, color: textColor, fontWeight: FontWeight.w600)),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _EmptyState({required this.icon, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 56, height: 56, decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: _cBlue, size: 26)),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _cText)),
      const SizedBox(height: 4),
      Text(sub, style: const TextStyle(fontSize: 12.5, color: _cSub)),
    ])),
  );
}

// ── Formulaires (inchangés) ───────────────────────────────────────────────────
class _VidangeForm extends StatefulWidget {
  final Vidange? editing;
  final void Function(Vidange) onSaved;
  final VoidCallback onCancel;
  const _VidangeForm({this.editing, required this.onSaved, required this.onCancel});
  @override State<_VidangeForm> createState() => _VidangeFormState();
}

class _VidangeFormState extends State<_VidangeForm> {
  final _fk = GlobalKey<FormState>();
  DateTime? _date;
  late final TextEditingController _km, _proch, _mont;
  bool _fH = false, _fA = false, _fG = false;
  String? _docPath;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date = e?.date;
    _km   = TextEditingController(text: e?.kilometrage.toStringAsFixed(0) ?? '');
    _proch= TextEditingController(text: e?.prochaineVidange.toStringAsFixed(0) ?? '');
    _mont = TextEditingController(text: e?.montant.toStringAsFixed(2) ?? '');
    _fH = e?.filtreHuile ?? false; _fA = e?.filtreAir ?? false; _fG = e?.filtreGasoil ?? false;
    _docPath = e?.documentPath;
  }
  @override void dispose() { _km.dispose(); _proch.dispose(); _mont.dispose(); super.dispose(); }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    if (_date == null) { _showToast(context, '⚠  Date requise'); return; }
    widget.onSaved(Vidange(
      date: _date!, kilometrage: double.tryParse(_km.text) ?? 0,
      filtreHuile: _fH, filtreAir: _fA, filtreGasoil: _fG,
      prochaineVidange: double.tryParse(_proch.text) ?? 0,
      montant: double.tryParse(_mont.text) ?? 0,
      documentPath: _docPath,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _GlassCard(
      header: _FormHeader(icon: Icons.oil_barrel_outlined,
          title: widget.editing != null ? 'Modifier la vidange' : 'Nouvelle vidange',
          onClose: widget.onCancel),
      child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mobile) ...[
          _LDateField(label: 'Date de vidange', value: _date, onPicked: (d) => setState(() => _date = d)),
          const SizedBox(height: 10),
          _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
        ] else
          _Row2(_LDateField(label: 'Date de vidange', value: _date, onPicked: (d) => setState(() => _date = d)),
              _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: _cBlue, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('FILTRES REMPLACÉS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cSub, letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _CheckChip(label: 'Filtre à huile',  val: _fH, onChanged: (v) => setState(() => _fH = v ?? false)),
              _CheckChip(label: 'Filtre à air',    val: _fA, onChanged: (v) => setState(() => _fA = v ?? false)),
              _CheckChip(label: 'Filtre à gasoil', val: _fG, onChanged: (v) => setState(() => _fG = v ?? false)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        if (mobile) ...[
          _Field(ctrl: _proch, label: 'Prochaine vidange (km)', icon: Icons.update_rounded, type: TextInputType.number, req: true),
          const SizedBox(height: 10),
          _Field(ctrl: _mont, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true),
        ] else
          _Row2(_Field(ctrl: _proch, label: 'Prochaine vidange (km)', icon: Icons.update_rounded, type: TextInputType.number, req: true),
              _Field(ctrl: _mont, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true)),
        const SizedBox(height: 14),
        _DocPicker(path: _docPath,
            onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
            onRemove: () => setState(() => _docPath = null)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _LGhostBtn(label: 'Annuler', onTap: widget.onCancel),
          const SizedBox(width: 10),
          _PrimaryBtn(label: widget.editing != null ? 'Modifier' : 'Enregistrer', icon: Icons.check_rounded, onTap: _save),
        ]),
      ])),
    );
  }
}

class _VidangeCard extends StatelessWidget {
  final Vidange vidange;
  final VoidCallback onEdit, onDelete, onDetail;
  const _VidangeCard({required this.vidange, required this.onEdit, required this.onDelete, required this.onDetail});
  @override
  Widget build(BuildContext context) {
    final filtres = [if (vidange.filtreHuile) 'Huile', if (vidange.filtreAir) 'Air', if (vidange.filtreGasoil) 'Gasoil'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _cCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cBorder),
          boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))]),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.oil_barrel_outlined, color: Colors.white, size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_fmtDate(vidange.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _cText)),
                _Tag(label: '${_fmtKm(vidange.kilometrage)} km', color: _cBlueFaint, textColor: _cBlue),
              ]),
              if (filtres.isNotEmpty) ...[const SizedBox(height: 5), Wrap(spacing: 5, runSpacing: 4, children: filtres.map((f) => _Tag(label: f, color: _cSuccessBg, textColor: _cSuccess)).toList())],
              const SizedBox(height: 4),
              Text('Prochaine : ${_fmtKm(vidange.prochaineVidange)} km  ·  ${vidange.montant.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 11.5, color: _cSub)),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue, tooltip: 'Détails', onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined, color: _cOrange, tooltip: 'Modifier', onTap: onEdit),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger, tooltip: 'Supprimer', onTap: onDelete),
          ]),
        ]),
      ),
    );
  }
}

class _VidangeDetailSheet extends StatelessWidget {
  final Vidange vidange;
  const _VidangeDetailSheet({required this.vidange});
  @override
  Widget build(BuildContext context) {
    final filtres = [if (vidange.filtreHuile) 'Filtre à huile', if (vidange.filtreAir) 'Filtre à air', if (vidange.filtreGasoil) 'Filtre à gasoil'];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(color: _cSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cBlue, _cBlueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.oil_barrel_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails vidange', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(vidange.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.speed_rounded, label: 'Kilométrage', value: '${_fmtKm(vidange.kilometrage)} km'),
            _SheetRow(icon: Icons.update_rounded, label: 'Prochaine vidange', value: '${_fmtKm(vidange.prochaineVidange)} km'),
            _SheetRow(icon: Icons.payments_outlined, label: 'Montant total', value: '${vidange.montant.toStringAsFixed(2)} MAD'),
            const SizedBox(height: 12),
            if (filtres.isNotEmpty) ...[
              Row(children: [const Icon(Icons.check_circle_outline_rounded, color: _cSub, size: 15), const SizedBox(width: 8), const Text('Filtres remplacés', style: TextStyle(fontSize: 12, color: _cSub))]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: filtres.map((f) => _Tag(label: f, color: _cSuccessBg, textColor: _cSuccess)).toList()),
            ] else const _Tag(label: 'Aucun filtre remplacé', color: _cBg, textColor: _cSub),
          ]),
        ),
      ]),
    );
  }
}

class _GasoilForm extends StatefulWidget {
  final PleinGasoil? editing;
  final void Function(PleinGasoil) onSaved;
  final VoidCallback onCancel;
  const _GasoilForm({this.editing, required this.onSaved, required this.onCancel});
  @override State<_GasoilForm> createState() => _GasoilFormState();
}

class _GasoilFormState extends State<_GasoilForm> {
  final _fk = GlobalKey<FormState>();
  DateTime? _date;
  late final TextEditingController _km, _litres, _prix;
  String? _docPath;

  double get _montant {
    final l = double.tryParse(_litres.text.replaceAll(',', '.')) ?? 0;
    final p = double.tryParse(_prix.text.replaceAll(',', '.')) ?? 0;
    return l * p;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date   = e?.date;
    _km     = TextEditingController(text: e?.kilometrage.toStringAsFixed(0) ?? '');
    _litres = TextEditingController(text: e?.litres.toStringAsFixed(1) ?? '');
    _prix   = TextEditingController(text: e?.prixParLitre.toStringAsFixed(2) ?? '');
    _docPath = e?.documentPath;
  }
  @override void dispose() { _km.dispose(); _litres.dispose(); _prix.dispose(); super.dispose(); }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    if (_date == null) { _showToast(context, '⚠  Date requise'); return; }
    widget.onSaved(PleinGasoil(
      date: _date!, kilometrage: double.tryParse(_km.text) ?? 0,
      litres: double.tryParse(_litres.text.replaceAll(',', '.')) ?? 0,
      prixParLitre: double.tryParse(_prix.text.replaceAll(',', '.')) ?? 0,
      documentPath: _docPath,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _GlassCard(
      header: _FormHeader(icon: Icons.local_gas_station_outlined,
          title: widget.editing != null ? 'Modifier le plein' : 'Nouveau plein gasoil',
          onClose: widget.onCancel),
      child: Form(key: _fk, child: StatefulBuilder(builder: (ctx, setInner) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (mobile) ...[
            _LDateField(label: 'Date du plein', value: _date, onPicked: (d) { setState(() => _date = d); setInner(() {}); }),
            const SizedBox(height: 10),
            _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
          ] else
            _Row2(_LDateField(label: 'Date du plein', value: _date, onPicked: (d) { setState(() => _date = d); setInner(() {}); }),
                _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true)),
          const SizedBox(height: 12),
          if (mobile) ...[
            _Field(ctrl: _litres, label: 'Litres', icon: Icons.water_drop_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {})),
            const SizedBox(height: 10),
            _Field(ctrl: _prix, label: 'Prix / litre (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {})),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [_cBlue.withOpacity(0.08), _cBlueFaint], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBlueBorder)),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, color: _cBlue, size: 16), const SizedBox(width: 8),
                const Text('Montant auto', style: TextStyle(fontSize: 12, color: _cBlue)), const Spacer(),
                Text('${_montant.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _cBlue)),
              ]),
            ),
          ] else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _Field(ctrl: _litres, label: 'Litres', icon: Icons.water_drop_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {}))),
              const SizedBox(width: 12),
              Expanded(child: _Field(ctrl: _prix, label: 'Prix / litre (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {}))),
              const SizedBox(width: 12),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [_cBlue.withOpacity(0.08), _cBlueFaint], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBlueBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [const Icon(Icons.calculate_outlined, color: _cBlue, size: 14), const SizedBox(width: 5), const Text('Montant auto', style: TextStyle(fontSize: 10.5, color: _cBlue))]),
                  const SizedBox(height: 5),
                  Text('${_montant.toStringAsFixed(2)} MAD', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _cBlue)),
                ]),
              )),
            ]),
          const SizedBox(height: 12),
          _DocPicker(path: _docPath,
              onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
              onRemove: () => setState(() => _docPath = null)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _LGhostBtn(label: 'Annuler', onTap: widget.onCancel),
            const SizedBox(width: 10),
            _PrimaryBtn(label: widget.editing != null ? 'Modifier' : 'Enregistrer', icon: Icons.check_rounded, onTap: _save),
          ]),
        ]);
      })),
    );
  }
}

class _GasoilCard extends StatelessWidget {
  final PleinGasoil plein;
  final double? conso100km, consoMAD, kmEntrePleins;
  final int? joursEntrePleins;
  final VoidCallback onEdit, onDelete, onDetail;
  const _GasoilCard({
    required this.plein,
    this.conso100km,
    this.consoMAD,
    this.kmEntrePleins,
    this.joursEntrePleins,
    required this.onEdit,
    required this.onDelete,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final hasStats = kmEntrePleins != null || joursEntrePleins != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // ── En-tête principal ──────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [BoxShadow(color: const Color(0xFFD97706).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_fmtDate(plein.date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _cText)),
                _Tag(label: '${_fmtKm(plein.kilometrage)} km', color: _cWarningBg, textColor: _cWarning),
              ]),
              const SizedBox(height: 4),
              Text(
                '${plein.litres.toStringAsFixed(1)} L  ·  ${plein.prixParLitre.toStringAsFixed(2)} MAD/L  ·  ${plein.montant.toStringAsFixed(2)} MAD',
                style: const TextStyle(fontSize: 11.5, color: _cSub),
              ),
              if (conso100km != null) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Tag(label: '${conso100km!.toStringAsFixed(1)} L/100km', color: _cBlueFaint, textColor: _cBlue),
                  _Tag(label: '${consoMAD!.toStringAsFixed(1)} MAD/100km', color: _cWarningBg, textColor: _cWarning),
                ]),
              ],
            ])),
          ]),
        ),

        // ── Métriques km / jours entre pleins ─────────────────────────────
        if (hasStats) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _cBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cBorder),
              ),
              child: Row(children: [
                if (kmEntrePleins != null) ...[
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.route_outlined, size: 14, color: _cBlue),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('${_fmtKm(kmEntrePleins!)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _cBlue)),
                    const Text('parcourus', style: TextStyle(fontSize: 10, color: _cSub)),
                  ]),
                ],
                if (kmEntrePleins != null && joursEntrePleins != null)
                  Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 28, color: _cBorder),
                if (joursEntrePleins != null) ...[
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: _cSuccessBg, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.calendar_month_outlined, size: 14, color: _cSuccess),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('$joursEntrePleins jours', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _cSuccess)),
                    const Text('entre pleins', style: TextStyle(fontSize: 10, color: _cSub)),
                  ]),
                ],
              ]),
            ),
          ),
        ],

        // ── Actions ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue, tooltip: 'Détails', onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined, color: _cOrange, tooltip: 'Modifier', onTap: onEdit),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger, tooltip: 'Supprimer', onTap: onDelete),
          ]),
        ),
      ]),
    );
  }
}

class _GasoilDetailSheet extends StatelessWidget {
  final PleinGasoil plein;
  final double? conso100km, consoMAD, kmEntrePleins;
  final int? joursEntrePleins;
  const _GasoilDetailSheet({required this.plein, this.conso100km, this.consoMAD, this.kmEntrePleins, this.joursEntrePleins});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(color: _cSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails plein gasoil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(plein.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.speed_rounded, label: 'Kilométrage', value: '${_fmtKm(plein.kilometrage)} km'),
            _SheetRow(icon: Icons.water_drop_outlined, label: 'Litres', value: '${plein.litres.toStringAsFixed(1)} L'),
            _SheetRow(icon: Icons.sell_outlined, label: 'Prix / litre', value: '${plein.prixParLitre.toStringAsFixed(2)} MAD'),
            _SheetRow(icon: Icons.payments_outlined, label: 'Montant total', value: '${plein.montant.toStringAsFixed(2)} MAD', highlight: true),
            if (conso100km != null || kmEntrePleins != null || joursEntrePleins != null) ...[
              const Divider(height: 20, color: _cBorder),
              if (kmEntrePleins != null || joursEntrePleins != null) ...[
                Row(children: [
                  if (kmEntrePleins != null)
                    Expanded(child: _ConsoBox(
                      label: 'Distance parcourue',
                      value: _fmtKm(kmEntrePleins!),
                      unit: 'km entre pleins',
                      color: _cBlueFaint,
                      textColor: _cBlue,
                    )),
                  if (kmEntrePleins != null && joursEntrePleins != null) const SizedBox(width: 10),
                  if (joursEntrePleins != null)
                    Expanded(child: _ConsoBox(
                      label: 'Intervalle',
                      value: '$joursEntrePleins',
                      unit: 'jours entre pleins',
                      color: _cSuccessBg,
                      textColor: _cSuccess,
                    )),
                ]),
                const SizedBox(height: 10),
              ],
              if (conso100km != null)
                Row(children: [
                  Expanded(child: _ConsoBox(label: 'Consommation', value: conso100km!.toStringAsFixed(1), unit: 'L / 100 km', color: _cWarningBg, textColor: _cWarning)),
                  const SizedBox(width: 10),
                  Expanded(child: _ConsoBox(label: 'Coût carburant', value: consoMAD!.toStringAsFixed(1), unit: 'MAD / 100 km', color: _cOrangeBg, textColor: _cOrange)),
                ]),
            ] else
              Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [Icon(Icons.info_outline_rounded, color: _cSub, size: 14), SizedBox(width: 8), Flexible(child: Text('Statistiques disponibles à partir du 2ème plein', style: TextStyle(fontSize: 12, color: _cSub)))])),
          ]),
        ),
      ]),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool highlight;
  const _SheetRow({required this.icon, required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F4F8)))),
    child: Row(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: _cBlue, size: 14)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: _cSub))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: highlight ? _cBlue : _cText)),
    ]),
  );
}

class _ConsoBox extends StatelessWidget {
  final String label, value, unit;
  final Color color, textColor;
  const _ConsoBox({required this.label, required this.value, required this.unit, required this.color, required this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 10.5, color: textColor.withOpacity(0.7))),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
      Text(unit, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
    ]),
  );
}

class _ReparationForm extends StatefulWidget {
  final Reparation? editing;
  final void Function(Reparation) onSaved;
  final VoidCallback onCancel;
  const _ReparationForm({this.editing, required this.onSaved, required this.onCancel});
  @override State<_ReparationForm> createState() => _ReparationFormState();
}

class _ReparationFormState extends State<_ReparationForm> {
  final _fk = GlobalKey<FormState>();
  DateTime? _date;
  late final TextEditingController _desc, _montant, _pieceCtrl;
  final List<String> _pieces = [];
  String? _docPath;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _date    = e?.date;
    _desc    = TextEditingController(text: e?.description ?? '');
    _montant = TextEditingController(text: e?.montant.toStringAsFixed(2) ?? '');
    _pieceCtrl = TextEditingController();
    _docPath = e?.documentPath;
    if (e != null) _pieces.addAll(e.piecesChangees);
  }
  @override void dispose() { _desc.dispose(); _montant.dispose(); _pieceCtrl.dispose(); super.dispose(); }

  void _addPiece() {
    final val = _pieceCtrl.text.trim();
    if (val.isEmpty) return;
    setState(() { _pieces.add(val); _pieceCtrl.clear(); });
  }

  void _save() {
    if (!_fk.currentState!.validate()) return;
    if (_date == null) { _showToast(context, '⚠  Date requise'); return; }
    widget.onSaved(Reparation(
      date: _date!, description: _desc.text.trim(),
      piecesChangees: List.from(_pieces),
      montant: double.tryParse(_montant.text.replaceAll(',', '.')) ?? 0,
      documentPath: _docPath,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _GlassCard(
      header: _FormHeader(icon: Icons.build_rounded,
          title: widget.editing != null ? 'Modifier la réparation' : 'Nouvelle réparation',
          onClose: widget.onCancel),
      child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mobile) ...[
          _LDateField(label: 'Date de réparation', value: _date, onPicked: (d) => setState(() => _date = d)),
          const SizedBox(height: 10),
          _Field(ctrl: _montant, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true),
        ] else
          _Row2(_LDateField(label: 'Date de réparation', value: _date, onPicked: (d) => setState(() => _date = d)),
              _Field(ctrl: _montant, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true)),
        const SizedBox(height: 12),
        _Field(ctrl: _desc, label: 'Description (optionnelle)', icon: Icons.description_outlined, req: false),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: _cOrange, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('PIÈCES CHANGÉES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cSub, letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                controller: _pieceCtrl,
                style: const TextStyle(fontSize: 13, color: _cText),
                decoration: InputDecoration(
                  hintText: 'Ex: Filtre à huile, Plaquettes...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: _cSub),
                  prefixIcon: const Icon(Icons.build_circle_outlined, size: 17, color: _cOrange),
                  filled: true, fillColor: _cSurface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _cBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _cOrange, width: 1.8)),
                ),
                onFieldSubmitted: (_) => _addPiece(),
              )),
              const SizedBox(width: 8),
              Material(color: _cOrange, borderRadius: BorderRadius.circular(10),
                  child: InkWell(onTap: _addPiece, borderRadius: BorderRadius.circular(10),
                      child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: Colors.white, size: 20)))),
            ]),
            if (_pieces.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6,
                children: _pieces.asMap().entries.map((e) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _cOrangeBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cOrange.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(e.value, style: const TextStyle(fontSize: 12, color: _cOrange, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: () => setState(() => _pieces.removeAt(e.key)), child: const Icon(Icons.close_rounded, size: 13, color: _cOrange)),
                  ]),
                )).toList(),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        _DocPicker(path: _docPath,
            onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
            onRemove: () => setState(() => _docPath = null)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _LGhostBtn(label: 'Annuler', onTap: widget.onCancel),
          const SizedBox(width: 10),
          _PrimaryBtn(label: widget.editing != null ? 'Modifier' : 'Enregistrer', icon: Icons.check_rounded, onTap: _save),
        ]),
      ])),
    );
  }
}

class _ReparationCard extends StatelessWidget {
  final Reparation reparation;
  final VoidCallback onEdit, onDelete, onDetail;
  const _ReparationCard({required this.reparation, required this.onEdit, required this.onDelete, required this.onDetail});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _cCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cBorder),
          boxShadow: [BoxShadow(color: _cOrange.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))]),
      child: Padding(padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.build_rounded, color: Colors.white, size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_fmtDate(reparation.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _cText)),
                _Tag(label: '${reparation.montant.toStringAsFixed(2)} MAD', color: _cOrangeBg, textColor: _cOrange),
              ]),
              if (reparation.description.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(reparation.description, style: const TextStyle(fontSize: 12, color: _cSub), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (reparation.piecesChangees.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 5, runSpacing: 4,
                  children: reparation.piecesChangees.take(3).map((p) => _Tag(label: p, color: _cBg, textColor: _cSub)).toList()
                    ..addAll(reparation.piecesChangees.length > 3 ? [_Tag(label: '+${reparation.piecesChangees.length - 3}', color: _cBg, textColor: _cSub)] : []),
                ),
              ],
            ])),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue, tooltip: 'Détails', onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined, color: _cOrange, tooltip: 'Modifier', onTap: onEdit),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger, tooltip: 'Supprimer', onTap: onDelete),
          ]),
        ]),
      ),
    );
  }
}

class _ReparationDetailSheet extends StatelessWidget {
  final Reparation reparation;
  const _ReparationDetailSheet({required this.reparation});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: const BoxDecoration(color: _cSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 46, height: 46,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.build_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails réparation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(reparation.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.calendar_today_outlined, label: 'Date', value: _fmtDate(reparation.date)),
            _SheetRow(icon: Icons.payments_outlined, label: 'Montant total', value: '${reparation.montant.toStringAsFixed(2)} MAD', highlight: true),
            if (reparation.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cBorder)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Row(children: [Icon(Icons.description_outlined, color: _cSub, size: 13), SizedBox(width: 6), Text('Description', style: TextStyle(fontSize: 11, color: _cSub, fontWeight: FontWeight.w600))]),
                    const SizedBox(height: 6),
                    Text(reparation.description, style: const TextStyle(fontSize: 13, color: _cText, height: 1.5)),
                  ])),
            ],
            if (reparation.piecesChangees.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _cOrangeBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cOrange.withOpacity(0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Row(children: [Icon(Icons.build_circle_outlined, color: _cOrange, size: 13), SizedBox(width: 6), Text('Pièces changées', style: TextStyle(fontSize: 11, color: _cOrange, fontWeight: FontWeight.w700))]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6,
                      children: reparation.piecesChangees.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _cSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cOrange.withOpacity(0.3))),
                        child: Text(p, style: const TextStyle(fontSize: 12, color: _cOrange, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ])),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _DocPicker extends StatelessWidget {
  final String? path;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  const _DocPicker({required this.path, required this.onPick, this.onRemove});

  String get _name {
    if (path == null) return '';
    final parts = path!.replaceAll('\\', '/').split('/');
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: _cSuccessBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cSuccess.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined, color: _cSuccess, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Document importé', style: TextStyle(fontSize: 11, color: _cSuccess, fontWeight: FontWeight.w700)),
            Text(_name, style: const TextStyle(fontSize: 12, color: _cText), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 6),
          GestureDetector(onTap: onPick,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: _cSuccess.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                  child: const Text('Changer', style: TextStyle(fontSize: 11, color: _cSuccess, fontWeight: FontWeight.w600)))),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, color: _cDanger, size: 16)),
        ]),
      );
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cBorder, width: 1.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.upload_file_outlined, color: _cBlue.withOpacity(0.6), size: 18),
          const SizedBox(width: 8),
          const Text('Importer facture / document', style: TextStyle(fontSize: 13, color: _cSub)),
        ]),
      ),
    );
  }
}

Future<String?> _pickDocument(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      dialogTitle: 'Choisir une facture ou document',
    );
    if (result != null && result.files.isNotEmpty) return result.files.single.path;
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _cDanger));
  }
  return null;
}