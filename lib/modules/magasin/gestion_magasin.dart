import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DESIGN SYSTEM
// ════════════════════════════════════════════════════════════════════════════
const Color kBlue      = Color(0xFF328EEE);
const Color kBlueDk    = Color(0xFF1A6FCA);
const Color kBlueLt    = Color(0xFFE8F3FD);
const Color kBlueMd    = Color(0xFFB3D6F9);
const Color kBg        = Color(0xFFF0F4FA);
const Color kSurface   = Colors.white;
const Color kText      = Color(0xFF0F1D2E);
const Color kMuted     = Color(0xFF6B7A90);
const Color kBorder    = Color(0xFFE2EAF4);
const Color kGreen     = Color(0xFF1A8C40);
const Color kGreenLt   = Color(0xFFEAF7EE);
const Color kOrange    = Color(0xFFCC7700);
const Color kOrangeLt  = Color(0xFFFFF5E0);
const Color kRed       = Color(0xFFCC2222);
const Color kRedLt     = Color(0xFFFFF0F0);

const _h1    = TextStyle(fontSize:18, fontWeight:FontWeight.w800, color:kText);
const _h2    = TextStyle(fontSize:14, fontWeight:FontWeight.w700, color:kText);
const _body  = TextStyle(fontSize:13, color:kText);
const _muted = TextStyle(fontSize:12, color:kMuted);
const _label = TextStyle(fontSize:11, fontWeight:FontWeight.w600, color:kMuted, letterSpacing:0.5);
const _mono  = TextStyle(fontSize:12, fontWeight:FontWeight.w500, color:kMuted, fontFamily:'monospace');

const double kR  = 10;
const double kR2 = 14;
const double kP  = 24;

const List<String> kMagasins = ['A','B','C','D'];

// ════════════════════════════════════════════════════════════════════════════
//  UNITÉS DE MESURE
// ════════════════════════════════════════════════════════════════════════════
enum TypeMesure { taille, volume, poids, piece }

class GroupeUnites {
  final String label, description;
  final IconData icon;
  final TypeMesure type;
  final List<String> unites;
  const GroupeUnites({
    required this.label, required this.description,
    required this.icon, required this.type, required this.unites,
  });
}

const List<GroupeUnites> kGroupes = [
  GroupeUnites(label:'Tailles vestimentaires', description:'XS→XXXL',
      icon:Icons.checkroom_rounded, type:TypeMesure.taille,
      unites:['XS','S','M','L','XL','XXL','XXXL']),
  GroupeUnites(label:'Pointures chaussures', description:'36→48',
      icon:Icons.straighten_rounded, type:TypeMesure.taille,
      unites:['36','37','38','39','40','41','42','43','44','45','46','47','48']),
  GroupeUnites(label:'Volume (liquides)', description:'ml, L…',
      icon:Icons.water_drop_rounded, type:TypeMesure.volume,
      unites:['25 ml','50 ml','100 ml','250 ml','500 ml','1 L','2 L','5 L','10 L','20 L']),
  GroupeUnites(label:'Poids (solides)', description:'g, kg…',
      icon:Icons.scale_rounded, type:TypeMesure.poids,
      unites:['100 g','250 g','500 g','1 kg','2 kg','5 kg','10 kg','25 kg','50 kg','100 kg','1 T']),
  GroupeUnites(label:'Pièces / Unités', description:'Boîte, Carton…',
      icon:Icons.widgets_rounded, type:TypeMesure.piece,
      unites:['Unité','Boîte x10','Boîte x20','Carton x50','Palette']),
];

GroupeUnites? groupeByLabel(String? label) =>
    label == null ? null : kGroupes.firstWhere((g) => g.label == label, orElse: () => kGroupes.first);

// ════════════════════════════════════════════════════════════════════════════
//  MODÈLES
// ════════════════════════════════════════════════════════════════════════════
class VarianteStock {
  String unite;
  int    quantite;
  VarianteStock({required this.unite, required this.quantite});
  VarianteStock clone() => VarianteStock(unite: unite, quantite: quantite);
}

class Produit {
  final String id;
  String nom, reference, categorie, magasin;
  bool   aVariantes;
  String? groupeUniteLabel;
  int    quantiteStock;
  List<VarianteStock> variantes;

  Produit({
    required this.id, required this.nom, required this.reference,
    required this.categorie, required this.magasin,
    required this.aVariantes, this.groupeUniteLabel,
    required this.quantiteStock, required this.variantes,
  });

  int  get total   => aVariantes ? variantes.fold(0, (s,v) => s + v.quantite) : quantiteStock;
  bool get rupture => total == 0;
  bool get bas     => total > 0 && total <= 5;
}

class LigneMouvement {
  String unite;
  int    quantite;
  LigneMouvement({required this.unite, required this.quantite});
}

class Mouvement {
  final String   id, type; // type: 'entree' | 'sortie'
  final String   produitId, nomProduit, reference, categorie, magasin;
  final bool     aVariantes;
  final String?  groupeUniteLabel;
  final int      quantite;
  final List<LigneMouvement> lignes;
  final DateTime date;
  final String?  preneurNom;

  const Mouvement({
    required this.id, required this.type,
    required this.produitId, required this.nomProduit,
    required this.reference, required this.categorie, required this.magasin,
    required this.aVariantes, this.groupeUniteLabel,
    required this.quantite, required this.lignes,
    required this.date, this.preneurNom,
  });

  int get totalQte => aVariantes ? lignes.fold(0, (s,l) => s + l.quantite) : quantite;
}

