import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/responsive.dart';

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

// ─── Modèles ──────────────────────────────────────────────────────────────────
class Vehicule {
  String matricule, marque, modele;
  double kilometrage;
  DateTime? expirationCarteGrise, expirationAssurance, expirationVisite,
      expirationAutorisationTransport, dateTaxe, expirationBadge;
  List<Vidange> vidanges;
  List<PleinGasoil> pleins;
  List<Reparation> reparations;

  Vehicule({
    required this.matricule, required this.marque, required this.modele,
    required this.kilometrage,
    this.expirationCarteGrise, this.expirationAssurance, this.expirationVisite,
    this.expirationAutorisationTransport, this.dateTaxe, this.expirationBadge,
    List<Vidange>? vidanges, List<PleinGasoil>? pleins, List<Reparation>? reparations,
  }) : vidanges = vidanges ?? [], pleins = pleins ?? [], reparations = reparations ?? [];
}

class Vidange {
  DateTime date;
  double kilometrage, prochaineVidange, montant;
  bool filtreHuile, filtreAir, filtreGasoil;
  String? documentPath;

  Vidange({
    required this.date, required this.kilometrage,
    required this.filtreHuile, required this.filtreAir, required this.filtreGasoil,
    required this.prochaineVidange, required this.montant,
    this.documentPath,
  });
}

class PleinGasoil {
  DateTime date;
  double kilometrage, litres, prixParLitre;
  String? documentPath;

  double get montant => litres * prixParLitre;

  PleinGasoil({
    required this.date, required this.kilometrage,
    required this.litres, required this.prixParLitre,
    this.documentPath,
  });
}

class Reparation {
  DateTime date;
  String description;
  List<String> piecesChangees;
  double montant;
  String? documentPath;

  Reparation({
    required this.date,
    this.description = '',
    required this.piecesChangees,
    required this.montant,
    this.documentPath,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE PRINCIPALE
// ═════════════════════════════════════════════════════════════════════════════
class LogistiquePage extends StatefulWidget {
  const LogistiquePage({super.key});
  @override State<LogistiquePage> createState() => _LogistiquePageState();
}

class _LogistiquePageState extends State<LogistiquePage> {
  final List<Vehicule> _vehicules = [
    Vehicule(
      matricule: '12345-A-1', marque: 'Mercedes', modele: 'Sprinter',
      kilometrage: 145200,
      expirationAssurance: DateTime(2025, 6, 30),
      expirationVisite: DateTime(2026, 9, 15),
      expirationCarteGrise: DateTime(2026, 12, 31),
      expirationBadge: DateTime(2026, 3, 15),
      vidanges: [
        Vidange(date: DateTime(2026, 2, 10), kilometrage: 145200,
            filtreHuile: true, filtreAir: true, filtreGasoil: false,
            prochaineVidange: 155200, montant: 850),
        Vidange(date: DateTime(2025, 9, 5), kilometrage: 135000,
            filtreHuile: true, filtreAir: false, filtreGasoil: true,
            prochaineVidange: 145000, montant: 720),
        Vidange(date: DateTime(2025, 3, 20), kilometrage: 124500,
            filtreHuile: true, filtreAir: true, filtreGasoil: true,
            prochaineVidange: 134500, montant: 980),
      ],
      pleins: [
        PleinGasoil(date: DateTime(2026, 3, 1),  kilometrage: 145200, litres: 65, prixParLitre: 11.50),
        PleinGasoil(date: DateTime(2026, 2, 15), kilometrage: 144500, litres: 60, prixParLitre: 11.40),
        PleinGasoil(date: DateTime(2026, 1, 28), kilometrage: 143700, litres: 58, prixParLitre: 11.30),
        PleinGasoil(date: DateTime(2026, 1, 10), kilometrage: 142900, litres: 62, prixParLitre: 11.25),
      ],
      reparations: [
        Reparation(date: DateTime(2026, 1, 15), description: 'Remplacement plaquettes de frein avant',
            piecesChangees: ['Plaquettes avant', 'Disques avant'], montant: 1200),
        Reparation(date: DateTime(2025, 11, 3), description: 'Révision complète',
            piecesChangees: ['Courroie distribution', 'Pompe à eau', 'Thermostat'], montant: 3500),
        Reparation(date: DateTime(2025, 7, 18), description: 'Réparation climatisation',
            piecesChangees: ['Compresseur', 'Filtre habitacle'], montant: 1800),
      ],
    ),
    Vehicule(
      matricule: '67890-B-2', marque: 'Renault', modele: 'Master',
      kilometrage: 89300,
      expirationAssurance: DateTime(2026, 1, 10),
      expirationCarteGrise: DateTime(2026, 8, 20),
      expirationVisite: DateTime(2026, 5, 30),
      vidanges: [
        Vidange(date: DateTime(2026, 1, 20), kilometrage: 89300,
            filtreHuile: true, filtreAir: false, filtreGasoil: false,
            prochaineVidange: 99300, montant: 650),
        Vidange(date: DateTime(2025, 6, 10), kilometrage: 79800,
            filtreHuile: true, filtreAir: true, filtreGasoil: false,
            prochaineVidange: 89800, montant: 700),
      ],
      pleins: [
        PleinGasoil(date: DateTime(2026, 2, 25), kilometrage: 89300, litres: 55, prixParLitre: 11.50),
        PleinGasoil(date: DateTime(2026, 2, 8),  kilometrage: 88600, litres: 50, prixParLitre: 11.40),
        PleinGasoil(date: DateTime(2026, 1, 22), kilometrage: 87900, litres: 52, prixParLitre: 11.35),
      ],
      reparations: [
        Reparation(date: DateTime(2025, 12, 5), description: 'Changement pneus',
            piecesChangees: ['4 pneus Michelin 215/65R16'], montant: 2400),
        Reparation(date: DateTime(2025, 8, 14), description: '',
            piecesChangees: ['Batterie 70Ah', 'Alternateur'], montant: 950),
      ],
    ),
  ];
  bool _showForm = false;

  void _openDetail(Vehicule v) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DetailPage(
        vehicule: v,
        onUpdate: (u) => setState(() {
          final i = _vehicules.indexWhere((x) => x.matricule == v.matricule);
          if (i >= 0) _vehicules[i] = u;
        }),
        onDelete: () { setState(() => _vehicules.remove(v)); Navigator.pop(context); },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    final mobile = isMobile(context);
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_car_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text('${_vehicules.length} véh.',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ),

        // ── Corps ────────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: EdgeInsets.all(p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  onSaved: (v) { setState(() { _vehicules.add(v); _showForm = false; }); _toast('✓  Véhicule ajouté'); },
                  onCancel: () => setState(() => _showForm = false),
                ),
                const SizedBox(height: 20),
              ],

              if (_vehicules.isEmpty)
                _EmptyState(icon: Icons.local_shipping_outlined,
                    title: 'Aucun véhicule', sub: 'Commencez par ajouter un véhicule')
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _vehicules.map((v) => _VehiculeCard(
                    vehicule: v,
                    onTap: () => _openDetail(v),
                    onEdit: () => _openDetail(v),
                    onDelete: () async {
                      final ok = await _confirmDlg(context,
                          title: 'Supprimer le véhicule',
                          msg: 'Cette action est irréversible.', danger: true);
                      if (ok == true) setState(() => _vehicules.remove(v));
                    },
                  )).toList(),
                ),
            ],
          ),
        )),
      ]),
    );
  }

  void _toast(String m) => _showToast(context, m);
}

