import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive.dart';
import '../../services/dips_pdf_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const Color kBlue       = Color(0xFF328EEE);
const Color kBlueMid    = Color(0xFF1A70CC);
const Color kBlueFaint  = Color(0xFFF0F7FF);
const Color kBlueBorder = Color(0xFFCDE5FF);
const Color kSurface    = Color(0xFFFFFFFF);
const Color kBg         = Color(0xFFF4F7FB);
const Color kText       = Color(0xFF0F1C2E);
const Color kSubtext    = Color(0xFF6B7E94);
const Color kSuccess    = Color(0xFF22C55E);
const Color kWarning    = Color(0xFFF59E0B);
const Color kDanger     = Color(0xFFEF4444);

// ─── Données fictives ─────────────────────────────────────────────────────────
class _Employe {
  final String id, nom, poste;
  const _Employe({required this.id, required this.nom, required this.poste});
}

class _Equipe {
  final String id, nom, chef;
  final List<_Employe> employes;
  const _Equipe({
    required this.id,
    required this.nom,
    required this.chef,
    required this.employes,
  });
}

const List<_Equipe> kEquipes = [
  _Equipe(id: 'e1', nom: 'Équipe Alpha', chef: 'Mohamed Alami', employes: [
    _Employe(id: 'a1', nom: 'Ahmed Bensalem', poste: 'Technicien'),
    _Employe(id: 'a2', nom: 'Karim Lahlou',   poste: 'Opérateur'),
    _Employe(id: 'a3', nom: 'Youssef Amrani', poste: 'Agent de terrain'),
    _Employe(id: 'a4', nom: 'Reda Karimi',    poste: 'Chauffeur'),
  ]),
  _Equipe(id: 'e2', nom: 'Équipe Beta', chef: 'Fatima Zohra', employes: [
    _Employe(id: 'b1', nom: 'Sara Mansouri',     poste: 'Responsable RH'),
    _Employe(id: 'b2', nom: 'Nadia Benchekroun', poste: 'Comptable'),
    _Employe(id: 'b3', nom: 'Hamid Tazi',        poste: 'Technicien'),
  ]),
  _Equipe(id: 'e3', nom: 'Équipe Gamma', chef: 'Omar Idrissi', employes: [
    _Employe(id: 'c1', nom: 'Zineb El Fassi', poste: 'Ingénieure'),
    _Employe(id: 'c2', nom: 'Amine Benali',   poste: 'Assistant technique'),
    _Employe(id: 'c3', nom: 'Loubna Chraibi', poste: 'Chargée de projet'),
  ]),
];

// ─── Modèle ───────────────────────────────────────────────────────────────────
class _Demande {
  final String type;
  final String equipe;
  final String employeNom;
  final String employePoste;
  final Map<String, String> extras;
  String statut;

