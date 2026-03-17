// =============================================================================
//  gestion_magasin.dart
//  Fichier UNIQUE et autonome — Gestion du stock magasin
//  Contient : Modèles · MagasinProvider (Firebase) · UI complète
//
//  Dépendances requises dans pubspec.yaml :
//    cloud_firestore: ^5.x.x
//    firebase_core: ^3.x.x
//    provider: ^6.x.x
//
//  Utilisation dans main.dart :
//    ChangeNotifierProvider(create: (_) => MagasinProvider()..init(), ...)
//
//  Structure Firestore :
//    magasin/
//      categories/    → {id, nom}
//      produits/      → {id, nom, reference, categorie, magasin, ...}
//      mouvements/    → {id, type, produitId, ...}
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/utils/responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — MODÈLES DE DONNÉES
// ─────────────────────────────────────────────────────────────────────────────

class LigneMouvement {
  final String unite;
  final int quantite;

  const LigneMouvement({required this.unite, required this.quantite});

  Map<String, dynamic> toMap() => {'unite': unite, 'quantite': quantite};

  factory LigneMouvement.fromMap(Map<String, dynamic> m) => LigneMouvement(
        unite: m['unite'] as String? ?? '',
        quantite: (m['quantite'] as num?)?.toInt() ?? 0,
      );
}

class VarianteProduit {
  final String unite;
  final int quantite;

  const VarianteProduit({required this.unite, required this.quantite});

  Map<String, dynamic> toMap() => {'unite': unite, 'quantite': quantite};

  factory VarianteProduit.fromMap(Map<String, dynamic> m) => VarianteProduit(
        unite: m['unite'] as String? ?? '',
        quantite: (m['quantite'] as num?)?.toInt() ?? 0,
      );
}

class Produit {
  final String id;
  final String nom;
  final String reference;
  final String categorie;
  final String magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantiteStock;
  final List<VarianteProduit> variantes;
  final String siteId;

  const Produit({
    required this.id,
    required this.nom,
    required this.reference,
    required this.categorie,
    required this.magasin,
    required this.aVariantes,
    this.groupeUniteLabel,
    required this.quantiteStock,
    required this.variantes,
    this.siteId = 'default',
  });

  int get total => aVariantes
      ? variantes.fold(0, (s, v) => s + v.quantite)
      : quantiteStock;

  bool get rupture => total == 0;
  bool get bas => !rupture && total <= 5;

  Map<String, dynamic> toFirestore() => {
        'nom': nom,
        'reference': reference,
        'categorie': categorie,
        'magasin': magasin,
        'aVariantes': aVariantes,
        'groupeUniteLabel': groupeUniteLabel,
        'quantiteStock': quantiteStock,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'siteId': siteId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Produit.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Produit(
      id: doc.id,
      nom: d['nom'] as String? ?? '',
      reference: d['reference'] as String? ?? '',
      categorie: d['categorie'] as String? ?? '',
      magasin: d['magasin'] as String? ?? '',
      aVariantes: d['aVariantes'] as bool? ?? false,
      groupeUniteLabel: d['groupeUniteLabel'] as String?,
      quantiteStock: (d['quantiteStock'] as num?)?.toInt() ?? 0,
      variantes: (d['variantes'] as List?)
              ?.map((v) => VarianteProduit.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      siteId: d['siteId'] as String? ?? 'default',
    );
  }

  Produit copyWith({
    String? id,
    String? nom,
    String? reference,
    String? categorie,
    String? magasin,
    bool? aVariantes,
    String? groupeUniteLabel,
    int? quantiteStock,
    List<VarianteProduit>? variantes,
    String? siteId,
  }) =>
      Produit(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        reference: reference ?? this.reference,
        categorie: categorie ?? this.categorie,
        magasin: magasin ?? this.magasin,
        aVariantes: aVariantes ?? this.aVariantes,
        groupeUniteLabel: groupeUniteLabel ?? this.groupeUniteLabel,
        quantiteStock: quantiteStock ?? this.quantiteStock,
        variantes: variantes ?? this.variantes,
        siteId: siteId ?? this.siteId,
      );
}

class Mouvement {
  final String id;
  final String type; // 'entree' | 'sortie'
  final String produitId;
  final String nomProduit;
  final String reference;
  final String categorie;
  final String magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantite;
  final List<LigneMouvement> lignes;
  final DateTime date;
  final String? preneurNom;
  final String siteId;

  const Mouvement({
    required this.id,
    required this.type,
    required this.produitId,
    required this.nomProduit,
    required this.reference,
    required this.categorie,
    required this.magasin,
    required this.aVariantes,
    this.groupeUniteLabel,
    required this.quantite,
    required this.lignes,
    required this.date,
    this.preneurNom,
    this.siteId = 'default',
  });

  int get totalQte => aVariantes
      ? lignes.fold(0, (s, l) => s + l.quantite)
      : quantite;

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'produitId': produitId,
        'nomProduit': nomProduit,
        'reference': reference,
        'categorie': categorie,
        'magasin': magasin,
        'aVariantes': aVariantes,
        'groupeUniteLabel': groupeUniteLabel,
        'quantite': quantite,
        'lignes': lignes.map((l) => l.toMap()).toList(),
        'date': Timestamp.fromDate(date),
        'preneurNom': preneurNom,
        'siteId': siteId,
      };