// ═════════════════════════════════════════════════════════════════════════════
//  CARTE VÉHICULE — responsive
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
    if (minDays < 0) return _cDanger;
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(mobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Icône + indicateur
                  Stack(children: [
                    Container(
                      width: mobile ? 46 : 54, height: mobile ? 46 : 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_cBlue, _cBlueSoft],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: Colors.white, size: mobile ? 22 : 26),
                    ),
                    Positioned(right: 0, top: 0,
                      child: Container(
                        width: 13, height: 13,
                        decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  // Infos
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Flexible(child: Text(v.matricule,
                            style: TextStyle(fontWeight: FontWeight.w800,
                                fontSize: mobile ? 13.5 : 15, color: _cText),
                            overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        _Tag(label: v.marque, color: _cBlueFaint, textColor: _cBlue),
                      ]),
                      const SizedBox(height: 3),
                      Text(v.modele, style: TextStyle(
                          fontSize: mobile ? 12 : 13, color: _cSub, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 5),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.speed_rounded, size: 12, color: _cSub),
                          const SizedBox(width: 3),
                          Text('${_fmtKm(v.kilometrage)} km',
                              style: const TextStyle(fontSize: 11, color: _cSub)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.oil_barrel_outlined, size: 12, color: _cSub),
                          const SizedBox(width: 3),
                          Text('${v.vidanges.length} vidange${v.vidanges.length != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 11, color: _cSub)),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_gas_station_outlined, size: 12, color: _cSub),
                          const SizedBox(width: 3),
                          Text('${v.pleins.length} plein${v.pleins.length != 1 ? 's' : ''}',
                              style: const TextStyle(fontSize: 11, color: _cSub)),
                        ]),
                      ]),
                    ],
                  )),
                ]),
                // Boutons actions en bas sur mobile
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue,
                      tooltip: 'Détails', onTap: onTap),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.edit_outlined, color: _cOrange,
                      tooltip: 'Modifier', onTap: onEdit),
                  const SizedBox(width: 6),
                  _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger,
                      tooltip: 'Supprimer', onTap: onDelete),
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
//  FORMULAIRE VÉHICULE — responsive
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
      matricule: _matricule.text.trim(), marque: _marque.text.trim(),
      modele: _modele.text.trim(),
      kilometrage: double.tryParse(_km.text.replaceAll(' ', '')) ?? 0,
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
      child: Form(
        key: _fk,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SecLabel(label: 'IDENTIFICATION'),
            const SizedBox(height: 12),
            // Sur mobile : 1 colonne, sur desktop : 3 colonnes
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
            const SizedBox(height: 20),
            const _SecLabel(label: 'DOCUMENTS & EXPIRATIONS'),
            const SizedBox(height: 12),
            if (mobile) ...[
              _LDateField(label: 'Carte grise (exp.)', value: _exCG, onPicked: (d) => setState(() => _exCG = d)),
              const SizedBox(height: 10),
              _LDateField(label: 'Assurance (exp.)', value: _exAss, onPicked: (d) => setState(() => _exAss = d)),
              const SizedBox(height: 10),
              _LDateField(label: 'Visite technique (exp.)', value: _exVis, onPicked: (d) => setState(() => _exVis = d)),
              const SizedBox(height: 10),
              _LDateField(label: 'Autorisation transport (exp.)', value: _exAT, onPicked: (d) => setState(() => _exAT = d)),
              const SizedBox(height: 10),
              _LDateField(label: 'Date taxe', value: _dateTaxe, onPicked: (d) => setState(() => _dateTaxe = d)),
              const SizedBox(height: 10),
              _LDateField(label: 'Badge (exp.)', value: _exBadge, onPicked: (d) => setState(() => _exBadge = d)),
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
              _PrimaryBtn(
                label: widget.editing != null ? 'Modifier' : 'Enregistrer',
                icon: widget.editing != null ? Icons.check_rounded : Icons.save_rounded,
                onTap: _save,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PAGE DÉTAILS — responsive
// ═════════════════════════════════════════════════════════════════════════════
class _DetailPage extends StatefulWidget {
  final Vehicule vehicule;
  final void Function(Vehicule) onUpdate;
  final VoidCallback onDelete;
  const _DetailPage({required this.vehicule, required this.onUpdate, required this.onDelete});
  @override State<_DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<_DetailPage> with TickerProviderStateMixin {
  late Vehicule _v;
  late final TabController _tc;
  final _tabLabels = ["Fiche", "Vidanges", "Gasoil", "Réparations"];
  final _tabIcons  = [Icons.info_outline_rounded, Icons.oil_barrel_outlined,
    Icons.local_gas_station_outlined, Icons.build_outlined];

  @override
  void initState() {
    super.initState();
    _v = widget.vehicule;
    _tc = TabController(length: 4, vsync: this);
  }

  @override void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _cBg,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
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
                    Text(_v.matricule, style: TextStyle(color: Colors.white,
                        fontSize: mobile ? 17 : 20, fontWeight: FontWeight.w800)),
                    Text('${_v.marque} · ${_v.modele}  ·  ${_fmtKm(_v.kilometrage)} km',
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                )),
              ]),
              const SizedBox(height: 14),
              // TabBar scrollable
              TabBar(
                controller: _tc,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                ),
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
            _FicheTab(vehicule: _v,
                onUpdate: (v) { setState(() => _v = v); widget.onUpdate(v); },
                onDelete: widget.onDelete),
            _VidangeTab(vehicule: _v,
                onUpdate: (v) { setState(() => _v = v); widget.onUpdate(v); }),
            _GasoilTab(vehicule: _v,
                onUpdate: (v) { setState(() => _v = v); widget.onUpdate(v); }),
            _AutresTab(vehicule: _v,
                onUpdate: (v) { setState(() => _v = v); widget.onUpdate(v); }),
          ],
        )),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 1 — FICHE
