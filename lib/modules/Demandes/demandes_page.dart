import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:dips_managment/core/utils/responsive.dart';

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
const Color kPurple     = Color(0xFF8B5CF6);

// ─── Rôles ────────────────────────────────────────────────────────────────────
enum UserRole { demandeur, administrateur }

// ─── Données fictives ─────────────────────────────────────────────────────────
class _Employe {
  final String id, nom, poste, email, telephone;
  const _Employe({
    required this.id, required this.nom, required this.poste,
    required this.email, required this.telephone,
  });
}

class _Equipe {
  final String id, nom, chef;
  final List<_Employe> employes;
  const _Equipe({required this.id, required this.nom, required this.chef, required this.employes});
}

const List<_Equipe> kEquipes = [
  _Equipe(id: 'e1', nom: 'Équipe Alpha', chef: 'Mohamed Alami', employes: [
    _Employe(id: 'a1', nom: 'Ahmed Bensalem',   poste: 'Technicien',       email: 'ahmed@dips.ma',   telephone: '0661234567'),
    _Employe(id: 'a2', nom: 'Karim Lahlou',     poste: 'Opérateur',        email: 'karim@dips.ma',   telephone: '0662345678'),
    _Employe(id: 'a3', nom: 'Youssef Amrani',   poste: 'Agent de terrain', email: 'youssef@dips.ma', telephone: '0663456789'),
    _Employe(id: 'a4', nom: 'Reda Karimi',      poste: 'Chauffeur',        email: 'reda@dips.ma',    telephone: '0664567890'),
  ]),
  _Equipe(id: 'e2', nom: 'Équipe Beta', chef: 'Fatima Zohra', employes: [
    _Employe(id: 'b1', nom: 'Sara Mansouri',     poste: 'Responsable RH',  email: 'sara@dips.ma',    telephone: '0665678901'),
    _Employe(id: 'b2', nom: 'Nadia Benchekroun', poste: 'Comptable',       email: 'nadia@dips.ma',   telephone: '0666789012'),
    _Employe(id: 'b3', nom: 'Hamid Tazi',        poste: 'Technicien',      email: 'hamid@dips.ma',   telephone: '0667890123'),
  ]),
  _Equipe(id: 'e3', nom: 'Équipe Gamma', chef: 'Omar Idrissi', employes: [
    _Employe(id: 'c1', nom: 'Zineb El Fassi',  poste: 'Ingénieure',        email: 'zineb@dips.ma',   telephone: '0668901234'),
    _Employe(id: 'c2', nom: 'Amine Benali',    poste: 'Assistant technique',email: 'amine@dips.ma',  telephone: '0669012345'),
    _Employe(id: 'c3', nom: 'Loubna Chraibi',  poste: 'Chargée de projet', email: 'loubna@dips.ma',  telephone: '0660123456'),
  ]),
];

// ─── Statuts ──────────────────────────────────────────────────────────────────
enum DemandeStatut { enAttente, approuve, refuse, pdfDisponible }

extension DemandeStatutExt on DemandeStatut {
  String get label {
    switch (this) {
      case DemandeStatut.enAttente:     return 'En attente';
      case DemandeStatut.approuve:      return 'Approuvé';
      case DemandeStatut.refuse:        return 'Refusé';
      case DemandeStatut.pdfDisponible: return 'PDF disponible';
    }
  }

  Color get color {
    switch (this) {
      case DemandeStatut.enAttente:     return kWarning;
      case DemandeStatut.approuve:      return kSuccess;
      case DemandeStatut.refuse:        return kDanger;
      case DemandeStatut.pdfDisponible: return kBlue;
    }
  }

  IconData get icon {
    switch (this) {
      case DemandeStatut.enAttente:     return Icons.hourglass_empty_rounded;
      case DemandeStatut.approuve:      return Icons.check_circle_outline_rounded;
      case DemandeStatut.refuse:        return Icons.cancel_outlined;
      case DemandeStatut.pdfDisponible: return Icons.picture_as_pdf_rounded;
    }
  }
}

// ─── Modèle Demande ───────────────────────────────────────────────────────────
class Demande {
  final String id;
  final String type;
  final String equipe;
  final String employeNom;
  final String employePoste;
  final String employeEmail;
  final String employeTelephone;
  final Map<String, String> extras;
  DemandeStatut statut;
  String? commentaireAdmin;
  Uint8List? pdfBytes;
  final DateTime createdAt;