  factory Mouvement.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Mouvement(
      id: doc.id,
      type: d['type'] as String? ?? 'entree',
      produitId: d['produitId'] as String? ?? '',
      nomProduit: d['nomProduit'] as String? ?? '',
      reference: d['reference'] as String? ?? '',
      categorie: d['categorie'] as String? ?? '',
      magasin: d['magasin'] as String? ?? '',
      aVariantes: d['aVariantes'] as bool? ?? false,
      groupeUniteLabel: d['groupeUniteLabel'] as String?,
      quantite: (d['quantite'] as num?)?.toInt() ?? 0,
      lignes: (d['lignes'] as List?)
              ?.map((l) => LigneMouvement.fromMap(l as Map<String, dynamic>))
              .toList() ??
          [],
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preneurNom: d['preneurNom'] as String?,
      siteId: d['siteId'] as String? ?? 'default',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 2 — PROVIDER FIREBASE
// ─────────────────────────────────────────────────────────────────────────────

class MagasinProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collections ────────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _produitsRef =>
      _db.collection('magasin').doc('stock').collection('produits');

  CollectionReference<Map<String, dynamic>> get _mouvementsRef =>
      _db.collection('magasin').doc('stock').collection('mouvements');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('magasin').doc('stock').collection('categories');

  // ── État ───────────────────────────────────────────────────────────────────
  List<Produit> _produits = [];
  List<Mouvement> _mouvements = [];
  List<String> _categories = [];
  bool _loading = true;
  String? _error;
  bool _firebaseAvailable = true;

  List<Produit> get produits => _produits;
  List<Mouvement> get entrees =>
      _mouvements.where((m) => m.type == 'entree').toList();
  List<Mouvement> get sorties =>
      _mouvements.where((m) => m.type == 'sortie').toList();
  List<String> get categoryNames => _categories;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;
  int get totalProduits => _produits.length;

  // ── Listeners actifs ───────────────────────────────────────────────────────
  final List<Function()> _cancelListeners = [];

  // ── Initialisation ─────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      _loading = true;
      notifyListeners();

      // Stream produits
      final cancelProduits = _produitsRef
          .orderBy('nom')
          .snapshots()
          .listen((snap) {
        _produits = snap.docs.map(Produit.fromFirestore).toList();
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _firebaseAvailable = false;
        notifyListeners();
      });

      // Stream mouvements
      final cancelMouvements = _mouvementsRef
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snap) {
        _mouvements = snap.docs.map(Mouvement.fromFirestore).toList();
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        notifyListeners();
      });

      // Stream catégories
      final cancelCategories = _categoriesRef
          .orderBy('nom')
          .snapshots()
          .listen((snap) {
        _categories = snap.docs
            .map((d) => d.data()['nom'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        _loading = false;
        notifyListeners();
      }, onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      });

      _cancelListeners.addAll([
        cancelProduits.cancel,
        cancelMouvements.cancel,
        cancelCategories.cancel,
      ]);
    } catch (e) {
      _loading = false;
      _error = e.toString();
      _firebaseAvailable = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final cancel in _cancelListeners) cancel();
    super.dispose();
  }

  // ── CATÉGORIES ─────────────────────────────────────────────────────────────
  Future<void> addCategorie(String nom) async {
    if (_categories.contains(nom)) return;
    await _categoriesRef.add({'nom': nom});
  }

  // ── PRODUITS ───────────────────────────────────────────────────────────────
  Future<String> addProduit(Produit produit) async {
    final data = produit.toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _produitsRef.add(data);
    return ref.id;
  }

  Future<void> updateProduit(Produit produit) async {
    await _produitsRef.doc(produit.id).update(produit.toFirestore());
  }

  Future<void> deleteProduit(String id) async {
    await _produitsRef.doc(id).delete();
  }

  // ── Mise à jour stock interne ──────────────────────────────────────────────
  Future<void> _appliquerMouvement(Mouvement m, {required bool annuler}) async {
    final prodDoc = _produitsRef.doc(m.produitId);
    final snap = await prodDoc.get();
    if (!snap.exists) return;

    final produit = Produit.fromFirestore(snap);
    final signe = annuler
        ? (m.type == 'entree' ? -1 : 1)
        : (m.type == 'entree' ? 1 : -1);

    if (!produit.aVariantes) {
      final newQte = (produit.quantiteStock + signe * m.quantite).clamp(0, 999999);
      await prodDoc.update({
        'quantiteStock': newQte,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final newVariantes = produit.variantes.map((v) {
        final ligne = m.lignes.firstWhere(
          (l) => l.unite == v.unite,
          orElse: () => LigneMouvement(unite: v.unite, quantite: 0),
        );
        final newQte = (v.quantite + signe * ligne.quantite).clamp(0, 999999);
        return VarianteProduit(unite: v.unite, quantite: newQte);
      }).toList();

      // Ajouter variantes nouvelles si c'est une entrée d'un nouveau produit
      for (final ligne in m.lignes) {
        if (!newVariantes.any((v) => v.unite == ligne.unite)) {
          newVariantes.add(VarianteProduit(
            unite: ligne.unite,
            quantite: (signe * ligne.quantite).clamp(0, 999999),
          ));
        }
      }

      await prodDoc.update({
        'variantes': newVariantes.map((v) => v.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── ENTRÉES ────────────────────────────────────────────────────────────────
  Future<void> addEntree(Mouvement mouvement) async {
    final batch = _db.batch();
    final ref = _mouvementsRef.doc();
    batch.set(ref, mouvement.toFirestore());
    await batch.commit();
    await _appliquerMouvement(mouvement.copyWithId(ref.id), annuler: false);
  }

  Future<void> deleteEntree(String id) async {
    final snap = await _mouvementsRef.doc(id).get();
    if (!snap.exists) return;
    final m = Mouvement.fromFirestore(snap);
    await _appliquerMouvement(m, annuler: true);
    await _mouvementsRef.doc(id).delete();
  }

  // ── SORTIES ────────────────────────────────────────────────────────────────
  Future<void> addSortie(Mouvement mouvement) async {
    final batch = _db.batch();
    final ref = _mouvementsRef.doc();
    batch.set(ref, mouvement.toFirestore());
    await batch.commit();
    await _appliquerMouvement(mouvement.copyWithId(ref.id), annuler: false);
  }

  Future<void> deleteSortie(String id) async {
    final snap = await _mouvementsRef.doc(id).get();
    if (!snap.exists) return;
    final m = Mouvement.fromFirestore(snap);
    await _appliquerMouvement(m, annuler: true);
    await _mouvementsRef.doc(id).delete();
  }
}

// Extension utilitaire sur Mouvement
extension _MouvementX on Mouvement {
  Mouvement copyWithId(String newId) => Mouvement(
        id: newId,
        type: type,
        produitId: produitId,
        nomProduit: nomProduit,
        reference: reference,
        categorie: categorie,
        magasin: magasin,
        aVariantes: aVariantes,
        groupeUniteLabel: groupeUniteLabel,
        quantite: quantite,
        lignes: lignes,
        date: date,
        preneurNom: preneurNom,
        siteId: siteId,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — CONSTANTES UI
// ─────────────────────────────────────────────────────────────────────────────

// ── Palette ──────────────────────────────────────────────────────────────────
const Color kBlue     = Color(0xFF2563EB);
const Color kBlueDk   = Color(0xFF1D4ED8);
const Color kBlueLt   = Color(0xFFEFF6FF);
const Color kBlueMd   = Color(0xFFBFDBFE);
const Color kBg       = Color(0xFFF1F5F9);
const Color kSurface  = Colors.white;
const Color kText     = Color(0xFF0F172A);
const Color kMuted    = Color(0xFF64748B);
const Color kBorder   = Color(0xFFE2E8F0);
const Color kBorderMd = Color(0xFFCBD5E1);
const Color kGreen    = Color(0xFF16A34A);
const Color kGreenLt  = Color(0xFFF0FDF4);
const Color kOrange   = Color(0xFFD97706);
const Color kOrangeLt = Color(0xFFFFFBEB);
const Color kRed      = Color(0xFFDC2626);
const Color kRedLt    = Color(0xFFFEF2F2);
const Color kIndigo   = Color(0xFF4455AA);
const Color kIndigoLt = Color(0xFFEEF1FF);
const Color kPurple   = Color(0xFF7C3AED);
const Color kPurpleLt = Color(0xFFF5F3FF);

// ── Styles texte ──────────────────────────────────────────────────────────────
const _h2    = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText);
const _muted = TextStyle(fontSize: 12, color: kMuted);
const _label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.6);
const _mono  = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted, fontFamily: 'monospace');

// ── Constantes layout ─────────────────────────────────────────────────────────
const double kR  = 10;
const double kR2 = 14;
const double kP  = 22;

const List<String> kMagasins = ['A', 'B', 'C', 'D'];

// ── Groupes d'unités ──────────────────────────────────────────────────────────
class GroupeUnites {
  final String label, emoji;
  final List<String> unites;
  const GroupeUnites({required this.label, required this.emoji, required this.unites});
}

const List<GroupeUnites> kGroupes = [
  GroupeUnites(label: 'Tailles vestimentaires', emoji: '👔',
      unites: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
  GroupeUnites(label: 'Pointures chaussures', emoji: '👟',
      unites: ['36','37','38','39','40','41','42','43','44','45','46','47','48']),
  GroupeUnites(label: 'Volume (liquides)', emoji: '💧',
      unites: ['25 ml','50 ml','100 ml','250 ml','500 ml','1 L','2 L','5 L','10 L','20 L']),
  GroupeUnites(label: 'Poids (solides)', emoji: '⚖️',
      unites: ['100 g','250 g','500 g','1 kg','2 kg','5 kg','10 kg','25 kg','50 kg','100 kg','1 T']),
  GroupeUnites(label: 'Pièces / Unités', emoji: '📦',
      unites: ['Unité','Boîte x10','Boîte x20','Carton x50','Palette']),
];

GroupeUnites? groupeByLabel(String? label) =>
    label == null ? null : kGroupes.firstWhere((g) => g.label == label, orElse: () => kGroupes.first);

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 4 — PAGE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────

class GestionMagasinPage extends StatefulWidget {
  const GestionMagasinPage({super.key});

  @override
  State<GestionMagasinPage> createState() => _GestionMagasinPageState();
}

class _GestionMagasinPageState extends State<GestionMagasinPage>
    with TickerProviderStateMixin {
  int _tab = 0;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _tab = _tabCtrl.index);
    });
    // Initialise le provider Firebase au premier chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MagasinProvider>().init();
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

    // ── Firebase non disponible ───────────────────────────────────────────────
    if (!magasin.firebaseAvailable) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: _FirebaseErrorState()),
      );
    }

    // ── Chargement ────────────────────────────────────────────────────────────
    if (magasin.loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: _LoadingState()),
      );
    }

    // ── Erreur ────────────────────────────────────────────────────────────────
    if (magasin.error != null) {
      return Scaffold(
        backgroundColor: kBg,
        body: Center(child: _ErrorState(message: magasin.error!)),
      );
    }

    final rupt    = magasin.produits.where((p) => p.rupture).length;
    final bas     = magasin.produits.where((p) => p.bas).length;
    final totalE  = magasin.entrees.fold(0, (s, m) => s + m.totalQte);
    final totalS  = magasin.sorties.fold(0, (s, m) => s + m.totalQte);
    final totalH  = magasin.entrees.length + magasin.sorties.length;

    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        _TopNavBar(
          tab: _tab,
          onTap: (i) => setState(() { _tab = i; _tabCtrl.animateTo(i); }),
          statChips: [
            if (_tab == 0) ...[
              _StatChip('${magasin.produits.length} produits', kBlueLt, kBlue),
              if (rupt > 0) _StatChip('$rupt rupture${rupt > 1 ? "s" : ""}', kRedLt, kRed),
              if (bas  > 0) _StatChip('$bas bas', kOrangeLt, kOrange),
            ],
            if (_tab == 1) ...[
              _StatChip('${magasin.entrees.length} entrée${magasin.entrees.length != 1 ? "s" : ""}', kGreenLt, kGreen),
              _StatChip('$totalE unités reçues', kBlueLt, kBlue),
            ],
            if (_tab == 2) ...[
              _StatChip('${magasin.sorties.length} sortie${magasin.sorties.length != 1 ? "s" : ""}', kOrangeLt, kOrange),
              _StatChip('$totalS unités sorties', kBlueLt, kBlue),
            ],
            if (_tab == 3) _StatChip('$totalH opérations', kPurpleLt, kPurple),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StockPage(magasin: magasin, produits: magasin.produits),
              _EntreesPage(magasin: magasin, entrees: magasin.entrees),
              _SortiesPage(magasin: magasin, sorties: magasin.sorties),
              _HistoriquePage(magasin: magasin),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 5 — TOP NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopNavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  final List<Widget> statChips;
  const _TopNavBar({required this.tab, required this.onTap, required this.statChips});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      {'label': 'Stock Actuel', 'icon': Icons.inventory_2_rounded,      'color': kBlue},
      {'label': 'Les Entrées',  'icon': Icons.arrow_circle_down_rounded, 'color': kGreen},
      {'label': 'Les Sorties',  'icon': Icons.arrow_circle_up_rounded,   'color': kOrange},
      {'label': 'Historique',   'icon': Icons.history_rounded,           'color': kPurple},
    ];
    final mobile  = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    final tabRow = Row(
      children: List.generate(tabs.length, (i) {
        final col = tabs[i]['color'] as Color;
        final sel = tab == i;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: 40,
                decoration: BoxDecoration(
                  color: sel ? col.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: sel ? Border.all(color: col.withOpacity(0.3), width: 1.5) : null,
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(tabs[i]['icon'] as IconData, size: 16, color: sel ? col : kMuted),
                  const SizedBox(width: 7),
                  Text(tabs[i]['label'] as String,
                      style: TextStyle(fontSize: 13,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? col : kMuted)),
                  if (sel) ...[
                    const SizedBox(width: 6),
                    Container(width: 5, height: 5,
                        decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  ],
                ]),
              ),
            ),
          ),
        );
      }),
    );

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
          child: mobile
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(height: 50, child: Row(children: [
                    Container(width: 32, height: 32,
                        decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.store_rounded, color: kBlue, size: 17)),
                    const SizedBox(width: 8),
                    const Text('STOCK MANAGER',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: .5)),
                    const Spacer(),
                    if (statChips.isNotEmpty)
                      Flexible(child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(mainAxisSize: MainAxisSize.min, children: statChips))),
                  ])),
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: tabRow),
                ])
              : SizedBox(height: 66, child: Row(children: [
                  Container(width: 38, height: 38,
                      decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.store_rounded, color: kBlue, size: 20)),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('STOCK',   style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: .5)),
                        Text('MANAGER', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1.2)),
                      ]),
                  const SizedBox(width: 16),
                  Container(width: 1.5, height: 24, color: kBorder),
                  const SizedBox(width: 16),
                  Expanded(child: tabRow),
                  if (statChips.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(width: 1.5, height: 24, color: kBorder),
                    const SizedBox(width: 8),
                    ...statChips,
                  ],
                ])),
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
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(0.25))),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: col)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 6 — PAGE STOCK ACTUEL
// ─────────────────────────────────────────────────────────────────────────────

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
      if (_sort == 'ref')        c = a.reference.compareTo(b.reference);
      else if (_sort == 'stock') c = a.total.compareTo(b.total);
      else if (_sort == 'mag')   c = a.magasin.compareTo(b.magasin);
      else                       c = a.nom.compareTo(b.nom);
      return _asc ? c : -c;
    });
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final list    = _list;
    final mobile  = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;
    final cats    = ['Toutes', ...widget.magasin.categoryNames];

    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(padding, 14, padding, 0),
        child: mobile
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _DropBox(value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v))),
                  const SizedBox(width: 8),
                  Expanded(child: _DropBox(value: _mag, items: ['Tous', ...kMagasins],
                      labels: {'Tous': 'Tous magasins', ...{for (var m in kMagasins) m: 'Mag. $m'}},
                      onChanged: (v) => setState(() => _mag = v))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _DropBox(value: _sort,
                      items: ['nom', 'ref', 'stock', 'mag'],
                      labels: {'nom': 'Nom', 'ref': 'Référence', 'stock': 'Stock', 'mag': 'Magasin'},
                      onChanged: (v) => setState(() => _sort = v))),
                  const SizedBox(width: 8),
                  _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
                ]),
              ])
            : Row(children: [
                Expanded(flex: 3, child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _DropBox(value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _DropBox(value: _mag, items: ['Tous', ...kMagasins],
                    labels: {'Tous': 'Tous magasins', ...{for (var m in kMagasins) m: 'Magasin $m'}},
                    onChanged: (v) => setState(() => _mag = v))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _DropBox(value: _sort,
                    items: ['nom', 'ref', 'stock', 'mag'],
                    labels: {'nom': 'Nom', 'ref': 'Référence', 'stock': 'Stock', 'mag': 'Magasin'},
                    onChanged: (v) => setState(() => _sort = v))),
                const SizedBox(width: 8),
                _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
              ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
          child: _DataTable(
            count: '${list.length} / ${widget.magasin.totalProduits} produits',
            empty: list.isEmpty,
            emptyMsg: 'Aucun produit trouvé',
            columns: const [
              _Col('PRODUIT',   flex: 3),
              _Col('RÉFÉRENCE', flex: 2),
              _Col('CATÉGORIE', flex: 2),
              _Col('STOCK',     flex: 1),
              _Col('MAGASIN',   flex: 1),
              _Col('',          flex: 1),
            ],
            rows: list.map((p) {
              final g          = groupeByLabel(p.groupeUniteLabel);
              final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
              final stockBg    = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
              return _DataTableRow(cells: [
                Row(children: [
                  Container(width: 34, height: 34,
                      decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(g?.emoji ?? '📦', style: const TextStyle(fontSize: 16)))),
                  const SizedBox(width: 8),
                  Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText),
                        overflow: TextOverflow.ellipsis, maxLines: 1),
                    Text(p.categorie, style: _muted.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 1),
                  ])),
                ]),
                Text(p.reference, style: _mono, overflow: TextOverflow.ellipsis),
                _PillBadge(p.categorie, kBlueLt, kBlue),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                  child: Text('${p.total}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: stockColor)),
                )),
                Center(child: _PillBadge('M.${p.magasin}', kIndigoLt, kIndigo)),
                Center(child: _IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () {
                  _showDialog(context, _DetailsDialog(produit: p, groupe: g));
                })),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 7 — PAGE ENTRÉES
