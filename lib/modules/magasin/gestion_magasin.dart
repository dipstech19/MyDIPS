import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════════════════════════

const Color kBlue       = Color(0xFF328EEE);
const Color kBlueDark   = Color(0xFF1A6FCA);
const Color kBlueLight  = Color(0xFFE8F3FD);
const Color kBlueMid    = Color(0xFFB3D6F9);
const Color kBg         = Color(0xFFF0F4FA);
const Color kSurface    = Colors.white;
const Color kText       = Color(0xFF0F1D2E);
const Color kTextMuted  = Color(0xFF6B7A90);
const Color kBorder     = Color(0xFFE2EAF4);

const _tsH1    = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText, letterSpacing: -0.2);
const _tsH2    = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText);
const _tsMuted = TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: kTextMuted);
const _tsLabel = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMuted, letterSpacing: 0.4);
const _tsBtn   = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kSurface);
const _tsMono  = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextMuted, fontFamily: 'monospace');

const double kRadius  = 10;
const double kRadius2 = 14;
const double kPadH    = 28;

const List<String> kMagasins = ['A', 'B', 'C', 'D'];

// ═══════════════════════════════════════════════════════════════════════════════
//  SYSTÈME D'UNITÉS DE MESURE
// ═══════════════════════════════════════════════════════════════════════════════

enum TypeMesure { taille, volume, poids, piece }

class GroupeUnites {
  final String label;
  final IconData icon;
  final String description;
  final TypeMesure type;
  final List<String> unites;

  const GroupeUnites({
    required this.label,
    required this.icon,
    required this.description,
    required this.type,
    required this.unites,
  });
}