  Demande({
    required this.id,
    required this.type,
    required this.equipe,
    required this.employeNom,
    required this.employePoste,
    required this.employeEmail,
    required this.employeTelephone,
    required this.extras,
    this.statut = DemandeStatut.enAttente,
    this.commentaireAdmin,
    this.pdfBytes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────
class DemandesPage extends StatefulWidget {
  final UserRole role;
  const DemandesPage({super.key, required this.role});

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

  final List<String> _tabsMobile = ['Congé', 'Att. travail', 'Bulletin', 'Att. salaire'];
  final List<IconData> _tabIcons = [
    Icons.beach_access_rounded,
    Icons.assignment_outlined,
    Icons.receipt_long_outlined,
    Icons.account_balance_wallet_outlined,
  ];

  // Base de données partagée (simulée)
  final List<Demande> _demandes = [
    Demande(
      id: 'd1', type: 'conge', equipe: 'Équipe Alpha',
      employeNom: 'Ahmed Bensalem', employePoste: 'Technicien',
      employeEmail: 'ahmed@dips.ma', employeTelephone: '0661234567',
      extras: {'date': '01/06/2025', 'duree': '7 jours'},
      statut: DemandeStatut.pdfDisponible,
    ),
    Demande(
      id: 'd2', type: 'conge', equipe: 'Équipe Beta',
      employeNom: 'Hamid Tazi', employePoste: 'Technicien',
      employeEmail: 'hamid@dips.ma', employeTelephone: '0667890123',
      extras: {'date': '10/06/2025', 'duree': '3 jours'},
      statut: DemandeStatut.enAttente,
    ),
    Demande(
      id: 'd3', type: 'attest_trav', equipe: 'Équipe Beta',
      employeNom: 'Sara Mansouri', employePoste: 'Responsable RH',
      employeEmail: 'sara@dips.ma', employeTelephone: '0665678901',
      extras: {'motif': 'Visa'},
      statut: DemandeStatut.approuve,
    ),
    Demande(
      id: 'd4', type: 'bulletin', equipe: 'Équipe Alpha',
      employeNom: 'Youssef Amrani', employePoste: 'Agent de terrain',
      employeEmail: 'youssef@dips.ma', employeTelephone: '0663456789',
      extras: {'mois': 'Avril 2025', 'salaire': '8500'},
      statut: DemandeStatut.pdfDisponible,
    ),
    Demande(
      id: 'd5', type: 'attest_sal', equipe: 'Équipe Beta',
      employeNom: 'Nadia Benchekroun', employePoste: 'Comptable',
      employeEmail: 'nadia@dips.ma', employeTelephone: '0666789012',
      extras: {'salaire': '9200', 'motif': 'Banque'},
      statut: DemandeStatut.refuse,
      commentaireAdmin: 'Documents incomplets, veuillez compléter votre dossier.',
    ),
  ];

  String _typeForTab(int t) => ['conge', 'attest_trav', 'bulletin', 'attest_sal'][t];

  List<Demande> get _current =>
      _demandes.where((d) => d.type == _typeForTab(_tab)).toList();

  void _addDemande(Demande d)    => setState(() => _demandes.add(d));
  void _deleteDemande(Demande d) => setState(() => _demandes.remove(d));

  void _updateStatut(Demande d, DemandeStatut s, {String? comment, Uint8List? pdf}) {
    setState(() {
      d.statut = s;
      if (comment != null) d.commentaireAdmin = comment;
      if (pdf != null) d.pdfBytes = pdf;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile  = isMobile(context);
    final padding = pagePadding(context);
    final topPad  = MediaQuery.of(context).padding.top;

    return Container(
      color: kBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            color: kSurface,
            padding: EdgeInsets.fromLTRB(
                padding, topPad + (mobile ? 14 : padding), padding, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4, height: 28,
                      decoration: BoxDecoration(
                          color: widget.role == UserRole.administrateur ? kPurple : kBlue,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Demandes',
                              style: TextStyle(
                                  fontSize: mobile ? 17 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: kText,
                                  letterSpacing: -0.4)),
                          Text(
                            widget.role == UserRole.administrateur
                                ? 'Administration — traitement des demandes'
                                : 'Portail collaborateur — suivi de vos demandes',
                            style: TextStyle(
                                fontSize: mobile ? 11 : 12, color: kSubtext),
                          ),
                        ],
                      ),
                    ),
                    // Badge rôle
                    _RoleBadge(role: widget.role),
                  ],
                ),
                const SizedBox(height: 16),
                // Pill tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_tabs.length, (i) {
                      final sel = _tab == i;
                      final label = mobile ? _tabsMobile[i] : _tabs[i];
                      final color = widget.role == UserRole.administrateur
                          ? kPurple
                          : kBlue;
                      // Count pending for admin
                      final pendingCount = widget.role == UserRole.administrateur
                          ? _demandes
                          .where((d) =>
                      d.type == _typeForTab(i) &&
                          d.statut == DemandeStatut.enAttente)
                          .length
                          : 0;
                      return GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 12 : 16,
                              vertical: mobile ? 7 : 9),
                          decoration: BoxDecoration(
                            color: sel ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: sel ? color : const Color(0xFFDDE4ED),
                                width: 1.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_tabIcons[i],
                                size: 13,
                                color: sel ? Colors.white : kSubtext),
                            const SizedBox(width: 6),
                            Text(label,
                                style: TextStyle(
                                    fontSize: mobile ? 11.5 : 13,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color:
                                    sel ? Colors.white : kSubtext)),
                            if (pendingCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? Colors.white.withOpacity(0.3)
                                      : kWarning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text('$pendingCount',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sel ? Colors.white : kWarning)),
                              ),
                            ],
                          ]),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE8EFF7)),

          // ── Corps ────────────────────────────────────────────────────────
          Expanded(
            child: _TabBody(
              key: ValueKey('${_tab}_${widget.role}'),
              tab: _tab,
              role: widget.role,
              demandes: _current,
              onAdd: _addDemande,
              onDelete: _deleteDemande,
              onUpdateStatut: _updateStatut,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BADGE RÔLE
// ─────────────────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.administrateur;
    final color   = isAdmin ? kPurple : kBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_outline_rounded,
          size: 13, color: color,
        ),
        const SizedBox(width: 5),
        Text(
          isAdmin ? 'Administrateur' : 'Collaborateur',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CORPS ONGLET
// ─────────────────────────────────────────────────────────────────────────────
class _TabBody extends StatefulWidget {
  final int tab;
  final UserRole role;
  final List<Demande> demandes;
  final void Function(Demande) onAdd;
  final void Function(Demande) onDelete;
  final void Function(Demande, DemandeStatut, {String? comment, Uint8List? pdf}) onUpdateStatut;

  const _TabBody({
    super.key,
    required this.tab,
    required this.role,
    required this.demandes,
    required this.onAdd,
    required this.onDelete,
    required this.onUpdateStatut,
  });

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  bool _showForm = false;

  void _openNew()   => setState(() => _showForm = true);
  void _closeForm() => setState(() => _showForm = false);

  void _onSaved(Demande d) {
    widget.onAdd(d);
    _closeForm();
    _showToast(context, '✓  Demande soumise avec succès');
  }

  Future<void> _confirmDelete(BuildContext ctx, Demande d) async {
    final ok = await _showConfirmDialog(ctx,
        title: 'Supprimer la demande',
        message: 'Cette action est irréversible. Confirmer ?',
        confirmLabel: 'Supprimer',
        danger: true);
    if (ok == true) {
      widget.onDelete(d);
      if (mounted) _showToast(context, '🗑  Demande supprimée');
    }
  }

  String get _type => ['conge', 'attest_trav', 'bulletin', 'attest_sal'][widget.tab];

  // Statistiques pour l'admin
  Map<String, int> get _stats {
    final list = widget.demandes;
    return {
      'total':    list.length,
      'attente':  list.where((d) => d.statut == DemandeStatut.enAttente).length,
      'approuve': list.where((d) => d.statut == DemandeStatut.approuve ||
          d.statut == DemandeStatut.pdfDisponible).length,
      'refuse':   list.where((d) => d.statut == DemandeStatut.refuse).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final padding = pagePadding(context);
    final isAdmin = widget.role == UserRole.administrateur;
    final stats   = _stats;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stats bar (admin seulement) ──────────────────────────────
          if (isAdmin) ...[
            _StatsBar(stats: stats),
            const SizedBox(height: 16),
          ],

          // ── Bouton nouvelle demande (demandeur seulement) ─────────────
          if (!isAdmin && !_showForm) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _PillBtn(
                label: '+ Nouvelle demande',
                onTap: _openNew,
                color: kBlue,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Formulaire demandeur ─────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, -0.03), end: Offset.zero)
                    .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                child: child,
              ),
            ),
            child: _showForm
                ? _DemandeForm(
              key: const ValueKey('new'),
              type: _type,
              onSaved: _onSaved,
              onCancel: _closeForm,
            )
                : const SizedBox.shrink(),
          ),

          if (_showForm) const SizedBox(height: 20),

          // ── Liste des demandes ────────────────────────────────────────
          _DCard(
            title: isAdmin
                ? 'Demandes à traiter (${widget.demandes.length})'
                : 'Mes demandes (${widget.demandes.length})',
            child: widget.demandes.isEmpty
                ? const _Empty()
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.demandes.map((d) => isAdmin
                  ? _AdminDemandeRow(
                demande: d,
                onUpdateStatut: widget.onUpdateStatut,
                onDelete: () => _confirmDelete(context, d),
              )
                  : _DemandeurRow(
                demande: d,
                onDelete: () => _confirmDelete(context, d),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATS BAR (admin)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final items = [
      {'label': 'Total',    'value': stats['total'],    'color': kBlue,    'icon': Icons.inbox_outlined},
      {'label': 'En attente','value': stats['attente'],  'color': kWarning,  'icon': Icons.hourglass_empty_rounded},
      {'label': 'Approuvé', 'value': stats['approuve'], 'color': kSuccess,  'icon': Icons.check_circle_outline_rounded},
      {'label': 'Refusé',   'value': stats['refuse'],   'color': kDanger,   'icon': Icons.cancel_outlined},
    ];

    if (mobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _StatCard(
          label: items[i]['label'] as String,
          value: items[i]['value'] as int,
          color: items[i]['color'] as Color,
          icon: items[i]['icon'] as IconData,
        ),
      );
    }

    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _StatCard(
            label: item['label'] as String,
            value: item['value'] as int,
            color: item['color'] as Color,
            icon: item['icon'] as IconData,
          ),
        ),
      )).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.15)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: kSubtext)),
        ],
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROW — VUE DEMANDEUR
// ─────────────────────────────────────────────────────────────────────────────
class _DemandeurRow extends StatefulWidget {
  final Demande demande;
  final VoidCallback onDelete;