// ─────────────────────────────────────────────────────────────────────────────

class _EntreesPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Mouvement> entrees;
  const _EntreesPage({required this.magasin, required this.entrees});

  @override
  State<_EntreesPage> createState() => _EntreesPageState();
}

class _EntreesPageState extends State<_EntreesPage> {
  String _cat = 'Toutes', _mag = 'Tous';

  List<Mouvement> get _list => widget.entrees
      .where((m) => (_cat == 'Toutes' || m.categorie == _cat) && (_mag == 'Tous' || m.magasin == _mag))
      .toList();

  @override
  Widget build(BuildContext context) {
    final list    = _list;
    final total   = list.fold(0, (s, m) => s + m.totalQte);
    final cats    = ['Toutes', ...widget.magasin.categoryNames];
    final mobile  = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(children: [
      _BanniereAction(
        padding: padding, mobile: mobile,
        gradient: const [Color(0xFF14532D), Color(0xFF16A34A)],
        shadowColor: kGreen,
        icon: Icons.arrow_circle_down_rounded,
        titre: 'Entrées de Stock',
        sous: '${list.length} mouvement${list.length != 1 ? "s" : ""} · $total unité${total != 1 ? "s" : ""} reçue${total != 1 ? "s" : ""}',
        cats: cats, catVal: _cat, magVal: _mag,
        onCatChanged: (v) => setState(() => _cat = v),
        onMagChanged: (v) => setState(() => _mag = v),
        btnColor: kGreen, btnLabel: 'Nouvelle entrée',
        onBtnTap: () => _showDialog(context,
            _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context)),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
          child: _DataTable(
            count: '${list.length} entrée${list.length != 1 ? "s" : ""}',
            empty: list.isEmpty,
            emptyMsg: 'Aucune entrée — cliquez sur « Nouvelle entrée »',
            accentColor: kGreen,
            columns: const [
              _Col('DATE',      flex: 2),
              _Col('PRODUIT',   flex: 3),
              _Col('RÉFÉR.',    flex: 2),
              _Col('CATÉGORIE', flex: 2),
              _Col('MAG.',      flex: 1),
              _Col('QTÉ',       flex: 1),
              _Col('',          flex: 1),
            ],
            rows: list.map((m) => _MouvRow(
              m: m, color: kGreen, bgColor: kGreenLt,
              onDelete: () => _showDialog(context, _ConfirmDel(
                nom: m.nomProduit,
                msg: 'Supprimer cette entrée ? Le stock sera décrémenté.',
                onConfirm: () {
                  widget.magasin.deleteEntree(m.id);
                  Navigator.of(context, rootNavigator: true).pop();
                },
              )),
            )).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 8 — PAGE SORTIES
// ─────────────────────────────────────────────────────────────────────────────

class _SortiesPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Mouvement> sorties;
  const _SortiesPage({required this.magasin, required this.sorties});

  @override
  State<_SortiesPage> createState() => _SortiesPageState();
}

class _SortiesPageState extends State<_SortiesPage> {
  String _cat = 'Toutes', _mag = 'Tous';

  List<Mouvement> get _list => widget.sorties
      .where((m) => (_cat == 'Toutes' || m.categorie == _cat) && (_mag == 'Tous' || m.magasin == _mag))
      .toList();

  @override
  Widget build(BuildContext context) {
    final list    = _list;
    final total   = list.fold(0, (s, m) => s + m.totalQte);
    final cats    = ['Toutes', ...widget.magasin.categoryNames];
    final mobile  = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(children: [
      _BanniereAction(
        padding: padding, mobile: mobile,
        gradient: const [Color(0xFF92400E), Color(0xFFD97706)],
        shadowColor: kOrange,
        icon: Icons.arrow_circle_up_rounded,
        titre: 'Sorties de Stock',
        sous: '${list.length} mouvement${list.length != 1 ? "s" : ""} · $total unité${total != 1 ? "s" : ""} sortie${total != 1 ? "s" : ""}',
        cats: cats, catVal: _cat, magVal: _mag,
        onCatChanged: (v) => setState(() => _cat = v),
        onMagChanged: (v) => setState(() => _mag = v),
        btnColor: kOrange, btnLabel: 'Nouvelle sortie',
        onBtnTap: () => _showDialog(context,
            _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context)),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
          child: _DataTable(
            count: '${list.length} sortie${list.length != 1 ? "s" : ""}',
            empty: list.isEmpty,
            emptyMsg: 'Aucune sortie — cliquez sur « Nouvelle sortie »',
            accentColor: kOrange,
            columns: const [
              _Col('DATE',       flex: 2),
              _Col('PRODUIT',    flex: 3),
              _Col('RÉFÉR.',     flex: 2),
              _Col('CATÉGORIE',  flex: 2),
              _Col('MAG.',       flex: 1),
              _Col('QTÉ',        flex: 1),
              _Col('PRÉLEVÉ PAR', flex: 2),
              _Col('',           flex: 1),
            ],
            rows: list.map((m) => _MouvRow(
              m: m, color: kOrange, bgColor: kOrangeLt, showPreneur: true,
              onDelete: () => _showDialog(context, _ConfirmDel(
                nom: m.nomProduit,
                msg: 'Supprimer cette sortie ? Le stock sera restitué.',
                onConfirm: () {
                  widget.magasin.deleteSortie(m.id);
                  Navigator.of(context, rootNavigator: true).pop();
                },
              )),
            )).toList(),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 9 — BANNIÈRE ACTION (réutilisable)
// ─────────────────────────────────────────────────────────────────────────────

class _BanniereAction extends StatelessWidget {
  final double padding;
  final bool mobile;
  final List<Color> gradient;
  final Color shadowColor, btnColor;
  final IconData icon;
  final String titre, sous, btnLabel;
  final List<String> cats;
  final String catVal, magVal;
  final ValueChanged<String> onCatChanged, onMagChanged;
  final VoidCallback onBtnTap;

  const _BanniereAction({
    required this.padding, required this.mobile, required this.gradient,
    required this.shadowColor, required this.icon, required this.titre, required this.sous,
    required this.cats, required this.catVal, required this.magVal,
    required this.onCatChanged, required this.onMagChanged,
    required this.btnColor, required this.btnLabel, required this.onBtnTap,
  });

  Widget _iconTitre() => Row(children: [
    Container(padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: Colors.white, size: 22)),
    const SizedBox(width: 12),
    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
      Text(sous, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75)), overflow: TextOverflow.ellipsis),
    ])),
  ]);

  Widget _filtres() => Row(mainAxisSize: MainAxisSize.min, children: [
    _GlassDropdown(value: catVal, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: onCatChanged),
    const SizedBox(width: 8),
    _GlassDropdown(value: magVal, items: ['Tous', ...kMagasins],
        labels: {'Tous': 'Tous', ...{for (var m in kMagasins) m: 'Mag. $m'}},
        icon: Icons.warehouse_rounded, hint: 'Magasin', onChanged: onMagChanged),
  ]);

  Widget _btn() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white, foregroundColor: btnColor, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    ),
    icon: const Icon(Icons.add_rounded, size: 15),
    label: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    onPressed: onBtnTap,
  );

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.fromLTRB(padding, 14, padding, 0),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(kR2),
      boxShadow: [BoxShadow(color: shadowColor.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _iconTitre(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _GlassDropdown(value: catVal, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: onCatChanged)),
              const SizedBox(width: 8),
              Expanded(child: _GlassDropdown(value: magVal, items: ['Tous', ...kMagasins],
                  labels: {'Tous': 'Tous', ...{for (var m in kMagasins) m: 'Mag. $m'}},
                  icon: Icons.warehouse_rounded, hint: 'Magasin', onChanged: onMagChanged)),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: _btn()),
          ])
        : Row(children: [
            Expanded(child: _iconTitre()),
            const SizedBox(width: 12),
            _filtres(),
            const SizedBox(width: 12),
            _btn(),
          ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 10 — PAGE HISTORIQUE
// ─────────────────────────────────────────────────────────────────────────────

class _HistoriquePage extends StatefulWidget {
  final MagasinProvider magasin;
  const _HistoriquePage({required this.magasin});

  @override
  State<_HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<_HistoriquePage> {
  String _typeFiltre = 'Tout';
  DateTime? _dateDebut, _dateFin;
  String _mag = 'Tous';

  List<Mouvement> get _list {
    final all = [...widget.magasin.entrees, ...widget.magasin.sorties];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.where((m) {
      final typeOk  = _typeFiltre == 'Tout'
          || (_typeFiltre == 'Entrées' && m.type == 'entree')
          || (_typeFiltre == 'Sorties' && m.type == 'sortie');
      final debutOk = _dateDebut == null || !m.date.isBefore(DateTime(_dateDebut!.year, _dateDebut!.month, _dateDebut!.day));
      final finOk   = _dateFin   == null || !m.date.isAfter(DateTime(_dateFin!.year, _dateFin!.month, _dateFin!.day, 23, 59, 59));
      final magOk   = _mag == 'Tous' || m.magasin == _mag;
      return typeOk && debutOk && finOk && magOk;
    }).toList();
  }

  Future<void> _pickDate(BuildContext context, bool isDebut) async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? (_dateDebut ?? now) : (_dateFin ?? now),
      firstDate: DateTime(2020), lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPurple, onPrimary: Colors.white, surface: kSurface)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() { if (isDebut) _dateDebut = picked; else _dateFin = picked; });
  }

  @override
  Widget build(BuildContext context) {
    final list    = _list;
    final mobile  = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(children: [
      Container(
        margin: EdgeInsets.fromLTRB(padding, 14, padding, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(kR2),
          boxShadow: [BoxShadow(color: kPurple.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: EdgeInsets.all(mobile ? 8 : 9),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.history_rounded, color: Colors.white, size: mobile ? 20 : 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Historique des opérations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('${list.length} opération${list.length != 1 ? "s" : ""}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
            ])),
            if (!mobile) ...[
              const SizedBox(width: 12),
              _TypeToggleRow(typeFiltre: _typeFiltre, onChanged: (v) => setState(() => _typeFiltre = v)),
              const SizedBox(width: 12),
              _GlassDropdown(value: _mag, items: ['Tous', ...kMagasins],
                  labels: {'Tous': 'Tous magasins', ...{for (var m in kMagasins) m: 'Mag. $m'}},
                  icon: Icons.warehouse_rounded, hint: 'Magasin', onChanged: (v) => setState(() => _mag = v)),
            ],
          ]),
          if (mobile) ...[
            const SizedBox(height: 10),
            _TypeToggleRow(typeFiltre: _typeFiltre, onChanged: (v) => setState(() => _typeFiltre = v)),
            const SizedBox(height: 8),
            _GlassDropdown(value: _mag, items: ['Tous', ...kMagasins],
                labels: {'Tous': 'Tous magasins', ...{for (var m in kMagasins) m: 'Mag. $m'}},
                icon: Icons.warehouse_rounded, hint: 'Magasin', onChanged: (v) => setState(() => _mag = v)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.date_range_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Text('Période :', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            if (mobile) ...[
              Expanded(child: _DatePickerBtn(label: 'Du', date: _dateDebut, onTap: () => _pickDate(context, true))),
              const SizedBox(width: 6),
              Expanded(child: _DatePickerBtn(label: 'Au', date: _dateFin, onTap: () => _pickDate(context, false))),
            ] else ...[
              _DatePickerBtn(label: 'Du', date: _dateDebut, onTap: () => _pickDate(context, true)),
              const SizedBox(width: 8),
              _DatePickerBtn(label: 'Au', date: _dateFin, onTap: () => _pickDate(context, false)),
            ],
            if (_dateDebut != null || _dateFin != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() { _dateDebut = null; _dateFin = null; }),
                borderRadius: BorderRadius.circular(7),
                child: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
              ),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
          child: _DataTable(
            count: '${list.length} opération${list.length != 1 ? "s" : ""}',
            empty: list.isEmpty,
            emptyMsg: 'Aucune opération pour ces filtres',
            accentColor: kPurple,
            columns: const [
              _Col('TYPE',      flex: 1),
              _Col('DATE',      flex: 2),
              _Col('PRODUIT',   flex: 3),
              _Col('RÉFÉR.',    flex: 2),
              _Col('CATÉGORIE', flex: 2),
              _Col('MAG.',      flex: 1),
              _Col('QTÉ',       flex: 1),
              _Col('PRÉLEVÉ',   flex: 2),
              _Col('',          flex: 1),
            ],
            rows: list.map((m) {
              final isE = m.type == 'entree';
              final color = isE ? kGreen : kOrange;
              final bg    = isE ? kGreenLt : kOrangeLt;
              return _DataTableRow(cells: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isE ? Icons.south_rounded : Icons.north_rounded, size: 11, color: color),
                    const SizedBox(width: 3),
                    Text(isE ? 'Entrée' : 'Sortie', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmtDate(m.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
                  Text(_fmtTime(m.date), style: _muted.copyWith(fontSize: 10)),
                ]),
                Text(m.nomProduit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
                Text(m.reference, style: _mono, overflow: TextOverflow.ellipsis),
                _PillBadge(m.categorie, kBlueLt, kBlue),
                Center(child: _PillBadge('M.${m.magasin}', kIndigoLt, kIndigo)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text('${m.totalQte}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ),
                m.preneurNom != null
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: kMuted),
                        const SizedBox(width: 4),
                        Flexible(child: Text(m.preneurNom!, style: const TextStyle(fontSize: 11, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ])
                    : const Text('—', style: _muted),
                Center(child: _IconBtn(Icons.visibility_outlined, 'Détails', kPurpleLt, kPurple, () {
                  _showDialog(context, _DetailsOperationDialog(m: m));
                })),
              ]);
            }).toList(),
          ),
        ),
      ),
    ]);
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 11 — FORMULAIRE MOUVEMENT
// ─────────────────────────────────────────────────────────────────────────────

class _MouvForm extends StatefulWidget {
  final String type;
  final MagasinProvider magasin;
  final BuildContext? scaffoldContext;
  const _MouvForm({required this.type, required this.magasin, this.scaffoldContext});

  @override
  State<_MouvForm> createState() => _MouvFormState();
}

class _MouvFormState extends State<_MouvForm> {
  String? _selMag, _selCat;
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
  String? _stockError;
  Map<String, String> _varStockErrors = {};
  bool _saving = false;

  bool get _isSortie => widget.type == 'sortie';
  Color get _col => _isSortie ? kOrange : kGreen;
  GroupeUnites? get _groupe => _newProdMode ? groupeByLabel(_newGroupeLabel) : groupeByLabel(_selProd?.groupeUniteLabel);
  bool get _hasVar => _newProdMode ? _newHasVar : (_selProd?.aVariantes ?? false);

  List<Produit> get _filteredProduits => widget.magasin.produits.where((p) {
    final magOk = _selMag == null || p.magasin == _selMag;
    final catOk = _selCat == null || p.categorie == _selCat;
    return magOk && catOk;
  }).toList();

  void _validateStock() {
    if (!_isSortie || _selProd == null) {
      setState(() { _stockError = null; _varStockErrors = {}; });
      return;
    }
    if (!_hasVar) {
      final demande = int.tryParse(_qteC.text) ?? 0;
      final dispo   = _selProd!.total;
      setState(() => _stockError = demande > dispo ? 'Stock insuffisant (disponible : $dispo)' : null);
    } else {
      final errors = <String, String>{};
      for (final u in _selVar) {
        final demande  = int.tryParse(_varCtrl[u]?.text ?? '0') ?? 0;
        final varMatch = _selProd!.variantes.where((v) => v.unite == u);
        final dispo    = varMatch.isEmpty ? 0 : varMatch.first.quantite;
        if (demande > dispo) errors[u] = 'Max $dispo';
      }
      setState(() => _varStockErrors = errors);
    }
  }

  bool get _hasStockError =>
      !_isSortie ? false : (!_hasVar ? _stockError != null : _varStockErrors.isNotEmpty);

  void _toggleVar(String u) => setState(() {
    if (_selVar.contains(u)) { _selVar.remove(u); _varCtrl.remove(u); }
    else { _selVar.add(u); _varCtrl[u] = TextEditingController(text: '1'); }
    _validateStock();
  });

  bool get _canSave {
    if (_saving) return false;
    final magOk  = _selMag != null;
    final catOk  = _newCatMode ? _newCatCtrl.text.trim().isNotEmpty : _selCat != null;
    final prodOk = _newProdMode ? (_newNomCtrl.text.trim().isNotEmpty && _newRefCtrl.text.trim().isNotEmpty) : _selProd != null;
    final qteOk  = _hasVar ? _selVar.isNotEmpty : (int.tryParse(_qteC.text) ?? 0) > 0;
    final prenOk = !_isSortie || _preneurC.text.trim().isNotEmpty;
    return magOk && catOk && prodOk && qteOk && prenOk && !_hasStockError;
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    final dialogCtx   = context;
    final scaffoldCtx = widget.scaffoldContext;

    try {
      final catFinal = _newCatMode ? _newCatCtrl.text.trim() : (_selCat ?? '');
      if (catFinal.isEmpty) throw Exception('Catégorie manquante');

      if (_newCatMode) await widget.magasin.addCategorie(catFinal);

      // ── Produit ────────────────────────────────────────────────────────────
      Produit prod;
      if (_newProdMode) {
        final nom = _newNomCtrl.text.trim();
        final ref = _newRefCtrl.text.trim();
        if (nom.isEmpty || ref.isEmpty) throw Exception('Nom ou référence manquant');
        if (_selMag == null) throw Exception('Aucun magasin sélectionné');

        final newProd = Produit(
          id: '', nom: nom, reference: ref, categorie: catFinal,
          magasin: _selMag!, aVariantes: _newHasVar,
          groupeUniteLabel: _newHasVar ? _newGroupeLabel : null,
          quantiteStock: 0, variantes: [],
        );
        final newId = await widget.magasin.addProduit(newProd);
        if (newId.isEmpty) throw Exception('Erreur création produit');

        // Attendre que le stream reçoive le nouveau produit
        for (int i = 0; i < 40; i++) {
          if (widget.magasin.produits.any((p) => p.id == newId)) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        prod = newProd.copyWith(id: newId);
      } else {
        if (_selProd == null) throw Exception('Aucun produit sélectionné');
        prod = _selProd!;
      }

      if (_selMag == null) throw Exception('Aucun magasin sélectionné');

      // ── Lignes variantes ───────────────────────────────────────────────────
      final lignes = _hasVar
          ? _selVar.map((u) => LigneMouvement(
                unite: u,
                quantite: int.tryParse(_varCtrl[u]?.text ?? '0') ?? 0,
              )).where((l) => l.quantite > 0).toList()
          : <LigneMouvement>[];

      final quantite = _hasVar ? 0 : (int.tryParse(_qteC.text) ?? 0);
      if (!_hasVar && quantite <= 0) throw Exception('Quantité invalide');
      if (_hasVar && lignes.isEmpty) throw Exception('Sélectionnez au moins une variante');

      // ── Mouvement ──────────────────────────────────────────────────────────
      final mouvement = Mouvement(
        id: '', type: widget.type,
        produitId: prod.id, nomProduit: prod.nom, reference: prod.reference,
        categorie: catFinal, magasin: _selMag!,
        aVariantes: _hasVar,
        groupeUniteLabel: _hasVar ? (prod.groupeUniteLabel ?? _newGroupeLabel) : null,
        quantite: quantite, lignes: lignes,
        date: DateTime.now(),
        preneurNom: (_isSortie && _preneurC.text.trim().isNotEmpty) ? _preneurC.text.trim() : null,
      );

      if (_isSortie) {
        await widget.magasin.addSortie(mouvement);
      } else {
        await widget.magasin.addEntree(mouvement);
      }

      // ── Fermer + SnackBar ──────────────────────────────────────────────────
      if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) {
        Navigator.of(dialogCtx, rootNavigator: true).pop();
      }
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(
          content: Text(_isSortie ? 'Sortie enregistrée' : 'Entrée enregistrée'),
          backgroundColor: _isSortie ? kOrange : kGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FullDialog(
      color: _col,
      icon: _isSortie ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
      title: _isSortie ? 'Nouvelle Sortie de Stock' : "Nouvelle Entrée de Stock",
      onSave: _canSave ? _save : null,
      saveLabel: _saving ? 'Enregistrement…' : (_isSortie ? 'Valider la sortie' : "Valider l'entrée"),
      saving: _saving,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 1. Magasin ───────────────────────────────────────────────────────
        _SectionHdr('1. Choisir le magasin', Icons.warehouse_rounded, _col),
        const SizedBox(height: 12),
        Row(children: kMagasins.map((mag) {
          final sel       = _selMag == mag;
          final prodCount = widget.magasin.produits.where((p) => p.magasin == mag).length;
          return Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => setState(() {
                _selMag = mag; _selProd = null; _selCat = null;
                _selVar.clear(); _varCtrl.clear();
                _newCatMode = false; _newProdMode = false;
                _stockError = null; _varStockErrors = {};
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: sel ? _col.withOpacity(0.07) : kSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: sel ? _col : kBorder, width: sel ? 2.0 : 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: sel ? _col : kBg, borderRadius: BorderRadius.circular(9)),
                    child: const Center(child: Text('🏪', style: TextStyle(fontSize: 20)))),
                  const SizedBox(height: 8),
                  Text('Mag. $mag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: sel ? _col : kText)),
                  const SizedBox(height: 3),
                  Text('$prodCount prod.', style: _muted.copyWith(fontSize: 10)),
                  if (sel) ...[
                    const SizedBox(height: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: _col, borderRadius: BorderRadius.circular(20)),
                        child: const Text('✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                  ],
                ]),
              ),
            ),
          ));
        }).toList()),
        const SizedBox(height: 22),

        if (_selMag != null) ...[
          // ── 2. Catégorie ─────────────────────────────────────────────────
          _SectionHdr('2. Catégorie', Icons.category_outlined, _col),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _newCatMode
                ? _StyledTF(ctrl: _newCatCtrl, hint: 'Nom de la nouvelle catégorie…',
                    prefix: const Icon(Icons.category_outlined, size: 18, color: kMuted),
                    onChanged: (_) => setState(() {}))
                : _StyledDrop<String>(
                    value: _selCat, hint: 'Sélectionner une catégorie',
                    items: widget.magasin.categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() { _selCat = v; _selProd = null; _selVar.clear(); _varCtrl.clear(); }))),
            const SizedBox(width: 8),
            _ModeBtn(label: _newCatMode ? '← Existante' : '+ Nouvelle', color: _col,
                onTap: () => setState(() { _newCatMode = !_newCatMode; _selCat = null; })),
          ]),
          const SizedBox(height: 22),

          if (_selCat != null || _newCatMode) ...[
            // ── 3. Produit ───────────────────────────────────────────────
            _SectionHdr('3. Produit', Icons.inventory_2_outlined, _col),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _newProdMode
                  ? _NewProdBlock(
                      nomCtrl: _newNomCtrl, refCtrl: _newRefCtrl, mag: _selMag!,
                      hasVar: _newHasVar, groupeLabel: _newGroupeLabel, color: _col,
                      onHasVarChanged: (v) => setState(() { _newHasVar = v; _selVar.clear(); _varCtrl.clear(); }),
                      onGroupeChanged: (v) => setState(() { _newGroupeLabel = v; _selVar.clear(); _varCtrl.clear(); }),
                      onChanged: () => setState(() {}))
                  : _StyledDrop<Produit>(
                      value: _selProd,
                      hint: _filteredProduits.isEmpty ? 'Aucun produit' : 'Sélectionner un produit',
                      items: _filteredProduits.map((p) => DropdownMenuItem(value: p, child: Row(children: [
                        Flexible(child: Text(p.nom, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        _PillBadge(p.reference, kBlueLt, kBlue),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${p.total}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                              color: p.rupture ? kRed : p.bas ? kOrange : kGreen))),
                      ]))).toList(),
                      onChanged: (v) => setState(() { _selProd = v; _selVar.clear(); _varCtrl.clear(); _validateStock(); }))),
              const SizedBox(width: 8),
              _ModeBtn(label: _newProdMode ? '← Existant' : '+ Nouveau', color: _col,
                  onTap: () => setState(() {
                    _newProdMode = !_newProdMode; _selProd = null;
                    _selVar.clear(); _varCtrl.clear(); _stockError = null; _varStockErrors = {};
                  })),
            ]),
            const SizedBox(height: 22),

            if (_selProd != null || _newProdMode) ...[
              // ── 4. Quantité ────────────────────────────────────────────
              _SectionHdr('4. Quantité', _hasVar ? Icons.grid_view_rounded : Icons.tag_rounded, _col),
              const SizedBox(height: 10),

              if (_isSortie && _selProd != null && !_newProdMode) ...[
                if (_stockError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kRed.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: kRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_stockError!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kRed))),
                    ]),
                  ),
                if (!_hasVar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 13, color: kMuted),
                      const SizedBox(width: 5),
                      Text('Stock disponible : ${_selProd!.total}', style: _muted.copyWith(fontSize: 11)),
                    ]),
                  ),
              ],

              if (!_hasVar)
                SizedBox(width: 180, child: _NumStepField(ctrl: _qteC, color: _col, onChanged: () { setState(() {}); _validateStock(); }))
              else if (_groupe != null) ...[
                Wrap(spacing: 7, runSpacing: 7, children: _groupe!.unites.map((u) {
                  final sel = _selVar.contains(u);
                  int? disp;
                  if (_isSortie && _selProd != null) {
                    final vm = _selProd!.variantes.where((v) => v.unite == u);
                    disp = vm.isEmpty ? 0 : vm.first.quantite;
                  }
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _toggleVar(u),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _col : kSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? _col : kBorder, width: sel ? 2 : 1.5),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(u, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : kMuted)),
                        if (disp != null) Text('$disp dispo', style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : kMuted)),
                      ]),
                    ),
                  );
                }).toList()),
                if (_selVar.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _VarQteTable(
                    selVar: _selVar, varCtrl: _varCtrl, color: _col,
                    onRemove: _toggleVar,
                    stockErrors: _varStockErrors,
                    stockDisp: _isSortie && _selProd != null
                        ? {for (var v in _selProd!.variantes) v.unite: v.quantite}
                        : {},
                    onQteChanged: _validateStock,
                  ),
                ],
              ],
              const SizedBox(height: 22),
            ],

            if (_isSortie && (_selProd != null || _newProdMode)) ...[
              // ── 5. Prélevé par ─────────────────────────────────────────
              _SectionHdr('5. Prélevé par', Icons.person_outline_rounded, _col),
              const SizedBox(height: 10),
              _StyledTF(ctrl: _preneurC, hint: 'Nom et prénom…',
                  prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted),
                  onChanged: (_) => setState(() {})),
            ],
          ],
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 12 — WIDGETS FORMULAIRE
// ─────────────────────────────────────────────────────────────────────────────

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
    required this.nomCtrl, required this.refCtrl, required this.mag,
    required this.hasVar, this.groupeLabel, required this.color,
    required this.onHasVarChanged, required this.onGroupeChanged, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: kIndigoLt, borderRadius: BorderRadius.circular(7), border: Border.all(color: kIndigo.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warehouse_rounded, size: 13, color: kIndigo),
          const SizedBox(width: 6),
          Flexible(child: Text('Enregistré dans Magasin $mag',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kIndigo))),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NOM DU PRODUIT', style: _label),
          const SizedBox(height: 5),
          _StyledTF(ctrl: nomCtrl, hint: 'Ex: Casque de sécurité', onChanged: (_) => onChanged()),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('RÉFÉRENCE', style: _label),
          const SizedBox(height: 5),
          _StyledTF(ctrl: refCtrl, hint: 'Ex: EPI-010', onChanged: (_) => onChanged()),
        ])),
      ]),
      const SizedBox(height: 12),
      const Text('A DES VARIANTES ?', style: _label),
      const SizedBox(height: 5),
      Row(children: [
        _ToggleBtn('Oui', hasVar,  color, () => onHasVarChanged(true)),
        const SizedBox(width: 8),
        _ToggleBtn('Non', !hasVar, color, () => onHasVarChanged(false)),
      ]),
      if (hasVar) ...[
        const SizedBox(height: 12),
        const Text("GROUPE D'UNITÉS", style: _label),
        const SizedBox(height: 5),
        _StyledDrop<String>(
          value: groupeLabel,
          hint: 'Choisir un groupe',
          items: kGroupes.map((g) => DropdownMenuItem(value: g.label,
              child: Row(children: [Text(g.emoji), const SizedBox(width: 8),
                Flexible(child: Text(g.label, overflow: TextOverflow.ellipsis))]))).toList(),
          onChanged: onGroupeChanged,
        ),
      ],
    ]),
  );
}