// ═════════════════════════════════════════════════════════════════════════════
class _FicheTab extends StatefulWidget {
  final Vehicule vehicule;
  final void Function(Vehicule) onUpdate;
  final VoidCallback onDelete;
  const _FicheTab({required this.vehicule, required this.onUpdate, required this.onDelete});
  @override State<_FicheTab> createState() => _FicheTabState();
}

class _FicheTabState extends State<_FicheTab> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    if (_editing) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(p),
        child: _VehiculeForm(
          editing: widget.vehicule,
          onSaved: (v) { widget.onUpdate(v); setState(() => _editing = false); _showToast(context, '✓  Modifié'); },
          onCancel: () => setState(() => _editing = false),
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _OutlineBtn(icon: Icons.edit_rounded, label: 'Modifier', color: _cOrange,
              onTap: () => setState(() => _editing = true)),
          const SizedBox(width: 8),
          _OutlineBtn(icon: Icons.delete_rounded, label: 'Supprimer', color: _cDanger,
              onTap: () async {
                final ok = await _confirmDlg(context,
                    title: 'Supprimer', msg: 'Cette action est irréversible.', danger: true);
                if (ok == true) widget.onDelete();
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
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 2 — VIDANGES
// ═════════════════════════════════════════════════════════════════════════════
class _VidangeTab extends StatefulWidget {
  final Vehicule vehicule;
  final void Function(Vehicule) onUpdate;
  const _VidangeTab({required this.vehicule, required this.onUpdate});
  @override State<_VidangeTab> createState() => _VidangeTabState();
}

class _VidangeTabState extends State<_VidangeTab> {
  bool _showForm = false;
  Vidange? _editing;
  int? _editingIndex;

  void _openForm({Vidange? v, int? index}) =>
      setState(() { _editing = v; _editingIndex = index; _showForm = true; });

  void _save(Vidange v) {
    setState(() {
      if (_editingIndex != null) widget.vehicule.vidanges[_editingIndex!] = v;
      else widget.vehicule.vidanges.insert(0, v);
      _showForm = false; _editing = null; _editingIndex = null;
    });
    widget.onUpdate(widget.vehicule);
    _showToast(context, _editingIndex != null ? '✓  Vidange modifiée' : '✓  Vidange enregistrée');
  }

  void _delete(int index) {
    setState(() => widget.vehicule.vidanges.removeAt(index));
    widget.onUpdate(widget.vehicule);
    _showToast(context, '✓  Vidange supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showForm)
            Align(alignment: Alignment.centerRight,
                child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter vidange', onTap: () => _openForm())),
          if (_showForm) ...[
            _VidangeForm(editing: _editing, onSaved: _save,
                onCancel: () => setState(() { _showForm = false; _editing = null; _editingIndex = null; })),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 14),
          _SectionHeader(icon: Icons.oil_barrel_outlined, title: 'Historique vidanges', count: widget.vehicule.vidanges.length),
          const SizedBox(height: 10),
          widget.vehicule.vidanges.isEmpty
              ? _EmptyState(icon: Icons.oil_barrel_outlined, title: 'Aucune vidange', sub: 'Ajoutez la première vidange')
              : Column(mainAxisSize: MainAxisSize.min,
              children: widget.vehicule.vidanges.asMap().entries.map((e) =>
                  _VidangeCard(
                    vidange: e.value,
                    onEdit: () => _openForm(v: e.value, index: e.key),
                    onDelete: () async {
                      final ok = await _confirmDlg(context, title: 'Supprimer cette vidange', msg: 'Cette action est irréversible.', danger: true);
                      if (ok == true) _delete(e.key);
                    },
                    onDetail: () => _showVidangeDetail(context, e.value),
                  ),
              ).toList()),
        ],
      ),
    );
  }

  void _showVidangeDetail(BuildContext ctx, Vidange v) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _VidangeDetailSheet(vidange: v));
  }
}

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
      header: _FormHeader(
        icon: Icons.oil_barrel_outlined,
        title: widget.editing != null ? 'Modifier la vidange' : 'Nouvelle vidange',
        onClose: widget.onCancel,
      ),
      child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mobile) ...[
          _LDateField(label: 'Date de vidange', value: _date, onPicked: (d) => setState(() => _date = d)),
          const SizedBox(height: 10),
          _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
        ] else
          _Row2(
            _LDateField(label: 'Date de vidange', value: _date, onPicked: (d) => setState(() => _date = d)),
            _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
          ),
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
          _Row2(
            _Field(ctrl: _proch, label: 'Prochaine vidange (km)', icon: Icons.update_rounded, type: TextInputType.number, req: true),
            _Field(ctrl: _mont, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true),
          ),
        const SizedBox(height: 14),
        _DocPicker(
          path: _docPath,
          onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
          onRemove: () => setState(() => _docPath = null),
        ),
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
    final filtres = [
      if (vidange.filtreHuile)  'Huile',
      if (vidange.filtreAir)    'Air',
      if (vidange.filtreGasoil) 'Gasoil',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.oil_barrel_outlined, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_fmtDate(vidange.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _cText)),
                _Tag(label: '${_fmtKm(vidange.kilometrage)} km', color: _cBlueFaint, textColor: _cBlue),
              ]),
              if (filtres.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 5, runSpacing: 4, children: filtres.map((f) => _Tag(label: f, color: _cSuccessBg, textColor: _cSuccess)).toList()),
              ],
              const SizedBox(height: 4),
              Text('Prochaine : ${_fmtKm(vidange.prochaineVidange)} km  ·  ${vidange.montant.toStringAsFixed(2)} MAD',
                  style: const TextStyle(fontSize: 11.5, color: _cSub)),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue,    tooltip: 'Détails',   onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined,       color: _cOrange,  tooltip: 'Modifier',  onTap: onEdit),
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
    final filtres = [
      if (vidange.filtreHuile)  'Filtre à huile',
      if (vidange.filtreAir)    'Filtre à air',
      if (vidange.filtreGasoil) 'Filtre à gasoil',
    ];
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
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_cBlue, _cBlueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.oil_barrel_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails vidange', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(vidange.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.speed_rounded,     label: 'Kilométrage',      value: '${_fmtKm(vidange.kilometrage)} km'),
            _SheetRow(icon: Icons.update_rounded,    label: 'Prochaine vidange', value: '${_fmtKm(vidange.prochaineVidange)} km'),
            _SheetRow(icon: Icons.payments_outlined, label: 'Montant total',    value: '${vidange.montant.toStringAsFixed(2)} MAD'),
            const SizedBox(height: 12),
            if (filtres.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.check_circle_outline_rounded, color: _cSub, size: 15),
                const SizedBox(width: 8),
                const Text('Filtres remplacés', style: TextStyle(fontSize: 12, color: _cSub)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: filtres.map((f) => _Tag(label: f, color: _cSuccessBg, textColor: _cSuccess)).toList()),
            ] else
              const _Tag(label: 'Aucun filtre remplacé', color: _cBg, textColor: _cSub),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 3 — GASOIL