  const _DemandeurRow({required this.demande, required this.onDelete});

  @override
  State<_DemandeurRow> createState() => _DemandeurRowState();
}

class _DemandeurRowState extends State<_DemandeurRow>
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

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  String _subtitle() {
    final d = widget.demande;
    return [d.equipe, d.employePoste, ...d.extras.values].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.demande;
    final mobile = isMobile(context);

    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(mobile ? 12 : 14),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: d.statut == DemandeStatut.pdfDisponible
                ? kBlueBorder
                : const Color(0xFFE8EFF7),
            width: d.statut == DemandeStatut.pdfDisponible ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
            color: d.statut == DemandeStatut.pdfDisponible
                ? kBlue.withOpacity(0.06)
                : Colors.black.withOpacity(0.02),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(d.employeNom),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.employeNom,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5, color: kText),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(_subtitle(),
                        style: const TextStyle(fontSize: 11, color: kSubtext),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                )),
                const SizedBox(width: 8),
                _StatusBadge(statut: d.statut),
              ],
            ),

            // Commentaire admin si refusé
            if (d.statut == DemandeStatut.refuse && d.commentaireAdmin != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kDanger.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kDanger.withOpacity(0.2)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: kDanger, size: 14),
                  const SizedBox(width: 7),
                  Expanded(child: Text(d.commentaireAdmin!,
                      style: const TextStyle(fontSize: 11.5, color: kDanger, height: 1.4))),
                ]),
              ),
            ],

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(d.createdAt),
                  style: const TextStyle(fontSize: 10.5, color: kSubtext),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  // Télécharger PDF si disponible
                  if (d.statut == DemandeStatut.pdfDisponible)
                    _IBtn(
                      icon: Icons.download_rounded,
                      color: kBlue,
                      tooltip: 'Télécharger votre document',
                      onTap: () => _telechargerPdf(context, d),
                    ),
                  // Supprimer uniquement si en attente
                  if (d.statut == DemandeStatut.enAttente)
                    _IBtn(
                      icon: Icons.delete_outline_rounded,
                      color: kDanger,
                      tooltip: 'Annuler la demande',
                      onTap: widget.onDelete,
                    ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _telechargerPdf(BuildContext context, Demande d) async {
    if (d.pdfBytes != null) {
      await Printing.layoutPdf(
        onLayout: (_) => d.pdfBytes!,
        name: 'document_${d.employeNom}',
      );
    } else {
      _showToast(context, '❌  PDF non disponible');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROW — VUE ADMINISTRATEUR
// ─────────────────────────────────────────────────────────────────────────────
class _AdminDemandeRow extends StatefulWidget {
  final Demande demande;
  final void Function(Demande, DemandeStatut, {String? comment, Uint8List? pdf}) onUpdateStatut;
  final VoidCallback onDelete;

  const _AdminDemandeRow({
    required this.demande,
    required this.onUpdateStatut,
    required this.onDelete,
  });

  @override
  State<_AdminDemandeRow> createState() => _AdminDemandeRowState();
}

class _AdminDemandeRowState extends State<_AdminDemandeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  String _subtitle() {
    final d = widget.demande;
    return [d.equipe, d.employePoste].join(' · ');
  }

  Future<void> _approuverAvecPdf(BuildContext ctx) async {
    _showToast(ctx, '⚙️  Génération du document en cours...');
    try {
      final d = widget.demande;
      Uint8List? logoBytes;
      try {
        final data = await rootBundle.load('assets/images/logo.png');
        logoBytes = data.buffer.asUint8List();
      } catch (_) { logoBytes = null; }

      final now = DateTime.now();
      final dateDoc = _formatDateSimple(now);

      Uint8List pdfBytes;
      switch (d.type) {
        case 'conge':
          final nbJours = int.tryParse(
              (d.extras['duree'] ?? '0').replaceAll(' jours', '')) ?? 0;
          pdfBytes = await PdfGenerator.genererDemandeConge(
            logoBytes: logoBytes,
            nomEmploye: d.employeNom,
            poste: d.employePoste,
            telephone: d.employeTelephone,
            nbJours: nbJours,
            dateDebut: d.extras['date'] ?? '',
            dateFin: d.extras['dateFin'] ?? d.extras['date'] ?? '',
            dateDocument: dateDoc,
          );
          break;

        case 'attest_trav':
          pdfBytes = await PdfGenerator.genererAttestationTravail(
            logoBytes: logoBytes,
            nomEmploye: d.employeNom,
            poste: d.employePoste,
            dateEmbauche: d.extras['dateEmbauche'] ?? '01/01/2020',
            dateDocument: dateDoc,
            motif: d.extras['motif'] ?? '',
          );
          break;

        case 'bulletin':
          final sal = double.tryParse(
              (d.extras['salaire'] ?? '0').replaceAll(' DH', '').replaceAll(' ', '')) ?? 0;
          pdfBytes = await PdfGenerator.genererBulletinPaie(
            logoBytes: logoBytes,
            nomEmploye: d.employeNom,
            poste: d.employePoste,
            mois: d.extras['mois'] ?? '',
            salaireBrut: sal,
            dateDocument: dateDoc,
          );
          break;

        case 'attest_sal':
        default:
          final sal = double.tryParse(
              (d.extras['salaire'] ?? '0').replaceAll(' DH', '').replaceAll(' ', '')) ?? 0;
          pdfBytes = await PdfGenerator.genererAttestationSalaire(
            logoBytes: logoBytes,
            nomEmploye: d.employeNom,
            poste: d.employePoste,
            salaireMensuel: sal,
            motif: d.extras['motif'] ?? '',
            dateDocument: dateDoc,
          );
          break;
      }

      widget.onUpdateStatut(
        widget.demande,
        DemandeStatut.pdfDisponible,
        comment: 'Document généré et disponible au téléchargement.',
        pdf: pdfBytes,
      );
      if (mounted) _showToast(ctx, '✅  Document approuvé et PDF généré');
    } catch (e) {
      if (mounted) _showToast(ctx, '❌  Erreur : ${e.toString().substring(0, 40)}');
    }
  }

  Future<void> _refuser(BuildContext ctx) async {
    final commentaire = await _showRefusalDialog(ctx);
    if (commentaire != null) {
      widget.onUpdateStatut(
        widget.demande,
        DemandeStatut.refuse,
        comment: commentaire.isNotEmpty ? commentaire : 'Demande refusée par l\'administrateur.',
      );
      if (mounted) _showToast(ctx, '✗  Demande refusée');
    }
  }

  Future<void> _previewPdf(BuildContext ctx) async {
    final d = widget.demande;
    if (d.pdfBytes != null) {
      await Printing.layoutPdf(
        onLayout: (_) => d.pdfBytes!,
        name: 'document_${d.employeNom}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.demande;
    final mobile = isMobile(context);
    final isPending = d.statut == DemandeStatut.enAttente;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending
                ? kWarning.withOpacity(0.4)
                : const Color(0xFFE8EFF7),
            width: isPending ? 1.5 : 1,
          ),
          boxShadow: [BoxShadow(
            color: isPending
                ? kWarning.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête cliquable ────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Padding(
                padding: EdgeInsets.all(mobile ? 12 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(d.employeNom),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(d.employeNom,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13.5, color: kText),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(_subtitle(),
                            style: const TextStyle(fontSize: 11, color: kSubtext)),
                      ],
                    )),
                    const SizedBox(width: 8),
                    _StatusBadge(statut: d.statut),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded,
                          size: 20, color: kSubtext),
                    ),
                  ],
                ),
              ),
            ),

            // ── Détails expandables ──────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 1,
                      color: const Color(0xFFF0F4F8),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),

                    // Détails de la demande
                    _DetailsGrid(extras: d.extras, email: d.employeeEmail(d)),

                    const SizedBox(height: 12),

                    // Commentaire admin existant
                    if (d.commentaireAdmin != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: d.statut == DemandeStatut.refuse
                              ? kDanger.withOpacity(0.05)
                              : kSuccess.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: d.statut == DemandeStatut.refuse
                                ? kDanger.withOpacity(0.2)
                                : kSuccess.withOpacity(0.2),
                          ),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.comment_outlined,
                              color: d.statut == DemandeStatut.refuse
                                  ? kDanger
                                  : kSuccess,
                              size: 14),
                          const SizedBox(width: 7),
                          Expanded(child: Text(d.commentaireAdmin!,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: d.statut == DemandeStatut.refuse
                                      ? kDanger
                                      : kSuccess,
                                  height: 1.4))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Boutons d'action admin ────────────────────
                    if (mobile)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildAdminActions(ctx: context, isMobile: true),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _buildAdminActions(ctx: context, isMobile: false),
                      ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAdminActions({required BuildContext ctx, required bool isMobile}) {
    final d = widget.demande;
    final List<Widget> actions = [];

    if (d.statut == DemandeStatut.pdfDisponible && d.pdfBytes != null) {
      final btn = _ActionBtn(
        label: 'Prévisualiser PDF',
        icon: Icons.visibility_outlined,
        color: kBlueMid,
        onTap: () => _previewPdf(ctx),
      );
      actions.add(isMobile ? btn : Padding(padding: const EdgeInsets.only(left: 8), child: btn));
    }

    if (d.statut == DemandeStatut.enAttente || d.statut == DemandeStatut.approuve) {
      final refuserBtn = _ActionBtn(
        label: 'Refuser',
        icon: Icons.close_rounded,
        color: kDanger,
        onTap: () => _refuser(ctx),
        outlined: true,
      );
      final approuverBtn = _ActionBtn(
        label: 'Approuver & générer PDF',
        icon: Icons.check_rounded,
        color: kSuccess,
        onTap: () => _approuverAvecPdf(ctx),
      );
      actions.add(isMobile
          ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        refuserBtn,
        const SizedBox(height: 8),
        approuverBtn,
      ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
        refuserBtn,
        const SizedBox(width: 8),
        approuverBtn,
      ]));
    }

    if (d.statut == DemandeStatut.refuse) {
      final btn = _ActionBtn(
        label: 'Reconsidérer',
        icon: Icons.refresh_rounded,
        color: kWarning,
        onTap: () => widget.onUpdateStatut(d, DemandeStatut.enAttente, comment: null),
      );
      actions.add(isMobile ? btn : Padding(padding: const EdgeInsets.only(left: 8), child: btn));
    }

    final deleteBtn = _IBtn(
      icon: Icons.delete_outline_rounded, color: kDanger,
      tooltip: 'Supprimer', onTap: widget.onDelete,
    );
    actions.add(isMobile
        ? Padding(padding: const EdgeInsets.only(top: 8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [deleteBtn]))
        : Padding(padding: const EdgeInsets.only(left: 8), child: deleteBtn));

    return actions;
  }
}