class _VarQteTable extends StatefulWidget {
  final Set<String> selVar;
  final Map<String, TextEditingController> varCtrl;
  final Color color;
  final void Function(String) onRemove;
  final Map<String, String> stockErrors;
  final Map<String, int> stockDisp;
  final VoidCallback onQteChanged;

  const _VarQteTable({
    required this.selVar, required this.varCtrl, required this.color,
    required this.onRemove, this.stockErrors = const {}, this.stockDisp = const {},
    required this.onQteChanged,
  });

  @override
  State<_VarQteTable> createState() => _VarQteTableState();
}

class _VarQteTableState extends State<_VarQteTable> {
  @override
  Widget build(BuildContext context) {
    final col   = widget.color;
    final total = widget.selVar.fold(0, (s, u) => s + (int.tryParse(widget.varCtrl[u]?.text ?? '0') ?? 0));
    return Container(
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(kR))),
          child: Row(children: [
            SizedBox(width: 100, child: Text('UNITÉ',    style: _label.copyWith(color: col))),
            const SizedBox(width: 10),
            Expanded(child: Text('QUANTITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 34),
          ]),
        ),
        ...widget.selVar.toList().asMap().entries.map((e) {
          final i    = e.key;
          final u    = e.value;
          final ctrl = widget.varCtrl[u]!;
          final err  = widget.stockErrors[u];
          final disp = widget.stockDisp[u];
          return Column(children: [
            if (i > 0) const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(children: [
                Row(children: [
                  Container(width: 100, height: 36, alignment: Alignment.center,
                      decoration: BoxDecoration(color: err != null ? kRed : col, borderRadius: BorderRadius.circular(7)),
                      child: Text(u, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  Expanded(child: Row(children: [
                    _StepBtn(Icons.remove_rounded, col, () {
                      final v = int.tryParse(ctrl.text) ?? 0;
                      if (v > 0) { ctrl.text = '${v - 1}'; setState(() {}); widget.onQteChanged(); }
                    }),
                    Expanded(child: SizedBox(height: 40, child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kText),
                      decoration: InputDecoration(
                        hintText: '0', contentPadding: EdgeInsets.zero,
                        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : col, width: 2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : kBorder, width: err != null ? 2 : 1)),
                      ),
                      onChanged: (_) { setState(() {}); widget.onQteChanged(); },
                    ))),
                    _StepBtn(Icons.add_rounded, col, () {
                      final v = int.tryParse(ctrl.text) ?? 0;
                      ctrl.text = '${v + 1}'; setState(() {}); widget.onQteChanged();
                    }),
                  ])),
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () { widget.onRemove(u); setState(() {}); },
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close_rounded, size: 14, color: kRed)),
                  ),
                ]),
                if (err != null)
                  Padding(padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const SizedBox(width: 110),
                        const Icon(Icons.error_outline, size: 12, color: kRed),
                        const SizedBox(width: 3),
                        Text(err, style: const TextStyle(fontSize: 10, color: kRed, fontWeight: FontWeight.w600)),
                      ]))
                else if (disp != null)
                  Padding(padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        const SizedBox(width: 110),
                        Icon(Icons.info_outline, size: 11, color: kMuted.withOpacity(0.7)),
                        const SizedBox(width: 3),
                        Text('$disp dispo', style: TextStyle(fontSize: 10, color: kMuted.withOpacity(0.8))),
                      ])),
              ]),
            ),
          ]);
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kR))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('TOTAL', style: _label.copyWith(color: col)),
            Text('$total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: col)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 13 — DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsDialog extends StatelessWidget {
  final Produit produit;
  final GroupeUnites? groupe;
  const _DetailsDialog({required this.produit, this.groupe});

  @override
  Widget build(BuildContext context) {
    final p          = produit;
    final g          = groupe;
    final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
    final stockBg    = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
    final stockLabel = p.rupture ? 'Rupture' : p.bas ? 'Bas' : 'OK';

    return _FullDialog(
      color: kBlue, icon: Icons.inventory_2_rounded, title: p.nom,
      saveLabel: 'Fermer',
      onSave: () => Navigator.of(context, rootNavigator: true).pop(),
      showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _DetCard(Icons.qr_code_rounded,   '🏷️ Référence', p.reference),
          _DetCard(Icons.category_outlined, '📂 Catégorie', p.categorie),
          _DetCard(Icons.warehouse_rounded, '🏪 Magasin',   'Magasin ${p.magasin}'),
          if (g != null) _DetCard(Icons.widgets_rounded, '${g.emoji} Mesures', g.label),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: stockColor.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inventory_2_outlined, color: stockColor, size: 20),
            const SizedBox(width: 10),
            Text('${p.total}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: stockColor)),
            const SizedBox(width: 5),
            Text('unité${p.total != 1 ? "s" : ""}', style: TextStyle(fontSize: 12, color: stockColor.withOpacity(0.8))),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: stockColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(stockLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stockColor)),
            ),
          ]),
        ),
        if (p.aVariantes && p.variantes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
            child: ClipRRect(borderRadius: BorderRadius.circular(kR), child: Column(children: [
              Container(color: kBlueLt, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text('UNITÉ',    style: _label.copyWith(color: kBlue))),
                    Expanded(flex: 2, child: Text('QUANTITÉ', style: _label.copyWith(color: kBlue))),
                    Expanded(flex: 1, child: Text('STATUT',   style: _label.copyWith(color: kBlue))),
                  ])),
              ...p.variantes.asMap().entries.map((e) {
                final v  = e.value;
                final r  = v.quantite == 0;
                final lo = v.quantite > 0 && v.quantite <= 3;
                final vc = r ? kRed : lo ? kOrange : kGreen;
                final vb = r ? kRedLt : lo ? kOrangeLt : kGreenLt;
                return Column(children: [
                  if (e.key > 0) const Divider(height: 1, color: kBorder),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft,
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(7)),
                                child: Text(v.unite, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)))),
                        Expanded(flex: 2, child: Text('${v.quantite}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: vc))),
                        Expanded(flex: 1, child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: vb, borderRadius: BorderRadius.circular(20)),
                            child: Text(r ? 'Rupture' : lo ? 'Bas' : 'OK',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: vc)))),
                      ])),
                ]);
              }),
              Container(color: kBlueLt, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('TOTAL', style: _label.copyWith(color: kBlue)),
                    Text('${p.total}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlue)),
                  ])),
            ])),
          ),
        ],
      ]),
    );
  }
}