// ════════════════════════════════════════════════════════════════════════════
//  DONNÉES INITIALES
// ════════════════════════════════════════════════════════════════════════════
List<Produit> _initialProduits() => [
  Produit(id:'p1',  nom:'Casque de protection',   reference:'EPI-001', categorie:'EPI',   magasin:'A', aVariantes:false, quantiteStock:14, variantes:[]),
  Produit(id:'p2',  nom:'Jacket de sécurité',     reference:'EPI-002', categorie:'EPI',   magasin:'A', aVariantes:true,  groupeUniteLabel:'Tailles vestimentaires', quantiteStock:0,
      variantes:[VarianteStock(unite:'S',quantite:4), VarianteStock(unite:'M',quantite:6), VarianteStock(unite:'L',quantite:3)]),
  Produit(id:'p3',  nom:'Pantalon de travail',    reference:'EPI-003', categorie:'EPI',   magasin:'B', aVariantes:true,  groupeUniteLabel:'Tailles vestimentaires', quantiteStock:0,
      variantes:[VarianteStock(unite:'M',quantite:5), VarianteStock(unite:'L',quantite:5), VarianteStock(unite:'XL',quantite:2)]),
  Produit(id:'p4',  nom:'Chaussures de sécurité', reference:'EPI-004', categorie:'EPI',   magasin:'B', aVariantes:true,  groupeUniteLabel:'Pointures chaussures', quantiteStock:0,
      variantes:[VarianteStock(unite:'41',quantite:3), VarianteStock(unite:'42',quantite:4), VarianteStock(unite:'43',quantite:2)]),
  Produit(id:'p5',  nom:'Lunettes de protection', reference:'EPI-005', categorie:'EPI',   magasin:'C', aVariantes:false, quantiteStock:30, variantes:[]),
  Produit(id:'p6',  nom:'Masque panoramique',     reference:'EPI-006', categorie:'EPI',   magasin:'C', aVariantes:false, quantiteStock:4,  variantes:[]),
  Produit(id:'p7',  nom:'Moniteur',               reference:'INF-001', categorie:'Informatique', magasin:'D', aVariantes:false, quantiteStock:8,  variantes:[]),
  Produit(id:'p8',  nom:'Unité centrale',         reference:'INF-002', categorie:'Informatique', magasin:'D', aVariantes:false, quantiteStock:6,  variantes:[]),
  Produit(id:'p9',  nom:'Clavier',                reference:'INF-003', categorie:'Informatique', magasin:'D', aVariantes:false, quantiteStock:20, variantes:[]),
  Produit(id:'p10', nom:'Souris',                 reference:'INF-004', categorie:'Informatique', magasin:'D', aVariantes:false, quantiteStock:18, variantes:[]),
  Produit(id:'p11', nom:'Câble réseau',           reference:'INF-005', categorie:'Informatique', magasin:'D', aVariantes:false, quantiteStock:0,  variantes:[]),
];

// ════════════════════════════════════════════════════════════════════════════
//  ÉTAT GLOBAL — AppStore (passé par InheritedWidget)
// ════════════════════════════════════════════════════════════════════════════
class AppStore {
  final List<String>    cats;
  final List<Produit>   produits;
  final List<Mouvement> entrees;
  final List<Mouvement> sorties;
  final void Function(Mouvement)  addEntree;
  final void Function(Mouvement)  addSortie;
  final void Function(String)     delEntree;
  final void Function(String)     delSortie;
  final void Function(String)     addCat;