extension on _AdminDemandeRowState {
  // Workaround to access employeeEmail
}

extension DemandeHelper on Demande {
  String employeeEmail(Demande d) => d.employeEmail;
}

// ─────────────────────────────────────────────────────────────────────────────
//  GRILLE DÉTAILS
// ─────────────────────────────────────────────────────────────────────────────
class _DetailsGrid extends StatelessWidget {
  final Map<String, String> extras;
  final String email;
  const _DetailsGrid({required this.extras, required this.email});

  static const _labels = {
    'date': 'Date de début',
    'duree': 'Durée',
    'mois': 'Mois',
    'salaire': 'Salaire',
    'motif': 'Motif',
    'dateEmbauche': 'Date embauche',
    'dateFin': 'Date de fin',
  };

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final allEntries = <MapEntry<String, String>>[
      MapEntry('email', email),
      ...extras.entries,
    ];

    if (mobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: allEntries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(_labels[e.key] ?? e.key,
                    style: const TextStyle(fontSize: 11, color: kSubtext)),
              ),
              Expanded(child: Text(
                e.key == 'salaire' && !e.value.contains('DH')
                    ? '${e.value} DH'
                    : e.value,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: kText),
              )),
            ],
          ),
        )).toList(),
      );
    }

    // Desktop: grille 2 colonnes
    final rows = <Widget>[];
    for (var i = 0; i < allEntries.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: _DetailItem(
            label: _labels[allEntries[i].key] ?? allEntries[i].key,
            value: allEntries[i].key == 'salaire' && !allEntries[i].value.contains('DH')
                ? '${allEntries[i].value} DH'
                : allEntries[i].value,
          )),
          if (i + 1 < allEntries.length) ...[
            const SizedBox(width: 14),
            Expanded(child: _DetailItem(
              label: _labels[allEntries[i+1].key] ?? allEntries[i+1].key,
              value: allEntries[i+1].key == 'salaire' && !allEntries[i+1].value.contains('DH')
                  ? '${allEntries[i+1].value} DH'
                  : allEntries[i+1].value,
            )),
          ] else const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < allEntries.length) rows.add(const SizedBox(height: 8));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _DetailItem extends StatelessWidget {
  final String label, value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: kBg, borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: kSubtext)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: kText),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG REFUS