class _DetailsOperationDialog extends StatelessWidget {
  final Mouvement m;
  const _DetailsOperationDialog({required this.m});

  @override
  Widget build(BuildContext context) {
    final isE   = m.type == 'entree';
    final color = isE ? kGreen : kOrange;
    final bg    = isE ? kGreenLt : kOrangeLt;
    final g     = groupeByLabel(m.groupeUniteLabel);

    return _FullDialog(
      color: color,
      icon: isE ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded,
      title: isE ? "Détails de l'entrée" : 'Détails de la sortie',
      saveLabel: 'Fermer',
      onSave: () => Navigator.of(context, rootNavigator: true).pop(),
      showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _DetCard(Icons.inventory_2_outlined,   '📦 Produit',    m.nomProduit),
          _DetCard(Icons.qr_code_rounded,        '🏷️ Référence',  m.reference),
          _DetCard(Icons.category_outlined,      '📂 Catégorie',  m.categorie),
          _DetCard(Icons.warehouse_rounded,      '🏪 Magasin',    'Magasin ${m.magasin}'),
          _DetCard(Icons.calendar_today_rounded, '📅 Date',       _fmtFull(m.date)),
          if (m.preneurNom != null)
            _DetCard(Icons.person_outline_rounded, '👤 Prélevé par', m.preneurNom!),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: color.withOpacity(0.2))),
          child: Row(children: [
            Icon(isE ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(
                isE ? 'Entrée de stock — ${m.totalQte} unité${m.totalQte != 1 ? "s" : ""}' : 'Sortie de stock — ${m.totalQte} unité${m.totalQte != 1 ? "s" : ""}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
          ]),
        ),
        if (m.aVariantes && m.lignes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
            child: ClipRRect(borderRadius: BorderRadius.circular(kR), child: Column(children: [
              Container(color: color.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(children: [
                    Expanded(flex: 2, child: Text('UNITÉ',    style: _label.copyWith(color: color))),
                    Expanded(flex: 2, child: Text('QUANTITÉ', style: _label.copyWith(color: color))),
                  ])),
              ...m.lignes.asMap().entries.map((e) => Column(children: [
                if (e.key > 0) const Divider(height: 1, color: kBorder),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft,
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                              child: Text(e.value.unite, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis)))),
                      Expanded(flex: 2, child: Text('${e.value.quantite}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))),
                    ])),
              ])),
              Container(color: color.withOpacity(0.1), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('TOTAL', style: _label.copyWith(color: color)),
                    Text('${m.totalQte}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                  ])),
            ])),
          ),
        ] else if (!m.aVariantes) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: color.withOpacity(0.2))),
            child: Row(children: [
              Icon(Icons.tag_rounded, color: color, size: 16),
              const SizedBox(width: 8),
              Text('Quantité : ${m.quantite}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            ]),
          ),
        ],
      ]),
    );
  }

  static String _fmtFull(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ConfirmDel extends StatelessWidget {
  final String nom, msg;
  final VoidCallback onConfirm;
  const _ConfirmDel({required this.nom, required this.msg, required this.onConfirm});

  @override
  Widget build(BuildContext context) => _FullDialog(
    color: kRed, icon: Icons.delete_outline_rounded, title: 'Confirmer la suppression',
    saveLabel: 'Supprimer', onSave: onConfirm,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kRed.withOpacity(0.2))),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: kRed, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 3),
          Text(msg, style: _muted),
        ])),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 14 — FULL DIALOG SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _FullDialog extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, saveLabel;
  final VoidCallback? onSave;
  final Widget child;
  final bool showCancel;
  final bool saving;

  const _FullDialog({
    required this.color, required this.icon, required this.title,
    required this.saveLabel, required this.onSave, required this.child,
    this.showCancel = true, this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final margin = mobile ? 12.0 : 40.0;
    final maxW   = mobile ? double.infinity : 600.0;
    final maxH   = MediaQuery.of(context).size.height * 0.9;

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.fromLTRB(margin, margin, margin, margin),
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          decoration: BoxDecoration(
            color: kSurface, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 16),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis)),
                InkWell(
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
                ),
              ]),
            ),
            // ── Corps scrollable ────────────────────────────────────────────
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(kP), child: child)),
            // ── Footer boutons ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kP, vertical: 12),
              decoration: const BoxDecoration(
                  color: kBg, border: Border(top: BorderSide(color: kBorder)),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (showCancel) ...[
                  TextButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: const Text('Annuler', style: TextStyle(color: kMuted)),
                  ),
                  const SizedBox(width: 8),
                ],
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: onSave != null ? 1.0 : 0.4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: onSave,
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icon, size: 14),
                            const SizedBox(width: 6),
                            Text(saveLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 15 — COMPOSANTS UI PARTAGÉS
// ─────────────────────────────────────────────────────────────────────────────

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

  const _DataTable({
    required this.columns, required this.rows, required this.count,
    required this.empty, this.emptyMsg = 'Aucun résultat', this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? kBlue;
    return Container(
      decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(kR2), border: Border.all(color: kBorder),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(kR2), child: Column(children: [
        Container(
          color: accent.withOpacity(0.07),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: columns.map((c) => Expanded(flex: c.flex,
              child: Text(c.label, style: _label.copyWith(color: accent), overflow: TextOverflow.ellipsis))).toList()),
        ),
        const Divider(height: 1, color: kBorder),
        Expanded(child: empty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_rounded, size: 48, color: accent.withOpacity(0.2)),
                const SizedBox(height: 10),
                Text(emptyMsg, style: _muted, textAlign: TextAlign.center),
              ]))
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                itemBuilder: (_, i) => _RowWidget(row: rows[i], columns: columns, accentColor: accent))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: accent.withOpacity(0.04), border: const Border(top: BorderSide(color: kBorder))),
          child: Text(count, style: _muted.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
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
    onExit:  (_) => setState(() => _hov = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _hov ? widget.accentColor.withOpacity(0.04) : kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.columns.length, (i) => Expanded(
          flex: widget.columns[i].flex,
          child: i < widget.row.cells.length
              ? Align(alignment: Alignment.centerLeft, child: widget.row.cells[i])
              : const SizedBox.shrink(),
        )),
      ),
    ),
  );
}

