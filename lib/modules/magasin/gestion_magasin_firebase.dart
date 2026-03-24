import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import 'magasin_provider.dart';

const Color kBlue = Color(0xFF2563EB);
const Color kBlueDk = Color(0xFF1D4ED8);
const Color kBlueLt = Color(0xFFEFF6FF);
const Color kBlueMd = Color(0xFFBFDBFE);
const Color kBg = Color(0xFFF1F5F9);
const Color kSurface = Colors.white;
const Color kText = Color(0xFF0F172A);
const Color kMuted = Color(0xFF64748B);
const Color kBorder = Color(0xFFE2E8F0);
const Color kBorderMd = Color(0xFFCBD5E1);
const Color kGreen = Color(0xFF16A34A);
const Color kGreenLt = Color(0xFFF0FDF4);
const Color kGreenMd = Color(0xFFBBF7D0);
const Color kOrange = Color(0xFFD97706);
const Color kOrangeLt = Color(0xFFFFFBEB);
const Color kOrangeMd = Color(0xFFFDE68A);
const Color kRed = Color(0xFFDC2626);
const Color kRedLt = Color(0xFFFEF2F2);
const Color kIndigo = Color(0xFF4455AA);
const Color kIndigoLt = Color(0xFFEEF1FF);

const _h2 = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText);
const _body = TextStyle(fontSize: 13, color: kText);
const _muted = TextStyle(fontSize: 12, color: kMuted);
const _label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.6);
const _mono = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted, fontFamily: 'monospace');

const double kR = 10;
const double kR2 = 14;
const double kP = 22;

const List<String> kMagasins = ['A', 'B', 'C', 'D'];

class GroupeUnites {
  final String label, emoji;
  final List<String> unites;
  const GroupeUnites({required this.label, required this.emoji, required this.unites});
}