// ─────────────────────────────────────────────────────────────────────────────
Future<String?> _showRefusalDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showGeneralDialog<String>(
    context: context, barrierDismissible: true, barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(child: Material(
      color: Colors.transparent,
      child: Container(
        width: 340, margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 36, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: kDanger.withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.cancel_outlined, color: kDanger, size: 22),
          ),
          const SizedBox(height: 12),
          const Text('Refuser la demande',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 6),
          const Text('Vous pouvez ajouter un commentaire visible par le demandeur.',
              style: TextStyle(fontSize: 12.5, color: kSubtext, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: kText),
            decoration: InputDecoration(
              hintText: 'Motif de refus (optionnel)...',
              hintStyle: const TextStyle(color: kSubtext, fontSize: 12.5),
              filled: true, fillColor: kBg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE6F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDDE6F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kDanger, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, null),
              style: OutlinedButton.styleFrom(
                foregroundColor: kSubtext,
                side: const BorderSide(color: Color(0xFFDDE6F0)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: kDanger, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmer le refus',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FORMULAIRE DEMANDEUR
// ─────────────────────────────────────────────────────────────────────────────
class _DemandeForm extends StatefulWidget {
  final String type;
  final void Function(Demande) onSaved;
  final VoidCallback onCancel;

  const _DemandeForm({
    super.key, required this.type,
    required this.onSaved, required this.onCancel,
  });

  @override
  State<_DemandeForm> createState() => _DemandeFormState();
}

class _DemandeFormState extends State<_DemandeForm>
    with SingleTickerProviderStateMixin {
  final _fk = GlobalKey<FormState>();
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
      case 'attest_trav': return {'motif': _motifCtrl.text};
      case 'bulletin':    return {'mois': _moisCtrl.text, 'salaire': _salaireCtrl.text};
      case 'attest_sal':  return {'salaire': _salaireCtrl.text, 'motif': _motifCtrl.text};
      default: return {};
    }
  }

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    if (_equipe == null || _employe == null) {
      _showToast(context, '⚠  Veuillez sélectionner une équipe et un collaborateur');
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final now = DateTime.now();
    widget.onSaved(Demande(
      id: 'req_${now.millisecondsSinceEpoch}',
      type: widget.type,
      equipe: _equipe!.nom,
      employeNom: _employe!.nom,
      employePoste: _employe!.poste,
      employeEmail: _employe!.email,
      employeTelephone: _employe!.telephone,
      extras: _buildExtras(),
      createdAt: now,
    ));
  }

  String get _title => {
    'conge':       'Nouvelle demande de congé',
    'attest_trav': "Demande d'attestation de travail",
    'bulletin':    'Demande de bulletin de paie',
    'attest_sal':  "Demande d'attestation de salaire",
  }[widget.type]!;

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBlueBorder, width: 1.5),
          boxShadow: [BoxShadow(
              color: kBlue.withOpacity(0.07),
              blurRadius: 28, offset: const Offset(0, 8))],
        ),
        child: Form(
          key: _fk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bandeau
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [kBlue.withOpacity(0.07), kBlueFaint],
                      begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [kBlue, kBlueMid],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700, color: kText))),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close_rounded, color: kSubtext, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ]),
              ),

              Padding(
                padding: EdgeInsets.all(mobile ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SectionLabel(label: 'IDENTIFICATION'),
                    const SizedBox(height: 12),

                    if (mobile) ...[
                      _DropField<_Equipe>(
                        label: 'Équipe', icon: Icons.groups_2_outlined,
                        value: _equipe, items: kEquipes,
                        display: (q) => q.nom, subtitle: (q) => 'Chef : ${q.chef}',
                        onChanged: (q) => setState(() { _equipe = q; _employe = null; }),
                      ),
                      const SizedBox(height: 10),
                      _DropField<_Employe>(
                        label: 'Collaborateur', icon: Icons.person_outline,
                        value: _employe, items: _equipe?.employes ?? [],
                        display: (e) => e.nom, subtitle: (e) => e.poste,
                        onChanged: (e) => setState(() => _employe = e),
                        enabled: _equipe != null,
                      ),
                    ] else
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _DropField<_Equipe>(
                          label: 'Équipe', icon: Icons.groups_2_outlined,
                          value: _equipe, items: kEquipes,
                          display: (q) => q.nom, subtitle: (q) => 'Chef : ${q.chef}',
                          onChanged: (q) => setState(() { _equipe = q; _employe = null; }),
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: _DropField<_Employe>(
                          label: 'Collaborateur', icon: Icons.person_outline,
                          value: _employe, items: _equipe?.employes ?? [],
                          display: (e) => e.nom, subtitle: (e) => e.poste,
                          onChanged: (e) => setState(() => _employe = e),
                          enabled: _equipe != null,
                        )),
                      ]),

                    const SizedBox(height: 18),
                    const _SectionLabel(label: 'DÉTAILS'),
                    const SizedBox(height: 12),

                    ..._buildSpecificFields(mobile),

                    // Info box
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kBlueFaint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kBlueBorder),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline_rounded, color: kBlue, size: 15),
                        const SizedBox(width: 8),
                        const Expanded(child: Text(
                          'Votre demande sera traitée par un administrateur. '
                              'Vous recevrez une notification dès qu\'un document sera disponible.',
                          style: TextStyle(fontSize: 11.5, color: kBlueMid, height: 1.5),
                        )),
                      ]),
                    ),

                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _GhostBtn(label: 'Annuler', onTap: widget.onCancel),
                      const SizedBox(width: 10),
                      _SubmitBtn(
                        label: 'Soumettre la demande',
                        loading: _submitting,
                        onTap: _submit,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSpecificFields(bool mobile) {
    switch (widget.type) {
      case 'conge':
        if (mobile) {
          return [
            _DateField(label: 'Date de début', value: _dateDebut,
                onPicked: (d) => setState(() => _dateDebut = d)),
            const SizedBox(height: 10),
            _TField(ctrl: _dureeCtrl, label: 'Durée (jours)',
                icon: Icons.hourglass_bottom_outlined,
                type: TextInputType.number, req: true),
          ];
        }
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _DateField(label: 'Date de début', value: _dateDebut,
                onPicked: (d) => setState(() => _dateDebut = d))),
            const SizedBox(width: 14),
            Expanded(child: _TField(ctrl: _dureeCtrl, label: 'Durée (jours)',
                icon: Icons.hourglass_bottom_outlined,
                type: TextInputType.number, req: true)),
          ]),
        ];

      case 'attest_trav':
        return [
          _TField(ctrl: _motifCtrl, label: 'Motif de la demande',
              icon: Icons.info_outline, req: true),
        ];

      case 'bulletin':
        if (mobile) {
          return [
            _TField(ctrl: _moisCtrl, label: 'Mois concerné (ex : Mai 2025)',
                icon: Icons.calendar_month_outlined, req: true),
            const SizedBox(height: 10),
            _TField(ctrl: _salaireCtrl, label: 'Salaire brut (DH)',
                icon: Icons.payments_outlined, type: TextInputType.number, req: true),
          ];
        }
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _TField(ctrl: _moisCtrl, label: 'Mois concerné (ex : Mai 2025)',
                icon: Icons.calendar_month_outlined, req: true)),
            const SizedBox(width: 14),
            Expanded(child: _TField(ctrl: _salaireCtrl, label: 'Salaire brut (DH)',
                icon: Icons.payments_outlined, type: TextInputType.number, req: true)),
          ]),
        ];

      case 'attest_sal':
        if (mobile) {
          return [
            _TField(ctrl: _salaireCtrl, label: 'Salaire (DH)',
                icon: Icons.payments_outlined, type: TextInputType.number, req: true),
            const SizedBox(height: 10),
            _TField(ctrl: _motifCtrl, label: 'Motif',
                icon: Icons.info_outline, req: true),
          ];
        }
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _TField(ctrl: _salaireCtrl, label: 'Salaire (DH)',
                icon: Icons.payments_outlined, type: TextInputType.number, req: true)),
            const SizedBox(width: 14),
            Expanded(child: _TField(ctrl: _motifCtrl, label: 'Motif',
                icon: Icons.info_outline, req: true)),
          ]),
        ];

      default: return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PDF GENERATOR  (package:pdf)