class _MouvRow extends _DataTableRow {
  final Mouvement m;
  final Color color, bgColor;
  final bool showPreneur;
  final VoidCallback onDelete;

  _MouvRow({required this.m, required this.color, required this.bgColor,
    this.showPreneur = false, required this.onDelete}) : super(cells: const []);

  String get _d => '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}';
  String get _t => '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';

  @override
  List<Widget> get cells => [
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
      Text(_t, style: _muted.copyWith(fontSize: 10)),
    ]),
    Text(m.nomProduit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
    Text(m.reference, style: _mono, overflow: TextOverflow.ellipsis),
    _PillBadge(m.categorie, kBlueLt, kBlue),
    Center(child: _PillBadge('M.${m.magasin}', kIndigoLt, kIndigo)),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text('${m.totalQte}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    ),
    if (showPreneur)
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_outline_rounded, size: 12, color: kMuted),
        const SizedBox(width: 4),
        Flexible(child: Text(m.preneurNom ?? '—', style: const TextStyle(fontSize: 11, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1)),
      ]),
    Center(child: _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete)),
  ];
}

// ── Petits composants ─────────────────────────────────────────────────────────

class _PillBadge extends StatelessWidget {
  final String text;
  final Color bg, col;
  const _PillBadge(this.text, this.bg, this.col);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col), overflow: TextOverflow.ellipsis, maxLines: 1),
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
      borderRadius: BorderRadius.circular(7), onTap: fn,
      child: Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: col)),
    ),
  );
}