const List<GroupeUnites> kGroupes = [
  GroupeUnites(label: 'Tailles vestimentaires', emoji: '👔',
      unites: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
  GroupeUnites(label: 'Pointures chaussures', emoji: '👟',
      unites: ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47', '48']),
  GroupeUnites(label: 'Volume (liquides)', emoji: '💧',
      unites: ['25 ml', '50 ml', '100 ml', '250 ml', '500 ml', '1 L', '2 L', '5 L', '10 L', '20 L']),
  GroupeUnites(label: 'Poids (solides)', emoji: '⚖️',
      unites: ['100 g', '250 g', '500 g', '1 kg', '2 kg', '5 kg', '10 kg', '25 kg', '50 kg', '100 kg', '1 T']),
  GroupeUnites(label: 'Pièces / Unités', emoji: '📦',
      unites: ['Unité', 'Boîte x10', 'Boîte x20', 'Carton x50', 'Palette']),
];

GroupeUnites? groupeByLabel(String? label) =>
    label == null ? null : kGroupes.firstWhere((g) => g.label == label, orElse: () => kGroupes.first);

class GestionMagasinFirebase extends StatefulWidget {
  const GestionMagasinFirebase({super.key});
  @override
  State<GestionMagasinFirebase> createState() => _GestionMagasinFirebaseState();
}

class _GestionMagasinFirebaseState extends State<GestionMagasinFirebase> with TickerProviderStateMixin {
  int _tab = 0;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _tab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magasin = context.watch<MagasinProvider>();

    if (!magasin.firebaseAvailable) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: kMuted),
            SizedBox(height: 16),
            Text('Firebase non disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Veuillez configurer Firebase pour utiliser le stock', style: TextStyle(color: kMuted)),
          ],
        ),
      );
    }

    if (magasin.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (magasin.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: kRed),
            const SizedBox(height: 16),
            Text('Erreur: ${magasin.error}', style: const TextStyle(color: kRed)),
          ],
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    final site = context.watch<SiteProvider>();
    final user = auth.currentUser;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final allowedSiteIds = user?.allowedSiteIds;
    final filteredProduits = SiteId.filterBySite<Produit>(
      magasin.produits,
      allowedSiteIds,
      isSuperAdmin ? site.selectedSiteId : null,
      (p) => p.siteId,
    );
    final filteredEntrees = SiteId.filterBySite<Mouvement>(
      magasin.entrees,
      allowedSiteIds,
      isSuperAdmin ? site.selectedSiteId : null,
      (m) => m.siteId,
    );
    final filteredSorties = SiteId.filterBySite<Mouvement>(
      magasin.sorties,
      allowedSiteIds,
      isSuperAdmin ? site.selectedSiteId : null,
      (m) => m.siteId,
    );
    final effectiveSiteId = allowedSiteIds != null &&
            allowedSiteIds.isNotEmpty &&
            allowedSiteIds.first != SiteId.all
        ? allowedSiteIds.first
        : (site.selectedSiteId ?? SiteId.jadida);
    final siteIdForNew = effectiveSiteId == SiteId.all ? SiteId.jadida : effectiveSiteId;

    final rupt = filteredProduits.where((p) => p.rupture).length;
    final bas = filteredProduits.where((p) => p.bas).length;
    final totalE = filteredEntrees.fold<int>(0, (s, m) => s + m.totalQte);
    final totalS = filteredSorties.fold<int>(0, (s, m) => s + m.totalQte);

    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _TopNavBar(
          tab: _tab,
          onTap: (i) => setState(() {
            _tab = i;
            _tabCtrl.animateTo(i);
          }),
          statChips: [
            if (_tab == 0) ...[
              _StatChip('${filteredProduits.length} produits', kBlueLt, kBlue),
              if (rupt > 0) _StatChip('$rupt rupture${rupt > 1 ? "s" : ""}', kRedLt, kRed),
              if (bas > 0) _StatChip('$bas bas', kOrangeLt, kOrange),
            ],
            if (_tab == 1) ...[
              _StatChip('${filteredEntrees.length} entrée${filteredEntrees.length != 1 ? "s" : ""}', kGreenLt, kGreen),
              _StatChip('$totalE unités reçues', kBlueLt, kBlue),
            ],
            if (_tab == 2) ...[
              _StatChip('${filteredSorties.length} sortie${filteredSorties.length != 1 ? "s" : ""}', kOrangeLt, kOrange),
              _StatChip('$totalS unités sorties', kBlueLt, kBlue),
            ],
          ],
        ),
        Expanded(
            child: TabBarView(
          controller: _tabCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StockPage(magasin: magasin, produits: filteredProduits),
            _EntreesPage(magasin: magasin, entrees: filteredEntrees, siteId: siteIdForNew),
            _SortiesPage(magasin: magasin, sorties: filteredSorties, siteId: siteIdForNew),
          ],
        )),
      ]),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  final List<Widget> statChips;
  const _TopNavBar({required this.tab, required this.onTap, required this.statChips});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      {'label': 'Stock Actuel', 'icon': Icons.inventory_2_rounded, 'color': kBlue},
      {'label': 'Les Entrées', 'icon': Icons.arrow_circle_down_rounded, 'color': kGreen},
      {'label': 'Les Sorties', 'icon': Icons.arrow_circle_up_rounded, 'color': kOrange},
    ];
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;
    return Container(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(bottom: BorderSide(color: kBorder, width: 1.5)),
        boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: SizedBox(
            height: mobile ? 56 : 64,
            child: Row(children: [
              Container(
                  width: mobile ? 34 : 38,
                  height: mobile ? 34 : 38,
                  decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.store_rounded, color: kBlue, size: mobile ? 18 : 20)),
              SizedBox(width: mobile ? 8 : 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('STOCK', style: TextStyle(fontSize: mobile ? 11 : 13, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: .5)),
                const Text('MANAGER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1)),
              ]),
              SizedBox(width: mobile ? 12 : 20),
              Container(width: 1.5, height: 24, color: kBorder),
              SizedBox(width: mobile ? 8 : 14),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(tabs.length, (i) {
                        final col = tabs[i]['color'] as Color;
                        final sel = tab == i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onTap(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 15, vertical: mobile ? 7 : 9),
                              decoration: BoxDecoration(
                                color: sel ? col.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: sel ? Border.all(color: col.withOpacity(0.25), width: 1.5) : null,
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(tabs[i]['icon'] as IconData, size: mobile ? 15 : 17, color: sel ? col : kMuted),
                                SizedBox(width: mobile ? 5 : 7),
                                Text(tabs[i]['label'] as String,
                                    style: TextStyle(
                                      fontSize: mobile ? 12 : 13,
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                      color: sel ? col : kMuted,
                                    )),
                                if (sel) ...[
                                  SizedBox(width: mobile ? 5 : 7),
                                  Container(width: 6, height: 6, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                                ],
                              ]),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              Wrap(spacing: 6, runSpacing: 4, children: statChips),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color bg, col;
  const _StatChip(this.label, this.bg, this.col);
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
      );
}

class _StockPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Produit> produits;
  const _StockPage({required this.magasin, required this.produits});
  @override
  State<_StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<_StockPage> {
  String _q = '', _cat = 'Toutes', _mag = 'Tous', _sort = 'nom';
  bool _asc = true;
  final _sc = TextEditingController();

  List<Produit> get _list {
    final q = _q.toLowerCase();
    var l = widget.produits.where((p) {
      final mq = q.isEmpty || p.nom.toLowerCase().contains(q) || p.reference.toLowerCase().contains(q);
      return mq && (_cat == 'Toutes' || p.categorie == _cat) && (_mag == 'Tous' || p.magasin == _mag);
    }).toList();
    l.sort((a, b) {
      int c;
      if (_sort == 'ref')
        c = a.reference.compareTo(b.reference);
      else if (_sort == 'stock')
        c = a.total.compareTo(b.total);
      else if (_sort == 'mag')
        c = a.magasin.compareTo(b.magasin);
      else
        c = a.nom.compareTo(b.nom);
      return _asc ? c : -c;
    });
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;
    final cats = ['Toutes', ...widget.magasin.categoryNames];

    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 0),
        child: mobile
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(width: double.infinity, child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v))),
                  SizedBox(width: 140, child: _DropBox(value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v))),
                  SizedBox(
                      width: 140,
                      child: _DropBox(
                          value: _mag,
                          items: ['Tous', ...kMagasins],
                          labels: {
                            'Tous': 'Tous magasins',
                            ...{for (var m in kMagasins) m: 'Magasin $m'}
                          },
                          onChanged: (v) => setState(() => _mag = v))),
                  SizedBox(
                      width: 140,
                      child: _DropBox(
                          value: _sort,
                          items: ['nom', 'ref', 'stock', 'mag'],
                          labels: {'nom': 'Nom', 'ref': 'Référence', 'stock': 'Stock', 'mag': 'Magasin'},
                          onChanged: (v) => setState(() => _sort = v))),
                  _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
                ],
              )
            : Row(children: [
                Expanded(flex: 3, child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _DropBox(value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: _DropBox(
                        value: _mag,
                        items: ['Tous', ...kMagasins],
                        labels: {
                          'Tous': 'Tous magasins',
                          ...{for (var m in kMagasins) m: 'Magasin $m'}
                        },
                        onChanged: (v) => setState(() => _mag = v))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 2,
                    child: _DropBox(
                        value: _sort,
                        items: ['nom', 'ref', 'stock', 'mag'],
                        labels: {'nom': 'Nom', 'ref': 'Référence', 'stock': 'Stock', 'mag': 'Magasin'},
                        onChanged: (v) => setState(() => _sort = v))),
                const SizedBox(width: 8),
                _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
              ]),
      ),
      const SizedBox(height: 14),
      Expanded(
          child: Padding(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
        child: _DataTable(
          count: '${list.length} / ${widget.magasin.totalProduits} produits',
          empty: list.isEmpty,
          emptyMsg: 'Aucun produit trouvé',
          columns: const [
            _Col('PRODUIT', flex: 3),
            _Col('RÉFÉRENCE', flex: 2),
            _Col('CATÉGORIE', flex: 2),
            _Col('STOCK', flex: 1),
            _Col('MAGASIN', flex: 1),
            _Col('', flex: 1),
          ],
          rows: list.map((p) {
            final g = groupeByLabel(p.groupeUniteLabel);
            final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
            final stockBg = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
            return _DataTableRow(cells: [
              Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(9)),
                    child: Center(child: Text(g?.emoji ?? '📦', style: const TextStyle(fontSize: 17)))),
                const SizedBox(width: 10),
                Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis),
                  if (g != null) Text(g.label, style: _muted.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis),
                ])),
              ]),
              Text(p.reference, style: _mono),
              _PillBadge(p.categorie, kBlueLt, kBlue),
              Center(
                  child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                child: Text('${p.total}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: stockColor)),
              )),
              Center(child: _PillBadge('Mag. ${p.magasin}', kIndigoLt, kIndigo)),
              Center(
                  child: _IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () {
                _showDialog(context, _DetailsDialog(produit: p, groupe: g));
              })),
            ]);
          }).toList(),
        ),
      )),
    ]);
  }
}