// ─────────────────────────────────────────────────────────────────────────────
class PdfGenerator {
  // ── En-tête commun ──────────────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required Uint8List? logoBytes,
    required String title,
    required String dateDocument,
    required String reference,
  }) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo ou nom société
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), width: 100, height: 50, fit: pw.BoxFit.contain)
              else
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF328EEE),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text('DIPS',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold)),
                ),
              pw.SizedBox(height: 4),
              pw.Text('Direction Industrielle & Prestations de Services',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Casablanca, Maroc | contact@dips.ma',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          // Infos document
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF1A70CC),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(title.toUpperCase(),
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 9,
                        fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Réf : $reference',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text('Date : $dateDocument',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(color: const PdfColor.fromInt(0xFF328EEE), thickness: 2),
    ]);
  }

  // ── Bloc employé ────────────────────────────────────────────────────────────
  static pw.Widget _employeeBlock(String nom, String poste) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF0F7FF),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFCDE5FF)),
      ),
      child: pw.Row(children: [
        pw.Container(
          width: 40, height: 40,
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF328EEE),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Center(
            child: pw.Text(
              nom.isNotEmpty ? nom[0].toUpperCase() : '?',
              style: pw.TextStyle(
                  color: PdfColors.white, fontSize: 18,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(nom,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0F1C2E))),
            pw.SizedBox(height: 2),
            pw.Text(poste,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ]),
    );
  }

  // ── Pied de page ────────────────────────────────────────────────────────────
  static pw.Widget _footer() {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Document généré par le système DIPS',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          pw.Text('Ce document est officiel et certifié',
              style: pw.TextStyle(
                  fontSize: 7, color: const PdfColor.fromInt(0xFF1A70CC),
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ]);
  }

  // ── Signature block ──────────────────────────────────────────────────────────
  static pw.Widget _signatureBlock() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text('Le collaborateur ou la collaboratrice',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 40),
          pw.Container(width: 120, height: 1, color: PdfColors.grey400),
          pw.Text('Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text("La Direction",
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 40),
          pw.Container(width: 120, height: 1, color: PdfColors.grey400),
          pw.Text('Cachet & Signature',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
      ],
    );
  }

  // ── 1. Autorisation de congé ─────────────────────────────────────────────────
  static Future<Uint8List> genererDemandeConge({
    required Uint8List? logoBytes,
    required String nomEmploye,
    required String poste,
    required String telephone,
    required int nbJours,
    required String dateDebut,
    required String dateFin,
    required String dateDocument,
  }) async {
    final pdf = pw.Document();
    final ref = 'CONGE-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(logoBytes: logoBytes, title: 'Autorisation de congé',
              dateDocument: dateDocument, reference: ref),
          pw.SizedBox(height: 24),

          // Texte intro
          pw.Text('AUTORISATION DE CONGÉ ANNUEL',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F1C2E)),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Container(
            width: 60, height: 3,
            color: const PdfColor.fromInt(0xFF328EEE),
          )),
          pw.SizedBox(height: 20),

          // Bloc employé
          _employeeBlock(nomEmploye, poste),
          pw.SizedBox(height: 20),

          // Corps
          pw.Text(
            'La Direction certifie avoir accordé au collaborateur / à la collaboratrice susmentionné(e) '
                'une autorisation de congé annuel dans les conditions suivantes :',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
          ),
          pw.SizedBox(height: 16),

          // Tableau détails
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              _tableRow('Durée du congé', '$nbJours jour(s)', header: true),
              _tableRow('Date de départ', dateDebut),
              _tableRow('Date de reprise', dateFin.isNotEmpty ? dateFin : 'À définir'),
              if (telephone.isNotEmpty)
                _tableRow('Contact', telephone),
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Text(
            'Le bénéficiaire est tenu de reprendre son poste le lendemain de la date '
                'de fin de congé indiquée ci-dessus, sauf prolongation expressément accordée '
                'par la Direction.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3, color: PdfColors.grey700),
          ),
          pw.Spacer(),
          pw.SizedBox(height: 20),
          _signatureBlock(),
          pw.SizedBox(height: 16),
          _footer(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── 2. Attestation de travail ────────────────────────────────────────────────
  static Future<Uint8List> genererAttestationTravail({
    required Uint8List? logoBytes,
    required String nomEmploye,
    required String poste,
    required String dateEmbauche,
    required String dateDocument,
    required String motif,
  }) async {
    final pdf = pw.Document();
    final ref = 'ATT-TRAV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(logoBytes: logoBytes, title: 'Attestation de travail',
              dateDocument: dateDocument, reference: ref),
          pw.SizedBox(height: 30),

          pw.Text('ATTESTATION DE TRAVAIL',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F1C2E)),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Container(
              width: 60, height: 3,
              color: const PdfColor.fromInt(0xFF328EEE))),
          pw.SizedBox(height: 30),

          pw.Text('Je soussigné(e), représentant(e) légal(e) de la société DIPS, '
              'certifie par la présente que :',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 4)),
          pw.SizedBox(height: 20),

          _employeeBlock(nomEmploye, poste),
          pw.SizedBox(height: 20),

          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 5),
              children: [
                const pw.TextSpan(text: 'exerce bien la fonction de collaborateur / collaboratrice au sein de notre société en tant que '),
                pw.TextSpan(
                    text: poste,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (dateEmbauche.isNotEmpty) ...[
                  const pw.TextSpan(text: ', et ce depuis le '),
                  pw.TextSpan(
                      text: dateEmbauche,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
                const pw.TextSpan(text: '.'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          if (motif.isNotEmpty) ...[
            pw.Text(
              'La présente attestation est délivrée à l\'intéressé(e) pour servir et valoir '
                  'ce que de droit, notamment pour : $motif.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 16),
          ],

          pw.Text(
            'Cette attestation est délivrée à la demande de l\'intéressé(e) '
                'et ne saurait engager la responsabilité de la société quant à son utilisation.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, lineSpacing: 3),
          ),

          pw.Spacer(),
          _signatureBlock(),
          pw.SizedBox(height: 16),
          _footer(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── 3. Bulletin de paie ──────────────────────────────────────────────────────
  static Future<Uint8List> genererBulletinPaie({
    required Uint8List? logoBytes,
    required String nomEmploye,
    required String poste,
    required String mois,
    required double salaireBrut,
    required String dateDocument,
  }) async {
    final pdf = pw.Document();
    final ref = 'BUL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    final cnss    = salaireBrut * 0.0448;
    final amo     = salaireBrut * 0.0226;
    final irBase  = salaireBrut - cnss - amo;
    final ir      = irBase * 0.10;
    final netAPayer = salaireBrut - cnss - amo - ir;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(logoBytes: logoBytes, title: 'Bulletin de paie',
              dateDocument: dateDocument, reference: ref),
          pw.SizedBox(height: 16),

          // Infos employé + période
          pw.Row(
            children: [
              pw.Expanded(child: _employeeBlock(nomEmploye, poste)),
              pw.SizedBox(width: 16),
              pw.Expanded(child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF0F1C2E),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PÉRIODE', style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey400, letterSpacing: 1)),
                    pw.SizedBox(height: 4),
                    pw.Text(mois, style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                  ],
                ),
              )),
            ],
          ),
          pw.SizedBox(height: 16),

          // Tableau salaire
          pw.Text('DÉTAIL DU SALAIRE',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1, color: const PdfColor.fromInt(0xFF1A70CC))),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1A70CC)),
                children: ['DÉSIGNATION', 'TAUX', 'MONTANT (DH)']
                    .map((h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: pw.Text(h, style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 9,
                      fontWeight: pw.FontWeight.bold)),
                ))
                    .toList(),
              ),
              // Gains
              _tablePaieRow('Salaire brut', '', _formatMontant(salaireBrut),
                  bg: const PdfColor.fromInt(0xFFF0F7FF)),
              // Cotisations
              _tablePaieRow('CNSS', '4.48%', _formatMontant(cnss)),
              _tablePaieRow('AMO', '2.26%', _formatMontant(amo)),
              _tablePaieRow('IR (sur base imposable)', '10%', _formatMontant(ir)),
              // Net
              _tablePaieRow(
                  'SALAIRE NET À PAYER', '',
                  _formatMontant(netAPayer),
                  bold: true,
                  bg: const PdfColor.fromInt(0xFF0F1C2E),
                  textColor: PdfColors.white),
            ],
          ),

          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF0F7FF),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFCDE5FF)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('NET À PAYER EN TOUTES LETTRES :',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1A70CC))),
                pw.Text(_numberToWords(netAPayer),
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0F1C2E))),
              ],
            ),
          ),

          pw.Spacer(),
          _signatureBlock(),
          pw.SizedBox(height: 16),
          _footer(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── 4. Attestation de salaire ────────────────────────────────────────────────
  static Future<Uint8List> genererAttestationSalaire({
    required Uint8List? logoBytes,
    required String nomEmploye,
    required String poste,
    required double salaireMensuel,
    required String motif,
    required String dateDocument,
  }) async {
    final pdf = pw.Document();
    final ref = 'ATT-SAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final salaireAnnuel = salaireMensuel * 12;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildHeader(logoBytes: logoBytes, title: 'Attestation de salaire',
              dateDocument: dateDocument, reference: ref),
          pw.SizedBox(height: 30),

          pw.Text('ATTESTATION DE SALAIRE',
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0F1C2E)),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Container(
              width: 60, height: 3,
              color: const PdfColor.fromInt(0xFF328EEE))),
          pw.SizedBox(height: 30),

          pw.Text(
            'Je soussigné(e), représentant(e) légal(e) de la société DIPS, '
                'atteste que :',
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
          pw.SizedBox(height: 20),

          _employeeBlock(nomEmploye, poste),
          pw.SizedBox(height: 20),

          pw.Text(
            'perçoit une rémunération mensuelle brute de :',
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
          pw.SizedBox(height: 12),

          // Montant en évidence
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: pw.BoxDecoration(
              gradient: const pw.LinearGradient(
                colors: [PdfColor.fromInt(0xFF1A70CC), PdfColor.fromInt(0xFF328EEE)],
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(children: [
              pw.Text('${_formatMontant(salaireMensuel)} DH / mois',
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text('(${_formatMontant(salaireAnnuel)} DH / an)',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                  textAlign: pw.TextAlign.center),
            ]),
          ),
          pw.SizedBox(height: 16),

          if (motif.isNotEmpty) ...[
            pw.Text(
              'Cette attestation est établie à la demande de l\'intéressé(e) '
                  'pour servir et valoir ce que de droit, notamment dans le cadre de : $motif.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            ),
            pw.SizedBox(height: 12),
          ],

          pw.Text(
            'Les montants indiqués sont bruts avant déductions fiscales et sociales.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, lineSpacing: 3),
          ),

          pw.Spacer(),
          _signatureBlock(),
          pw.SizedBox(height: 16),
          _footer(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  static pw.TableRow _tableRow(String label, String value, {bool header = false}) {
    return pw.TableRow(
      decoration: header
          ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF0F7FF))
          : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: const PdfColor.fromInt(0xFF6B7E94))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: const PdfColor.fromInt(0xFF0F1C2E))),
        ),
      ],
    );
  }

  static pw.TableRow _tablePaieRow(String label, String taux, String montant,
      {bool bold = false, PdfColor? bg, PdfColor? textColor}) {
    final tc = textColor ?? const PdfColor.fromInt(0xFF0F1C2E);
    return pw.TableRow(
      decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
      children: [label, taux, montant].map((v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Text(v,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: tc)),
      )).toList(),
    );
  }

  static String _formatMontant(double v) {
    return v.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  static String _numberToWords(double amount) {
    // Simplified - returns formatted amount in words
    final intPart = amount.toInt();
    if (intPart < 1000) return '$intPart dirhams';
    if (intPart < 1000000) {
      final thousands = intPart ~/ 1000;
      final remainder = intPart % 1000;
      final rem = remainder > 0 ? ' ${remainder}' : '';
      return '${thousands} mille$rem dirhams';
    }
    return '$intPart dirhams';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────
String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _formatDateSimple(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

void _showToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  final entry   = OverlayEntry(builder: (_) => _ToastWidget(message: msg));
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2800), entry.remove);
}