  _Demande({
    required this.type,
    required this.equipe,
    required this.employeNom,
    required this.employePoste,
    required this.extras,
    this.statut = 'En attente',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────
class DemandesPage extends StatefulWidget {
  const DemandesPage({super.key});
  @override
  State<DemandesPage> createState() => _DemandesPageState();
}

class _DemandesPageState extends State<DemandesPage> {
  int _tab = 0;
  final List<String> _tabs = [
    'Demande de congé',
    'Attestation de travail',
    'Bulletin de paie',
    'Attestation de salaire',
  ];

  final List<_Demande> _demandes = [
    _Demande(type: 'conge',       equipe: 'Équipe Alpha', employeNom: 'Ahmed Bensalem',   employePoste: 'Technicien',       extras: {'date': '01/06/2025', 'duree': '7 jours'}, statut: 'Approuvé'),
    _Demande(type: 'conge',       equipe: 'Équipe Beta',  employeNom: 'Hamid Tazi',        employePoste: 'Technicien',       extras: {'date': '10/06/2025', 'duree': '3 jours'}, statut: 'En attente'),
    _Demande(type: 'attest_trav', equipe: 'Équipe Beta',  employeNom: 'Sara Mansouri',     employePoste: 'Responsable RH',   extras: {'motif': 'Visa'},                          statut: 'Approuvé'),
    _Demande(type: 'bulletin',    equipe: 'Équipe Alpha', employeNom: 'Youssef Amrani',    employePoste: 'Agent de terrain', extras: {'mois': 'Avril 2025', 'salaire': '8 500 DH'}, statut: 'Approuvé'),
    _Demande(type: 'attest_sal',  equipe: 'Équipe Beta',  employeNom: 'Nadia Benchekroun', employePoste: 'Comptable',        extras: {'salaire': '9 200 DH', 'motif': 'Banque'}, statut: 'Approuvé'),
  ];

  String _typeForTab(int t) => ['conge', 'attest_trav', 'bulletin', 'attest_sal'][t];
  List<_Demande> get _current => _demandes.where((d) => d.type == _typeForTab(_tab)).toList();

  void _addDemande(_Demande d)               => setState(() => _demandes.add(d));
  void _delete(_Demande d)                   => setState(() => _demandes.remove(d));
  void _update(_Demande old, _Demande neo)   { final i = _demandes.indexOf(old); if (i >= 0) setState(() => _demandes[i] = neo); }

  @override
  Widget build(BuildContext context) {
    final mobile  = isMobile(context);
    final padding = pagePadding(context);

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header (fixed height, no overflow) ───────────────────────────
          Container(
            color: kSurface,
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,          // ← FIX: don't expand
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4, height: 26,
                      decoration: BoxDecoration(
                          color: kBlue, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(                           // ← FIX: Expanded in Row
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Demandes',
                            style: TextStyle(
                              fontSize: mobile ? 18 : 22,
                              fontWeight: FontWeight.w700,
                              color: kText,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Gestion des demandes administratives',
                            style: TextStyle(fontSize: 12, color: kSubtext),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Pill tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_tabs.length, (i) {
                      final sel = _tab == i;
                      return GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel ? kBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: sel ? kBlue : const Color(0xFFDDE4ED),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _tabs[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                              color: sel ? Colors.white : kSubtext,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE8EFF7)),

          // ── Corps scrollable ───────────────────────────────────────────
          Expanded(
            child: _TabBody(
              key: ValueKey(_tab),
              tab: _tab,
              demandes: _current,
              onAdd: _addDemande,
              onUpdate: _update,
              onDelete: _delete,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CORPS ONGLET
// ─────────────────────────────────────────────────────────────────────────────
class _TabBody extends StatefulWidget {
  final int tab;
  final List<_Demande> demandes;
  final void Function(_Demande) onAdd;
  final void Function(_Demande, _Demande) onUpdate;
  final void Function(_Demande) onDelete;

  const _TabBody({
    super.key,
    required this.tab,
    required this.demandes,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  bool _showForm = false;
  _Demande? _editing;

  void _openNew()          => setState(() { _showForm = true;  _editing = null; });
  void _openEdit(_Demande d) => setState(() { _showForm = true;  _editing = d; });
  void _closeForm()        => setState(() { _showForm = false; _editing = null; });

  void _onSaved(_Demande d) {
    if (_editing != null) widget.onUpdate(_editing!, d);
    else widget.onAdd(d);
    _closeForm();
    _showToast(context, '✓  Demande enregistrée avec succès');
  }

  Future<void> _confirmDelete(BuildContext ctx, _Demande d) async {
    final ok = await _showConfirmDialog(ctx,
      title: 'Supprimer la demande',
      message: 'Cette action est irréversible. Confirmer la suppression ?',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (ok == true) {
      widget.onDelete(d);
      if (mounted) _showToast(context, '🗑  Demande supprimée');
    }
  }

  bool get _canEdit => widget.tab == 0 || widget.tab == 2;
  String get _type  => ['conge', 'attest_trav', 'bulletin', 'attest_sal'][widget.tab];

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,              // ← FIX
        children: [
          if (!_showForm) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _PillBtn(label: '+ Nouvelle demande', onTap: _openNew),
            ),
            const SizedBox(height: 18),
          ],

          // Formulaire animé
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.03), end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: _showForm
                ? _DemandeForm(
              key: ValueKey(_editing?.hashCode ?? 'new'),
              type: _type,
              editing: _editing,
              onSaved: _onSaved,
              onCancel: _closeForm,
            )
                : const SizedBox.shrink(),
          ),

          if (_showForm) const SizedBox(height: 20),

          _DCard(
            title: 'Demandes enregistrées (${widget.demandes.length})',
            child: widget.demandes.isEmpty
                ? const _Empty()
                : Column(
              mainAxisSize: MainAxisSize.min,   // ← FIX
              children: widget.demandes
                  .map((d) => _DemandeRow(
                demande: d,
                canEdit: _canEdit,
                onEdit: () => _openEdit(d),
                onDelete: () => _confirmDelete(context, d),
              ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FORMULAIRE
// ─────────────────────────────────────────────────────────────────────────────
class _DemandeForm extends StatefulWidget {
  final String type;
  final _Demande? editing;
  final void Function(_Demande) onSaved;
  final VoidCallback onCancel;

  const _DemandeForm({
    super.key,
    required this.type,
    required this.editing,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<_DemandeForm> createState() => _DemandeFormState();
}

class _DemandeFormState extends State<_DemandeForm>
    with SingleTickerProviderStateMixin {
  final _fk           = GlobalKey<FormState>();
  _Equipe?  _equipe;
  _Employe? _employe;

  final _dureeCtrl   = TextEditingController();
  final _moisCtrl    = TextEditingController();
  final _salaireCtrl = TextEditingController();
  final _motifCtrl   = TextEditingController();
  DateTime? _dateDebut;

  late final AnimationController _animCtrl;
  late final Animation<double>   _scaleAnim;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _animCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    final e = widget.editing;
    if (e != null) {
      _equipe  = kEquipes.firstWhere((q) => q.nom == e.equipe, orElse: () => kEquipes.first);
      _employe = _equipe!.employes.firstWhere(
              (emp) => emp.nom == e.employeNom, orElse: () => _equipe!.employes.first);
      _dureeCtrl.text   = e.extras['duree']?.replaceAll(' jours', '') ?? '';
      _moisCtrl.text    = e.extras['mois'] ?? '';
      _salaireCtrl.text = e.extras['salaire']?.replaceAll(' DH', '').replaceAll(' ', '') ?? '';
      _motifCtrl.text   = e.extras['motif'] ?? '';
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _dureeCtrl.dispose(); _moisCtrl.dispose();
    _salaireCtrl.dispose(); _motifCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _buildExtras() {
    switch (widget.type) {
      case 'conge':
        return {
          'date': _dateDebut != null
              ? '${_dateDebut!.day.toString().padLeft(2, '0')}/'
              '${_dateDebut!.month.toString().padLeft(2, '0')}/'
              '${_dateDebut!.year}'
              : '--',
          'duree': '${_dureeCtrl.text} jours',
        };
      case 'attest_trav':
        return {'motif': _motifCtrl.text};
      case 'bulletin':
        return {'mois': _moisCtrl.text, 'salaire': '${_salaireCtrl.text} DH'};
      case 'attest_sal':
        return {'salaire': '${_salaireCtrl.text} DH', 'motif': _motifCtrl.text};
      default:
        return {};
    }
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    if (_equipe == null || _employe == null) {
      _showToast(context, '⚠  Veuillez sélectionner une équipe et un employé');
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final d = _Demande(
      type: widget.type,
      equipe: _equipe!.nom,
      employeNom: _employe!.nom,
      employePoste: _employe!.poste,
      extras: _buildExtras(),
    );
    widget.onSaved(d);
  }

  String get _title => {
    'conge':      widget.editing != null ? 'Modifier la demande de congé' : 'Nouvelle demande de congé',
    'attest_trav': "Nouvelle demande d'attestation de travail",
    'bulletin':   widget.editing != null ? 'Modifier le bulletin de paie'  : 'Nouveau bulletin de paie',
    'attest_sal': "Nouvelle demande d'attestation de salaire",
  }[widget.type]!;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlueBorder, width: 1.5),
          boxShadow: [
            BoxShadow(color: kBlue.withOpacity(0.07), blurRadius: 28, offset: const Offset(0, 8)),
          ],
        ),
        child: Form(
          key: _fk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,           // ← FIX
            children: [
              // Bandeau
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kBlue.withOpacity(0.07), kBlueFaint],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kBlue, kBlueMid],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                    ),
                    IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close_rounded, color: kSubtext, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,     // ← FIX
                  children: [
                    // Section équipe
                    const _SectionLabel(label: 'IDENTIFICATION'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _DropField<_Equipe>(
                            label: 'Équipe',
                            icon: Icons.groups_2_outlined,
                            value: _equipe,
                            items: kEquipes,
                            display: (q) => q.nom,
                            subtitle: (q) => 'Chef : ${q.chef}',
                            onChanged: (q) => setState(() { _equipe = q; _employe = null; }),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DropField<_Employe>(
                            label: 'Employé',
                            icon: Icons.person_outline,
                            value: _employe,
                            items: _equipe?.employes ?? [],
                            display: (e) => e.nom,
                            subtitle: (e) => e.poste,
                            onChanged: (e) => setState(() => _employe = e),
                            enabled: _equipe != null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const _SectionLabel(label: 'DÉTAILS'),
                    const SizedBox(height: 12),

                    ..._buildSpecificFields(),

                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _GhostBtn(label: 'Annuler', onTap: widget.onCancel),
                        const SizedBox(width: 10),
                        _SubmitBtn(
                          label: widget.editing != null ? 'Modifier' : 'Enregistrer',
                          loading: _submitting,
                          onTap: _submit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpecificFields() {
    switch (widget.type) {
      case 'conge':
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DateField(label: 'Date de début', value: _dateDebut,
                  onPicked: (d) => setState(() => _dateDebut = d))),
              const SizedBox(width: 14),
              Expanded(child: _TField(ctrl: _dureeCtrl, label: 'Durée (jours)',
                  icon: Icons.hourglass_bottom_outlined,
                  type: TextInputType.number, req: true)),
            ],
          ),
        ];
      case 'attest_trav':
        return [
          _TField(ctrl: _motifCtrl, label: 'Motif de la demande',
              icon: Icons.info_outline, req: true),
        ];
      case 'bulletin':
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TField(ctrl: _moisCtrl, label: 'Mois concerné (ex : Mai 2025)',
                  icon: Icons.calendar_month_outlined, req: true)),
              const SizedBox(width: 14),
              Expanded(child: _TField(ctrl: _salaireCtrl, label: 'Salaire brut (DH)',
                  icon: Icons.payments_outlined,
                  type: TextInputType.number, req: true)),
            ],
          ),
        ];
      case 'attest_sal':
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TField(ctrl: _salaireCtrl, label: 'Salaire (DH)',
                  icon: Icons.payments_outlined,
                  type: TextInputType.number, req: true)),
              const SizedBox(width: 14),
              Expanded(child: _TField(ctrl: _motifCtrl, label: 'Motif',
                  icon: Icons.info_outline, req: true)),
            ],
          ),
        ];
      default:
        return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIGNE DEMANDE
// ─────────────────────────────────────────────────────────────────────────────
class _DemandeRow extends StatefulWidget {
  final _Demande demande;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DemandeRow({
    required this.demande,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DemandeRow> createState() => _DemandeRowState();
}

class _DemandeRowState extends State<_DemandeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _approved =>
      widget.demande.statut == 'Approuvé' ||
          widget.demande.statut == 'Généré'   ||
          widget.demande.statut == 'Disponible';

  String _subtitle() {
    final d = widget.demande;
    return [d.equipe, d.employePoste, ...d.extras.values].join(' · ');
  }

  Future<void> _telechargerPdf(BuildContext context, _Demande d) async {
    _showToast(context, '📄  Génération du PDF...');
    try {
      // ── Chargement du logo ICI dans le widget (contexte Flutter actif) ────
      Uint8List? logoBytes;
      try {
        final data = await rootBundle.load('assets/images/logo.png');
        logoBytes = data.buffer.asUint8List();
      } catch (_) {
        logoBytes = null; // continue sans logo si absent
      }

      final now2 = DateTime.now();
      final dd   = now2.day.toString().padLeft(2, '0');
      final mm   = now2.month.toString().padLeft(2, '0');
      final dateDoc = '$dd/$mm/${now2.year}';

      switch (d.type) {
        case 'conge':
          final bytes = await DipsPdfService.genererDemandeConge(
            logoBytes:           logoBytes,
            nomEmploye:          d.employeNom,
            telephone:           d.extras['telephone'] ?? '',
            nbJours:             int.tryParse(
                (d.extras['duree'] ?? '0')
                    .replaceAll(' jours', '')) ?? 0,
            dateDebut:           d.extras['date'] ?? '',
            dateFin:             d.extras['dateFin'] ?? d.extras['date'] ?? '',
            nbMoisTravail:       int.tryParse(d.extras['nbMois'] ?? '0') ?? 0,
            periodeDebutTravail: d.extras['periodeDebut'] ?? '',
            periodeFinTravail:   d.extras['periodeFin'] ?? '',
            dateDocument:        dateDoc,
          );
          await DipsPdfService.imprimer(bytes, 'Conge_${d.employeNom}');
          break;

        case 'attest_trav':
          final bytes = await DipsPdfService.genererAttestationTravail(
            logoBytes:    logoBytes,
            nomEmploye:   d.employeNom,
            poste:        d.employePoste,
            dateEmbauche: d.extras['dateEmbauche'] ?? '',
            dateDocument: dateDoc,
            motif:        d.extras['motif'] ?? '',
          );
          await DipsPdfService.imprimer(bytes, 'AttestTravail_${d.employeNom}');
          break;

        case 'bulletin':
          final salaire = double.tryParse(
              (d.extras['salaire'] ?? '0')
                  .replaceAll(' DH', '').replaceAll(' ', '')) ?? 0;
          final bytes = await DipsPdfService.genererBulletinPaie(
            logoBytes:    logoBytes,
            nomEmploye:   d.employeNom,
            poste:        d.employePoste,
            mois:         d.extras['mois'] ?? '',
            salaireBrut:  salaire,
            cnss:         salaire * 0.0448,
            amo:          salaire * 0.0226,
            ir:           salaire * 0.10,
            dateDocument: dateDoc,
          );
          await DipsPdfService.imprimer(
              bytes, 'Bulletin_${d.employeNom}_${d.extras["mois"] ?? ""}');
          break;

        case 'attest_sal':
          final salaire = double.tryParse(
              (d.extras['salaire'] ?? '0')
                  .replaceAll(' DH', '').replaceAll(' ', '')) ?? 0;
          final bytes = await DipsPdfService.genererAttestationSalaire(
            logoBytes:      logoBytes,
            nomEmploye:     d.employeNom,
            poste:          d.employePoste,
            salaireMensuel: salaire,
            motif:          d.extras['motif'] ?? '',
            dateDocument:   dateDoc,
          );
          await DipsPdfService.imprimer(bytes, 'AttestSalaire_${d.employeNom}');
          break;
      }

      if (mounted) _showToast(context, '✅  PDF généré avec succès');
    } catch (e) {
      if (mounted) _showToast(context, '❌  Erreur lors de la génération du PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.demande;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero)
            .animate(_fade),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EFF7)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02),
                  blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(d.employeNom),
              const SizedBox(width: 12),
              // Info — wrapped in Expanded to prevent overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,   // ← FIX
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.employeNom,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: kText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TeamChip(label: d.equipe),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(),
                      style: const TextStyle(fontSize: 11.5, color: kSubtext),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badge + actions — shrink-wrapped
              _Badge(label: d.statut, approved: _approved),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,     // ← FIX
                children: [
                  if (_approved)
                    _IBtn(
                      icon: Icons.download_rounded,
                      color: kBlue,
                      tooltip: 'Télécharger PDF',
                      onTap: () => _telechargerPdf(context, widget.demande),
                    ),
                  if (widget.canEdit)
                    _IBtn(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFF64748B),
                      tooltip: 'Modifier',
                      onTap: widget.onEdit,
                    ),
                  _IBtn(
                    icon: Icons.delete_outline_rounded,
                    color: kDanger,
                    tooltip: 'Supprimer',
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOAST
// ─────────────────────────────────────────────────────────────────────────────
void _showToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  final entry   = OverlayEntry(builder: (_) => _ToastWidget(message: msg));
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2800), entry.remove);
}

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 32, left: 0, right: 0,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 36 * (1 - _anim.value)),
          child: Opacity(opacity: _anim.value.clamp(0.0, 1.0), child: child),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1C2E),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.16),
                    blurRadius: 20, offset: const Offset(0, 5)),
              ],
            ),
            child: Text(widget.message,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG
// ─────────────────────────────────────────────────────────────────────────────
Future<bool?> _showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      bool danger = false,
    }) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12),
                  blurRadius: 36, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,           // ← FIX
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: danger ? kDanger.withOpacity(0.10) : kBlue.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                  color: danger ? kDanger : kBlue, size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: const TextStyle(fontSize: 13, color: kSubtext, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSubtext,
                      side: const BorderSide(color: Color(0xFFDDE6F0)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: danger ? kDanger : kBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGETS ATOMIQUES
// ─────────────────────────────────────────────────────────────────────────────

class _DCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF5)),
        boxShadow: [
          BoxShadow(color: kBlue.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,               // ← FIX
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: kSubtext, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 8),
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 20),
              color: const Color(0xFFF0F4F8)),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 3, height: 13,
          decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: kSubtext, letterSpacing: 0.8)),
    ],
  );
}