class _EntreesPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Mouvement> entrees;
  final String siteId;
  const _EntreesPage({required this.magasin, required this.entrees, required this.siteId});
  @override
  State<_EntreesPage> createState() => _EntreesPageState();
}

class _EntreesPageState extends State<_EntreesPage> {
  String _cat = 'Toutes', _mag = 'Tous';

  List<Mouvement> get _list => widget.entrees
      .where((m) => (_cat == 'Toutes' || m.categorie == _cat) && (_mag == 'Tous' || m.magasin == _mag))
      .toList();

  int get _totalUnites => _list.fold<int>(0, (sum, m) => sum + m.totalQte);

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(kP, 16, kP, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF14532D), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(kR2),
          boxShadow: [BoxShadow(color: kGreen.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_circle_down_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Entrées de Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(
              '${list.length} mouvement${list.length != 1 ? "s" : ""} · $_totalUnites unité${_totalUnites != 1 ? "s" : ""} reçue${_totalUnites != 1 ? "s" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
            ),
          ])),
          _GlassDropdown(value: _cat, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: (v) => setState(() => _cat = v)),
          const SizedBox(width: 8),
          _GlassDropdown(
              value: _mag,
              items: ['Tous', ...kMagasins],
              labels: {
                'Tous': 'Tous',
                ...{for (var m in kMagasins) m: 'Mag. $m'}
              },
              icon: Icons.warehouse_rounded,
              hint: 'Magasin',
              onChanged: (v) => setState(() => _mag = v)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nouvelle entrée', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            onPressed: () => _showDialog(context, _MouvForm(type: 'entree', magasin: widget.magasin, siteId: widget.siteId)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(kP, 0, kP, kP),
        child: _DataTable(
          count: '${list.length} entrée${list.length != 1 ? "s" : ""}',
          empty: list.isEmpty,
          emptyMsg: 'Aucune entrée — cliquez sur « Nouvelle entrée »',
          accentColor: kGreen,
          columns: const [
            _Col('DATE & HEURE', flex: 2),
            _Col('PRODUIT', flex: 3),
            _Col('RÉFÉRENCE', flex: 2),
            _Col('CATÉGORIE', flex: 2),
            _Col('MAGASIN', flex: 1),
            _Col('QUANTITÉ', flex: 3),
            _Col('', flex: 1),
          ],
          rows: list
              .map((m) => _MouvRow(
                    m: m,
                    color: kGreen,
                    bgColor: kGreenLt,
                    onDelete: () => _showDialog(
                        context,
                        _ConfirmDel(
                          nom: m.nomProduit,
                          msg: 'Supprimer cette entrée ? Le stock sera décrémenté.',
                          onConfirm: () {
                            widget.magasin.deleteEntree(m.id);
                            Navigator.pop(context);
                          },
                        )),
                  ))
              .toList(),
        ),
      )),
    ]);
  }
}

class _SortiesPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Mouvement> sorties;
  final String siteId;
  const _SortiesPage({required this.magasin, required this.sorties, required this.siteId});
  @override
  State<_SortiesPage> createState() => _SortiesPageState();
}

class _SortiesPageState extends State<_SortiesPage> {
  String _cat = 'Toutes', _mag = 'Tous';

  List<Mouvement> get _list => widget.sorties
      .where((m) => (_cat == 'Toutes' || m.categorie == _cat) && (_mag == 'Tous' || m.magasin == _mag))
      .toList();