Future<bool?> _showConfirmDialog(BuildContext context, {
  required String title, required String message,
  required String confirmLabel, bool danger = false,
}) {
  return showGeneralDialog<bool>(
    context: context, barrierDismissible: true, barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (_, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(child: Material(
      color: Colors.transparent,
      child: Container(
        width: 310, margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 36, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: danger ? kDanger.withOpacity(0.10) : kBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
                danger ? Icons.delete_outline_rounded : Icons.help_outline_rounded,
                color: danger ? kDanger : kBlue, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kText),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 12.5, color: kSubtext, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: kSubtext,
                side: const BorderSide(color: Color(0xFFDDE6F0)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger ? kDanger : kBlue,
                foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(confirmLabel,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    )),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOAST
// ─────────────────────────────────────────────────────────────────────────────
class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});
  @override State<_ToastWidget> createState() => _ToastWidgetState();
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
    Future.delayed(
        const Duration(milliseconds: 2100), () { if (mounted) _ctrl.reverse(); });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned(
    bottom: 32 + MediaQuery.of(context).padding.bottom,
    left: 20, right: 20,
    child: AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, 36 * (1 - _anim.value)),
        child: Opacity(opacity: _anim.value.clamp(0.0, 1.0), child: child),
      ),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1C2E),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 20, offset: const Offset(0, 5))],
        ),
        child: Text(widget.message,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      )),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIDGETS ATOMIQUES
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final DemandeStatut statut;
  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: statut.color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: statut.color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(statut.icon, size: 11, color: statut.color),
      const SizedBox(width: 4),
      Text(statut.label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: statut.color)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionBtn({
    required this.label, required this.icon, required this.color,
    required this.onTap, this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _DCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kSurface, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4ECF5)),
      boxShadow: [BoxShadow(
          color: kBlue.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: kSubtext, letterSpacing: 0.5)),
      ),
      const SizedBox(height: 8),
      Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFFF0F4F8)),
      Padding(padding: const EdgeInsets.all(12), child: child),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 3, height: 13,
            decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: kSubtext, letterSpacing: 0.8)),
      ]);
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
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value, onChanged: enabled ? onChanged : null,
    isExpanded: true, itemHeight: 56,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontSize: 12.5,
          color: enabled ? kSubtext : kSubtext.withOpacity(0.5)),
      prefixIcon: Icon(icon, size: 17,
          color: enabled ? kBlue : kSubtext.withOpacity(0.4)),
      filled: true, fillColor: enabled ? kBg : kBg.withOpacity(0.6),
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE6F0), width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.8)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFDDE6F0).withOpacity(0.5))),
    ),
    icon: const Icon(Icons.expand_more_rounded, color: kSubtext, size: 20),
    dropdownColor: kSurface, borderRadius: BorderRadius.circular(12),
    selectedItemBuilder: (ctx) => items.map((item) => Align(
      alignment: Alignment.centerLeft,
      child: Text(display(item),
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: kText),
          overflow: TextOverflow.ellipsis),
    )).toList(),
    items: items.map((item) => DropdownMenuItem<T>(
      value: item,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
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
    )).toList(),
  );
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
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, keyboardType: type,
    style: const TextStyle(fontSize: 13, color: kText),
    validator: req ? (v) => (v == null || v.isEmpty) ? 'Champ requis' : null : null,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12.5, color: kSubtext),
      prefixIcon: Icon(icon, size: 17, color: kBlue),
      filled: true, fillColor: kBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE6F0), width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBlue, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDanger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDanger, width: 1.8)),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  const _DateField({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final p = await showDatePicker(
        context: context, initialDate: value ?? DateTime.now(),
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
        color: kBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE6F0), width: 1.2),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined, color: kBlue, size: 17),
        const SizedBox(width: 10),
        Expanded(child: Text(
          value != null
              ? '${value!.day.toString().padLeft(2, '0')}/'
              '${value!.month.toString().padLeft(2, '0')}/'
              '${value!.year}'
              : label,
          style: TextStyle(
              fontSize: 13, color: value != null ? kText : kSubtext),
        )),
      ]),
    ),
  );
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
      width: 38, height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: List<Color>.from(_palettes[idx]),
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _IBtn({
    required this.icon, required this.color,
    required this.tooltip, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
    ),
  );
}