const List<GroupeUnites> kGroupesUnites = [
  GroupeUnites(
    label: 'Tailles vestimentaires',
    icon: Icons.checkroom_rounded,
    description: 'XS, S, M, L…',
    type: TypeMesure.taille,
    unites: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'],
  ),
  GroupeUnites(
    label: 'Pointures chaussures',
    icon: Icons.straighten_rounded,
    description: '36 à 48',
    type: TypeMesure.taille,
    unites: ['36','37','38','39','40','41','42','43','44','45','46','47','48'],
  ),
  GroupeUnites(
    label: 'Volume (liquides)',
    icon: Icons.water_drop_rounded,
    description: 'ml, L, cl…',
    type: TypeMesure.volume,
    unites: ['25 ml','50 ml','100 ml','200 ml','250 ml','500 ml','1 L','2 L','5 L','10 L','20 L'],
  ),
  GroupeUnites(
    label: 'Poids (solides)',
    icon: Icons.scale_rounded,
    description: 'g, kg, T…',
    type: TypeMesure.poids,
    unites: ['100 g','250 g','500 g','1 kg','2 kg','5 kg','10 kg','25 kg','50 kg','100 kg','1 T'],
  ),
  GroupeUnites(
    label: 'Pièces / Unités',
    icon: Icons.widgets_rounded,
    description: 'Boîte, Carton…',
    type: TypeMesure.piece,
    unites: ['Unité','Boîte x10','Boîte x20','Carton x50','Palette'],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════════
//  MODÈLES
// ═══════════════════════════════════════════════════════════════════════════════

class TailleStock {
  String unite;
  int    quantite;
  TailleStock({required this.unite, required this.quantite});
}

class Produit {
  final  String id;
  String nom, reference, categorie, magasin;
  bool   aVariantes;
  String? groupeUniteLabel; // libellé du GroupeUnites choisi
  int    quantiteStock;
  List<TailleStock> stockParVariante;

  Produit({
    required this.id, required this.nom, required this.reference,
    required this.categorie, required this.magasin,
    required this.aVariantes, this.groupeUniteLabel,
    required this.quantiteStock,
    required this.stockParVariante,
  });

  int  get totalStock => aVariantes
      ? stockParVariante.fold(0, (s, t) => s + t.quantite)
      : quantiteStock;
  bool get isRupture => totalStock == 0;
  bool get isLow     => totalStock > 0 && totalStock <= 5;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════════

class GestionMagasin extends StatefulWidget {
  const GestionMagasin({super.key});
  @override State<GestionMagasin> createState() => _GestionMagasinState();
}

class _GestionMagasinState extends State<GestionMagasin> {

  List<String> _cats = ['EPI', 'Informatique'];

  final List<Produit> _all = [
    // ── EPI ──
    Produit(id:'1',  nom:'Casque de protection',   reference:'EPI-001', categorie:'EPI',
        aVariantes:false, quantiteStock:14, stockParVariante:[], magasin:'A'),
    Produit(id:'2',  nom:'Jacket de sécurité',     reference:'EPI-002', categorie:'EPI',
        aVariantes:true,  groupeUniteLabel:'Tailles vestimentaires', quantiteStock:0,
        stockParVariante:[TailleStock(unite:'S',quantite:4),TailleStock(unite:'M',quantite:6),TailleStock(unite:'L',quantite:3)],
        magasin:'A'),
    Produit(id:'3',  nom:'Pantalon de travail',    reference:'EPI-003', categorie:'EPI',
        aVariantes:true,  groupeUniteLabel:'Tailles vestimentaires', quantiteStock:0,
        stockParVariante:[TailleStock(unite:'M',quantite:5),TailleStock(unite:'L',quantite:5),TailleStock(unite:'XL',quantite:2)],
        magasin:'B'),
    Produit(id:'4',  nom:'Chaussures de sécurité', reference:'EPI-004', categorie:'EPI',
        aVariantes:true,  groupeUniteLabel:'Pointures chaussures', quantiteStock:0,
        stockParVariante:[TailleStock(unite:'41',quantite:3),TailleStock(unite:'42',quantite:4),TailleStock(unite:'43',quantite:2)],
        magasin:'B'),
    Produit(id:'5',  nom:'Lunettes de protection', reference:'EPI-005', categorie:'EPI',
        aVariantes:false, quantiteStock:30, stockParVariante:[], magasin:'C'),
    Produit(id:'6',  nom:'Masque panoramique',     reference:'EPI-006', categorie:'EPI',
        aVariantes:false, quantiteStock:4, stockParVariante:[], magasin:'C'),
    // ── Informatique ──
    Produit(id:'7',  nom:'Moniteur',        reference:'INF-001', categorie:'Informatique',
        aVariantes:false, quantiteStock:8, stockParVariante:[], magasin:'D'),
    Produit(id:'8',  nom:'Unité centrale',  reference:'INF-002', categorie:'Informatique',
        aVariantes:false, quantiteStock:6, stockParVariante:[], magasin:'D'),
    Produit(id:'9',  nom:'Clavier',         reference:'INF-003', categorie:'Informatique',
        aVariantes:false, quantiteStock:20, stockParVariante:[], magasin:'D'),
    Produit(id:'10', nom:'Souris',          reference:'INF-004', categorie:'Informatique',
        aVariantes:false, quantiteStock:18, stockParVariante:[], magasin:'D'),
    Produit(id:'11', nom:'Câble réseau',    reference:'INF-005', categorie:'Informatique',
        aVariantes:false, quantiteStock:0, stockParVariante:[], magasin:'D'),
  ];

  List<Produit> _filtered  = [];
  String _search = '', _selCat = 'Toutes', _sortBy = 'nom';
  bool   _asc    = true;
  final  _searchCtrl = TextEditingController();

  List<String> get _catsFilter => ['Toutes', ..._cats];

  int _mi(int a, int b) => a < b ? a : b;

  String _genRef(String cat) {
    final px = cat.substring(0, _mi(3, cat.length)).toUpperCase().replaceAll(' ','');
    final nums = _all.where((p) => p.reference.startsWith(px))
        .map((p) { final s = p.reference.split('-'); return s.length==2?(int.tryParse(s[1])??0):0; }).toList();
    final n = nums.isEmpty ? 1 : nums.reduce((a,b)=>a>b?a:b)+1;
    return '$px-${n.toString().padLeft(3,'0')}';
  }

  @override void initState() { super.initState(); _applyFilters(); }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((p) {
        final ms = _search.isEmpty ||
            p.nom.toLowerCase().contains(_search.toLowerCase()) ||
            p.reference.toLowerCase().contains(_search.toLowerCase());
        final mc = _selCat == 'Toutes' || p.categorie == _selCat;
        return ms && mc;
      }).toList();
      _filtered.sort((a,b){
        int c;
        switch(_sortBy){
          case 'reference':     c=a.reference.compareTo(b.reference); break;
          case 'quantiteStock': c=a.totalStock.compareTo(b.totalStock); break;
          default:              c=a.nom.compareTo(b.nom);
        }
        return _asc?c:-c;
      });
    });
  }

  List<String> _nomsCat(String cat) =>
      _all.where((p)=>p.categorie==cat).map((p)=>p.nom).toSet().toList()..sort();

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOG FORMULAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  void _openDialog({Produit? p}) {
    final isEdit = p != null;
    String  cat        = p?.categorie ?? _cats.first;
    final   nomC       = TextEditingController(text: p?.nom ?? '');
    final   refC       = TextEditingController(text: p?.reference ?? _genRef(cat));
    bool    aVariantes = p?.aVariantes ?? false;
    final   qteC       = TextEditingController(text: p!=null&&!p.aVariantes?p.quantiteStock.toString():'');
    String  mag        = p?.magasin ?? 'A';

    // Groupe d'unités sélectionné
    GroupeUnites? selGroupe = p?.groupeUniteLabel != null
        ? kGroupesUnites.firstWhere((g)=>g.label==p!.groupeUniteLabel, orElse:()=>kGroupesUnites.first)
        : null;

    final List<TailleStock>              variantes = p?.aVariantes==true
        ? p!.stockParVariante.map((t)=>TailleStock(unite:t.unite,quantite:t.quantite)).toList() : [];
    final Set<String>                    selV      = variantes.map((t)=>t.unite).toSet();
    final Map<String,TextEditingController> ctrlV  = {for(var t in variantes) t.unite:TextEditingController(text:t.quantite>0?t.quantite.toString():'')};
    final newCatC = TextEditingController();

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {

        void toggleV(String u) => ss((){
          if(selV.contains(u)){selV.remove(u);variantes.removeWhere((x)=>x.unite==u);ctrlV.remove(u);}
          else{selV.add(u);variantes.add(TailleStock(unite:u,quantite:0));ctrlV[u]=TextEditingController();}
        });

        void onCat(String c) => ss((){cat=c;if(!isEdit){refC.text=_genRef(c);nomC.clear();}});

        void onGroupeChanged(GroupeUnites? g) => ss((){
          selGroupe=g;
          // Nettoyer les variantes si on change de groupe
          selV.clear(); variantes.clear(); ctrlV.clear();
        });

        void addCatDlg() => showDialog(context:ctx, builder:(c2)=>Dialog(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(kRadius2)),
          child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Nouvelle catégorie',style:_tsH1),
            const SizedBox(height:14),
            _input(ctrl:newCatC,hint:'Ex: Produits chimiques',icon:const Icon(Icons.category_outlined,color:kBlue,size:18)),
            const SizedBox(height:18),
            Row(mainAxisAlignment:MainAxisAlignment.end,children:[
              _textBtn('Annuler',()=>Navigator.pop(c2)),
              const SizedBox(width:8),
              _solidBtn('Ajouter',(){
                final c=newCatC.text.trim();
                if(c.isNotEmpty&&!_cats.contains(c)){setState(()=>_cats.add(c));onCat(c);}
                newCatC.clear(); Navigator.pop(c2);
              }),
            ]),
          ])),
        ));

        return Dialog(
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
          insetPadding:const EdgeInsets.symmetric(horizontal:80,vertical:40),
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:700, maxHeight:860),
            child:Column(mainAxisSize:MainAxisSize.min,children:[

              _dlgHeader(isEdit?'Modifier le produit':'Ajouter un produit',
                  isEdit?Icons.edit_rounded:Icons.add_circle_outline_rounded),

              Flexible(child:SingleChildScrollView(
                padding:const EdgeInsets.fromLTRB(kPadH,22,kPadH,8),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[

                  // ─ 1. Catégorie ─
                  _fieldLabel('Catégorie'),
                  const SizedBox(height:6),
                  Row(children:[
                    Expanded(child:_dropdownField(
                      value:_cats.contains(cat)?cat:_cats.first,
                      items:_cats, onChanged:onCat,
                    )),
                    const SizedBox(width:8),
                    _iconBtn(Icons.add_rounded,addCatDlg,tooltip:'Nouvelle catégorie'),
                  ]),

                  // Produits existants ou catégorie vide
                  if(!isEdit)...[
                    const SizedBox(height:10),
                    if(_nomsCat(cat).isNotEmpty)
                      _existantsCard(_nomsCat(cat),nomC,ss,cat)
                    else
                      _emptyCategCard(cat),
                  ],

                  const SizedBox(height:16),

                  // ─ 2. Nom ─
                  _fieldLabel('Nom du produit'),
                  const SizedBox(height:6),
                  _input(ctrl:nomC,hint:'Ex: Casque de protection'),

                  const SizedBox(height:16),

                  // ─ 3. Référence ─
                  _fieldLabel('Référence (auto-générée)'),
                  const SizedBox(height:6),
                  _input(ctrl:refC,hint:'EPI-001',
                    suffix:Tooltip(message:'Régénérer',child:InkWell(
                      borderRadius:BorderRadius.circular(8),
                      onTap:()=>ss(()=>refC.text=_genRef(cat)),
                      child:const Padding(padding:EdgeInsets.all(10),
                          child:Icon(Icons.refresh_rounded,size:16,color:kBlue)),
                    )),
                  ),

                  const SizedBox(height:16),

                  // ─ 4. Quantité / Variantes ─
                  _fieldLabel('Quantité en stock'),
                  const SizedBox(height:6),
                  _buildStockSection(
                    aVariantes: aVariantes,
                    selGroupe: selGroupe,
                    variantes: variantes,
                    selV: selV,
                    ctrlV: ctrlV,
                    qteC: qteC,
                    toggleV: toggleV,
                    onToggle: ()=>ss((){
                      aVariantes=!aVariantes;
                      if(!aVariantes){variantes.clear();selV.clear();ctrlV.clear();selGroupe=null;}
                    }),
                    onGroupeChanged: onGroupeChanged,
                    ss: ss,
                  ),

                  const SizedBox(height:16),

                  // ─ 5. Magasin ─
                  _fieldLabel('Magasin de stockage'),
                  const SizedBox(height:8),
                  Row(children:kMagasins.map((m){
                    final sel=mag==m;
                    return Expanded(child:Padding(
                      padding:const EdgeInsets.only(right:8),
                      child:InkWell(
                        borderRadius:BorderRadius.circular(kRadius),
                        onTap:()=>ss(()=>mag=m),
                        child:AnimatedContainer(
                          duration:const Duration(milliseconds:150),
                          padding:const EdgeInsets.symmetric(vertical:14),
                          decoration:BoxDecoration(
                            color:sel?kBlue:kSurface,
                            borderRadius:BorderRadius.circular(kRadius),
                            border:Border.all(color:sel?kBlue:kBorder,width:sel?2:1),
                            boxShadow:sel?[BoxShadow(color:kBlue.withOpacity(0.25),blurRadius:8,offset:const Offset(0,3))]:null,
                          ),
                          alignment:Alignment.center,
                          child:Column(children:[
                            Icon(Icons.warehouse_rounded,color:sel?Colors.white:kTextMuted,size:22),
                            const SizedBox(height:5),
                            Text('Mag. $m',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,
                                color:sel?Colors.white:kTextMuted)),
                          ]),
                        ),
                      ),
                    ));
                  }).toList()),

                  const SizedBox(height:22),
                ]),
              )),

              _dlgFooter(
                onCancel:()=>Navigator.pop(ctx),
                onSubmit:(){
                  final nom=nomC.text.trim(); final ref=refC.text.trim();
                  if(nom.isEmpty||ref.isEmpty) return;
                  final qte=aVariantes?0:(int.tryParse(qteC.text)??0);
                  for(final v in variantes) v.quantite=int.tryParse(ctrlV[v.unite]?.text??'0')??0;
                  setState((){
                    if(isEdit){
                      p!..nom=nom..reference=ref..categorie=cat..aVariantes=aVariantes
                        ..groupeUniteLabel=selGroupe?.label
                        ..quantiteStock=qte..stockParVariante=aVariantes?List.from(variantes):[]..magasin=mag;
                    } else {
                      _all.add(Produit(
                        id:DateTime.now().millisecondsSinceEpoch.toString(),
                        nom:nom,reference:ref,categorie:cat,aVariantes:aVariantes,
                        groupeUniteLabel:selGroupe?.label,
                        quantiteStock:qte,stockParVariante:aVariantes?List.from(variantes):[],magasin:mag,
                      ));
                    }
                  });
                  _applyFilters(); Navigator.pop(ctx);
                },
                label:isEdit?'Enregistrer':'Ajouter le produit',
                icon:isEdit?Icons.save_rounded:Icons.add_rounded,
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SECTION STOCK — avec sélecteur de groupe d'unités
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStockSection({
    required bool aVariantes,
    required GroupeUnites? selGroupe,
    required List<TailleStock> variantes,
    required Set<String> selV,
    required Map<String,TextEditingController> ctrlV,
    required TextEditingController qteC,
    required void Function(String) toggleV,
    required VoidCallback onToggle,
    required void Function(GroupeUnites?) onGroupeChanged,
    required StateSetter ss,
  }) {
    return Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        color:const Color(0xFFF7FAFF),
        borderRadius:BorderRadius.circular(kRadius),
        border:Border.all(color:kBorder),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[

        // Toggle variantes
        InkWell(
          borderRadius:BorderRadius.circular(6), onTap:onToggle,
          child:Row(children:[
            AnimatedContainer(
              duration:const Duration(milliseconds:160),
              width:20,height:20,
              decoration:BoxDecoration(
                color:aVariantes?kBlue:kSurface,
                borderRadius:BorderRadius.circular(5),
                border:Border.all(color:aVariantes?kBlue:const Color(0xFFBCC8D8),width:2),
              ),
              child:aVariantes?const Icon(Icons.check_rounded,color:Colors.white,size:13):null,
            ),
            const SizedBox(width:10),
            const Text('Ce produit a des variantes (tailles, volumes, poids…)',style:_tsH2),
          ]),
        ),

        // Quantité simple
        if(!aVariantes)...[
          const SizedBox(height:12),
          _input(ctrl:qteC,hint:'Quantité totale',keyType:TextInputType.number),
        ]

        // Mode variantes
        else...[
          const SizedBox(height:16),

          // ── Étape 1 : choisir le TYPE de mesure ──
          Text('Étape 1 — Choisir le type de mesure :',style:_tsLabel.copyWith(color:kTextMuted)),
          const SizedBox(height:10),
          Wrap(spacing:8,runSpacing:8,children:kGroupesUnites.map((g){
            final sel=selGroupe?.label==g.label;
            return InkWell(
              borderRadius:BorderRadius.circular(kRadius),
              onTap:()=>onGroupeChanged(sel?null:g),
              child:AnimatedContainer(
                duration:const Duration(milliseconds:140),
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
                decoration:BoxDecoration(
                  color:sel?kBlue:kSurface,
                  borderRadius:BorderRadius.circular(kRadius),
                  border:Border.all(color:sel?kBlue:kBorder,width:sel?2:1),
                  boxShadow:sel?[BoxShadow(color:kBlue.withOpacity(0.2),blurRadius:6,offset:const Offset(0,2))]:null,
                ),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(g.icon,size:15,color:sel?Colors.white:kTextMuted),
                  const SizedBox(width:7),
                  Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(g.label,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,
                        color:sel?Colors.white:kText)),
                    Text(g.description,style:TextStyle(fontSize:10,
                        color:sel?Colors.white.withOpacity(0.8):kTextMuted)),
                  ]),
                ]),
              ),
            );
          }).toList()),

          // ── Étape 2 : sélectionner les unités du groupe choisi ──
          if(selGroupe!=null)...[
            const SizedBox(height:16),
            Row(children:[
              Icon(selGroupe.icon,size:14,color:kBlue),
              const SizedBox(width:6),
              Text('Étape 2 — Sélectionner les ${selGroupe.label.toLowerCase()} :',
                  style:_tsLabel.copyWith(color:kBlue)),
            ]),
            const SizedBox(height:8),
            Wrap(spacing:6,runSpacing:6,children:selGroupe.unites.map((u){
              final sel=selV.contains(u);
              return InkWell(
                borderRadius:BorderRadius.circular(7),onTap:()=>toggleV(u),
                child:AnimatedContainer(
                  duration:const Duration(milliseconds:130),
                  padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                  decoration:BoxDecoration(
                    color:sel?kBlue:kSurface,
                    borderRadius:BorderRadius.circular(7),
                    border:Border.all(color:sel?kBlue:kBorder,width:sel?2:1),
                    boxShadow:sel?[BoxShadow(color:kBlue.withOpacity(0.22),blurRadius:4,offset:const Offset(0,2))]:null,
                  ),
                  child:Text(u,style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,
                      color:sel?Colors.white:kTextMuted)),
                ),
              );
            }).toList()),
          ],

          // ── Étape 3 : saisir les quantités ──
          if(variantes.isNotEmpty)...[
            const SizedBox(height:14),
            Container(
              decoration:BoxDecoration(
                color:kSurface,
                borderRadius:BorderRadius.circular(kRadius),
                border:Border.all(color:kBorder),
              ),
              child:Column(children:[
                // En-tête
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  decoration:const BoxDecoration(
                    color:kBlueLight,
                    borderRadius:BorderRadius.vertical(top:Radius.circular(kRadius)),
                  ),
                  child:Row(children:[
                    SizedBox(width:100,child:Text('Unité',style:_tsLabel.copyWith(color:kBlue))),
                    const SizedBox(width:12),
                    Expanded(child:Text('Quantité',style:_tsLabel.copyWith(color:kBlue))),
                    const SizedBox(width:36),
                  ]),
                ),
                // Lignes
                ...variantes.asMap().entries.map((e){
                  final idx=e.key; final v=e.value; final ctrl=ctrlV[v.unite]!;
                  return Column(children:[
                    if(idx>0) Divider(height:1,color:kBorder),
                    Padding(
                      padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                      child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
                        Container(
                          width:100,height:34,alignment:Alignment.center,
                          decoration:BoxDecoration(color:kBlue,borderRadius:BorderRadius.circular(7)),
                          child:Text(v.unite,style:const TextStyle(
                              fontSize:12,fontWeight:FontWeight.w800,color:Colors.white),
                              textAlign:TextAlign.center),
                        ),
                        const SizedBox(width:12),
                        Expanded(child:Row(children:[
                          _stepBtn(Icons.remove_rounded,(){
                            final val=int.tryParse(ctrl.text)??0;
                            if(val>0){ctrl.text=(val-1).toString();ss(()=>v.quantite=val-1);}
                          }),
                          Expanded(child:SizedBox(height:40,child:TextField(
                            controller:ctrl,
                            keyboardType:TextInputType.number,
                            textAlign:TextAlign.center,
                            style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:kText),
                            decoration:InputDecoration(
                              hintText:'0',
                              hintStyle:const TextStyle(fontSize:14,color:Color(0xFFBBCCDD)),
                              contentPadding:EdgeInsets.zero,
                              border:OutlineInputBorder(borderRadius:BorderRadius.circular(7),borderSide:BorderSide(color:kBorder)),
                              focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(7),borderSide:const BorderSide(color:kBlue,width:2)),
                              enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(7),borderSide:BorderSide(color:kBorder)),
                            ),
                            onChanged:(val)=>ss(()=>v.quantite=int.tryParse(val)??0),
                          ))),
                          _stepBtn(Icons.add_rounded,(){
                            final val=int.tryParse(ctrl.text)??0;
                            ctrl.text=(val+1).toString();ss(()=>v.quantite=val+1);
                          }),
                        ])),
                        const SizedBox(width:8),
                        InkWell(
                          borderRadius:BorderRadius.circular(7),onTap:()=>toggleV(v.unite),
                          child:Container(padding:const EdgeInsets.all(7),
                              decoration:BoxDecoration(color:const Color(0xFFFFF0F0),borderRadius:BorderRadius.circular(7)),
                              child:const Icon(Icons.close_rounded,size:15,color:Colors.red)),
                        ),
                      ]),
                    ),
                  ]);
                }),
                // Total
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  decoration:const BoxDecoration(
                    color:kBlueLight,
                    borderRadius:BorderRadius.vertical(bottom:Radius.circular(kRadius)),
                    border:Border(top:BorderSide(color:Color(0xFFD0E8FF))),
                  ),
                  child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                    Text('Total',style:_tsLabel.copyWith(color:kBlue)),
                    Text('${variantes.fold(0,(s,v)=>s+v.quantite)}',
                        style:const TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:kBlue)),
                  ]),
                ),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOG DÉTAILS
  // ═══════════════════════════════════════════════════════════════════════════
  void _openDetails(Produit p) {
    final groupe = p.groupeUniteLabel!=null
        ? kGroupesUnites.firstWhere((g)=>g.label==p.groupeUniteLabel, orElse:()=>kGroupesUnites.first)
        : null;

    showDialog(context:context, builder:(ctx)=>Dialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      insetPadding:const EdgeInsets.symmetric(horizontal:100,vertical:60),
      child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:560,maxHeight:680),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          _dlgHeader(p.nom,Icons.info_outline_rounded),
          Flexible(child:SingleChildScrollView(
            padding:const EdgeInsets.all(kPadH),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              _detRow(Icons.qr_code_rounded,      'Référence',  p.reference),
              _detRow(Icons.category_outlined,    'Catégorie',  p.categorie),
              _detRow(Icons.warehouse_rounded,    'Magasin',    'Magasin ${p.magasin}'),
              _detRow(Icons.inventory_2_outlined, 'Stock total','${p.totalStock} unités'),
              if(groupe!=null)
                _detRow(groupe.icon,'Type de mesure',groupe.label),
              const SizedBox(height:4),
              if(p.isRupture) _alertChip(Icons.error_outline_rounded,'Rupture de stock',Colors.red,const Color(0xFFFFF0F0))
              else if(p.isLow) _alertChip(Icons.warning_amber_rounded,'Stock bas — ${p.totalStock} restants',Colors.orange,const Color(0xFFFFF8EC)),

              if(p.aVariantes&&p.stockParVariante.isNotEmpty)...[
                const SizedBox(height:20),
                Row(children:[
                  if(groupe!=null) Icon(groupe.icon,size:14,color:kBlue),
                  const SizedBox(width:6),
                  Text(groupe!=null?'Stock — ${groupe.label}':'Stock par variante',style:_tsH2),
                ]),
                const SizedBox(height:10),
                Container(
                  decoration:BoxDecoration(borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBorder)),
                  child:ClipRRect(borderRadius:BorderRadius.circular(kRadius),child:Column(children:[
                    Container(
                      color:kBlueLight,
                      padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
                      child:Row(children:[
                        Expanded(flex:2,child:Text('Unité',style:_tsLabel.copyWith(color:kBlue))),
                        Expanded(flex:2,child:Text('Quantité',style:_tsLabel.copyWith(color:kBlue))),
                        Expanded(flex:1,child:Text('Statut',style:_tsLabel.copyWith(color:kBlue))),
                      ]),
                    ),
                    ...p.stockParVariante.asMap().entries.map((e){
                      final v=e.value;
                      final r=v.quantite==0; final l=v.quantite>0&&v.quantite<=3;
                      final col=r?Colors.red:l?Colors.orange:Colors.green[700]!;
                      return Column(children:[
                        if(e.key>0) Divider(height:1,color:kBorder),
                        Container(
                          color:r?const Color(0xFFFFF8F8):kSurface,
                          padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
                          child:Row(children:[
                            Expanded(flex:2,child:Container(
                              padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                              decoration:BoxDecoration(color:kBlue,borderRadius:BorderRadius.circular(7)),
                              alignment:Alignment.center,
                              child:Text(v.unite,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:Colors.white)),
                            )),
                            const SizedBox(width:8),
                            Expanded(flex:2,child:Text('${v.quantite}',
                                style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:col))),
                            Expanded(flex:1,child:Container(
                              padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                              decoration:BoxDecoration(
                                color:r?const Color(0xFFFFEEEE):l?const Color(0xFFFFF3E0):const Color(0xFFE8F5E9),
                                borderRadius:BorderRadius.circular(20),
                              ),
                              child:Text(r?'Rupture':l?'Bas':'OK',
                                  textAlign:TextAlign.center,
                                  style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:col)),
                            )),
                          ]),
                        ),
                      ]);
                    }),
                    Container(
                      padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
                      color:kBlueLight,
                      child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                        Text('Total',style:_tsLabel.copyWith(color:kBlue)),
                        Text('${p.totalStock}',
                            style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800,color:kBlue)),
                      ]),
                    ),
                  ])),
                ),
              ],
            ]),
          )),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:kPadH,vertical:16),
            decoration:const BoxDecoration(border:Border(top:BorderSide(color:kBorder))),
            child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
              _solidBtn('Fermer',()=>Navigator.pop(ctx)),
            ]),
          ),
        ]),
      ),
    ));
  }

  // ─── Suppression ─────────────────────────────────────────────────────────
  void _confirmDelete(Produit p) {
    showDialog(context:context, builder:(ctx)=>Dialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(14),
            decoration:const BoxDecoration(color:Color(0xFFFFF0F0),shape:BoxShape.circle),
            child:const Icon(Icons.delete_outline_rounded,color:Colors.red,size:28)),
        const SizedBox(height:14),
        const Text('Supprimer ce produit ?',style:_tsH1),
        const SizedBox(height:6),
        Text(p.nom,style:_tsMuted,textAlign:TextAlign.center),
        const SizedBox(height:22),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          _outlineBtn('Annuler',()=>Navigator.pop(ctx)),
          const SizedBox(width:10),
          _solidBtn('Supprimer',(){
            setState(()=>_all.removeWhere((x)=>x.id==p.id));
            _applyFilters(); Navigator.pop(ctx);
          },color:Colors.red),
        ]),
      ])),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  WIDGETS ATOMIQUES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _input({
    required TextEditingController ctrl,
    required String hint,
    TextInputType? keyType,
    Widget? suffix,
    Widget? icon,
  }) => TextField(
    controller:ctrl,keyboardType:keyType,
    style:const TextStyle(fontSize:13,color:kText),
    decoration:InputDecoration(
      hintText:hint,
      hintStyle:const TextStyle(fontSize:13,color:Color(0xFFBBCCDD)),
      prefixIcon:icon, suffixIcon:suffix,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
      filled:true,fillColor:kSurface,
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBorder)),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBlue,width:2)),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBorder)),
    ),
  );

  Widget _dropdownField({required String value,required List<String> items,required void Function(String) onChanged}) =>
      Container(
        height:44,padding:const EdgeInsets.symmetric(horizontal:12),
        decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBorder)),
        child:DropdownButtonHideUnderline(child:DropdownButton<String>(
          value:items.contains(value)?value:items.first,isExpanded:true,
          style:const TextStyle(fontSize:13,color:kText),
          icon:const Icon(Icons.keyboard_arrow_down_rounded,color:kBlue,size:18),
          items:items.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
          onChanged:(v)=>onChanged(v!),
        )),
      );

  Widget _fieldLabel(String t) => Text(t.toUpperCase(),style:_tsLabel);

  Widget _iconBtn(IconData icon,VoidCallback onTap,{String? tooltip}){
    final btn=InkWell(
      borderRadius:BorderRadius.circular(kRadius),onTap:onTap,
      child:Container(width:44,height:44,
          decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBlueMid.withOpacity(0.5))),
          child:Icon(icon,color:kBlue,size:18)),
    );
    return tooltip!=null?Tooltip(message:tooltip,child:btn):btn;
  }

  Widget _stepBtn(IconData icon,VoidCallback onTap)=>InkWell(
    borderRadius:BorderRadius.circular(7),onTap:onTap,
    child:Container(width:40,height:40,
        decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(7),border:Border.all(color:kBlueMid.withOpacity(0.4))),
        child:Icon(icon,color:kBlue,size:16)),
  );

  Widget _existantsCard(List<String> noms,TextEditingController nomC,StateSetter ss,String cat)=>
      Container(
        padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:const Color(0xFFF0F7FF),borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBlueMid.withOpacity(0.4))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.lightbulb_outline_rounded,size:13,color:kBlue),
            const SizedBox(width:6),
            Text('Dans « $cat » — cliquer pour sélectionner',style:_tsLabel.copyWith(color:kBlue)),
          ]),
          const SizedBox(height:8),
          Wrap(spacing:6,runSpacing:6,children:noms.map((n){
            final sel=nomC.text==n;
            return InkWell(
              borderRadius:BorderRadius.circular(20),onTap:()=>ss(()=>nomC.text=n),
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
                decoration:BoxDecoration(color:sel?kBlue:kSurface,borderRadius:BorderRadius.circular(20),border:Border.all(color:sel?kBlue:kBlueMid)),
                child:Text(n,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:sel?Colors.white:kBlue)),
              ),
            );
          }).toList()),
        ]),
      );

  Widget _emptyCategCard(String cat)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
    decoration:BoxDecoration(
      color:const Color(0xFFF0FFF4),
      borderRadius:BorderRadius.circular(kRadius),
      border:Border.all(color:const Color(0xFF86EFAC)),
    ),
    child:Row(children:[
      const Icon(Icons.add_circle_outline_rounded,size:15,color:Color(0xFF16A34A)),
      const SizedBox(width:8),
      Flexible(child:Text(
        'Catégorie « $cat » vide — saisissez librement le nom et la référence du premier produit.',
        style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Color(0xFF15803D)),
      )),
    ]),
  );

  Widget _dlgHeader(String title,IconData icon)=>Container(
    width:double.infinity,
    padding:const EdgeInsets.symmetric(horizontal:kPadH,vertical:18),
    decoration:const BoxDecoration(color:kBlue,borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
    child:Row(children:[
      Icon(icon,color:Colors.white,size:20),const SizedBox(width:10),
      Flexible(child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Colors.white),overflow:TextOverflow.ellipsis)),
    ]),
  );

  Widget _dlgFooter({required VoidCallback onCancel,required VoidCallback onSubmit,required String label,required IconData icon})=>
      Container(
        padding:const EdgeInsets.symmetric(horizontal:kPadH,vertical:14),
        decoration:const BoxDecoration(color:Color(0xFFF7FAFF),border:Border(top:BorderSide(color:kBorder)),borderRadius:BorderRadius.vertical(bottom:Radius.circular(16))),
        child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
          _textBtn('Annuler',onCancel),const SizedBox(width:10),
          _solidBtn(label,onSubmit,icon:icon),
        ]),
      );

  Widget _detRow(IconData icon,String label,String val)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:7),
    child:Row(children:[
      Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(7)),child:Icon(icon,color:kBlue,size:15)),
      const SizedBox(width:12),Text('$label :',style:_tsMuted),const SizedBox(width:6),
      Flexible(child:Text(val,style:_tsH2)),
    ]),
  );

  Widget _alertChip(IconData icon,String msg,Color col,Color bg)=>Container(
    margin:const EdgeInsets.only(top:10),
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
    decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:col.withOpacity(0.25))),
    child:Row(children:[Icon(icon,color:col,size:16),const SizedBox(width:8),Flexible(child:Text(msg,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:col)))]),
  );

  Widget _solidBtn(String label,VoidCallback onTap,{Color? color,IconData? icon})=>ElevatedButton(
    style:ElevatedButton.styleFrom(backgroundColor:color??kBlue,foregroundColor:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(kRadius)),padding:const EdgeInsets.symmetric(horizontal:18,vertical:11)),
    onPressed:onTap,
    child:icon!=null?Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:15),const SizedBox(width:6),Text(label,style:_tsBtn)]):Text(label,style:_tsBtn),
  );

  Widget _outlineBtn(String label,VoidCallback onTap)=>OutlinedButton(
    style:OutlinedButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(kRadius)),padding:const EdgeInsets.symmetric(horizontal:18,vertical:11),side:const BorderSide(color:kBorder)),
    onPressed:onTap,
    child:Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:kTextMuted)),
  );

  Widget _textBtn(String label,VoidCallback onTap)=>TextButton(
    style:TextButton.styleFrom(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(kRadius)),padding:const EdgeInsets.symmetric(horizontal:14,vertical:11)),
    onPressed:onTap,
    child:Text(label,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w500,color:kTextMuted)),
  );

  Widget _statCard(String label,String value,IconData icon,{Color? valueColor})=>Container(
    padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),
    decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(kRadius2),boxShadow:[BoxShadow(color:kBlue.withOpacity(0.07),blurRadius:12,offset:const Offset(0,4))],border:Border.all(color:kBorder)),
    child:Row(children:[
      Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(9)),child:Icon(icon,color:kBlue,size:20)),
      const SizedBox(width:14),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(value,style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:valueColor??kText)),
        Text(label,style:_tsMuted),
      ]),
    ]),
  );

  Widget _alertBanner(){
    final alerts=_all.where((p)=>p.isLow||p.isRupture).toList();
    if(alerts.isEmpty) return const SizedBox.shrink();
    return Container(
      margin:const EdgeInsets.fromLTRB(24,14,24,0),
      padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
      decoration:BoxDecoration(color:const Color(0xFFFFF9EC),borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:const Color(0xFFFFD060),width:1.5)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
        const Icon(Icons.warning_amber_rounded,color:Color(0xFFE59000),size:20),
        const SizedBox(width:10),
        Expanded(child:Wrap(spacing:8,runSpacing:6,children:[
          Text('${alerts.length} produit${alerts.length>1?'s':''} à surveiller :',
              style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Color(0xFF7A4A00))),
          ...alerts.map((p){
            final r=p.isRupture;
            return Container(
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:3),
              decoration:BoxDecoration(color:r?const Color(0xFFFFEEEE):const Color(0xFFFFF3E0),borderRadius:BorderRadius.circular(20),border:Border.all(color:r?const Color(0xFFFFBBBB):const Color(0xFFFFD488))),
              child:Text('${p.nom} ${r?'(rupture)':'(${p.totalStock})'}',
                  style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:r?Colors.red[700]:Colors.orange[800])),
            );
          }),
        ])),
      ]),
    );
  }

  Widget _hCell(String label,{int flex=1,String? sortKey}){
    final active=sortKey!=null&&_sortBy==sortKey;
    return Expanded(flex:flex,child:GestureDetector(
      onTap:sortKey!=null?(){if(_sortBy==sortKey){_asc=!_asc;}else{_sortBy=sortKey;_asc=true;}_applyFilters();}:null,
      child:Row(children:[
        Text(label,style:TextStyle(fontWeight:FontWeight.w700,fontSize:12,color:active?kBlue:kTextMuted,letterSpacing:0.3)),
        if(active)...[const SizedBox(width:3),Icon(_asc?Icons.arrow_upward_rounded:Icons.arrow_downward_rounded,size:12,color:kBlue)],
      ]),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final total    = _all.length;
    final ruptures = _all.where((p)=>p.isRupture).length;

    return Scaffold(
      backgroundColor:kBg,
      body:Column(children:[

        // ── Top Bar ──
        Container(
          padding:const EdgeInsets.symmetric(horizontal:24,vertical:16),
          decoration:const BoxDecoration(color:kSurface,boxShadow:[BoxShadow(color:Color(0x0D000000),blurRadius:8,offset:Offset(0,2))]),
          child:Row(children:[
            Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(9)),child:const Icon(Icons.store_rounded,color:kBlue,size:20)),
            const SizedBox(width:12),
            const Text('Gestion du Magasin',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:kBlue,letterSpacing:-0.3)),
            const Spacer(),
            ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:kBlue,foregroundColor:Colors.white,elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(kRadius)),padding:const EdgeInsets.symmetric(horizontal:16,vertical:11)),
              icon:const Icon(Icons.add_rounded,size:16),
              label:const Text('Ajouter produit',style:TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
              onPressed:()=>_openDialog(),
            ),
          ]),
        ),

        // ── Stats ──
        Padding(
          padding:const EdgeInsets.fromLTRB(24,18,24,0),
          child:Row(children:[
            _statCard('Total produits','$total',Icons.inventory_2_rounded),
            const SizedBox(width:14),
            _statCard('Ruptures','$ruptures',Icons.warning_amber_rounded,valueColor:ruptures>0?Colors.red:null),
            const SizedBox(width:14),
            _statCard('Catégories','${_cats.length}',Icons.category_rounded),
          ]),
        ),

        _alertBanner(),
        const SizedBox(height:14),

        // ── Filtres ──
        Padding(
          padding:const EdgeInsets.symmetric(horizontal:24),
          child:Row(children:[
            Expanded(flex:3,child:SizedBox(height:40,child:TextField(
              controller:_searchCtrl,
              style:const TextStyle(fontSize:13),
              decoration:InputDecoration(
                hintText:'Rechercher…',hintStyle:const TextStyle(fontSize:13,color:Color(0xFFBBCCDD)),
                prefixIcon:const Icon(Icons.search_rounded,color:kBlue,size:17),
                suffixIcon:_search.isNotEmpty?IconButton(icon:const Icon(Icons.close_rounded,size:15),onPressed:(){_searchCtrl.clear();_search='';_applyFilters();}):null,
                filled:true,fillColor:kSurface,contentPadding:const EdgeInsets.symmetric(horizontal:12),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBorder)),
                focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBlue,width:2)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(kRadius),borderSide:const BorderSide(color:kBorder)),
              ),
              onChanged:(v){_search=v;_applyFilters();},
            ))),
            const SizedBox(width:10),
            Expanded(flex:2,child:Container(height:40,padding:const EdgeInsets.symmetric(horizontal:12),
              decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBorder)),
              child:DropdownButtonHideUnderline(child:DropdownButton<String>(
                value:_selCat,icon:const Icon(Icons.keyboard_arrow_down_rounded,color:kBlue,size:17),isExpanded:true,
                style:const TextStyle(fontSize:13,color:kText),
                items:_catsFilter.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
                onChanged:(v){_selCat=v!;_applyFilters();},
              )),
            )),
            const SizedBox(width:10),
            Expanded(flex:2,child:Container(height:40,padding:const EdgeInsets.symmetric(horizontal:12),
              decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBorder)),
              child:DropdownButtonHideUnderline(child:DropdownButton<String>(
                value:_sortBy,icon:const Icon(Icons.sort_rounded,color:kBlue,size:17),isExpanded:true,
                style:const TextStyle(fontSize:13,color:kText),
                items:const[
                  DropdownMenuItem(value:'nom',          child:Text('Nom')),
                  DropdownMenuItem(value:'reference',    child:Text('Référence')),
                  DropdownMenuItem(value:'quantiteStock',child:Text('Stock')),
                ],
                onChanged:(v){_sortBy=v!;_applyFilters();},
              )),
            )),
            const SizedBox(width:8),
            InkWell(
              borderRadius:BorderRadius.circular(kRadius),onTap:()=>setState((){_asc=!_asc;_applyFilters();}),
              child:Container(width:40,height:40,
                  decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(kRadius),border:Border.all(color:kBlueMid.withOpacity(0.5))),
                  child:Icon(_asc?Icons.arrow_upward_rounded:Icons.arrow_downward_rounded,color:kBlue,size:16)),
            ),
          ]),
        ),

        const SizedBox(height:14),

        // ── Tableau ──
        Expanded(child:Padding(
          padding:const EdgeInsets.fromLTRB(24,0,24,20),
          child:Container(
            decoration:BoxDecoration(color:kSurface,borderRadius:BorderRadius.circular(kRadius2),boxShadow:[BoxShadow(color:kBlue.withOpacity(0.06),blurRadius:16,offset:const Offset(0,4))],border:Border.all(color:kBorder)),
            child:ClipRRect(borderRadius:BorderRadius.circular(kRadius2),child:Column(children:[
              Container(
                color:kBlueLight,
                padding:const EdgeInsets.symmetric(horizontal:18,vertical:12),
                child:Row(children:[
                  _hCell('NOM DU PRODUIT',    flex:3,sortKey:'nom'),
                  _hCell('RÉFÉRENCE',         flex:2,sortKey:'reference'),
                  _hCell('CATÉGORIE',         flex:2),
                  _hCell('STOCK',             flex:1,sortKey:'quantiteStock'),
                  _hCell('MAGASIN',           flex:1),
                  const Expanded(flex:2,child:SizedBox()),
                ]),
              ),
              const Divider(height:1,color:kBorder),
              Expanded(child:_filtered.isEmpty
                  ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                Icon(Icons.search_off_rounded,size:44,color:kBlueMid),
                const SizedBox(height:10),
                const Text('Aucun produit trouvé',style:_tsMuted),
              ]))
                  :ListView.separated(
                itemCount:_filtered.length,
                separatorBuilder:(_,__)=>const Divider(height:1,color:kBorder),
                itemBuilder:(ctx,i){
                  final p=_filtered[i];
                  return _ProductRow(
                    produit:p,
                    onEdit:()=>_openDialog(p:p),
                    onDelete:()=>_confirmDelete(p),
                    onDetails:()=>_openDetails(p),
                  );
                },
              ),
              ),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:18,vertical:9),
                color:const Color(0xFFF7FAFF),
                child:Row(children:[
                  Text('${_filtered.length} / $total produit${total>1?'s':''}',style:_tsMuted),
                ]),
              ),
            ])),
          ),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LIGNE PRODUIT