  int get _totalUnites => _list.fold<int>(0, (sum, m) => sum + m.totalQte);

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(kP, 16, kP, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF92400E), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(kR2),
          boxShadow: [BoxShadow(color: kOrange.withOpacity(0.3), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_circle_up_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sorties de Stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(
              '${list.length} mouvement${list.length != 1 ? "s" : ""} · $_totalUnites unité${_totalUnites != 1 ? "s" : ""} sortie${_totalUnites != 1 ? "s" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
            ),
          ])),
          _GlassDropdown(value: _cat, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: (v) => setState(() => _cat = v)),
          const SizedBox(width: 8),
          _GlassDropdown(
              value: _mag,
              items: ['Tous', ...kMagasins],
              labels: {
                'Tous': 'Tous',
                ...{for (var m in kMagasins) m: 'Mag. $m'}
              },
              icon: Icons.warehouse_rounded,
              hint: 'Magasin',
              onChanged: (v) => setState(() => _mag = v)),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kOrange,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nouvelle sortie', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            onPressed: () => _showDialog(context, _MouvForm(type: 'sortie', magasin: widget.magasin, siteId: widget.siteId)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(kP, 0, kP, kP),
        child: _DataTable(
          count: '${list.length} sortie${list.length != 1 ? "s" : ""}',
          empty: list.isEmpty,
          emptyMsg: 'Aucune sortie — cliquez sur « Nouvelle sortie »',
          accentColor: kOrange,
          columns: const [
            _Col('DATE & HEURE', flex: 2),
            _Col('PRODUIT', flex: 3),
            _Col('RÉFÉRENCE', flex: 2),
            _Col('CATÉGORIE', flex: 2),
            _Col('MAGASIN', flex: 1),
            _Col('QUANTITÉ', flex: 3),
            _Col('PRÉLEVÉ PAR', flex: 2),
            _Col('', flex: 1),
          ],
          rows: list
              .map((m) => _MouvRow(
                    m: m,
                    color: kOrange,
                    bgColor: kOrangeLt,
                    showPreneur: true,
                    onDelete: () => _showDialog(
                        context,
                        _ConfirmDel(
                          nom: m.nomProduit,
                          msg: 'Supprimer cette sortie ? Le stock sera restitué.',
                          onConfirm: () {
                            widget.magasin.deleteSortie(m.id);
                            Navigator.pop(context);
                          },
                        )),
                  ))
              .toList(),
        ),
      )),
    ]);
  }
}

class _GlassDropdown extends StatelessWidget {
  final String value, hint;
  final List<String> items;
  final Map<String, String>? labels;
  final void Function(String) onChanged;
  final IconData icon;
  const _GlassDropdown({required this.value, required this.items, required this.onChanged, required this.icon, required this.hint, this.labels});

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w600),
          items: items
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 13, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(labels?[v] ?? v, style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ]),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v!),
        )),
      );
}

class _MouvForm extends StatefulWidget {
  final String type;
  final MagasinProvider magasin;
  final String siteId;
  const _MouvForm({required this.type, required this.magasin, this.siteId = 'jadida'});
  @override
  State<_MouvForm> createState() => _MouvFormState();
}

class _MouvFormState extends State<_MouvForm> {
  String? _selMag;
  String? _selCat;
  bool _newCatMode = false;
  final _newCatCtrl = TextEditingController();
  Produit? _selProd;
  bool _newProdMode = false;
  final _newNomCtrl = TextEditingController();
  final _newRefCtrl = TextEditingController();
  bool _newHasVar = false;
  String? _newGroupeLabel;
  final _qteC = TextEditingController(text: '1');
  final Map<String, TextEditingController> _varCtrl = {};
  final Set<String> _selVar = {};
  final _preneurC = TextEditingController();

  bool get _isSortie => widget.type == 'sortie';
  Color get _col => _isSortie ? kOrange : kGreen;
  GroupeUnites? get _groupe => _newProdMode ? groupeByLabel(_newGroupeLabel) : groupeByLabel(_selProd?.groupeUniteLabel);
  bool get _hasVar => _newProdMode ? _newHasVar : (_selProd?.aVariantes ?? false);

  List<Produit> get _filteredProduits => widget.magasin.produits.where((p) {
        if (p.siteId != widget.siteId) return false;
        final magOk = _selMag == null || p.magasin == _selMag;
        final catOk = _selCat == null || p.categorie == _selCat;
        return magOk && catOk;
      }).toList();

  List<String> get _availableCats => widget.magasin.categoryNames;

  void _toggleVar(String u) => setState(() {
        if (_selVar.contains(u)) {
          _selVar.remove(u);
          _varCtrl.remove(u);
        } else {
          _selVar.add(u);
          _varCtrl[u] = TextEditingController(text: '1');
        }
      });

  bool get _canSave {
    final magOk = _selMag != null;
    final catOk = _newCatMode ? _newCatCtrl.text.trim().isNotEmpty : _selCat != null;
    final prodOk = _newProdMode ? (_newNomCtrl.text.trim().isNotEmpty && _newRefCtrl.text.trim().isNotEmpty) : _selProd != null;
    final qteOk = _hasVar ? _selVar.isNotEmpty : (int.tryParse(_qteC.text) ?? 0) > 0;
    final prenOk = !_isSortie || _preneurC.text.trim().isNotEmpty;
    return magOk && catOk && prodOk && qteOk && prenOk;
  }