  const AppStore({
    required this.cats, required this.produits,
    required this.entrees, required this.sorties,
    required this.addEntree, required this.addSortie,
    required this.delEntree, required this.delSortie,
    required this.addCat,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  ROOT WIDGET
// ════════════════════════════════════════════════════════════════════════════
class GestionMagasin extends StatefulWidget {
  const GestionMagasin({super.key});
  @override State<GestionMagasin> createState() => _GestionMagasinState();
}

class _GestionMagasinState extends State<GestionMagasin> {
  List<String>    _cats     = ['EPI', 'Informatique'];
  List<Produit>   _produits = _initialProduits();
  List<Mouvement> _entrees  = [];
  List<Mouvement> _sorties  = [];
  int _tab = 0;

  // ── Entrée : incrémente le stock ──
  void _addEntree(Mouvement m) => setState(() {
    _entrees.add(m);
    final p = _produits.firstWhere((x) => x.id == m.produitId);
    if (p.aVariantes) {
      for (final lg in m.lignes) {
        final v = p.variantes.firstWhere((v) => v.unite == lg.unite,
            orElse: () { final nv = VarianteStock(unite: lg.unite, quantite: 0); p.variantes.add(nv); return nv; });
        v.quantite += lg.quantite;
      }
    } else {
      p.quantiteStock += m.quantite;
    }
  });

  // ── Sortie : décrémente le stock ──
  void _addSortie(Mouvement m) => setState(() {
    _sorties.add(m);
    final p = _produits.firstWhere((x) => x.id == m.produitId);
    if (p.aVariantes) {
      for (final lg in m.lignes) {
        final v = p.variantes.firstWhere((v) => v.unite == lg.unite,
            orElse: () => VarianteStock(unite: lg.unite, quantite: 0));
        v.quantite = (v.quantite - lg.quantite).clamp(0, 99999);
      }
    } else {
      p.quantiteStock = (p.quantiteStock - m.quantite).clamp(0, 99999);
    }
  });

  // ── Supprimer entrée → annule le stock ajouté ──
  void _delEntree(String id) => setState(() {
    final m = _entrees.firstWhere((x) => x.id == id);
    _entrees.removeWhere((x) => x.id == id);
    final p = _produits.firstWhere((x) => x.id == m.produitId);
    if (p.aVariantes) {
      for (final lg in m.lignes) {
        final v = p.variantes.firstWhere((v) => v.unite == lg.unite,
            orElse: () => VarianteStock(unite: lg.unite, quantite: 0));
        v.quantite = (v.quantite - lg.quantite).clamp(0, 99999);
      }
    } else {
      p.quantiteStock = (p.quantiteStock - m.quantite).clamp(0, 99999);
    }
  });

  // ── Supprimer sortie → restitue le stock ──
  void _delSortie(String id) => setState(() {
    final m = _sorties.firstWhere((x) => x.id == id);
    _sorties.removeWhere((x) => x.id == id);
    final p = _produits.firstWhere((x) => x.id == m.produitId);
    if (p.aVariantes) {
      for (final lg in m.lignes) {
        final v = p.variantes.firstWhere((v) => v.unite == lg.unite,
            orElse: () { final nv = VarianteStock(unite: lg.unite, quantite: 0); p.variantes.add(nv); return nv; });
        v.quantite += lg.quantite;
      }
    } else {
      p.quantiteStock += m.quantite;
    }
  });

  Widget _buildPage(AppStore store) {
    if (_tab == 1) return _EntreesPage(store: store, onRefresh: () => setState(() {}));
    if (_tab == 2) return _SortiesPage(store: store, onRefresh: () => setState(() {}));
    return _StockPage(store: store);
  }

  AppStore get _store => AppStore(
    cats: _cats, produits: _produits,
    entrees: _entrees, sorties: _sorties,
    addEntree: _addEntree, addSortie: _addSortie,
    delEntree: _delEntree, delSortie: _delSortie,
    addCat: (c) => setState(() => _cats.add(c)),
  );

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      backgroundColor: kBg,
      body: Row(children: [
        // ── Navigation verticale ──
        _SideNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
        // ── Contenu de la page ──
        Expanded(child: _buildPage(store)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SIDE NAV
// ════════════════════════════════════════════════════════════════════════════
class _SideNav extends StatelessWidget {
  final int current;
  final void Function(int) onTap;
  const _SideNav({required this.current, required this.onTap});

  @override Widget build(BuildContext context) {
    final icons  = <IconData>[Icons.inventory_2_rounded, Icons.arrow_circle_down_rounded, Icons.arrow_circle_up_rounded];
    final labels = <String>['Stock Actuel', 'Les Entrées', 'Les Sorties'];
    final colors = <Color>[kBlue, kGreen, kOrange];
    return Container(
    width: 90,
    decoration: const BoxDecoration(
    color: kSurface,
    border: Border(right: BorderSide(color: kBorder)),
    boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 10)],
    ),
    child: Column(children: [
    const SizedBox(height: 22),
    Container(
    width: 46, height: 46,
    decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(13)),
    child: const Icon(Icons.store_rounded, color: kBlue, size: 24),
    ),
    const SizedBox(height: 6),
    const Text('STOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kBlue, letterSpacing: 1.2)),
    const SizedBox(height: 20),
    const Divider(height: 1, color: kBorder),
    const SizedBox(height: 12),
    ...List.generate(icons.length, (i) {
    final sel = current == i;
    final col = colors[i];
    return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => onTap(i),
    child: AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
    color: sel ? col.withOpacity(0.11) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: sel ? Border.all(color: col.withOpacity(0.28), width: 1.5) : null,
    ),
    child: Column(children: [
    Icon(icons[i], color: sel ? col : kMuted, size: 22),
    const SizedBox(height: 5),
    Text(labels[i],
    textAlign: TextAlign.center,
    style: TextStyle(
    fontSize: 10, height: 1.3,
    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
    color: sel ? col : kMuted,
    ),
    ),
    ]),
    ),
    ),
    );
    }),
    ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE STOCK ACTUEL
// ════════════════════════════════════════════════════════════════════════════
class _StockPage extends StatefulWidget {
  final AppStore store;
  const _StockPage({required this.store});
  @override State<_StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<_StockPage> {
  String _q = '', _cat = 'Toutes', _mag = 'Tous', _sort = 'nom';
  bool   _asc = true;
  final  _sc  = TextEditingController();

  AppStore get s => widget.store;

  List<Produit> get _list {
    final q = _q.toLowerCase();
    var l = s.produits.where((p) {
      final mq = q.isEmpty || p.nom.toLowerCase().contains(q) || p.reference.toLowerCase().contains(q);
      final mc = _cat == 'Toutes' || p.categorie == _cat;
      final mm = _mag == 'Tous'   || p.magasin   == _mag;
      return mq && mc && mm;
    }).toList();
    l.sort((a, b) {
      int c;
      if (_sort == 'ref')        c = a.reference.compareTo(b.reference);
      else if (_sort == 'stock') c = a.total.compareTo(b.total);
      else if (_sort == 'mag')   c = a.magasin.compareTo(b.magasin);
      else                       c = a.nom.compareTo(b.nom);
      return _asc ? c : -c;
    });
    return l;
  }

  @override Widget build(BuildContext context) {
    final list  = _list;
    final total = s.produits.length;
    final rupt  = s.produits.where((p) => p.rupture).length;
    final bas   = s.produits.where((p) => p.bas).length;

    return Column(children: [
      // ── Header ──
      _Header(
        title: 'Stock Actuel',
        icon: Icons.inventory_2_rounded,
        color: kBlue,
        stats: [
          _Chip('$total produits',              kBlueLt,   kBlue,   Icons.inventory_2_outlined),
          _Chip('$rupt rupture${rupt>1?"s":""}', kRedLt,    kRed,    Icons.error_outline_rounded),
          _Chip('$bas bas',                      kOrangeLt, kOrange, Icons.warning_amber_rounded),
        ],
      ),

      // ── Filtres ──
      Padding(
        padding: const EdgeInsets.fromLTRB(kP, 14, kP, 0),
        child: Row(children: [
          Expanded(flex:3, child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v))),
          const SizedBox(width: 10),
          Expanded(flex:2, child: _DropBox(value: _cat, items: ['Toutes', ...s.cats], onChanged: (v) => setState(() => _cat = v))),
          const SizedBox(width: 10),
          Expanded(flex:2, child: _DropBox(value: _mag, items: ['Tous', ...kMagasins], onChanged: (v) => setState(() => _mag = v))),
          const SizedBox(width: 10),
          Expanded(flex:2, child: _DropBox(
            value: _sort,
            items: ['nom','ref','stock','mag'],
            labels: {'nom':'Nom','ref':'Référence','stock':'Stock','mag':'Magasin'},
            onChanged: (v) => setState(() => _sort = v),
          )),
          const SizedBox(width: 8),
          _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Tableau ──
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(kP, 0, kP, kP),
        child: _DataTable(
          count: '${list.length} / $total produits',
          empty: list.isEmpty,
          emptyMsg: 'Aucun produit trouvé',
          columns: const [
            _Col('NOM DU PRODUIT', flex: 3),
            _Col('RÉFÉRENCE',      flex: 2),
            _Col('CATÉGORIE',      flex: 2),
            _Col('STOCK',          flex: 1),
            _Col('MAGASIN',        flex: 1),
            _Col('VARIANTES',      flex: 3),
            _Col('',               flex: 1),
          ],
          rows: list.map((p) {
            final g = groupeByLabel(p.groupeUniteLabel);
            final stCol = p.rupture ? kRed : p.bas ? kOrange : kGreen;
            final stBg  = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
            return _StockRow(
              cells: [
                // Nom
                Row(children: [
                  Container(width:36, height:36, decoration:BoxDecoration(color:kBlueLt, borderRadius:BorderRadius.circular(8)), child:Icon(g?.icon??Icons.inventory_2_outlined, size:17, color:kBlue)),
                  const SizedBox(width:10),
                  Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start, mainAxisSize:MainAxisSize.min, children:[
                    Text(p.nom, style:const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:kText), overflow:TextOverflow.ellipsis),
                    if(g!=null) Text(g.label, style:_muted.copyWith(fontSize:10)),
                  ])),
                ]),
                // Référence
                Text(p.reference, style:_mono),
                // Catégorie
                _PillBadge(p.categorie, kBlueLt, kBlue),
                // Stock
                Center(child:Container(
                  padding:const EdgeInsets.symmetric(horizontal:10, vertical:5),
                  decoration:BoxDecoration(color:stBg, borderRadius:BorderRadius.circular(20)),
                  child:Text('${p.total}', style:TextStyle(fontSize:14, fontWeight:FontWeight.w800, color:stCol)),
                )),
                // Magasin
                Center(child:_PillBadge('Mag. ${p.magasin}', const Color(0xFFEEF1FF), const Color(0xFF4455AA))),
                // Variantes
                p.aVariantes ? Wrap(spacing:5, runSpacing:5,
                  children: p.variantes.map((v) {
                    final r=v.quantite==0; final l=v.quantite>0&&v.quantite<=3;
                    final cc = r?kRed:l?kOrange:kBlue;
                    final cb = r?kRedLt:l?kOrangeLt:kBlueLt;
                    return Container(
                      decoration:BoxDecoration(color:cb, borderRadius:BorderRadius.circular(7), border:Border.all(color:cc.withOpacity(0.2))),
                      child:IntrinsicWidth(child:Row(children:[
                        Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4), decoration:BoxDecoration(color:cc.withOpacity(0.1), borderRadius:const BorderRadius.horizontal(left:Radius.circular(6))), child:Text(v.unite, style:TextStyle(fontSize:11, fontWeight:FontWeight.w800, color:cc))),
                        Padding(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4), child:Text('${v.quantite}', style:TextStyle(fontSize:12, fontWeight:FontWeight.w900, color:cc))),
                      ])),
                    );
                  }).toList(),
                ) : const SizedBox.shrink(),
                // Détails
                Center(child:_IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () => _showDetails(p, g))),
              ],
            );
          }).toList(),
        ),
      )),
    ]);
  }

  void _showDetails(Produit p, GroupeUnites? g) {
    _showFullDialog(context, _DetailsDialog(produit: p, groupe: g));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ENTRÉES
// ════════════════════════════════════════════════════════════════════════════
class _EntreesPage extends StatefulWidget {
  final AppStore store;
  final VoidCallback onRefresh;
  const _EntreesPage({required this.store, required this.onRefresh});
  @override State<_EntreesPage> createState() => _EntreesPageState();
}

class _EntreesPageState extends State<_EntreesPage> {
  String _cat = 'Toutes', _mag = 'Tous';
  AppStore get s => widget.store;

  List<Mouvement> get _list => s.entrees.where((m) {
    final mc = _cat == 'Toutes' || m.categorie == _cat;
    final mm = _mag == 'Tous'   || m.magasin   == _mag;
    return mc && mm;
  }).toList().reversed.toList();

  @override Widget build(BuildContext context) {
    final list = _list;
    final totalUnites = s.entrees.fold(0, (acc, m) => acc + m.totalQte);
    return Column(children: [
      _Header(
        title: 'Les Entrées', icon: Icons.arrow_circle_down_rounded, color: kGreen,
        stats: [
          _Chip('${s.entrees.length} entrée${s.entrees.length>1?"s":""}', kGreenLt, kGreen, Icons.add_circle_outline_rounded),
          _Chip('$totalUnites unités reçues', kBlueLt, kBlue, Icons.inventory_2_outlined),
        ],
        action: _PrimaryBtn('Nouvelle entrée', Icons.add_rounded, kGreen, () => _openForm()),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(kP, 14, kP, 0),
        child: Row(children: [
          Expanded(flex:2, child: _DropBox(value:_cat, items:['Toutes',...s.cats], onChanged:(v)=>setState(()=>_cat=v))),
          const SizedBox(width:10),
          Expanded(flex:2, child: _DropBox(value:_mag, items:['Tous',...kMagasins], onChanged:(v)=>setState(()=>_mag=v))),
          const Spacer(flex:3),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(kP, 0, kP, kP),
        child: _DataTable(
          count: '${list.length} entrée${list.length>1?"s":""}',
          empty: list.isEmpty,
          emptyMsg: 'Aucune entrée — cliquez sur « Nouvelle entrée »',
          columns: const [
            _Col('DATE & HEURE',  flex:2),
            _Col('PRODUIT',       flex:3),
            _Col('RÉFÉRENCE',     flex:2),
            _Col('CATÉGORIE',     flex:2),
            _Col('MAGASIN',       flex:1),
            _Col('QUANTITÉ',      flex:3),
            _Col('',              flex:1),
          ],
          rows: list.map((m) => _MouvRow(
            m: m, color: kGreen, bgColor: kGreenLt,
            onEdit:   () => _openForm(existing: m),
            onDelete: () => _confirmDel(m, 'entree'),
          )).toList(),
        ),
      )),
    ]);
  }

  void _openForm({Mouvement? existing}) {
    _showFullDialog(context, _MouvForm(
      type: 'entree', store: s, existing: existing,
      onSave: (m) { if (existing != null) s.delEntree(existing.id); s.addEntree(m); widget.onRefresh(); },
    ));
  }

  void _confirmDel(Mouvement m, String type) {
    _showFullDialog(context, _ConfirmDel(
      nom: m.nomProduit,
      msg: 'Supprimer cette entrée ? Le stock sera décrémenté.',
      onConfirm: () { s.delEntree(m.id); widget.onRefresh(); Navigator.pop(context); },
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE SORTIES
// ════════════════════════════════════════════════════════════════════════════
class _SortiesPage extends StatefulWidget {
  final AppStore store;
  final VoidCallback onRefresh;
  const _SortiesPage({required this.store, required this.onRefresh});
  @override State<_SortiesPage> createState() => _SortiesPageState();
}

class _SortiesPageState extends State<_SortiesPage> {
  String _cat = 'Toutes', _mag = 'Tous';
  AppStore get s => widget.store;

  List<Mouvement> get _list => s.sorties.where((m) {
    final mc = _cat == 'Toutes' || m.categorie == _cat;
    final mm = _mag == 'Tous'   || m.magasin   == _mag;
    return mc && mm;
  }).toList().reversed.toList();

  @override Widget build(BuildContext context) {
    final list = _list;
    final totalUnites = s.sorties.fold(0, (acc, m) => acc + m.totalQte);
    return Column(children: [
      _Header(
        title: 'Les Sorties', icon: Icons.arrow_circle_up_rounded, color: kOrange,
        stats: [
          _Chip('${s.sorties.length} sortie${s.sorties.length>1?"s":""}', kOrangeLt, kOrange, Icons.remove_circle_outline_rounded),
          _Chip('$totalUnites unités sorties', kBlueLt, kBlue, Icons.inventory_2_outlined),
        ],
        action: _PrimaryBtn('Nouvelle sortie', Icons.add_rounded, kOrange, () => _openForm()),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(kP, 14, kP, 0),
        child: Row(children: [
          Expanded(flex:2, child: _DropBox(value:_cat, items:['Toutes',...s.cats], onChanged:(v)=>setState(()=>_cat=v))),
          const SizedBox(width:10),
          Expanded(flex:2, child: _DropBox(value:_mag, items:['Tous',...kMagasins], onChanged:(v)=>setState(()=>_mag=v))),
          const Spacer(flex:3),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(kP, 0, kP, kP),
        child: _DataTable(
          count: '${list.length} sortie${list.length>1?"s":""}',
          empty: list.isEmpty,
          emptyMsg: 'Aucune sortie — cliquez sur « Nouvelle sortie »',
          columns: const [
            _Col('DATE & HEURE',  flex:2),
            _Col('PRODUIT',       flex:3),
            _Col('RÉFÉRENCE',     flex:2),
            _Col('CATÉGORIE',     flex:2),
            _Col('MAGASIN',       flex:1),
            _Col('QUANTITÉ',      flex:3),
            _Col('PRÉLEVÉ PAR',   flex:2),
            _Col('',              flex:1),
          ],
          rows: list.map((m) => _MouvRow(
            m: m, color: kOrange, bgColor: kOrangeLt, showPreneur: true,
            onEdit:   () => _openForm(existing: m),
            onDelete: () => _confirmDel(m),
          )).toList(),
        ),
      )),
    ]);
  }

  void _openForm({Mouvement? existing}) {
    _showFullDialog(context, _MouvForm(
      type: 'sortie', store: s, existing: existing,
      onSave: (m) { if (existing != null) s.delSortie(existing.id); s.addSortie(m); widget.onRefresh(); },
    ));
  }

  void _confirmDel(Mouvement m) {
    _showFullDialog(context, _ConfirmDel(
      nom: m.nomProduit,
      msg: 'Supprimer cette sortie ? Le stock sera restitué.',
      onConfirm: () { s.delSortie(m.id); widget.onRefresh(); Navigator.pop(context); },
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FORMULAIRE MOUVEMENT — grand, pleine page
// ════════════════════════════════════════════════════════════════════════════
class _MouvForm extends StatefulWidget {
  final String type; // 'entree' | 'sortie'
  final AppStore store;
  final Mouvement? existing;
  final void Function(Mouvement) onSave;
  const _MouvForm({required this.type, required this.store, this.existing, required this.onSave});
  @override State<_MouvForm> createState() => _MouvFormState();
}

class _MouvFormState extends State<_MouvForm> {
  Produit?       _produit;
  GroupeUnites?  _groupe;
  final _qteC     = TextEditingController();
  final _preneurC = TextEditingController();
  final Map<String, TextEditingController> _varCtrl = {};
  final List<LigneMouvement> _lignes = [];
  final Set<String> _selVar = {};

  bool get _isSortie => widget.type == 'sortie';
  Color get _col     => _isSortie ? kOrange : kGreen;

  @override void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _produit    = widget.store.produits.firstWhere((p) => p.id == ex.produitId, orElse: () => widget.store.produits.first);
      _groupe     = groupeByLabel(ex.groupeUniteLabel);
      _preneurC.text = ex.preneurNom ?? '';
      _qteC.text     = ex.quantite > 0 ? '${ex.quantite}' : '';
      for (final lg in ex.lignes) {
        _selVar.add(lg.unite);
        _lignes.add(LigneMouvement(unite: lg.unite, quantite: lg.quantite));
        _varCtrl[lg.unite] = TextEditingController(text: '${lg.quantite}');
      }
    }
  }

  void _setProduit(Produit? p) => setState(() {
    _produit = p;
    _groupe  = groupeByLabel(p?.groupeUniteLabel);
    _selVar.clear(); _lignes.clear(); _varCtrl.clear();
    _qteC.clear();
  });

  void _toggleVar(String u) => setState(() {
    if (_selVar.contains(u)) {
      _selVar.remove(u);
      _lignes.removeWhere((l) => l.unite == u);
      _varCtrl.remove(u);
    } else {
      _selVar.add(u);
      _lignes.add(LigneMouvement(unite: u, quantite: 0));
      _varCtrl[u] = TextEditingController();
    }
  });

  void _save() {
    final p = _produit; if (p == null) return;
    for (final lg in _lignes) lg.quantite = int.tryParse(_varCtrl[lg.unite]?.text ?? '0') ?? 0;
    final m = Mouvement(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      type: widget.type,
      produitId: p.id, nomProduit: p.nom,
      reference: p.reference, categorie: p.categorie, magasin: p.magasin,
      aVariantes: p.aVariantes, groupeUniteLabel: p.groupeUniteLabel,
      quantite: p.aVariantes ? 0 : (int.tryParse(_qteC.text) ?? 0),
      lignes: List.from(_lignes),
      date: DateTime.now(),
      preneurNom: _isSortie ? _preneurC.text.trim() : null,
    );
    widget.onSave(m);
    Navigator.pop(context);
  }

  @override Widget build(BuildContext context) {
    final p = _produit;
    return _FullDialog(
      color: _col,
      icon:  _isSortie ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
      title: _isSortie ? 'Nouvelle Sortie de Stock' : 'Nouvelle Entrée de Stock',
      onSave: _produit == null ? null : _save,
      saveLabel: _isSortie ? 'Valider la sortie' : "Valider l'entrée",
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Sélection du produit ──
        _FLabel('Produit concerné'),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
          child: DropdownButtonHideUnderline(child: DropdownButton<Produit>(
            value: p,
            hint: const Text('Sélectionner un produit', style: TextStyle(fontSize: 13, color: kMuted)),
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue),
            items: widget.store.produits.map((pr) => DropdownMenuItem(
              value: pr,
              child: Row(children: [
                _PillBadge(pr.reference, kBlueLt, kBlue),
                const SizedBox(width: 10),
                Expanded(child: Text(pr.nom, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _PillBadge('Mag.${pr.magasin}', const Color(0xFFEEF1FF), const Color(0xFF4455AA)),
                const SizedBox(width: 6),
                _StockPill(pr),
              ]),
            )).toList(),
            onChanged: _setProduit,
          )),
        ),

        // ── Infos produit sélectionné ──
        if (p != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kBlueLt.withOpacity(0.4), borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
            child: Row(children: [
              _InfoTile(Icons.category_outlined,    'Catégorie',  p.categorie),
              const SizedBox(width: 24),
              _InfoTile(Icons.warehouse_rounded,    'Magasin',    'Magasin ${p.magasin}'),
              const SizedBox(width: 24),
              _InfoTile(Icons.inventory_2_outlined, 'Stock actuel','${p.total} unité${p.total>1?"s":""}',
                  col: p.rupture ? kRed : p.bas ? kOrange : kGreen),
              if (_isSortie) ...[
                const SizedBox(width: 24),
                _InfoTile(Icons.trending_down_rounded, 'Disponible', '${p.total}', col: p.rupture ? kRed : kText),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // ── Quantité / Variantes ──
          if (!p.aVariantes) ...[
            _FLabel(_isSortie ? 'Quantité à sortir' : 'Quantité à ajouter'),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: _NumField(_qteC, hint: _isSortie ? 'Ex: 5' : 'Ex: 10'),
            ),
          ] else if (_groupe != null) ...[
            Row(children: [
              Icon(_groupe!.icon, size: 15, color: _col),
              const SizedBox(width: 7),
              Text(_isSortie ? 'Variantes à sortir' : 'Variantes à ajouter',
                  style: _label.copyWith(color: _col, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            // Chips de sélection
            Wrap(spacing: 8, runSpacing: 8, children: _groupe!.unites.map((u) {
              final sel = _selVar.contains(u);
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _toggleVar(u),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _col : kSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? _col : kBorder, width: sel ? 2 : 1),
                  ),
                  child: Text(u, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : kMuted)),
                ),
              );
            }).toList()),

            // Tableau saisie
            if (_lignes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _VarTable(lignes: _lignes, ctrls: _varCtrl, color: _col, onRemove: _toggleVar,
                  onChanged: (u, v) => setState(() {})),
            ],
          ],

          // ── Prélevé par (sortie uniquement) ──
          if (_isSortie) ...[
            const SizedBox(height: 20),
            _FLabel('Prélevé par'),
            const SizedBox(height: 8),
            _TextField(_preneurC, 'Nom et prénom de la personne',
                prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted)),
          ],
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  TABLEAU VARIANTES dans le formulaire
// ════════════════════════════════════════════════════════════════════════════
class _VarTable extends StatefulWidget {
  final List<LigneMouvement> lignes;
  final Map<String, TextEditingController> ctrls;
  final Color color;
  final void Function(String) onRemove;
  final void Function(String, int) onChanged;
  const _VarTable({required this.lignes, required this.ctrls, required this.color,
    required this.onRemove, required this.onChanged});
  @override State<_VarTable> createState() => _VarTableState();
}

class _VarTableState extends State<_VarTable> {
  @override Widget build(BuildContext context) {
    final col = widget.color;
    return Container(
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: Column(children: [
        // En-tête
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(color: col.withOpacity(0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(kR))),
          child: Row(children: [
            SizedBox(width:120, child: Text('UNITÉ',    style: _label.copyWith(color: col))),
            const SizedBox(width: 12),
            Expanded(          child: Text('QUANTITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 44),
          ]),
        ),
        // Lignes
        ...widget.lignes.asMap().entries.map((e) {
          final i = e.key; final lg = e.value;
          final ctrl = widget.ctrls[lg.unite]!;
          return Column(children: [
            if (i > 0) const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(children: [
                // Badge unité
                Container(
                  width: 120, height: 40, alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(8)),
                  child: Text(lg.unite, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                // Stepper + champ
                Expanded(child: Row(children: [
                  _StepBtn(Icons.remove_rounded, col, () {
                    final v = int.tryParse(ctrl.text) ?? 0;
                    if (v > 0) { ctrl.text = '${v-1}'; setState(() => lg.quantite = v-1); }
                  }),
                  Expanded(child: SizedBox(height: 44, child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText),
                    decoration: InputDecoration(
                      hintText: '0', hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBCCDD)),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: col, width: 2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: kBorder)),
                    ),
                    onChanged: (s) => setState(() => lg.quantite = int.tryParse(s) ?? 0),
                  ))),
                  _StepBtn(Icons.add_rounded, col, () {
                    final v = int.tryParse(ctrl.text) ?? 0;
                    ctrl.text = '${v+1}'; setState(() => lg.quantite = v+1);
                  }),
                ])),
                const SizedBox(width: 8),
                // Supprimer
                InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => widget.onRemove(lg.unite),
                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.close_rounded, size: 16, color: kRed)),
                ),
              ]),
            ),
          ]);
        }),
        // Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(color: col.withOpacity(0.07), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kR))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL', style: _label.copyWith(color: col)),
            Text('${widget.lignes.fold(0,(s,l)=>s+l.quantite)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: col)),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DIALOG DÉTAILS PRODUIT
// ════════════════════════════════════════════════════════════════════════════
class _DetailsDialog extends StatelessWidget {
  final Produit produit;
  final GroupeUnites? groupe;
  const _DetailsDialog({required this.produit, this.groupe});

  @override Widget build(BuildContext context) {
    final p = produit; final g = groupe;
    final sc = p.rupture ? kRed : p.bas ? kOrange : kGreen;
    final sb = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
    return _FullDialog(
      color: kBlue,
      icon: g?.icon ?? Icons.inventory_2_rounded,
      title: p.nom,
      saveLabel: 'Fermer',
      onSave: () => Navigator.pop(context),
      showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Infos générales
        _DetRow(Icons.qr_code_rounded,      'Référence',   p.reference),
        _DetRow(Icons.category_outlined,    'Catégorie',   p.categorie),
        _DetRow(Icons.warehouse_rounded,    'Magasin',     'Magasin ${p.magasin}'),
        if (g != null) _DetRow(g.icon,     'Type mesure', g.label),
        const SizedBox(height: 14),
        // Badge stock total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(kR), border: Border.all(color: sc.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, color: sc, size: 20),
            const SizedBox(width: 10),
            Text('${p.total} unité${p.total>1?"s":""}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: sc)),
            const SizedBox(width: 10),
            Text(p.rupture ? '— Rupture de stock' : p.bas ? '— Stock bas' : '— En stock',
                style: TextStyle(fontSize: 12, color: sc.withOpacity(0.75))),
          ]),
        ),
        // Tableau variantes
        if (p.aVariantes && p.variantes.isNotEmpty) ...[
          const SizedBox(height: 20),
          Row(children: [
            if (g != null) Icon(g.icon, size: 15, color: kBlue),
            const SizedBox(width: 7),
            Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
            child: ClipRRect(borderRadius: BorderRadius.circular(kR), child: Column(children: [
              Container(color: kBlueLt, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(children: [
                    Expanded(flex:2, child: Text('UNITÉ',    style: _label.copyWith(color: kBlue))),
                    Expanded(flex:2, child: Text('QUANTITÉ', style: _label.copyWith(color: kBlue))),
                    Expanded(flex:1, child: Text('STATUT',   style: _label.copyWith(color: kBlue))),
                  ])),
              ...p.variantes.asMap().entries.map((e) {
                final v = e.value;
                final r = v.quantite == 0; final l = v.quantite > 0 && v.quantite <= 3;
                final vc = r ? kRed : l ? kOrange : kGreen;
                final vb = r ? kRedLt : l ? kOrangeLt : kGreenLt;
                return Column(children: [
                  if (e.key > 0) const Divider(height: 1, color: kBorder),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Row(children: [
                    Expanded(flex:2, child: Align(alignment: Alignment.centerLeft, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(8)),
                      child: Text(v.unite, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    ))),
                    Expanded(flex:2, child: Text('${v.quantite}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: vc))),
                    Expanded(flex:1, child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: vb, borderRadius: BorderRadius.circular(20)),
                      child: Text(r ? 'Rupture' : l ? 'Bas' : 'OK', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: vc)),
                    )),
                  ])),
                ]);
              }),
              Container(color: kBlueLt, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

// ════════════════════════════════════════════════════════════════════════════
//  CONFIRM DELETE
// ════════════════════════════════════════════════════════════════════════════
class _ConfirmDel extends StatelessWidget {
  final String nom, msg;
  final VoidCallback onConfirm;
  const _ConfirmDel({required this.nom, required this.msg, required this.onConfirm});

  @override Widget build(BuildContext context) => _FullDialog(
    color: kRed,
    icon: Icons.delete_outline_rounded,
    title: 'Confirmer la suppression',
    saveLabel: 'Supprimer',
    onSave: onConfirm,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kRed.withOpacity(0.2))),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: kRed, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
            const SizedBox(height: 4),
            Text(msg, style: _muted),
          ])),
        ]),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  FULL DIALOG — conteneur réutilisable, grande taille
// ════════════════════════════════════════════════════════════════════════════
class _FullDialog extends StatelessWidget {
  final Color      color;
  final IconData   icon;
  final String     title, saveLabel;
  final VoidCallback? onSave;
  final Widget     child;
  final bool       showCancel;
  const _FullDialog({
    required this.color, required this.icon, required this.title,
    required this.saveLabel, required this.onSave, required this.child,
    this.showCancel = true,
  });

  @override Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(60, 30, 60, 30),
          constraints: const BoxConstraints(maxWidth: 860),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(9)),
                    child: Icon(icon, color: Colors.white, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
                ),
              ]),
            ),
            // ── Body ──
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(kP),
              child: child,
            )),
            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFF),
                border: Border(top: BorderSide(color: kBorder)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (showCancel) ...[
                  TextButton(
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler', style: TextStyle(fontSize: 13, color: kMuted)),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: onSave,
                  icon: Icon(icon, size: 16),
                  label: Text(saveLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ROW MOUVEMENT (Entrées & Sorties)
// ════════════════════════════════════════════════════════════════════════════
class _MouvRow extends _DataRow {
  final Mouvement m;
  final Color     color, bgColor;
  final bool      showPreneur;
  final VoidCallback onEdit, onDelete;

  const _MouvRow({
    required this.m, required this.color, required this.bgColor,
    this.showPreneur = false,
    required this.onEdit, required this.onDelete,
  }) : super(cells: const []);

  @override List<Widget> get cells {
    final date = '${m.date.day.toString().padLeft(2,'0')}/${m.date.month.toString().padLeft(2,'0')}/${m.date.year}';
    final hour = '${m.date.hour.toString().padLeft(2,'0')}:${m.date.minute.toString().padLeft(2,'0')}';
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
        Text(hour, style: _muted.copyWith(fontSize: 11)),
      ]),
      Text(m.nomProduit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis),
      Text(m.reference, style: _mono),
      _PillBadge(m.categorie, kBlueLt, kBlue),
      Center(child: _PillBadge('Mag.${m.magasin}', const Color(0xFFEEF1FF), const Color(0xFF4455AA))),
      m.aVariantes
          ? Wrap(spacing: 4, runSpacing: 4, children: m.lignes.map((l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.2))),
        child: Text('${l.unite} ×${l.quantite}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      )).toList())
          : Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Text('${m.quantite}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ),
      if (showPreneur)
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline_rounded, size: 14, color: kMuted),
          const SizedBox(width: 5),
          Flexible(child: Text(m.preneurNom ?? '—', style: const TextStyle(fontSize: 12, color: kText), overflow: TextOverflow.ellipsis)),
        ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, onEdit),
        const SizedBox(width: 5),
        _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
      ]),
    ];
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DATA TABLE générique
// ════════════════════════════════════════════════════════════════════════════
class _Col {
  final String label;
  final int    flex;
  const _Col(this.label, {this.flex = 1});
}

class _DataRow {
  final List<Widget> cells;
  const _DataRow({required this.cells});
}

class _StockRow extends _DataRow {
  const _StockRow({required super.cells});
}

class _DataTable extends StatelessWidget {
  final List<_Col>     columns;
  final List<_DataRow> rows;
  final String         count;
  final bool           empty;
  final String         emptyMsg;

  const _DataTable({
    required this.columns, required this.rows,
    required this.count, required this.empty,
    this.emptyMsg = 'Aucun résultat',
  });

  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kR2),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: kBlue.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kR2),
        child: Column(children: [
          // En-tête
          Container(
            color: kBlueLt,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: columns.map((c) => Expanded(flex: c.flex, child:
            Text(c.label, style: _label),
            )).toList()),
          ),
          const Divider(height: 1, color: kBorder),
          // Corps
          Expanded(child: empty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: kBlueMd),
            const SizedBox(height: 12),
            Text(emptyMsg, style: _muted),
          ]))
              : ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
            itemBuilder: (_, i) => _DataRowWidget(row: rows[i], columns: columns),
          ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            color: const Color(0xFFF7FAFF),
            child: Text(count, style: _muted),
          ),
        ]),
      ),
    );
  }
}