// ═══════════════════════════════════════════════════════════════════════════════

class _ProductRow extends StatefulWidget {
  final Produit produit;
  final VoidCallback onEdit, onDelete, onDetails;
  const _ProductRow({required this.produit,required this.onEdit,required this.onDelete,required this.onDetails});
  @override State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  bool _hov=false;

  @override
  Widget build(BuildContext context) {
    final p=widget.produit;
    // Trouver l'icône du groupe d'unités si applicable
    final groupe = p.groupeUniteLabel!=null
        ? kGroupesUnites.firstWhere((g)=>g.label==p.groupeUniteLabel,orElse:()=>kGroupesUnites.first)
        : null;

    return MouseRegion(
      onEnter:(_)=>setState(()=>_hov=true),
      onExit: (_)=>setState(()=>_hov=false),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:120),
        color:_hov?const Color(0xFFF3F8FF):kSurface,
        padding:const EdgeInsets.symmetric(horizontal:18,vertical:12),
        child:Row(crossAxisAlignment:CrossAxisAlignment.center,children:[

          // Nom
          Expanded(flex:3,child:Row(children:[
            Container(width:36,height:36,
                decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(8)),
                child:const Icon(Icons.inventory_2_outlined,size:17,color:kBlue)),
            const SizedBox(width:10),
            Flexible(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              Text(p.nom,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:kText),overflow:TextOverflow.ellipsis),
              if(p.aVariantes&&groupe!=null)
                Row(mainAxisSize:MainAxisSize.min,children:[
                  Icon(groupe.icon,size:10,color:kTextMuted),
                  const SizedBox(width:3),
                  Text('${p.stockParVariante.length} ${groupe.label.toLowerCase().split(' ').first}',
                      style:_tsMuted.copyWith(fontSize:10)),
                ])
              else if(p.aVariantes)
                Text('${p.stockParVariante.length} variantes',style:_tsMuted.copyWith(fontSize:10)),
            ])),
            if(p.isRupture)
              Tooltip(message:'Rupture de stock',child:Padding(padding:const EdgeInsets.only(left:6),child:const Icon(Icons.error_outline_rounded,size:15,color:Colors.red)))
            else if(p.isLow)
              Tooltip(message:'Stock bas',child:Padding(padding:const EdgeInsets.only(left:6),child:Icon(Icons.warning_amber_rounded,size:15,color:Colors.orange[600]))),
          ])),

          Expanded(flex:2,child:Text(p.reference,style:_tsMono)),

          Expanded(flex:2,child:Align(alignment:Alignment.centerLeft,
            child:Container(
              padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
              decoration:BoxDecoration(color:kBlueLight,borderRadius:BorderRadius.circular(20)),
              child:Text(p.categorie,style:const TextStyle(fontSize:11,color:kBlue,fontWeight:FontWeight.w700),overflow:TextOverflow.ellipsis),
            ),
          )),

          Expanded(flex:1,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
            decoration:BoxDecoration(
              color:p.isRupture?const Color(0xFFFFEEEE):p.isLow?const Color(0xFFFFF8E1):const Color(0xFFEAF7EE),
              borderRadius:BorderRadius.circular(20),
            ),
            child:Text('${p.totalStock}',textAlign:TextAlign.center,
                style:TextStyle(fontSize:13,fontWeight:FontWeight.w800,
                    color:p.isRupture?Colors.red:p.isLow?Colors.orange[700]:Colors.green[700])),
          )),

          Expanded(flex:1,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
            decoration:BoxDecoration(color:const Color(0xFFEEF1FF),borderRadius:BorderRadius.circular(20)),
            child:Text('Mag. ${p.magasin}',textAlign:TextAlign.center,
                style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:Color(0xFF4455AA))),
          )),

          Expanded(flex:2,child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
            _btn(Icons.visibility_outlined,   'Détails',   kBlueLight,              kBlue,      widget.onDetails),
            const SizedBox(width:5),
            _btn(Icons.edit_rounded,           'Modifier',  kBlueLight,              kBlue,      widget.onEdit),
            const SizedBox(width:5),
            _btn(Icons.delete_outline_rounded, 'Supprimer', const Color(0xFFFFF0F0), Colors.red, widget.onDelete),
          ])),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon,String tip,Color bg,Color col,VoidCallback fn)=>
      Tooltip(message:tip,child:InkWell(
        borderRadius:BorderRadius.circular(7),onTap:fn,
        child:Container(padding:const EdgeInsets.all(7),
            decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(7)),
            child:Icon(icon,size:16,color:col)),
      ));
}