// ═════════════════════════════════════════════════════════════════════════════
class _GasoilTab extends StatefulWidget {
  final Vehicule vehicule;
  final void Function(Vehicule) onUpdate;
  const _GasoilTab({required this.vehicule, required this.onUpdate});
  @override State<_GasoilTab> createState() => _GasoilTabState();
}

class _GasoilTabState extends State<_GasoilTab> {
  bool _showForm = false;
  PleinGasoil? _editing;
  int? _editingIndex;

  void _openForm({PleinGasoil? v, int? index}) =>
      setState(() { _editing = v; _editingIndex = index; _showForm = true; });

  void _save(PleinGasoil p) {
    setState(() {
      if (_editingIndex != null) widget.vehicule.pleins[_editingIndex!] = p;
      else widget.vehicule.pleins.insert(0, p);
      _showForm = false; _editing = null; _editingIndex = null;
    });
    widget.onUpdate(widget.vehicule);
    _showToast(context, _editingIndex != null ? '✓  Plein modifié' : '✓  Plein enregistré');
  }

  void _delete(int index) {
    setState(() => widget.vehicule.pleins.removeAt(index));
    widget.onUpdate(widget.vehicule);
    _showToast(context, '✓  Plein supprimé');
  }

  List<Map<String, dynamic>> _withConso() {
    final pl = widget.vehicule.pleins;
    return pl.asMap().entries.map((e) {
      double? c100, cMAD;
      if (e.key > 0) {
        final newer = pl[e.key - 1];
        final dist  = newer.kilometrage - pl[e.key].kilometrage;
        if (dist > 0) {
          c100 = (newer.litres  / dist) * 100;
          cMAD = (newer.montant / dist) * 100;
        }
      }
      return {'plein': e.value, 'index': e.key, 'c100': c100, 'cMAD': cMAD};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    final rows = _withConso();
    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showForm)
            Align(alignment: Alignment.centerRight,
                child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter plein', onTap: () => _openForm())),
          if (_showForm) ...[
            _GasoilForm(editing: _editing, onSaved: _save,
                onCancel: () => setState(() { _showForm = false; _editing = null; _editingIndex = null; })),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 14),
          _SectionHeader(icon: Icons.local_gas_station_outlined, title: 'Historique gasoil', count: widget.vehicule.pleins.length),
          const SizedBox(height: 10),
          widget.vehicule.pleins.isEmpty
              ? _EmptyState(icon: Icons.local_gas_station_outlined, title: 'Aucun plein', sub: 'Ajoutez le premier plein de carburant')
              : Column(mainAxisSize: MainAxisSize.min,
              children: rows.map((r) => _GasoilCard(
                plein: r['plein'] as PleinGasoil,
                conso100km: r['c100'] as double?, consoMAD: r['cMAD'] as double?,
                onEdit: () => _openForm(v: r['plein'], index: r['index']),
                onDelete: () async {
                  final ok = await _confirmDlg(context, title: 'Supprimer ce plein', msg: 'Cette action est irréversible.', danger: true);
                  if (ok == true) _delete(r['index'] as int);
                },
                onDetail: () => _showGasoilDetail(context, r['plein'], r['c100'] as double?, r['cMAD'] as double?),
              )).toList()),
        ],
      ),
    );
  }

  void _showGasoilDetail(BuildContext ctx, PleinGasoil p, double? c100, double? cMAD) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _GasoilDetailSheet(plein: p, conso100km: c100, consoMAD: cMAD));
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
      date: _date!,
      kilometrage: double.tryParse(_km.text) ?? 0,
      litres: double.tryParse(_litres.text.replaceAll(',', '.')) ?? 0,
      prixParLitre: double.tryParse(_prix.text.replaceAll(',', '.')) ?? 0,
      documentPath: _docPath,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return _GlassCard(
      header: _FormHeader(
        icon: Icons.local_gas_station_outlined,
        title: widget.editing != null ? 'Modifier le plein' : 'Nouveau plein gasoil',
        onClose: widget.onCancel,
      ),
      child: Form(key: _fk, child: StatefulBuilder(builder: (ctx, setInner) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (mobile) ...[
            _LDateField(label: 'Date du plein', value: _date,
                onPicked: (d) { setState(() => _date = d); setInner(() {}); }),
            const SizedBox(height: 10),
            _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
          ] else
            _Row2(
              _LDateField(label: 'Date du plein', value: _date,
                  onPicked: (d) { setState(() => _date = d); setInner(() {}); }),
              _Field(ctrl: _km, label: 'Kilométrage (km)', icon: Icons.speed_outlined, type: TextInputType.number, req: true),
            ),
          const SizedBox(height: 12),
          // Litres + Prix + Montant auto
          if (mobile) ...[
            _Field(ctrl: _litres, label: 'Litres', icon: Icons.water_drop_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {})),
            const SizedBox(height: 10),
            _Field(ctrl: _prix, label: 'Prix / litre (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true, onChanged: (_) => setInner(() {})),
            const SizedBox(height: 10),
            // Montant auto compact
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cBlue.withOpacity(0.08), _cBlueFaint], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBlueBorder),
              ),
              child: Row(children: [
                const Icon(Icons.calculate_outlined, color: _cBlue, size: 16),
                const SizedBox(width: 8),
                const Text('Montant auto', style: TextStyle(fontSize: 12, color: _cBlue)),
                const Spacer(),
                Text('${_montant.toStringAsFixed(2)} MAD',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _cBlue)),
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_cBlue.withOpacity(0.08), _cBlueFaint], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: _cBlueBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.calculate_outlined, color: _cBlue, size: 14),
                    const SizedBox(width: 5),
                    const Text('Montant auto', style: TextStyle(fontSize: 10.5, color: _cBlue)),
                  ]),
                  const SizedBox(height: 5),
                  Text('${_montant.toStringAsFixed(2)} MAD',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _cBlue)),
                ]),
              )),
            ]),
          const SizedBox(height: 12),
          _DocPicker(
            path: _docPath,
            onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
            onRemove: () => setState(() => _docPath = null),
          ),
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
  final double? conso100km, consoMAD;
  final VoidCallback onEdit, onDelete, onDetail;
  const _GasoilCard({required this.plein, this.conso100km, this.consoMAD,
    required this.onEdit, required this.onDelete, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_fmtDate(plein.date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _cText)),
                _Tag(label: '${_fmtKm(plein.kilometrage)} km', color: _cWarningBg, textColor: _cWarning),
              ]),
              const SizedBox(height: 4),
              Text('${plein.litres.toStringAsFixed(1)} L  ·  ${plein.prixParLitre.toStringAsFixed(2)} MAD/L  ·  ${plein.montant.toStringAsFixed(2)} MAD',
                  style: const TextStyle(fontSize: 11.5, color: _cSub)),
              if (conso100km != null) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _Tag(label: '${conso100km!.toStringAsFixed(1)} L/100km', color: _cBlueFaint, textColor: _cBlue),
                  _Tag(label: '${consoMAD!.toStringAsFixed(1)} MAD/100km', color: _cWarningBg, textColor: _cWarning),
                ]),
              ],
            ])),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue,    tooltip: 'Détails',   onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined,       color: _cOrange,  tooltip: 'Modifier',  onTap: onEdit),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.delete_outline_rounded, color: _cDanger, tooltip: 'Supprimer', onTap: onDelete),
          ]),
        ]),
      ),
    );
  }
}