class _DataRowWidget extends StatefulWidget {
  final _DataRow   row;
  final List<_Col> columns;
  const _DataRowWidget({required this.row, required this.columns});
  @override State<_DataRowWidget> createState() => _DataRowWidgetState();
}

class _DataRowWidgetState extends State<_DataRowWidget> {
  bool _hov = false;
  @override Widget build(BuildContext context) {
    final cells = widget.row.cells;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hov ? const Color(0xFFF3F8FF) : kSurface,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(
            widget.columns.length,
                (i) => Expanded(
              flex: widget.columns[i].flex,
              child: i < cells.length ? cells[i] : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ATOMS
// ════════════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String title; final IconData icon; final Color color;
  final List<Widget> stats; final Widget? action;
  const _Header({required this.title, required this.icon, required this.color, required this.stats, this.action});

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 16),
    decoration: const BoxDecoration(color: kSurface, boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0,2))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20)),
      const SizedBox(width: 12),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
      const SizedBox(width: 20),
      ...stats.expand((w) => [w, const SizedBox(width: 8)]),
      const Spacer(),
      if (action != null) action!,
    ]),
  );
}

class _Chip extends StatelessWidget {
  final String label; final Color bg, col; final IconData icon;
  const _Chip(this.label, this.bg, this.col, this.icon);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: col), const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
    ]),
  );
}