  Future<void> _save() async {
    final catFinal = _newCatMode ? _newCatCtrl.text.trim() : _selCat!;
    if (_newCatMode) await widget.magasin.addCategorie(catFinal);

    Produit prod;
    if (_newProdMode) {
      final newProd = Produit(
        id: '',
        nom: _newNomCtrl.text.trim(),
        reference: _newRefCtrl.text.trim(),
        categorie: catFinal,
        magasin: _selMag!,
        aVariantes: _newHasVar,
        groupeUniteLabel: _newHasVar ? _newGroupeLabel : null,
        quantiteStock: 0,
        variantes: [],
        siteId: widget.siteId,
      );
      final newId = await widget.magasin.addProduit(newProd);
      prod = newProd.copyWith(id: newId);
    } else {
      prod = _selProd!;
    }

    final lignes = _hasVar
        ? _selVar.map((u) => LigneMouvement(unite: u, quantite: int.tryParse(_varCtrl[u]?.text ?? '0') ?? 0)).toList()
        : <LigneMouvement>[];

    final m = Mouvement(
      id: '',
      type: widget.type,
      produitId: prod.id,
      nomProduit: prod.nom,
      reference: prod.reference,
      categorie: catFinal,
      magasin: _selMag!,
      aVariantes: _hasVar,
      groupeUniteLabel: _hasVar ? (prod.groupeUniteLabel ?? _newGroupeLabel) : null,
      quantite: _hasVar ? 0 : (int.tryParse(_qteC.text) ?? 0),
      lignes: lignes,
      date: DateTime.now(),
      preneurNom: _isSortie ? _preneurC.text.trim() : null,
      siteId: prod.siteId,
    );

    if (_isSortie) {
      await widget.magasin.addSortie(m);
    } else {
      await widget.magasin.addEntree(m);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _FullDialog(
      color: _col,
      icon: _isSortie ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
      title: _isSortie ? 'Nouvelle Sortie de Stock' : 'Nouvelle Entrée de Stock',
      onSave: _canSave ? _save : null,
      saveLabel: _isSortie ? 'Valider la sortie' : "Valider l'entrée",
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHdr('1. Choisir le magasin', Icons.warehouse_rounded, _col),
        const SizedBox(height: 12),
        Row(
            children: kMagasins.map((mag) {
          final sel = _selMag == mag;
          final prodCount = widget.magasin.produits.where((p) => p.siteId == widget.siteId && p.magasin == mag).length;
          return Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                _selMag = mag;
                _selProd = null;
                _selCat = null;
                _selVar.clear();
                _varCtrl.clear();
                _newCatMode = false;
                _newProdMode = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: sel ? _col.withOpacity(0.07) : kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? _col : kBorder, width: sel ? 2.0 : 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: sel ? _col : kBg, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('🏪', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(height: 10),
                  Text('Magasin $mag', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sel ? _col : kText)),
                  const SizedBox(height: 4),
                  Text('$prodCount produit${prodCount != 1 ? "s" : ""}', style: _muted.copyWith(fontSize: 11)),
                  if (sel) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _col, borderRadius: BorderRadius.circular(20)),
                      child: const Text('✓ Sélectionné', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ]),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 26),

        if (_selMag != null) ...[
          _SectionHdr('2. Catégorie', Icons.category_outlined, _col),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _newCatMode
                    ? _StyledTF(
                        ctrl: _newCatCtrl,
                        hint: 'Nom de la nouvelle catégorie…',
                        prefix: const Icon(Icons.category_outlined, size: 18, color: kMuted),
                        onChanged: (_) => setState(() {}))
                    : _StyledDrop<String>(
                        value: _selCat,
                        hint: 'Sélectionner une catégorie',
                        items: _availableCats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() {
                              _selCat = v;
                              _selProd = null;
                              _selVar.clear();
                              _varCtrl.clear();
                            }))),
            const SizedBox(width: 10),
            _ModeBtn(
                label: _newCatMode ? '← Existante' : '+ Nouvelle',
                color: _col,
                onTap: () => setState(() {
                      _newCatMode = !_newCatMode;
                      _selCat = null;
                    })),
          ]),
          const SizedBox(height: 26),

          if (_selCat != null || _newCatMode) ...[
            _SectionHdr('3. Produit', Icons.inventory_2_outlined, _col),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _newProdMode
                      ? _NewProdBlock(
                          nomCtrl: _newNomCtrl,
                          refCtrl: _newRefCtrl,
                          mag: _selMag!,
                          hasVar: _newHasVar,
                          groupeLabel: _newGroupeLabel,
                          color: _col,
                          onHasVarChanged: (v) => setState(() {
                                _newHasVar = v;
                                _selVar.clear();
                                _varCtrl.clear();
                              }),
                          onGroupeChanged: (v) => setState(() {
                                _newGroupeLabel = v;
                                _selVar.clear();
                                _varCtrl.clear();
                              }),
                          onChanged: () => setState(() {}))
                      : _StyledDrop<Produit>(
                          value: _selProd,
                          hint: _filteredProduits.isEmpty ? 'Aucun produit dans ce magasin' : 'Sélectionner un produit',
                          items: _filteredProduits
                              .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Row(children: [
                                    Flexible(child: Text(p.nom, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    _PillBadge(p.reference, kBlueLt, kBlue),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: p.rupture
                                              ? kRedLt
                                              : p.bas
                                                  ? kOrangeLt
                                                  : kGreenLt,
                                          borderRadius: BorderRadius.circular(20)),
                                      child: Text('${p.total}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: p.rupture
                                                  ? kRed
                                                  : p.bas
                                                      ? kOrange
                                                      : kGreen)),
                                    ),
                                  ])))
                              .toList(),
                          onChanged: (v) => setState(() {
                                _selProd = v;
                                _selVar.clear();
                                _varCtrl.clear();
                              }))),
              const SizedBox(width: 10),
              _ModeBtn(
                  label: _newProdMode ? '← Existant' : '+ Nouveau',
                  color: _col,
                  onTap: () => setState(() {
                        _newProdMode = !_newProdMode;
                        _selProd = null;
                        _selVar.clear();
                        _varCtrl.clear();
                      })),
            ]),
            const SizedBox(height: 26),

            if (_selProd != null || _newProdMode) ...[
              _SectionHdr('4. Quantité', _hasVar ? Icons.grid_view_rounded : Icons.tag_rounded, _col),
              const SizedBox(height: 10),
              if (!_hasVar)
                SizedBox(width: 200, child: _NumStepField(ctrl: _qteC, color: _col, onChanged: () => setState(() {})))
              else if (_groupe != null) ...[
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _groupe!.unites.map((u) {
                      final sel = _selVar.contains(u);
                      return InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => _toggleVar(u),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel ? _col : kSurface,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: sel ? _col : kBorder, width: sel ? 2 : 1.5),
                          ),
                          child: Text(u, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : kMuted)),
                        ),
                      );
                    }).toList()),
                if (_selVar.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _VarQteTable(selVar: _selVar, varCtrl: _varCtrl, color: _col, onRemove: _toggleVar),
                ],
              ],
              const SizedBox(height: 26),
            ],

            if (_isSortie && (_selProd != null || _newProdMode)) ...[
              _SectionHdr('5. Prélevé par', Icons.person_outline_rounded, _col),
              const SizedBox(height: 10),
              _StyledTF(
                  ctrl: _preneurC,
                  hint: 'Nom et prénom de la personne…',
                  prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted),
                  onChanged: (_) => setState(() {})),
            ],
          ],
        ],
      ]),
    );
  }
}