class _GasoilDetailSheet extends StatelessWidget {
  final PleinGasoil plein;
  final double? conso100km, consoMAD;
  const _GasoilDetailSheet({required this.plein, this.conso100km, this.consoMAD});

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
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFFBBF24)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails plein gasoil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(plein.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.speed_rounded,       label: 'Kilométrage',   value: '${_fmtKm(plein.kilometrage)} km'),
            _SheetRow(icon: Icons.water_drop_outlined, label: 'Litres',        value: '${plein.litres.toStringAsFixed(1)} L'),
            _SheetRow(icon: Icons.sell_outlined,       label: 'Prix / litre',  value: '${plein.prixParLitre.toStringAsFixed(2)} MAD'),
            _SheetRow(icon: Icons.payments_outlined,   label: 'Montant total', value: '${plein.montant.toStringAsFixed(2)} MAD', highlight: true),
            if (conso100km != null) ...[
              const Divider(height: 20, color: _cBorder),
              Row(children: [
                Expanded(child: _ConsoBox(label: 'Consommation', value: '${conso100km!.toStringAsFixed(1)}', unit: 'L / 100 km', color: _cBlueFaint, textColor: _cBlue)),
                const SizedBox(width: 10),
                Expanded(child: _ConsoBox(label: 'Coût carburant', value: '${consoMAD!.toStringAsFixed(1)}', unit: 'MAD / 100 km', color: _cWarningBg, textColor: _cWarning)),
              ]),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: _cSub, size: 14),
                  SizedBox(width: 8),
                  Flexible(child: Text('Consommation disponible à partir du 2ème plein', style: TextStyle(fontSize: 12, color: _cSub))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ONGLET 4 — RÉPARATIONS
// ═════════════════════════════════════════════════════════════════════════════
class _AutresTab extends StatefulWidget {
  final Vehicule vehicule;
  final void Function(Vehicule) onUpdate;
  const _AutresTab({required this.vehicule, required this.onUpdate});
  @override State<_AutresTab> createState() => _AutresTabState();
}

class _AutresTabState extends State<_AutresTab> {
  bool _showForm = false;
  Reparation? _editing;
  int? _editingIndex;

  void _openForm({Reparation? r, int? index}) =>
      setState(() { _editing = r; _editingIndex = index; _showForm = true; });

  void _save(Reparation r) {
    setState(() {
      if (_editingIndex != null) widget.vehicule.reparations[_editingIndex!] = r;
      else widget.vehicule.reparations.insert(0, r);
      _showForm = false; _editing = null; _editingIndex = null;
    });
    widget.onUpdate(widget.vehicule);
    _showToast(context, _editingIndex != null ? '✓  Réparation modifiée' : '✓  Réparation enregistrée');
  }

  void _delete(int index) {
    setState(() => widget.vehicule.reparations.removeAt(index));
    widget.onUpdate(widget.vehicule);
    _showToast(context, '✓  Réparation supprimée');
  }

  @override
  Widget build(BuildContext context) {
    final p = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(p),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showForm)
            Align(alignment: Alignment.centerRight,
                child: _PrimaryBtn(icon: Icons.add_rounded, label: 'Ajouter réparation', onTap: () => _openForm())),
          if (_showForm) ...[
            _ReparationForm(editing: _editing, onSaved: _save,
                onCancel: () => setState(() { _showForm = false; _editing = null; _editingIndex = null; })),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 14),
          _SectionHeader(icon: Icons.build_rounded, title: 'Historique réparations', count: widget.vehicule.reparations.length),
          const SizedBox(height: 10),
          widget.vehicule.reparations.isEmpty
              ? _EmptyState(icon: Icons.build_outlined, title: 'Aucune réparation', sub: 'Ajoutez la première réparation')
              : Column(mainAxisSize: MainAxisSize.min,
              children: widget.vehicule.reparations.asMap().entries.map((e) =>
                  _ReparationCard(
                    reparation: e.value,
                    onEdit: () => _openForm(r: e.value, index: e.key),
                    onDelete: () async {
                      final ok = await _confirmDlg(context, title: 'Supprimer cette réparation', msg: 'Cette action est irréversible.', danger: true);
                      if (ok == true) _delete(e.key);
                    },
                    onDetail: () => _showReparationDetail(context, e.value),
                  ),
              ).toList()),
        ],
      ),
    );
  }

  void _showReparationDetail(BuildContext ctx, Reparation r) {
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => _ReparationDetailSheet(reparation: r));
  }
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
      header: _FormHeader(
        icon: Icons.build_rounded,
        title: widget.editing != null ? 'Modifier la réparation' : 'Nouvelle réparation',
        onClose: widget.onCancel,
      ),
      child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mobile) ...[
          _LDateField(label: 'Date de réparation', value: _date, onPicked: (d) => setState(() => _date = d)),
          const SizedBox(height: 10),
          _Field(ctrl: _montant, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true),
        ] else
          _Row2(
            _LDateField(label: 'Date de réparation', value: _date, onPicked: (d) => setState(() => _date = d)),
            _Field(ctrl: _montant, label: 'Montant total (MAD)', icon: Icons.payments_outlined, type: TextInputType.number, req: true),
          ),
        const SizedBox(height: 12),
        _Field(ctrl: _desc, label: 'Description (optionnelle)', icon: Icons.description_outlined, req: false),
        const SizedBox(height: 14),
        // Pièces
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
              Material(
                color: _cOrange, borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _addPiece, borderRadius: BorderRadius.circular(10),
                  child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: Colors.white, size: 20)),
                ),
              ),
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
                    GestureDetector(
                      onTap: () => setState(() => _pieces.removeAt(e.key)),
                      child: const Icon(Icons.close_rounded, size: 13, color: _cOrange),
                    ),
                  ]),
                )).toList(),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        _DocPicker(
          path: _docPath,
          onPick: () async { final p = await _pickDocument(context); if (p != null) setState(() => _docPath = p); },
          onRemove: () => setState(() => _docPath = null),
        ),
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
      decoration: BoxDecoration(
        color: _cCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorder),
        boxShadow: [BoxShadow(color: _cOrange.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.build_rounded, color: Colors.white, size: 19),
            ),
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
                    ..addAll(reparation.piecesChangees.length > 3
                        ? [_Tag(label: '+${reparation.piecesChangees.length - 3}', color: _cBg, textColor: _cSub)]
                        : []),
                ),
              ],
            ])),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _ActionBtn(icon: Icons.visibility_outlined, color: _cBlue,    tooltip: 'Détails',   onTap: onDetail),
            const SizedBox(width: 6),
            _ActionBtn(icon: Icons.edit_outlined,       color: _cOrange,  tooltip: 'Modifier',  onTap: onEdit),
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
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.build_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Détails réparation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _cText)),
                Text(_fmtDate(reparation.date), style: const TextStyle(fontSize: 12.5, color: _cSub)),
              ]),
            ]),
            const SizedBox(height: 18),
            _SheetRow(icon: Icons.calendar_today_outlined, label: 'Date',          value: _fmtDate(reparation.date)),
            _SheetRow(icon: Icons.payments_outlined,       label: 'Montant total', value: '${reparation.montant.toStringAsFixed(2)} MAD', highlight: true),
            if (reparation.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cBorder)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Row(children: [
                    Icon(Icons.description_outlined, color: _cSub, size: 13),
                    SizedBox(width: 6),
                    Text('Description', style: TextStyle(fontSize: 11, color: _cSub, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(reparation.description, style: const TextStyle(fontSize: 13, color: _cText, height: 1.5)),
                ]),
              ),
            ],
            if (reparation.piecesChangees.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cOrangeBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _cOrange.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Row(children: [
                    Icon(Icons.build_circle_outlined, color: _cOrange, size: 13),
                    SizedBox(width: 6),
                    Text('Pièces changées', style: TextStyle(fontSize: 11, color: _cOrange, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: reparation.piecesChangees.map((p) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: _cSurface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _cOrange.withOpacity(0.3))),
                      child: Text(p, style: const TextStyle(fontSize: 12, color: _cOrange, fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  WIDGET DOCUMENT (facture)
// ═════════════════════════════════════════════════════════════════════════════
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
        decoration: BoxDecoration(
          color: _cSuccessBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cSuccess.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined, color: _cSuccess, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Document importé', style: TextStyle(fontSize: 11, color: _cSuccess, fontWeight: FontWeight.w700)),
            Text(_name, style: const TextStyle(fontSize: 12, color: _cText), overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _cSuccess.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
              child: const Text('Changer', style: TextStyle(fontSize: 11, color: _cSuccess, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: _cDanger, size: 16),
          ),
        ]),
      );
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: _cBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cBorder, width: 1.5),
        ),
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
    if (result != null && result.files.isNotEmpty) {
      return result.files.single.path;
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: _cDanger),
      );
    }
  }
  return null;
}