class _DropField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) display;
  final String Function(T) subtitle;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const _DropField({
    required this.label, required this.icon, required this.value,
    required this.items, required this.display, required this.subtitle,
    required this.onChanged, this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: enabled ? onChanged : null,
      isExpanded: true,                               // ← FIX: prevents item overflow
      itemHeight: 56,                                 // ← FIX: fixed height per item
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontSize: 12.5,
            color: enabled ? kSubtext : kSubtext.withOpacity(0.5)),
        prefixIcon: Icon(icon, size: 17,
            color: enabled ? kBlue : kSubtext.withOpacity(0.4)),
        filled: true,
        fillColor: enabled ? kBg : kBg.withOpacity(0.6),
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE6F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFDDE6F0).withOpacity(0.5)),
        ),
      ),
      icon: const Icon(Icons.expand_more_rounded, color: kSubtext, size: 20),
      dropdownColor: kSurface,
      borderRadius: BorderRadius.circular(12),
      selectedItemBuilder: (ctx) => items
          .map((item) => Align(
        alignment: Alignment.centerLeft,
        child: Text(display(item),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: kText),
            overflow: TextOverflow.ellipsis),
      ))
          .toList(),
      items: items
          .map((item) => DropdownMenuItem<T>(
        value: item,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,     // ← FIX
          children: [
            Text(display(item),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: kText),
                overflow: TextOverflow.ellipsis),
            Text(subtitle(item),
                style: const TextStyle(fontSize: 11, color: kSubtext),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ))
          .toList(),
    );
  }
}