class _DetCard extends StatelessWidget {
  final IconData icon;
  final String label, val;
  const _DetCard(this.icon, this.label, this.val);

  @override
  Widget build(BuildContext context) => Container(
    width: 175, padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: Row(children: [
      Icon(icon, size: 14, color: kBlue),
      const SizedBox(width: 8),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: _muted.copyWith(fontSize: 10)),
        Text(val, style: _h2.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
      ])),
    ]),
  );
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ),
  );
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ToggleBtn(this.label, this.active, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color : kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? color : kBorder, width: 1.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : kMuted)),
    ),
  );
}

class _SectionHdr extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHdr(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 13, color: color)),
    const SizedBox(width: 8),
    Flexible(child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: .5),
        overflow: TextOverflow.ellipsis)),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: color.withOpacity(0.2))),
  ]);
}

class _TypeToggleRow extends StatelessWidget {
  final String typeFiltre;
  final ValueChanged<String> onChanged;
  const _TypeToggleRow({required this.typeFiltre, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: ['Tout', 'Entrées', 'Sorties'].map((t) {
      final sel = typeFiltre == t;
      final col = t == 'Entrées' ? kGreen : t == 'Sorties' ? kOrange : Colors.white;
      return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? Colors.white : Colors.white.withOpacity(0.25)),
            ),
            child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: sel ? (t == 'Entrées' ? kGreen : t == 'Sorties' ? kOrange : kPurple) : Colors.white)),
          ),
        ),
      );
    }).toList(),
  );
}