class _PillBadge extends StatelessWidget {
  final String text; final Color bg, col;
  const _PillBadge(this.text, this.bg, this.col);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col), overflow: TextOverflow.ellipsis),
  );
}

class _StockPill extends StatelessWidget {
  final Produit p;
  const _StockPill(this.p);
  @override Widget build(BuildContext context) {
    final col = p.rupture ? kRed : p.bas ? kOrange : kGreen;
    final bg  = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text('${p.total}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: col)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final String tip; final Color bg, col; final VoidCallback fn;
  const _IconBtn(this.icon, this.tip, this.bg, this.col, this.fn);
  @override Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: InkWell(borderRadius: BorderRadius.circular(7), onTap: fn,
        child: Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 16, color: col))),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _PrimaryBtn(this.label, this.icon, this.color, this.onTap);
  @override Widget build(BuildContext context) => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    icon: Icon(icon, size: 16), label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    onPressed: onTap,
  );
}

class _SearchBox extends StatelessWidget {
  final TextEditingController ctrl; final String value; final void Function(String) onChanged;
  const _SearchBox({required this.ctrl, required this.value, required this.onChanged});
  @override Widget build(BuildContext context) => SizedBox(height: 40, child: TextField(
    controller: ctrl, style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: 'Rechercher…', hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBCCDD)),
      prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 17),
      suffixIcon: value.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 15), onPressed: () { ctrl.clear(); onChanged(''); }) : null,
      filled: true, fillColor: kSurface, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
    ),
    onChanged: onChanged,
  ));
}