class _TField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool req;
  final TextInputType? type;

  const _TField({
    required this.ctrl, required this.label, required this.icon,
    this.req = false, this.type,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 13, color: kText),
      validator: req ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, color: kSubtext),
        prefixIcon: Icon(icon, size: 17, color: kBlue),
        filled: true, fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE6F0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDanger, width: 1.8),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  const _DateField({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: kBlue)),
            child: child!,
          ),
        );
        if (p != null) onPicked(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE6F0), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, color: kBlue, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value != null
                  ? '${value!.day.toString().padLeft(2, '0')}/'
                  '${value!.month.toString().padLeft(2, '0')}/'
                  '${value!.year}'
                  : label,
              style: TextStyle(fontSize: 13,
                  color: value != null ? kText : kSubtext),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);

  static const _palettes = [
    [Color(0xFF328EEE), Color(0xFF1A70CC)],
    [Color(0xFF22C55E), Color(0xFF15803D)],
    [Color(0xFFF59E0B), Color(0xFFB45309)],
    [Color(0xFFEC4899), Color(0xFFBE185D)],
    [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isNotEmpty ? name.codeUnitAt(0) % _palettes.length : 0;
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: List<Color>.from(_palettes[idx]),
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String label;
  const _TeamChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: kBlueFaint,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: kBlueBorder),
    ),
    child: Text(label,
        style: const TextStyle(
            fontSize: 10, color: kBlueMid, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final bool approved;
  const _Badge({required this.label, required this.approved});

  @override
  Widget build(BuildContext context) {
    final color = approved ? kSuccess : kWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IBtn({required this.icon, required this.color,
    required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30, height: 30,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    ),
  );
}

class _PillBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: kBlue, foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _GhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: kSubtext,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDDE6F0)),
      ),
    ),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _SubmitBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _SubmitBtn({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: kBlue, foregroundColor: Colors.white,
      disabledBackgroundColor: kBlue.withOpacity(0.6),
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: loading
        ? const SizedBox(width: 17, height: 17,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,               // ← FIX
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: kBlueFaint, borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inbox_outlined, color: kBlue, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('Aucune demande enregistrée',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: kText, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Cliquez sur « + Nouvelle demande » pour commencer',
              style: TextStyle(color: kSubtext, fontSize: 12)),
        ],
      ),
    ),
  );
}