class _PillBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _PillBtn({required this.label, required this.onTap, this.color = kBlue});

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
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
          side: const BorderSide(color: Color(0xFFDDE6F0))),
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
      disabledBackgroundColor: kBlue.withOpacity(0.6), elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
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
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
            color: kBlueFaint, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.inbox_outlined, color: kBlue, size: 25),
      ),
      const SizedBox(height: 12),
      const Text('Aucune demande enregistrée',
          style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Cliquez sur « + Nouvelle demande » pour commencer',
          style: TextStyle(color: kSubtext, fontSize: 12),
          textAlign: TextAlign.center),
    ])),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  EXEMPLE D'UTILISATION — switcher de rôle pour démonstration
// ─────────────────────────────────────────────────────────────────────────────
/// Pour intégrer dans votre app, passez simplement le bon rôle :
///
///   // Pour un employé :
///   DemandesPage(role: UserRole.demandeur)
///
///   // Pour un admin :
///   DemandesPage(role: UserRole.administrateur)
///
/// Exemple de switcher de démonstration dans votre main.dart :
class DemandesPageDemo extends StatefulWidget {
  const DemandesPageDemo({super.key});
  @override
  State<DemandesPageDemo> createState() => _DemandesPageDemoState();
}

class _DemandesPageDemoState extends State<DemandesPageDemo> {
  UserRole _role = UserRole.demandeur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          DemandesPage(role: _role),
          // Switcher flottant pour la démo
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () => setState(() => _role = _role == UserRole.demandeur
                  ? UserRole.administrateur
                  : UserRole.demandeur),
              backgroundColor: _role == UserRole.demandeur ? kPurple : kBlue,
              icon: Icon(
                _role == UserRole.demandeur
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_outline_rounded,
                size: 18,
              ),
              label: Text(
                _role == UserRole.demandeur
                    ? 'Vue Admin'
                    : 'Vue Collaborateur',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}