class _DropBox extends StatelessWidget {
  final String value; final List<String> items; final Map<String,String>? labels;
  final void Function(String) onChanged;
  const _DropBox({required this.value, required this.items, required this.onChanged, this.labels});
  @override Widget build(BuildContext context) => Container(
    height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true, style: const TextStyle(fontSize: 13, color: kText),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 17),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(labels?[v] ?? v))).toList(),
      onChanged: (v) => onChanged(v!),
    )),
  );
}

class _AscBtn extends StatelessWidget {
  final bool asc; final VoidCallback onTap;
  const _AscBtn({required this.asc, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(kR), onTap: onTap,
    child: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBlueMd.withOpacity(0.5))),
        child: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: kBlue, size: 16)),
  );
}

class _FLabel extends StatelessWidget {
  final String text;
  const _FLabel(this.text);
  @override Widget build(BuildContext context) => Text(text.toUpperCase(), style: _label.copyWith(fontSize: 11, letterSpacing: 0.7));
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl; final String hint;
  const _NumField(this.ctrl, {required this.hint});
  @override Widget build(BuildContext context) => SizedBox(height: 50, child: TextField(
    controller: ctrl, keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kText),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBCCDD)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
    ),
  ));
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final Widget? prefix;
  const _TextField(this.ctrl, this.hint, {this.prefix});
  @override Widget build(BuildContext context) => TextField(
    controller: ctrl, style: const TextStyle(fontSize: 13, color: kText),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBCCDD)),
      prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      filled: true, fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
    ),
  );
}

class _StepBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _StepBtn(this.icon, this.color, this.onTap);
  @override Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
        child: Icon(icon, color: color, size: 18)),
  );
}

class _DetRow extends StatelessWidget {
  final IconData icon; final String label, val;
  const _DetRow(this.icon, this.label, this.val);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(7)), child: Icon(icon, color: kBlue, size: 15)),
      const SizedBox(width: 12),
      Text('$label :', style: _muted), const SizedBox(width: 6),
      Flexible(child: Text(val, style: _h2)),
    ]),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, val; final Color? col;
  const _InfoTile(this.icon, this.label, this.val, {this.col});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 15, color: kBlue),
    const SizedBox(width: 7),
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: _label),
      Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: col ?? kText)),
    ]),
  ]);
}

// Helper — afficher un _FullDialog en plein écran avec showGeneralDialog
void _showFullDialog(BuildContext context, Widget dialog) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.03), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
    pageBuilder: (_, __, ___) => dialog,
  );
}