class _NewProdBlock extends StatelessWidget {
  final TextEditingController nomCtrl, refCtrl;
  final String mag;
  final bool hasVar;
  final String? groupeLabel;
  final Color color;
  final ValueChanged<bool> onHasVarChanged;
  final ValueChanged<String?> onGroupeChanged;
  final VoidCallback onChanged;
  const _NewProdBlock({
    required this.nomCtrl,
    required this.refCtrl,
    required this.mag,
    required this.hasVar,
    this.groupeLabel,
    required this.color,
    required this.onHasVarChanged,
    required this.onGroupeChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kIndigoLt, borderRadius: BorderRadius.circular(8), border: Border.all(color: kIndigo.withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warehouse_rounded, size: 14, color: kIndigo),
              const SizedBox(width: 7),
              Text('Sera enregistré dans Magasin $mag', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kIndigo)),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NOM DU PRODUIT', style: _label),
              const SizedBox(height: 6),
              _StyledTF(ctrl: nomCtrl, hint: 'Ex: Casque de sécurité', onChanged: (_) => onChanged()),
            ])),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('RÉFÉRENCE', style: _label),
              const SizedBox(height: 6),
              _StyledTF(ctrl: refCtrl, hint: 'Ex: EPI-010', onChanged: (_) => onChanged()),
            ])),
          ]),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('A DES VARIANTES ?', style: _label),
            const SizedBox(height: 6),
            Row(children: [
              _ToggleBtn('Oui', hasVar, color, () => onHasVarChanged(true)),
              const SizedBox(width: 8),
              _ToggleBtn('Non', !hasVar, color, () => onHasVarChanged(false)),
            ]),
          ]),
          if (hasVar) ...[
            const SizedBox(height: 14),
            const Text("GROUPE D'UNITÉS", style: _label),
            const SizedBox(height: 6),
            _StyledDrop<String>(
                value: groupeLabel,
                hint: 'Choisir un groupe',
                items: kGroupes
                    .map((g) => DropdownMenuItem(
                        value: g.label,
                        child: Row(children: [
                          Text(g.emoji),
                          const SizedBox(width: 8),
                          Text(g.label)
                        ])))
                    .toList(),
                onChanged: onGroupeChanged),
          ],
        ]),
      );
}

class _VarQteTable extends StatefulWidget {
  final Set<String> selVar;
  final Map<String, TextEditingController> varCtrl;
  final Color color;
  final void Function(String) onRemove;
  const _VarQteTable({required this.selVar, required this.varCtrl, required this.color, required this.onRemove});
  @override
  State<_VarQteTable> createState() => _VarQteTableState();
}

class _VarQteTableState extends State<_VarQteTable> {
  @override
  Widget build(BuildContext context) {
    final col = widget.color;
    final total = widget.selVar.fold(0, (s, u) => s + (int.tryParse(widget.varCtrl[u]?.text ?? '0') ?? 0));
    return Container(
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(kR))),
          child: Row(children: [
            SizedBox(width: 110, child: Text('UNITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 12),
            Expanded(child: Text('QUANTITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 36),
          ]),
        ),
        ...widget.selVar.toList().asMap().entries.map((e) {
          final i = e.key;
          final u = e.value;
          final ctrl = widget.varCtrl[u]!;
          return Column(children: [
            if (i > 0) const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Container(
                    width: 110,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)),
                    child: Text(u, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(
                    child: Row(children: [
                  _StepBtn(Icons.remove_rounded, col, () {
                    final v = int.tryParse(ctrl.text) ?? 0;
                    if (v > 0) {
                      ctrl.text = '${v - 1}';
                      setState(() {});
                    }
                  }),
                  Expanded(
                      child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText),
                            decoration: InputDecoration(
                              hintText: '0',
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: col, width: 2)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                            ),
                            onChanged: (_) => setState(() {}),
                          ))),
                  _StepBtn(Icons.add_rounded, col, () {
                    final v = int.tryParse(ctrl.text) ?? 0;
                    ctrl.text = '${v + 1}';
                    setState(() {});
                  }),
                ])),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () {
                    widget.onRemove(u);
                    setState(() {});
                  },
                  child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.close_rounded, size: 15, color: kRed)),
                ),
              ]),
            ),
          ]);
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kR))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL', style: _label.copyWith(color: col)),
            Text('$total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: col)),
          ]),
        ),
      ]),
    );
  }
}

class _DetailsDialog extends StatelessWidget {
  final Produit produit;
  final GroupeUnites? groupe;
  const _DetailsDialog({required this.produit, this.groupe});

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final g = groupe;
    final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
    final stockBg = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
    final stockLabel = p.rupture ? 'Rupture' : p.bas ? 'Bas' : 'OK';