class _DatePickerBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePickerBtn({required this.label, this.date, required this.onTap});

  String get _txt => date != null
      ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
      : 'jj/mm/aaaa';

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(date != null ? 0.6 : 0.3), width: date != null ? 1.5 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label : ', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600)),
        Text(_txt, style: TextStyle(fontSize: 11, color: date != null ? Colors.white : Colors.white70, fontWeight: date != null ? FontWeight.w700 : FontWeight.w400)),
        const SizedBox(width: 6),
        Icon(Icons.calendar_month_rounded, size: 13, color: Colors.white.withOpacity(0.75)),
      ]),
    ),
  );
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
    height: 38,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.3)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(value) ? value : items.first,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 15),
        dropdownColor: const Color(0xFF1E293B),
        style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w600),
        items: items.map((v) => DropdownMenuItem(value: v, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(labels?[v] ?? v, style: const TextStyle(fontSize: 11, color: Colors.white)),
        ]))).toList(),
        onChanged: (v) => onChanged(v!),
      ),
    ),
  );
}

class _SearchBox extends StatelessWidget {
  final TextEditingController ctrl;
  final String value;
  final void Function(String) onChanged;
  const _SearchBox({required this.ctrl, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => SizedBox(height: 42, child: TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 12),
    decoration: InputDecoration(
      hintText: 'Rechercher un produit…',
      hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
      prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 17),
      suffixIcon: value.isNotEmpty
          ? IconButton(icon: const Icon(Icons.close_rounded, size: 14), onPressed: () { ctrl.clear(); onChanged(''); })
          : null,
      filled: true, fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
    ),
    onChanged: onChanged,
  ));
}

class _DropBox extends StatelessWidget {
  final dynamic value;
  final List<String> items;
  final Map<String, String>? labels;
  final void Function(String) onChanged;
  const _DropBox({required this.value, required this.items, required this.onChanged, this.labels});

  @override
  Widget build(BuildContext context) => Container(
    height: 42, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: items.contains(value) ? value as String : items.first,
      isExpanded: true,
      style: const TextStyle(fontSize: 12, color: kText, fontFamily: 'Roboto'),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 17),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(labels?[v] ?? v, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => onChanged(v!),
    )),
  );
}

class _StyledDrop<T> extends StatelessWidget {
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _StyledDrop({this.value, this.hint, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<T>(
      value: value, isExpanded: true,
      hint: hint != null ? Text(hint!, style: const TextStyle(fontSize: 12, color: kBorderMd)) : null,
      style: const TextStyle(fontSize: 12, color: kText, fontFamily: 'Roboto'),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 17),
      items: items, onChanged: onChanged,
    )),
  );
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
    style: const TextStyle(fontSize: 12, color: kText),
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
      prefixIcon: prefix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true, fillColor: kSurface,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
    ),
  );
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
      if (v > 1) { ctrl.text = '${v - 1}'; onChanged(); }
    }),
    Expanded(child: SizedBox(height: 48, child: TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText),
      decoration: InputDecoration(
        hintText: '0', contentPadding: EdgeInsets.zero,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: color, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kBorder)),
      ),
    ))),
    _StepBtn(Icons.add_rounded, color, () {
      final v = int.tryParse(ctrl.text) ?? 0;
      ctrl.text = '${v + 1}'; onChanged();
    }),
  ]);
}

class _AscBtn extends StatelessWidget {
  final bool asc;
  final VoidCallback onTap;
  const _AscBtn({required this.asc, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(kR), onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBlueMd.withOpacity(.5))),
      child: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: kBlue, size: 16),
    ),
  );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(7), onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
          color: color.withOpacity(.09), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(.2))),
      child: Icon(icon, color: color, size: 17),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 16 — ÉTATS VIDES / ERREUR
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 56, height: 56,
        decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.store_rounded, color: kBlue, size: 28)),
    const SizedBox(height: 16),
    const CircularProgressIndicator(color: kBlue, strokeWidth: 2.5),
    const SizedBox(height: 12),
    const Text('Chargement du stock…', style: TextStyle(fontSize: 14, color: kMuted)),
  ]);
}

class _FirebaseErrorState extends StatelessWidget {
  const _FirebaseErrorState();

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 64, height: 64,
        decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.cloud_off_rounded, color: kRed, size: 32)),
    const SizedBox(height: 16),
    const Text('Firebase non disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText)),
    const SizedBox(height: 8),
    const Text('Vérifiez votre connexion et la configuration Firebase', style: TextStyle(color: kMuted)),
  ]);
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 56, color: kRed),
    const SizedBox(height: 12),
    const Text('Une erreur est survenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText)),
    const SizedBox(height: 8),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(message, style: const TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 17 — HELPER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

void _showDialog(BuildContext context, Widget dialog) {
  showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
    pageBuilder: (_, __, ___) => dialog,
  );
}