// ═════════════════════════════════════════════════════════════════════════════
//  WIDGETS COMMUNS
// ═════════════════════════════════════════════════════════════════════════════
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
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_cBlue, _cBlueMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
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
    decoration: BoxDecoration(
      color: _cCard, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _cBorder),
      boxShadow: [BoxShadow(color: _cBlue.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
    ),
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
      if (diff < 0)   { valueColor = _cDanger;  bgColor = _cDangerBg;  badge = 'Expiré'; }
      else if (diff < 30) { valueColor = _cWarning; bgColor = _cWarningBg; badge = '$diff j restants'; }
      else            { valueColor = _cSuccess;  bgColor = _cSuccessBg; badge = 'Valide'; }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F4F8)))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _cSub))),
        Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: valueColor))),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: valueColor)),
          ),
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
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_cBlue, _cBlueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _cText)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _cBlueFaint, borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _cBlue)),
    ),
  ]);
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
  const _Field({required this.ctrl, required this.label, required this.icon,
    this.req = false, this.type, this.onChanged});

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
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _cBlue)),
          child: child!,
        ),
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
            style: TextStyle(fontSize: 13, color: value != null ? _cText : _cSub),
            overflow: TextOverflow.ellipsis)),
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
      decoration: BoxDecoration(
        color: val ? _cBlue : _cBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: val ? _cBlue : _cBorder, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(val ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: val ? Colors.white : _cSub, size: 15),
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
    style: ElevatedButton.styleFrom(
      backgroundColor: _cBlue, foregroundColor: Colors.white, elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _LGhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LGhostBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: _cSub,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _cBorder)),
    ),
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
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: color.withOpacity(0.4)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
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
    child: Material(
      color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 34, height: 34, child: Icon(icon, color: color, size: 17)),
      ),
    ),
  );
}

class _Row2 extends StatelessWidget {
  final Widget a, b;
  const _Row2(this.a, this.b);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
  );
}

class _Row3 extends StatelessWidget {
  final Widget a, b, c;
  const _Row3(this.a, this.b, this.c);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a), const SizedBox(width: 12),
      Expanded(child: b), const SizedBox(width: 12),
      Expanded(child: c),
    ],
  );
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

// ═════════════════════════════════════════════════════════════════════════════
//  TOAST & DIALOG
// ═════════════════════════════════════════════════════════════════════════════
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

// ═════════════════════════════════════════════════════════════════════════════
//  UTILITAIRES
// ═════════════════════════════════════════════════════════════════════════════
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