    return _FullDialog(
      color: kBlue,
      icon: Icons.inventory_2_rounded,
      title: p.nom,
      saveLabel: 'Fermer',
      onSave: () => Navigator.pop(context),
      showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _DetCard(Icons.qr_code_rounded, '🏷️ Référence', p.reference),
          _DetCard(Icons.category_outlined, '📂 Catégorie', p.categorie),
          _DetCard(Icons.warehouse_rounded, '🏪 Magasin', 'Magasin ${p.magasin}'),
          if (g != null) _DetCard(Icons.widgets_rounded, '${g.emoji} Mesures', g.label),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: stockColor.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, color: stockColor, size: 22),
            const SizedBox(width: 12),
            Text('${p.total}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: stockColor)),
            const SizedBox(width: 6),
            Text('unité${p.total != 1 ? "s" : ""}', style: TextStyle(fontSize: 13, color: stockColor.withOpacity(0.8))),
            const SizedBox(width: 12),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: stockColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(stockLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: stockColor))),
          ]),
        ),
        if (p.aVariantes && p.variantes.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(kR),
                child: Column(children: [
                  Container(
                      color: kBlueLt,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Row(children: [
                        Expanded(flex: 2, child: Text('UNITÉ', style: _label.copyWith(color: kBlue))),
                        Expanded(flex: 2, child: Text('QUANTITÉ', style: _label.copyWith(color: kBlue))),
                        Expanded(flex: 1, child: Text('STATUT', style: _label.copyWith(color: kBlue))),
                      ])),
                  ...p.variantes.asMap().entries.map((e) {
                    final v = e.value;
                    final r = v.quantite == 0;
                    final l = v.quantite > 0 && v.quantite <= 3;
                    final vc = r ? kRed : l ? kOrange : kGreen;
                    final vb = r ? kRedLt : l ? kOrangeLt : kGreenLt;
                    return Column(children: [
                      if (e.key > 0) const Divider(height: 1, color: kBorder),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(children: [
                            Expanded(
                                flex: 2,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)),
                                      child: Text(v.unite, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                                    ))),
                            Expanded(flex: 2, child: Text('${v.quantite}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: vc))),
                            Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: vb, borderRadius: BorderRadius.circular(20)),
                                  child: Text(r ? 'Rupture' : l ? 'Bas' : 'OK',
                                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: vc)),
                                )),
                          ])),
                    ]);
                  }),
                  Container(
                      color: kBlueLt,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('TOTAL', style: _label.copyWith(color: kBlue)),
                        Text('${p.total}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kBlue)),
                      ])),
                ])),
          ),
        ],
      ]),
    );
  }
}

class _DetCard extends StatelessWidget {
  final IconData icon;
  final String label, val;
  const _DetCard(this.icon, this.label, this.val);
  @override
  Widget build(BuildContext context) => Container(
        width: 185,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
        child: Row(children: [
          Icon(icon, size: 15, color: kBlue),
          const SizedBox(width: 9),
          Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: _muted.copyWith(fontSize: 10)),
            Text(val, style: _h2.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );
}

class _ConfirmDel extends StatelessWidget {
  final String nom, msg;
  final VoidCallback onConfirm;
  const _ConfirmDel({required this.nom, required this.msg, required this.onConfirm});
  @override
  Widget build(BuildContext context) => _FullDialog(
        color: kRed,
        icon: Icons.delete_outline_rounded,
        title: 'Confirmer la suppression',
        saveLabel: 'Supprimer',
        onSave: onConfirm,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kRed.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: kRed, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
              const SizedBox(height: 4),
              Text(msg, style: _muted),
            ])),
          ]),
        ),
      );
}

class _FullDialog extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, saveLabel;
  final VoidCallback? onSave;
  final Widget child;
  final bool showCancel;
  const _FullDialog({
    required this.color,
    required this.icon,
    required this.title,
    required this.saveLabel,
    required this.onSave,
    required this.child,
    this.showCancel = true,
  });

  @override
  Widget build(BuildContext context) {
    final margin = dialogMargin(context);
    final maxW = dialogMaxWidth(context);
    final maxH = dialogMaxHeight(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.fromLTRB(margin, margin, margin, margin),
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 50, offset: const Offset(0, 12))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 18),
                decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(9)),
                      child: Icon(icon, color: Colors.white, size: 20)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
                  InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18))),
                ]),
              ),
              Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(kP), child: child)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 14),
                decoration: const BoxDecoration(
                    color: kBg, border: Border(top: BorderSide(color: kBorder)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (showCancel) ...[
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: kMuted))),
                    const SizedBox(width: 10),
                  ],
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: onSave != null ? 1.0 : 0.4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      ),
                      onPressed: onSave,
                      icon: Icon(icon, size: 15),
                      label: Text(saveLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ]),
          )),
    );
  }
}

class _MouvRow extends _DataTableRow {
  final Mouvement m;
  final Color color, bgColor;
  final bool showPreneur;
  final VoidCallback onDelete;
  const _MouvRow({required this.m, required this.color, required this.bgColor, this.showPreneur = false, required this.onDelete}) : super(cells: const []);

  String get _date {
    final d = m.date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get _time {
    final d = m.date;
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  List<Widget> get cells => [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(_date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
          Text(_time, style: _muted.copyWith(fontSize: 11)),
        ]),
        Text(m.nomProduit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis),
        Text(m.reference, style: _mono),
        _PillBadge(m.categorie, kBlueLt, kBlue),
        Center(child: _PillBadge('M.${m.magasin}', kIndigoLt, kIndigo)),
        m.aVariantes
            ? Wrap(
                spacing: 4,
                runSpacing: 4,
                children: m.lignes
                    .map((l) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(.2))),
                          child: Text('${l.unite} ×${l.quantite}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ))
                    .toList())
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                child: Text('${m.quantite}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
        if (showPreneur)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.person_outline_rounded, size: 13, color: kMuted),
            const SizedBox(width: 5),
            Flexible(child: Text(m.preneurNom ?? '—', style: _body.copyWith(fontSize: 12), overflow: TextOverflow.ellipsis)),
          ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
        ]),
      ];
}

class _Col {
  final String label;
  final int flex;
  const _Col(this.label, {this.flex = 1});
}

class _DataTableRow {
  final List<Widget> cells;
  const _DataTableRow({required this.cells});
}

class _DataTable extends StatelessWidget {
  final List<_Col> columns;
  final List<_DataTableRow> rows;
  final String count;
  final bool empty;
  final String emptyMsg;
  final Color? accentColor;
  const _DataTable({required this.columns, required this.rows, required this.count, required this.empty, this.emptyMsg = 'Aucun résultat', this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? kBlue;
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kR2),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(kR2),
          child: Column(children: [
            Container(
              color: accent.withOpacity(0.07),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(children: columns.map((c) => Expanded(flex: c.flex, child: Text(c.label, style: _label.copyWith(color: accent)))).toList()),
            ),
            const Divider(height: 1, color: kBorder),
            Expanded(
                child: empty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_rounded, size: 52, color: accent.withOpacity(0.2)),
                        const SizedBox(height: 12),
                        Text(emptyMsg, style: _muted),
                      ]))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                        itemBuilder: (_, i) => _RowWidget(row: rows[i], columns: columns, accentColor: accent))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.04),
                border: const Border(top: BorderSide(color: kBorder)),
              ),
              child: Text(count, style: _muted.copyWith(fontWeight: FontWeight.w600)),
            ),
          ])),
    );
  }
}

class _RowWidget extends StatefulWidget {
  final _DataTableRow row;
  final List<_Col> columns;
  final Color accentColor;
  const _RowWidget({required this.row, required this.columns, required this.accentColor});
  @override
  State<_RowWidget> createState() => _RowWidgetState();
}

class _RowWidgetState extends State<_RowWidget> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hov = true),
        onExit: (_) => setState(() => _hov = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hov ? widget.accentColor.withOpacity(0.04) : kSurface,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(widget.columns.length,
                  (i) => Expanded(flex: widget.columns[i].flex, child: i < widget.row.cells.length ? widget.row.cells[i] : const SizedBox.shrink()))),
        ),
      );
}

class _PillBadge extends StatelessWidget {
  final String text;
  final Color bg, col;
  const _PillBadge(this.text, this.bg, this.col);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col), overflow: TextOverflow.ellipsis),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final Color bg, col;
  final VoidCallback fn;
  const _IconBtn(this.icon, this.tip, this.bg, this.col, this.fn);
  @override
  Widget build(BuildContext context) => Tooltip(
      message: tip,
      child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: fn,
          child: Container(
              padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 15, color: col))));
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))));
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ToggleBtn(this.label, this.active, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(color: active ? color : kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? color : kBorder, width: 1.5)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : kMuted))));
}

class _SectionHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHdr(this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 9),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: .6)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: color.withOpacity(0.2))),
      ]);
}

class _SearchBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String value;
  final void Function(String) onChanged;
  const _SearchBox({required this.ctrl, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
              hintText: 'Rechercher un produit…',
              hintStyle: const TextStyle(fontSize: 13, color: kBorderMd),
              prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 18),
              suffixIcon: value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 15),
                      onPressed: () {
                        ctrl.clear();
                        onChanged('');
                      })
                  : null,
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder))),
          onChanged: onChanged));
}

class _DropBox extends StatelessWidget {
  final dynamic value;
  final List<String> items;
  final Map<String, String>? labels;
  final void Function(String) onChanged;
  const _DropBox({required this.value, required this.items, required this.onChanged, this.labels});
  @override
  Widget build(BuildContext context) => Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value as String : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: kText, fontFamily: 'Roboto'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 18),
              items: items.map((v) => DropdownMenuItem(value: v, child: Text(labels?[v] ?? v))).toList(),
              onChanged: (v) => onChanged(v!))));
}

class _StyledDrop<T> extends StatelessWidget {
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _StyledDrop({this.value, this.hint, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hint != null ? Text(hint!, style: const TextStyle(fontSize: 13, color: kBorderMd)) : null,
              style: const TextStyle(fontSize: 13, color: kText, fontFamily: 'Roboto'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 18),
              items: items,
              onChanged: onChanged)));
}

class _StyledTF extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Widget? prefix;
  final void Function(String)? onChanged;
  const _StyledTF({required this.ctrl, required this.hint, this.prefix, this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 13, color: kText),
      onChanged: onChanged,
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: kBorderMd),
          prefixIcon: prefix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder))));
}

class _NumStepField extends StatelessWidget {
  final TextEditingController ctrl;
  final Color color;
  final VoidCallback onChanged;
  const _NumStepField({required this.ctrl, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        _StepBtn(Icons.remove_rounded, color, () {
          final v = int.tryParse(ctrl.text) ?? 0;
          if (v > 1) {
            ctrl.text = '${v - 1}';
            onChanged();
          }
        }),
        Expanded(
            child: SizedBox(
                height: 50,
                child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    onChanged: (_) => onChanged(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText),
                    decoration: InputDecoration(
                        hintText: '0',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color, width: 2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)))))),
        _StepBtn(Icons.add_rounded, color, () {
          final v = int.tryParse(ctrl.text) ?? 0;
          ctrl.text = '${v + 1}';
          onChanged();
        }),
      ]);
}

class _AscBtn extends StatelessWidget {
  final bool asc;
  final VoidCallback onTap;
  const _AscBtn({required this.asc, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(kR),
      onTap: onTap,
      child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBlueMd.withOpacity(.5))),
          child: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: kBlue, size: 17)));
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepBtn(this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(.2))),
          child: Icon(icon, color: color, size: 18)));
}

void _showDialog(BuildContext context, Widget dialog) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
    ),
    pageBuilder: (_, __, ___) => dialog,
  );
}
