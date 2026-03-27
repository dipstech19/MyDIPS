// =============================================================================
//  gestion_magasin.dart — VERSION AVEC FOURNISSEURS
//  + Page Fournisseurs dans la nav
//  + Sélection fournisseur dans le formulaire d'entrée
//  + Date manuelle pour entrées/sorties
//  + Filtre par fournisseur dans l'historique
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/utils/responsive.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — MODÈLES
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

// ── NOUVEAU : Modèle Fournisseur ──────────────────────────────────────────────
class Fournisseur {
  final String id;
  final String nom;
  final String adresse;
  final String telephone;
  final String? telephone2;

  const Fournisseur({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.telephone,
    this.telephone2,
  });

  Map<String, dynamic> toFirestore() => {
    'nom': nom,
    'adresse': adresse,
    'telephone': telephone,
    'telephone2': telephone2,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory Fournisseur.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Fournisseur(
      id: doc.id,
      nom: d['nom'] as String? ?? '',
      adresse: d['adresse'] as String? ?? '',
      telephone: d['telephone'] as String? ?? '',
      telephone2: d['telephone2'] as String?,
    );
  }

  Fournisseur copyWith({
    String? id,
    String? nom,
    String? adresse,
    String? telephone,
    String? telephone2,
  }) => Fournisseur(
    id: id ?? this.id,
    nom: nom ?? this.nom,
    adresse: adresse ?? this.adresse,
    telephone: telephone ?? this.telephone,
    telephone2: telephone2 ?? this.telephone2,
  );
}

class Produit {
  final String id, nom, reference, categorie, magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantiteStock;
  final List<VarianteProduit> variantes;
  final String siteId;
  final String? fournisseurId; // NOUVEAU

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
    this.fournisseurId,
  });

  int get total =>
      aVariantes ? variantes.fold(0, (s, v) => s + v.quantite) : quantiteStock;
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
    'fournisseurId': fournisseurId,
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
      variantes:
      (d['variantes'] as List?)
          ?.map((v) => VarianteProduit.fromMap(v as Map<String, dynamic>))
          .toList() ??
          [],
      siteId: d['siteId'] as String? ?? 'default',
      fournisseurId: d['fournisseurId'] as String?,
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
    String? fournisseurId,
  }) => Produit(
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
    fournisseurId: fournisseurId ?? this.fournisseurId,
  );
}

class Mouvement {
  final String id, type, produitId, nomProduit, reference, categorie, magasin;
  final bool aVariantes;
  final String? groupeUniteLabel;
  final int quantite;
  final List<LigneMouvement> lignes;
  final DateTime date;
  final String? preneurNom;
  final String siteId;
  final String? fournisseurId;   // NOUVEAU
  final String? fournisseurNom;  // NOUVEAU (dénormalisé pour affichage)

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
    this.fournisseurId,
    this.fournisseurNom,
  });

  int get totalQte =>
      aVariantes ? lignes.fold(0, (s, l) => s + l.quantite) : quantite;

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
    'fournisseurId': fournisseurId,
    'fournisseurNom': fournisseurNom,
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
      lignes:
      (d['lignes'] as List?)
          ?.map((l) => LigneMouvement.fromMap(l as Map<String, dynamic>))
          .toList() ??
          [],
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preneurNom: d['preneurNom'] as String?,
      siteId: d['siteId'] as String? ?? 'default',
      fournisseurId: d['fournisseurId'] as String?,
      fournisseurNom: d['fournisseurNom'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 2 — PROVIDER FIREBASE
// ─────────────────────────────────────────────────────────────────────────────

class MagasinProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _produitsRef =>
      _db.collection('magasin').doc('stock').collection('produits');
  CollectionReference<Map<String, dynamic>> get _mouvementsRef =>
      _db.collection('magasin').doc('stock').collection('mouvements');
  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('magasin').doc('stock').collection('categories');
  CollectionReference<Map<String, dynamic>> get _fournisseursRef =>
      _db.collection('magasin').doc('stock').collection('fournisseurs');

  List<Produit> _produits = [];
  List<Mouvement> _mouvements = [];
  List<String> _categories = [];
  List<Fournisseur> _fournisseurs = [];
  bool _loading = true;
  String? _error;
  bool _firebaseAvailable = true;

  List<Produit> get produits => _produits;
  List<Mouvement> get entrees =>
      _mouvements.where((m) => m.type == 'entree').toList();
  List<Mouvement> get sorties =>
      _mouvements.where((m) => m.type == 'sortie').toList();
  List<String> get categoryNames => _categories;
  List<Fournisseur> get fournisseurs => _fournisseurs;
  bool get loading => _loading;
  String? get error => _error;
  bool get firebaseAvailable => _firebaseAvailable;
  int get totalProduits => _produits.length;

  final List<Function()> _cancelListeners = [];

  Future<void> init() async {
    try {
      _loading = true;
      notifyListeners();
      final cp = _produitsRef
          .orderBy('nom')
          .snapshots()
          .listen(
            (snap) {
          _produits = snap.docs.map(Produit.fromFirestore).toList();
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          _firebaseAvailable = false;
          notifyListeners();
        },
      );
      final cm = _mouvementsRef
          .orderBy('date', descending: true)
          .snapshots()
          .listen(
            (snap) {
          _mouvements = snap.docs.map(Mouvement.fromFirestore).toList();
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          notifyListeners();
        },
      );
      final cc = _categoriesRef
          .orderBy('nom')
          .snapshots()
          .listen(
            (snap) {
          _categories = snap.docs
              .map((d) => d.data()['nom'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .toList();
          _loading = false;
          notifyListeners();
        },
        onError: (e) {
          _loading = false;
          _error = e.toString();
          notifyListeners();
        },
      );
      final cf = _fournisseursRef
          .orderBy('nom')
          .snapshots()
          .listen(
            (snap) {
          _fournisseurs = snap.docs.map(Fournisseur.fromFirestore).toList();
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          notifyListeners();
        },
      );
      _cancelListeners.addAll([cp.cancel, cm.cancel, cc.cancel, cf.cancel]);
    } catch (e) {
      _loading = false;
      _error = e.toString();
      _firebaseAvailable = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final cancel in _cancelListeners) {
      cancel();
    }
    super.dispose();
  }

  // ── Fournisseurs CRUD ──────────────────────────────────────────────────────
  Future<void> addFournisseur(Fournisseur f) async {
    final data = f.toFirestore()..['createdAt'] = FieldValue.serverTimestamp();
    await _fournisseursRef.add(data);
  }

  Future<void> updateFournisseur(Fournisseur f) async =>
      _fournisseursRef.doc(f.id).update(f.toFirestore());

  Future<void> deleteFournisseur(String id) async =>
      _fournisseursRef.doc(id).delete();

  Fournisseur? fournisseurById(String? id) {
    if (id == null) return null;
    final matches = _fournisseurs.where((f) => f.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  // Quantité totale en stock pour un fournisseur donné
  int stockParFournisseur(String fournisseurId) {
    final prodsFourn = _produits.where((p) => p.fournisseurId == fournisseurId);
    return prodsFourn.fold(0, (s, p) => s + p.total);
  }

  Future<void> addCategorie(String nom) async {
    if (_categories.contains(nom)) return;
    await _categoriesRef.add({'nom': nom});
  }

  Future<String> addProduit(Produit produit) async {
    final data = produit.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _produitsRef.add(data);
    return ref.id;
  }

  Future<void> updateProduit(Produit produit) async =>
      _produitsRef.doc(produit.id).update(produit.toFirestore());
  Future<void> deleteProduit(String id) async => _produitsRef.doc(id).delete();

  Future<void> _appliquerMouvement(Mouvement m, {required bool annuler}) async {
    final prodDoc = _produitsRef.doc(m.produitId);
    final snap = await prodDoc.get();
    if (!snap.exists) return;
    final produit = Produit.fromFirestore(snap);
    final signe = annuler
        ? (m.type == 'entree' ? -1 : 1)
        : (m.type == 'entree' ? 1 : -1);
    if (!produit.aVariantes) {
      await prodDoc.update({
        'quantiteStock': (produit.quantiteStock + signe * m.quantite).clamp(0, 999999),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final newVariantes = produit.variantes.map((v) {
        final ligne = m.lignes.firstWhere(
              (l) => l.unite == v.unite,
          orElse: () => LigneMouvement(unite: v.unite, quantite: 0),
        );
        return VarianteProduit(
          unite: v.unite,
          quantite: (v.quantite + signe * ligne.quantite).clamp(0, 999999),
        );
      }).toList();
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

  Future<void> _updateMouvement(String id, Mouvement mouvement) async {
    final snap = await _mouvementsRef.doc(id).get();
    if (!snap.exists) return;
    final old = Mouvement.fromFirestore(snap);
    await _appliquerMouvement(old, annuler: true);
    final newM = mouvement.copyWithId(id);
    await _mouvementsRef.doc(id).set(newM.toFirestore());
    await _appliquerMouvement(newM, annuler: false);
  }

  Future<void> addEntree(Mouvement mouvement) async {
    final ref = _mouvementsRef.doc();
    await ref.set(mouvement.toFirestore());
    await _appliquerMouvement(mouvement.copyWithId(ref.id), annuler: false);
  }

  Future<void> deleteEntree(String id) async {
    final snap = await _mouvementsRef.doc(id).get();
    if (!snap.exists) return;
    await _appliquerMouvement(Mouvement.fromFirestore(snap), annuler: true);
    await _mouvementsRef.doc(id).delete();
  }

  Future<void> updateEntree(String id, Mouvement mouvement) async =>
      _updateMouvement(id, mouvement);

  Future<void> addSortie(Mouvement mouvement) async {
    final ref = _mouvementsRef.doc();
    await ref.set(mouvement.toFirestore());
    await _appliquerMouvement(mouvement.copyWithId(ref.id), annuler: false);
  }

  Future<void> deleteSortie(String id) async {
    final snap = await _mouvementsRef.doc(id).get();
    if (!snap.exists) return;
    await _appliquerMouvement(Mouvement.fromFirestore(snap), annuler: true);
    await _mouvementsRef.doc(id).delete();
  }

  Future<void> updateSortie(String id, Mouvement mouvement) async =>
      _updateMouvement(id, mouvement);
}

extension _MouvX on Mouvement {
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
    fournisseurId: fournisseurId,
    fournisseurNom: fournisseurNom,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — CONSTANTES UI
// ─────────────────────────────────────────────────────────────────────────────

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
const Color kOrange = Color(0xFFD97706);
const Color kOrangeLt = Color(0xFFFFFBEB);
const Color kRed = Color(0xFFDC2626);
const Color kRedLt = Color(0xFFFEF2F2);
const Color kIndigo = Color(0xFF4455AA);
const Color kIndigoLt = Color(0xFFEEF1FF);
const Color kPurple = Color(0xFF7C3AED);
const Color kPurpleLt = Color(0xFFF5F3FF);
const Color kTeal = Color(0xFF0D9488);      // NOUVEAU pour fournisseurs
const Color kTealLt = Color(0xFFF0FDFA);    // NOUVEAU

const _h2 = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText);
const _muted = TextStyle(fontSize: 12, color: kMuted);
const _label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.6);
const _mono = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted, fontFamily: 'monospace');

const double kR = 10;
const double kR2 = 14;
const double kP = 22;

const List<String> kMagasins = ['Base de vie', 'Siège', 'Chantier'];

class GroupeUnites {
  final String label, emoji;
  final List<String> unites;
  const GroupeUnites({required this.label, required this.emoji, required this.unites});
}

const List<GroupeUnites> kGroupes = [
  GroupeUnites(label: 'Tailles vestimentaires', emoji: '👔', unites: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL']),
  GroupeUnites(label: 'Pointures chaussures', emoji: '👟', unites: ['36','37','38','39','40','41','42','43','44','45','46','47','48']),
  GroupeUnites(label: 'Volume (liquides)', emoji: '💧', unites: ['25 ml','50 ml','100 ml','250 ml','500 ml','1 L','2 L','5 L','10 L','20 L']),
  GroupeUnites(label: 'Poids (solides)', emoji: '⚖️', unites: ['100 g','250 g','500 g','1 kg','2 kg','5 kg','10 kg','25 kg','50 kg','100 kg','1 T']),
  GroupeUnites(label: 'Pièces / Unités', emoji: '📦', unites: ['Unité','Boîte x10','Boîte x20','Carton x50','Palette']),
];

GroupeUnites? groupeByLabel(String? label) => label == null
    ? null
    : kGroupes.firstWhere((g) => g.label == label, orElse: () => kGroupes.first);

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 4 — PAGE PRINCIPALE (5 onglets)
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
    _tabCtrl = TabController(length: 5, vsync: this); // 5 onglets
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _tab = _tabCtrl.index);
    });
    WidgetsBinding.instance.addPostFrameCallback(
          (_) => context.read<MagasinProvider>().init(),
    );
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
      return SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: ColoredBox(color: kBg, child: Center(child: const _FirebaseErrorState())),
      );
    }
    if (magasin.loading) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: ColoredBox(color: kBg, child: const Center(child: _LoadingState())),
      );
    }
    if (magasin.error != null) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height,
        child: ColoredBox(color: kBg, child: Center(child: _ErrorState(message: magasin.error!))),
      );
    }

    final rupt = magasin.produits.where((p) => p.rupture).length;
    final bas = magasin.produits.where((p) => p.bas).length;
    final totalE = magasin.entrees.fold(0, (s, m) => s + m.totalQte);
    final totalS = magasin.sorties.fold(0, (s, m) => s + m.totalQte);
    final totalH = magasin.entrees.length + magasin.sorties.length;

    final screenH = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: screenH,
      child: ColoredBox(
        color: kBg,
        child: Column(
          children: [
            _TopNavBar(
              tab: _tab,
              onTap: (i) => setState(() {
                _tab = i;
                _tabCtrl.animateTo(i);
              }),
              statChips: [
                if (_tab == 0) ...[
                  _StatChip('${magasin.produits.length} produits', kBlueLt, kBlue),
                  if (rupt > 0) _StatChip('$rupt rupture${rupt > 1 ? "s" : ""}', kRedLt, kRed),
                  if (bas > 0) _StatChip('$bas bas', kOrangeLt, kOrange),
                ],
                if (_tab == 1) ...[
                  _StatChip('${magasin.entrees.length} entrée${magasin.entrees.length != 1 ? "s" : ""}', kGreenLt, kGreen),
                  _StatChip('$totalE unités', kBlueLt, kBlue),
                ],
                if (_tab == 2) ...[
                  _StatChip('${magasin.sorties.length} sortie${magasin.sorties.length != 1 ? "s" : ""}', kOrangeLt, kOrange),
                  _StatChip('$totalS unités', kBlueLt, kBlue),
                ],
                if (_tab == 3) _StatChip('$totalH opérations', kPurpleLt, kPurple),
                if (_tab == 4) _StatChip('${magasin.fournisseurs.length} fournisseur${magasin.fournisseurs.length != 1 ? "s" : ""}', kTealLt, kTeal),
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
                  _FournisseursPage(magasin: magasin),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 5 — TOP NAV BAR (5 onglets)
// ─────────────────────────────────────────────────────────────────────────────

class _TopNavBar extends StatelessWidget {
  final int tab;
  final void Function(int) onTap;
  final List<Widget> statChips;
  const _TopNavBar({required this.tab, required this.onTap, required this.statChips});

  @override
  Widget build(BuildContext context) {
    const tabs = [
      {'label': 'Stock', 'labelFull': 'Stock Actuel', 'icon': Icons.inventory_2_rounded, 'color': kBlue},
      {'label': 'Entrées', 'labelFull': 'Les Entrées', 'icon': Icons.arrow_circle_down_rounded, 'color': kGreen},
      {'label': 'Sorties', 'labelFull': 'Les Sorties', 'icon': Icons.arrow_circle_up_rounded, 'color': kOrange},
      {'label': 'Historique', 'labelFull': 'Historique', 'icon': Icons.history_rounded, 'color': kPurple},
      {'label': 'Fournisseurs', 'labelFull': 'Fournisseurs', 'icon': Icons.business_rounded, 'color': kTeal},
    ];
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    final tabRow = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(tabs.length, (i) {
        final col = tabs[i]['color'] as Color;
        final sel = tab == i;
        final label = mobile ? tabs[i]['label'] as String : tabs[i]['labelFull'] as String;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 2 : 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: mobile ? 36 : 40,
              constraints: BoxConstraints(minWidth: mobile ? 72 : 110),
              decoration: BoxDecoration(
                color: sel ? col.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: sel ? Border.all(color: col.withOpacity(0.3), width: 1.5) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tabs[i]['icon'] as IconData, size: mobile ? 13 : 15, color: sel ? col : kMuted),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: mobile ? 10 : 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? col : kMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (sel && !mobile) ...[
                    const SizedBox(width: 5),
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  ],
                ],
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
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.store_rounded, color: kBlue, size: 15),
                    ),
                    const SizedBox(width: 7),
                    const Text('STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: .5)),
                    const Spacer(),
                    if (statChips.isNotEmpty)
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(mainAxisSize: MainAxisSize.min, children: statChips),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: tabRow),
              ),
            ],
          )
              : SizedBox(
            height: 66,
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.store_rounded, color: kBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('STOCK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: .5)),
                    Text('MANAGER', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(width: 16),
                Container(width: 1.5, height: 24, color: kBorder),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: tabRow),
                ),
                if (statChips.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(width: 1.5, height: 24, color: kBorder),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(mainAxisSize: MainAxisSize.min, children: statChips),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: col.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 6 — PAGE STOCK
// ─────────────────────────────────────────────────────────────────────────────

class _StockPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Produit> produits;
  const _StockPage({required this.magasin, required this.produits});
  @override
  State<_StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<_StockPage> {
  String _q = '', _cat = 'Toutes', _mag = 'Tous';
  bool _asc = false; // false = stock décroissant par défaut
  final _sc = TextEditingController();

  List<Produit> get _list {
    final q = _q.toLowerCase();
    var l = widget.produits.where((p) {
      final mq = q.isEmpty || p.nom.toLowerCase().contains(q) || p.reference.toLowerCase().contains(q);
      return mq && (_cat == 'Toutes' || p.categorie == _cat) && (_mag == 'Tous' || p.magasin == _mag);
    }).toList();
    l.sort((a, b) {
      final c = a.total.compareTo(b.total);
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
    final mags = ['Tous', ...kMagasins];

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
          child: mobile
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Catégorie', value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v)),
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() => _mag = v)),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('Stock', style: _label),
                  const SizedBox(height: 4),
                  _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
                ]),
              ]),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _LabeledDrop(label: 'Catégorie', value: _cat, items: cats, onChanged: (v) => setState(() => _cat = v))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() => _mag = v))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Stock', style: _label),
                const SizedBox(height: 4),
                _AscBtn(asc: _asc, onTap: () => setState(() => _asc = !_asc)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(children: [
            Text('${list.length} / ${widget.magasin.totalProduits} produits', style: _muted.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? _EmptyState(message: 'Aucun produit trouvé', color: kBlue)
              : mobile
              ? ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _ProduitCard(
              produit: list[i],
              fournisseur: widget.magasin.fournisseurById(list[i].fournisseurId),
              onTap: () => _showDialog(ctx, _DetailsDialog(produit: list[i], groupe: groupeByLabel(list[i].groupeUniteLabel))),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false,
              accentColor: kBlue,
              columns: const [
                _Col('PRODUIT', flex: 3),
                _Col('RÉFÉRENCE', flex: 2),
                _Col('CATÉGORIE', flex: 2),
                _Col('MAGASIN', flex: 2),
                _Col('STOCK', flex: 1),
                _Col('', flex: 1),
              ],
              rows: list.map((p) {
                final g = groupeByLabel(p.groupeUniteLabel);
                final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
                final stockBg = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
                return _DataTableRow(cells: [
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(g?.emoji ?? '📦', style: const TextStyle(fontSize: 16))),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
                      Text(p.categorie, style: _muted.copyWith(fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 1),
                    ])),
                  ]),
                  Text(p.reference, style: _mono, overflow: TextOverflow.ellipsis, maxLines: 1),
                  _PillBadge(p.categorie, kBlueLt, kBlue),
                  p.magasin.isNotEmpty
                      ? _PillBadge(p.magasin, kIndigoLt, kIndigo)
                      : Text('—', style: _muted.copyWith(fontSize: 11)),
                  Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${p.total}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: stockColor)),
                  )),
                  Center(child: _IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () {
                    _showDialog(context, _DetailsDialog(produit: p, groupe: g));
                  })),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProduitCard extends StatelessWidget {
  final Produit produit;
  final Fournisseur? fournisseur;
  final VoidCallback onTap;
  const _ProduitCard({required this.produit, this.fournisseur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = produit;
    final g = groupeByLabel(p.groupeUniteLabel);
    final stockColor = p.rupture ? kRed : p.bas ? kOrange : kGreen;
    final stockBg = p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt;
    final stockLabel = p.rupture ? 'Rupture' : p.bas ? 'Stock bas' : 'OK';

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kR2),
        border: Border.all(color: p.rupture ? kRed.withOpacity(0.3) : kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kR2),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(9)),
                  child: Center(child: Text(g?.emoji ?? '📦', style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(p.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 2),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Text(p.reference, style: _mono.copyWith(fontSize: 11)),
                  ]),
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: stockColor.withOpacity(0.2))),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${p.total}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: stockColor)),
                    Text(stockLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: stockColor)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _PillBadge(p.categorie, kBlueLt, kBlue),
                const SizedBox(width: 6),
                if (p.magasin.isNotEmpty) _PillBadge(p.magasin, kIndigoLt, kIndigo),
                const Spacer(),
                Flexible(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text('Voir détails', style: TextStyle(fontSize: 11, color: kBlue.withOpacity(0.8), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kBlue.withOpacity(0.8)),
                ])),
              ]),
            ],
          ),
        ),
      ),
    );
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
  String _cat = 'Toutes';
  List<Mouvement> get _list => widget.entrees.where((m) => _cat == 'Toutes' || m.categorie == _cat).toList();

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final total = list.fold(0, (s, m) => s + m.totalQte);
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(
      children: [
        _BanniereAction(
          padding: padding, mobile: mobile,
          gradient: const [Color(0xFF14532D), Color(0xFF16A34A)],
          shadowColor: kGreen, icon: Icons.arrow_circle_down_rounded,
          titre: 'Entrées de Stock',
          sous: '${list.length} mouvement${list.length != 1 ? "s" : ""} · $total unités reçues',
          cats: cats, catVal: _cat,
          onCatChanged: (v) => setState(() => _cat = v),
          btnColor: kGreen, btnLabel: 'Nouvelle entrée',
          onBtnTap: () => _showDialog(context, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: list.isEmpty
              ? _EmptyState(message: 'Aucune entrée — cliquez sur « Nouvelle entrée »', color: kGreen)
              : mobile
              ? ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _MouvCard(
              m: list[i], color: kGreen, bgColor: kGreenLt,
              fournisseurNom: list[i].fournisseurNom,
              onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
              onEdit: () => _showDialog(ctx, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kGreen,
              columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('FOURNISSEUR', flex: 2), _Col('QTÉ', flex: 1), _Col('', flex: 1)],
              rows: list.map((m) => _MouvRow(m: m, color: kGreen, bgColor: kGreenLt, showPreneur: false, showFournisseur: true,
                onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                onEdit: () => _showDialog(context, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
              )).toList(),
            ),
          ),
        ),
      ],
    );
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
  String _cat = 'Toutes';
  List<Mouvement> get _list => widget.sorties.where((m) => _cat == 'Toutes' || m.categorie == _cat).toList();

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final total = list.fold(0, (s, m) => s + m.totalQte);
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(
      children: [
        _BanniereAction(
          padding: padding, mobile: mobile,
          gradient: const [Color(0xFF92400E), Color(0xFFD97706)],
          shadowColor: kOrange, icon: Icons.arrow_circle_up_rounded,
          titre: 'Sorties de Stock',
          sous: '${list.length} mouvement${list.length != 1 ? "s" : ""} · $total unités sorties',
          cats: cats, catVal: _cat,
          onCatChanged: (v) => setState(() => _cat = v),
          btnColor: kOrange, btnLabel: 'Nouvelle sortie',
          onBtnTap: () => _showDialog(context, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: list.isEmpty
              ? _EmptyState(message: 'Aucune sortie — cliquez sur « Nouvelle sortie »', color: kOrange)
              : mobile
              ? ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _MouvCard(
              m: list[i], color: kOrange, bgColor: kOrangeLt, showPreneur: true,
              onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: 'Supprimer cette sortie ? Le stock sera restitué.', onConfirm: () { widget.magasin.deleteSortie(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
              onEdit: () => _showDialog(ctx, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kOrange,
              columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('QTÉ', flex: 1), _Col('PRÉLEVÉ PAR', flex: 2), _Col('', flex: 1)],
              rows: list.map((m) => _MouvRow(m: m, color: kOrange, bgColor: kOrangeLt, showPreneur: true, showFournisseur: false,
                onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: 'Supprimer cette sortie ? Le stock sera restitué.', onConfirm: () { widget.magasin.deleteSortie(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                onEdit: () => _showDialog(context, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CARD MOUVEMENT (mobile)
// ─────────────────────────────────────────────────────────────────────────────

class _MouvCard extends StatelessWidget {
  final Mouvement m;
  final Color color, bgColor;
  final bool showPreneur;
  final String? fournisseurNom;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  const _MouvCard({required this.m, required this.color, required this.bgColor, this.showPreneur = false, this.fournisseurNom, required this.onDelete, this.onEdit});

  String get _d => '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}';
  String get _t => '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(kR2),
      border: Border.all(color: color.withOpacity(0.2)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(m.nomProduit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
            child: Text('${m.totalQte}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 5, runSpacing: 4, children: [
          Text(m.reference, style: _mono.copyWith(fontSize: 11)),
          _PillBadge(m.categorie, kBlueLt, kBlue),
          if (fournisseurNom != null) _PillBadge(fournisseurNom!, kTealLt, kTeal),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 11, color: kMuted),
          const SizedBox(width: 4),
          Text('$_d à $_t', style: _muted.copyWith(fontSize: 11)),
          if (showPreneur && m.preneurNom != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.person_outline_rounded, size: 12, color: kMuted),
            const SizedBox(width: 3),
            Expanded(child: Text(m.preneurNom!, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ] else const Spacer(),
          const SizedBox(width: 6),
          if (onEdit != null) ...[_IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, onEdit!), const SizedBox(width: 6)],
          _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 9 — BANNIÈRE ACTION
// ─────────────────────────────────────────────────────────────────────────────

class _BanniereAction extends StatelessWidget {
  final double padding;
  final bool mobile;
  final List<Color> gradient;
  final Color shadowColor, btnColor;
  final IconData icon;
  final String titre, sous, btnLabel;
  final List<String> cats;
  final String catVal;
  final ValueChanged<String> onCatChanged;
  final VoidCallback onBtnTap;

  const _BanniereAction({required this.padding, required this.mobile, required this.gradient, required this.shadowColor, required this.icon, required this.titre, required this.sous, required this.cats, required this.catVal, required this.onCatChanged, required this.btnColor, required this.btnLabel, required this.onBtnTap});

  Widget _iconTitre() => Row(children: [
    Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: Colors.white, size: 20)),
    const SizedBox(width: 10),
    Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(titre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1),
      Text(sous, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75)), overflow: TextOverflow.ellipsis, maxLines: 1),
    ])),
  ]);

  Widget _btn() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: btnColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
    icon: const Icon(Icons.add_rounded, size: 14),
    label: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    onPressed: onBtnTap,
  );

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: mobile ? 12 : 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(kR2),
      boxShadow: [BoxShadow(color: shadowColor.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _iconTitre(),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _GlassDropdown(value: catVal, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: onCatChanged))]),
      const SizedBox(height: 8),
      SizedBox(child: _btn()),
    ])
        : Row(children: [
      Expanded(child: _iconTitre()),
      const SizedBox(width: 12),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: _GlassDropdown(value: catVal, items: cats, icon: Icons.category_outlined, hint: 'Catégorie', onChanged: onCatChanged)),
      const SizedBox(width: 12),
      _btn(),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 10 — PAGE HISTORIQUE (avec filtre fournisseur)
// ─────────────────────────────────────────────────────────────────────────────

class _HistoriquePage extends StatefulWidget {
  final MagasinProvider magasin;
  const _HistoriquePage({required this.magasin});
  @override
  State<_HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<_HistoriquePage> {
  String _typeFiltre = 'Tout';
  String _magasinFiltre = 'Tous';
  String _fournisseurFiltre = 'Tous';
  DateTime? _dateDebut, _dateFin;

  List<Mouvement> get _list {
    final all = [...widget.magasin.entrees, ...widget.magasin.sorties];
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.where((m) {
      final typeOk = _typeFiltre == 'Tout' || (_typeFiltre == 'Entrées' && m.type == 'entree') || (_typeFiltre == 'Sorties' && m.type == 'sortie');
      final debutOk = _dateDebut == null || !m.date.isBefore(DateTime(_dateDebut!.year, _dateDebut!.month, _dateDebut!.day));
      final finOk = _dateFin == null || !m.date.isAfter(DateTime(_dateFin!.year, _dateFin!.month, _dateFin!.day, 23, 59, 59));
      final magOk = _magasinFiltre == 'Tous' || m.magasin == _magasinFiltre;
      final fouOk = _fournisseurFiltre == 'Tous' || m.fournisseurNom == _fournisseurFiltre;
      return typeOk && debutOk && finOk && magOk && fouOk;
    }).toList();
  }

  bool get _hasActiveFilter => _typeFiltre != 'Tout' || _magasinFiltre != 'Tous' || _fournisseurFiltre != 'Tous' || _dateDebut != null || _dateFin != null;

  void _resetFilters() => setState(() {
    _typeFiltre = 'Tout'; _magasinFiltre = 'Tous'; _fournisseurFiltre = 'Tous';
    _dateDebut = null; _dateFin = null;
  });

  Future<void> _pickDate(BuildContext context, bool isDebut) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? (_dateDebut ?? now) : (_dateFin ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: kPurple, onPrimary: Colors.white, surface: kSurface)), child: child!),
    );
    if (picked == null) return;
    setState(() { if (isDebut) _dateDebut = picked; else _dateFin = picked; });
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;
    final fournisseurs = widget.magasin.fournisseurs;
    final fouNoms = ['Tous', ...fournisseurs.map((f) => f.nom)];
    final mags = ['Tous', ...kMagasins];

    return Column(
      children: [
        // ── Bannière compacte ─────────────────────────────────────────────
        Container(
          margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16, vertical: mobile ? 10 : 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(kR2),
            boxShadow: [BoxShadow(color: kPurple.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.history_rounded, color: Colors.white, size: mobile ? 18 : 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(mobile ? 'Historique' : 'Historique des opérations',
                  style: TextStyle(fontSize: mobile ? 13 : 15, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
              Text('${list.length} opération${list.length != 1 ? "s" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
            ])),
            if (_hasActiveFilter)
              InkWell(
                onTap: _resetFilters,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.filter_alt_off_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Réinitialiser', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
          ]),
        ),

        // ── Panneau de filtres ────────────────────────────────────────────
        Container(
          margin: EdgeInsets.fromLTRB(padding, 8, padding, 0),
          padding: EdgeInsets.all(mobile ? 10 : 12),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kR2),
            border: Border.all(color: kBorder),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: mobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LabeledDrop(label: 'Type', value: _typeFiltre, items: const ['Tout', 'Entrées', 'Sorties'], onChanged: (v) => setState(() => _typeFiltre = v)),
            const SizedBox(height: 8),
            _LabeledDrop(label: 'Magasin', value: _magasinFiltre, items: mags, onChanged: (v) => setState(() => _magasinFiltre = v)),
            if (fournisseurs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Fournisseur', value: _fournisseurFiltre, items: fouNoms, onChanged: (v) => setState(() => _fournisseurFiltre = v)),
            ],
            const SizedBox(height: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Période', style: _label),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: _DateBox(label: 'De', date: _dateDebut, onTap: () => _pickDate(context, true))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 14, color: kMuted)),
                Expanded(child: _DateBox(label: 'À', date: _dateFin, onTap: () => _pickDate(context, false))),
                if (_dateDebut != null || _dateFin != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() { _dateDebut = null; _dateFin = null; }),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(7), border: Border.all(color: kRed.withOpacity(0.2))),
                        child: const Icon(Icons.close_rounded, color: kRed, size: 13)),
                  ),
                ],
              ]),
            ]),
          ])
              : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _LabeledDrop(label: 'Type', value: _typeFiltre, items: const ['Tout', 'Entrées', 'Sorties'], onChanged: (v) => setState(() => _typeFiltre = v))),
            const SizedBox(width: 10),
            Expanded(child: _LabeledDrop(label: 'Magasin', value: _magasinFiltre, items: mags, onChanged: (v) => setState(() => _magasinFiltre = v))),
            if (fournisseurs.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(child: _LabeledDrop(label: 'Fournisseur', value: _fournisseurFiltre, items: fouNoms, onChanged: (v) => setState(() => _fournisseurFiltre = v))),
            ],
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Période', style: _label),
              const SizedBox(height: 4),
              Row(children: [
                _DateBox(label: 'De', date: _dateDebut, onTap: () => _pickDate(context, true)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 14, color: kMuted)),
                _DateBox(label: 'À', date: _dateFin, onTap: () => _pickDate(context, false)),
                if (_dateDebut != null || _dateFin != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() { _dateDebut = null; _dateFin = null; }),
                    borderRadius: BorderRadius.circular(7),
                    child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(7), border: Border.all(color: kRed.withOpacity(0.2))),
                        child: const Icon(Icons.close_rounded, color: kRed, size: 13)),
                  ),
                ],
              ]),
            ]),
          ]),
        ),

        const SizedBox(height: 10),

        // ── Liste / Table ─────────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? _EmptyState(message: 'Aucune opération pour ces filtres', color: kPurple)
              : mobile
              ? ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final m = list[i];
              final isE = m.type == 'entree';
              return _MouvCard(
                m: m, color: isE ? kGreen : kOrange, bgColor: isE ? kGreenLt : kOrangeLt,
                showPreneur: false,
                fournisseurNom: isE ? m.fournisseurNom : null,
                onDelete: () => _showDialog(ctx, _ConfirmDel(nom: m.nomProduit, msg: isE ? 'Supprimer cette entrée ?' : 'Supprimer cette sortie ?', onConfirm: () { isE ? widget.magasin.deleteEntree(m.id) : widget.magasin.deleteSortie(m.id); Navigator.of(ctx, rootNavigator: true).pop(); })),
                onEdit: () => _showDialog(ctx, _MouvForm(type: m.type, magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
              );
            },
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kPurple,
              columns: const [
                _Col('TYPE', flex: 1), _Col('DATE', flex: 2), _Col('PRODUIT', flex: 3),
                _Col('CATÉGORIE', flex: 2), _Col('MAGASIN', flex: 2),
                _Col('QTÉ', flex: 1), _Col('FOURNISSEUR', flex: 2), _Col('', flex: 1),
              ],
              rows: list.map((m) {
                final isE = m.type == 'entree';
                final color = isE ? kGreen : kOrange;
                final bg = isE ? kGreenLt : kOrangeLt;
                return _DataTableRow(cells: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isE ? Icons.south_rounded : Icons.north_rounded, size: 10, color: color),
                      const SizedBox(width: 3),
                      Text(isE ? 'Entrée' : 'Sortie', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_fmtDate(m.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
                    Text(_fmtTime(m.date), style: _muted.copyWith(fontSize: 10)),
                  ]),
                  Text(m.nomProduit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
                  _PillBadge(m.categorie, kBlueLt, kBlue),
                  m.magasin.isNotEmpty
                      ? _PillBadge(m.magasin, kIndigoLt, kIndigo)
                      : Text('—', style: _muted.copyWith(fontSize: 11)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${m.totalQte}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                  ),
                  isE && m.fournisseurNom != null
                      ? _PillBadge(m.fournisseurNom!, kTealLt, kTeal)
                      : Text('—', style: _muted.copyWith(fontSize: 11)),
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, () => _showDialog(context, _MouvForm(type: m.type, magasin: widget.magasin, scaffoldContext: context, mouvement: m))),
                    const SizedBox(width: 6),
                    _IconBtn(Icons.visibility_outlined, 'Détails', kPurpleLt, kPurple, () => _showDialog(context, _DetailsOperationDialog(m: m))),
                  ])),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 10B — PAGE FOURNISSEURS (NOUVEAU)
// ─────────────────────────────────────────────────────────────────────────────

class _FournisseursPage extends StatefulWidget {
  final MagasinProvider magasin;
  const _FournisseursPage({required this.magasin});
  @override
  State<_FournisseursPage> createState() => _FournisseursPageState();
}

class _FournisseursPageState extends State<_FournisseursPage> {
  String _q = '';
  final _sc = TextEditingController();

  List<Fournisseur> get _list {
    final q = _q.toLowerCase();
    return widget.magasin.fournisseurs.where((f) =>
    q.isEmpty || f.nom.toLowerCase().contains(q) || f.telephone.contains(q) || (f.telephone2?.contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final mobile = isMobile(context);
    final padding = mobile ? pagePadding(context) : kP;

    return Column(
      children: [
        // Bannière
        Container(
          margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: mobile ? 12 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F4C40), Color(0xFF0D9488)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(kR2),
            boxShadow: [BoxShadow(color: kTeal.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: mobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.business_rounded, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Fournisseurs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('${list.length} fournisseur${list.length != 1 ? "s" : ""}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
              ])),
            ]),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kTeal, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Nouveau fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _showDialog(context, _FournisseurForm(magasin: widget.magasin, scaffoldContext: context)),
            ),
          ])
              : Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.business_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Gestion des fournisseurs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
              Text('${widget.magasin.fournisseurs.length} fournisseur${widget.magasin.fournisseurs.length != 1 ? "s" : ""} enregistré${widget.magasin.fournisseurs.length != 1 ? "s" : ""}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
            ])),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kTeal, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Nouveau fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: () => _showDialog(context, _FournisseurForm(magasin: widget.magasin, scaffoldContext: context)),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Recherche
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: _SearchBox(ctrl: _sc, value: _q, onChanged: (v) => setState(() => _q = v)),
        ),
        const SizedBox(height: 10),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(children: [
            Text('${list.length} / ${widget.magasin.fournisseurs.length} fournisseurs', style: _muted.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 8),

        // Liste
        Expanded(
          child: list.isEmpty
              ? _EmptyState(message: 'Aucun fournisseur — cliquez sur « Nouveau fournisseur »', color: kTeal)
              : mobile
              ? ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _FournisseurCard(
              f: list[i],
              onEdit: () => _showDialog(ctx, _FournisseurForm(magasin: widget.magasin, scaffoldContext: context, fournisseur: list[i])),
              onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nom, msg: 'Supprimer ce fournisseur ?', onConfirm: () { widget.magasin.deleteFournisseur(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kTeal,
              columns: const [_Col('FOURNISSEUR', flex: 3), _Col('TÉLÉPHONE', flex: 2), _Col('EMAIL', flex: 3), _Col('ADRESSE', flex: 3), _Col('', flex: 1)],
              rows: list.map((f) => _DataTableRow(cells: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: kTealLt, borderRadius: BorderRadius.circular(9)),
                    child: const Center(child: Icon(Icons.business_rounded, color: kTeal, size: 18)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(f.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1)),
                ]),
                Row(children: [
                  const Icon(Icons.phone_outlined, size: 12, color: kMuted),
                  const SizedBox(width: 4),
                  Flexible(child: Text(f.telephone, style: _mono.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
                ]),
                f.telephone2 != null && f.telephone2!.isNotEmpty
                    ? Row(children: [const Icon(Icons.phone_outlined, size: 12, color: kMuted), const SizedBox(width: 4), Flexible(child: Text(f.telephone2!, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1))])
                    : Text('—', style: _muted.copyWith(fontSize: 11)),
                Flexible(child: Text(f.adresse, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 2)),
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, () => _showDialog(context, _FournisseurForm(magasin: widget.magasin, scaffoldContext: context, fournisseur: f))),
                  const SizedBox(width: 6),
                  _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, () => _showDialog(context, _ConfirmDel(nom: f.nom, msg: 'Supprimer ce fournisseur ?', onConfirm: () { widget.magasin.deleteFournisseur(f.id); Navigator.of(context, rootNavigator: true).pop(); }))),
                ])),
              ])).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FournisseurCard extends StatelessWidget {
  final Fournisseur f;
  final VoidCallback onEdit, onDelete;
  const _FournisseurCard({required this.f, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(kR2),
      border: Border.all(color: kTeal.withOpacity(0.2)),
      boxShadow: [BoxShadow(color: kTeal.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: kTealLt, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.business_rounded, color: kTeal, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(f.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
            Text(f.adresse, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
          ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_outlined, size: 13, color: kMuted),
            const SizedBox(width: 4),
            Text(f.telephone, style: _mono.copyWith(fontSize: 11)),
          ]),
          if (f.telephone2 != null && f.telephone2!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.phone_outlined, size: 13, color: kMuted),
              const SizedBox(width: 4),
              Flexible(child: Text(f.telephone2!, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
            ]),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, onEdit),
          const SizedBox(width: 8),
          _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 11 — FORMULAIRE FOURNISSEUR (NOUVEAU)
// ─────────────────────────────────────────────────────────────────────────────

class _FournisseurForm extends StatefulWidget {
  final MagasinProvider magasin;
  final BuildContext? scaffoldContext;
  final Fournisseur? fournisseur;
  const _FournisseurForm({required this.magasin, this.scaffoldContext, this.fournisseur});
  @override
  State<_FournisseurForm> createState() => _FournisseurFormState();
}

class _FournisseurFormState extends State<_FournisseurForm> {
  final _nomCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _tel2Ctrl = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.fournisseur != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nomCtrl.text = widget.fournisseur!.nom;
      _adresseCtrl.text = widget.fournisseur!.adresse;
      _telCtrl.text = widget.fournisseur!.telephone;
      _tel2Ctrl.text = widget.fournisseur!.telephone2 ?? '';
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _adresseCtrl.dispose(); _telCtrl.dispose(); _tel2Ctrl.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _nomCtrl.text.trim().isNotEmpty && _adresseCtrl.text.trim().isNotEmpty && _telCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    final dialogCtx = context;
    final scaffoldCtx = widget.scaffoldContext;
    try {
      final f = Fournisseur(
        id: _isEditing ? widget.fournisseur!.id : '',
        nom: _nomCtrl.text.trim(),
        adresse: _adresseCtrl.text.trim(),
        telephone: _telCtrl.text.trim(),
        telephone2: _tel2Ctrl.text.trim().isEmpty ? null : _tel2Ctrl.text.trim(),
      );
      if (_isEditing) {
        await widget.magasin.updateFournisseur(f.copyWith(id: widget.fournisseur!.id));
      } else {
        await widget.magasin.addFournisseur(f);
      }
      if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) Navigator.of(dialogCtx, rootNavigator: true).pop();
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Fournisseur mis à jour' : 'Fournisseur ajouté'),
          backgroundColor: kTeal, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed, behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FullDialog(
      color: kTeal,
      icon: Icons.business_rounded,
      title: _isEditing ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
      onSave: _canSave ? _save : null,
      saveLabel: _saving ? 'Enregistrement…' : (_isEditing ? 'Mettre à jour' : 'Ajouter le fournisseur'),
      saving: _saving,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        _SectionHdr('1. Informations générales', Icons.business_outlined, kTeal),
        const SizedBox(height: 12),
        const Text('NOM DU FOURNISSEUR *', style: _label),
        const SizedBox(height: 5),
        _StyledTF(ctrl: _nomCtrl, hint: 'Ex: Société ABC', prefix: const Icon(Icons.business_outlined, size: 18, color: kMuted), onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _SectionHdr('2. Contact', Icons.contact_phone_outlined, kTeal),
        const SizedBox(height: 12),
        const Text('TÉLÉPHONE *', style: _label),
        const SizedBox(height: 5),
        _StyledTF(ctrl: _telCtrl, hint: 'Ex: +212 6XX XXX XXX', prefix: const Icon(Icons.phone_outlined, size: 18, color: kMuted), onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        Row(children: [
          const Text('TÉLÉPHONE 2', style: _label),
          const SizedBox(width: 6),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(6)), child: const Text('Optionnel', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kBlue))),
        ]),
        const SizedBox(height: 5),
        _StyledTF(ctrl: _tel2Ctrl, hint: 'Ex: +212 6XX XXX XXX', prefix: const Icon(Icons.phone_outlined, size: 18, color: kMuted), onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _SectionHdr('3. Adresse', Icons.location_on_outlined, kTeal),
        const SizedBox(height: 12),
        const Text('ADRESSE *', style: _label),
        const SizedBox(height: 5),
        _StyledTF(ctrl: _adresseCtrl, hint: 'Ex: 12 Rue du Commerce, Casablanca', prefix: const Icon(Icons.location_on_outlined, size: 18, color: kMuted), onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: kTealLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kTeal.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13, color: kTeal),
            const SizedBox(width: 6),
            const Flexible(child: Text('Les champs marqués * sont obligatoires.', style: TextStyle(fontSize: 11, color: kTeal))),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 12 — FORMULAIRE MOUVEMENT (avec fournisseur + date manuelle)
// ─────────────────────────────────────────────────────────────────────────────

class _MouvForm extends StatefulWidget {
  final String type;
  final MagasinProvider magasin;
  final BuildContext? scaffoldContext;
  final Mouvement? mouvement;
  const _MouvForm({required this.type, required this.magasin, this.scaffoldContext, this.mouvement});
  @override
  State<_MouvForm> createState() => _MouvFormState();
}

class _MouvFormState extends State<_MouvForm> {
  String? _selMag = 'Base de vie';
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
  final _prodSearchC = TextEditingController();
  final Map<String, TextEditingController> _varCtrl = {};
  final Set<String> _selVar = {};
  final _preneurC = TextEditingController();
  String? _stockError;
  Map<String, String> _varStockErrors = {};
  bool _saving = false;
  String? _selFournisseurId;      // NOUVEAU
  String? _newProdFournisseurId;  // NOUVEAU (pour nouveau produit)

  late DateTime _mvtDate;
  final _dateCtrl = TextEditingController(); // NOUVEAU : date manuelle

  bool get _isEditing => widget.mouvement != null;
  bool get _isSortie => widget.type == 'sortie';
  Color get _col => _isSortie ? kOrange : kGreen;

  final _mvtNomCtrl = TextEditingController();
  final _mvtRefCtrl = TextEditingController();

  GroupeUnites? get _groupe => _newProdMode ? groupeByLabel(_newGroupeLabel) : groupeByLabel(_selProd?.groupeUniteLabel);
  bool get _hasVar => _newProdMode ? _newHasVar : (_selProd?.aVariantes ?? false);

  List<Produit> get _filteredProduits => widget.magasin.produits.where((p) => _selCat == null || p.categorie == _selCat).toList();

  List<String> get _availableCatsForSelection {
    final base = widget.magasin.categoryNames;
    final m = widget.mouvement;
    if (m == null || base.contains(m.categorie)) return base;
    return [...base, m.categorie];
  }

  void _updateDateCtrl() {
    _dateCtrl.text = '${_mvtDate.day.toString().padLeft(2, '0')}/${_mvtDate.month.toString().padLeft(2, '0')}/${_mvtDate.year}  ${_mvtDate.hour.toString().padLeft(2, '0')}:${_mvtDate.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _mvtDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _col, onPrimary: Colors.white, surface: kSurface)), child: child!),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_mvtDate),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _col, onPrimary: Colors.white, surface: kSurface)), child: child!),
    );
    setState(() {
      _mvtDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime?.hour ?? _mvtDate.hour, pickedTime?.minute ?? _mvtDate.minute);
      _updateDateCtrl();
    });
  }

  @override
  void initState() {
    super.initState();
    _mvtDate = widget.mouvement?.date ?? DateTime.now();
    _updateDateCtrl();

    if (_isEditing) {
      final m = widget.mouvement!;
      _selCat = m.categorie;
      _mvtNomCtrl.text = m.nomProduit;
      _mvtRefCtrl.text = m.reference;
      _selFournisseurId = m.fournisseurId;
      _selMag = m.magasin.isNotEmpty ? m.magasin : 'Base de vie';

      if (_isSortie) { _newCatMode = false; _newProdMode = false; }

      final foundProd = widget.magasin.produits.where((p) => p.id == m.produitId).toList();
      if (foundProd.isNotEmpty) {
        _selProd = foundProd.first;
        _newProdMode = false;
      } else if (!_isSortie) {
        _newProdMode = true;
        _newHasVar = m.aVariantes;
        _newGroupeLabel = m.groupeUniteLabel;
        _newNomCtrl.text = m.nomProduit;
        _newRefCtrl.text = m.reference;
      }

      if (m.aVariantes) {
        _selVar.clear();
        for (final l in m.lignes) {
          _selVar.add(l.unite);
          _varCtrl[l.unite] = TextEditingController(text: l.quantite.toString());
        }
      } else {
        _qteC.text = m.quantite.toString();
      }

      if (_isSortie) {
        _preneurC.text = m.preneurNom ?? '';
        _validateStock();
      }
      return;
    }

    if (_isSortie) { _newCatMode = false; _newProdMode = false; }
  }

  @override
  void dispose() {
    _newCatCtrl.dispose(); _newNomCtrl.dispose(); _newRefCtrl.dispose();
    _mvtNomCtrl.dispose(); _mvtRefCtrl.dispose(); _qteC.dispose();
    _prodSearchC.dispose(); _preneurC.dispose(); _dateCtrl.dispose();
    for (final c in _varCtrl.values) c.dispose();
    super.dispose();
  }

  void _validateStock() {
    if (!_isSortie || _selProd == null) {
      setState(() { _stockError = null; _varStockErrors = {}; });
      return;
    }
    if (!_hasVar) {
      final demande = int.tryParse(_qteC.text) ?? 0;
      setState(() => _stockError = demande > _selProd!.total ? 'Stock insuffisant (disponible : ${_selProd!.total})' : null);
    } else {
      final errors = <String, String>{};
      for (final u in _selVar) {
        final demande = int.tryParse(_varCtrl[u]?.text ?? '0') ?? 0;
        final varMatch = _selProd!.variantes.where((v) => v.unite == u);
        final dispo = varMatch.isEmpty ? 0 : varMatch.first.quantite;
        if (demande > dispo) errors[u] = 'Max $dispo';
      }
      setState(() => _varStockErrors = errors);
    }
  }

  bool get _hasStockError => !_isSortie ? false : (!_hasVar ? _stockError != null : _varStockErrors.isNotEmpty);

  void _toggleVar(String u) => setState(() {
    if (_selVar.contains(u)) { _selVar.remove(u); _varCtrl.remove(u); }
    else { _selVar.add(u); _varCtrl[u] = TextEditingController(text: '1'); }
    _validateStock();
  });

  bool get _canSave {
    if (_saving) return false;
    final catOk = _newCatMode ? _newCatCtrl.text.trim().isNotEmpty : _selCat != null;
    final prodOk = _newProdMode ? (_newNomCtrl.text.trim().isNotEmpty && _newRefCtrl.text.trim().isNotEmpty) : _selProd != null;
    final qteOk = _hasVar ? _selVar.isNotEmpty : (int.tryParse(_qteC.text) ?? 0) > 0;
    final prenOk = !_isSortie || _preneurC.text.trim().isNotEmpty;
    // Pour une entrée, le fournisseur est obligatoire
    final fouOk = _isSortie || _selFournisseurId != null;
    return catOk && prodOk && qteOk && prenOk && fouOk && !_hasStockError;
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    final dialogCtx = context;
    final scaffoldCtx = widget.scaffoldContext;
    try {
      final magasinFinal = _selMag ?? 'Base de vie';
      final catFinal = _newCatMode ? _newCatCtrl.text.trim() : (_selCat ?? '');
      if (catFinal.isEmpty) throw Exception('Catégorie manquante');
      if (_newCatMode) await widget.magasin.addCategorie(catFinal);

      // Résolution fournisseur
      final fouId = _isSortie ? null : _selFournisseurId;
      final fouNom = fouId != null ? widget.magasin.fournisseurById(fouId)?.nom : null;

      Produit prod;
      if (_newProdMode) {
        final nom = _newNomCtrl.text.trim();
        final ref = _newRefCtrl.text.trim();
        if (nom.isEmpty || ref.isEmpty) throw Exception('Nom ou référence manquant');
        final newProd = Produit(
          id: '', nom: nom, reference: ref, categorie: catFinal,
          magasin: magasinFinal, aVariantes: _newHasVar,
          groupeUniteLabel: _newHasVar ? _newGroupeLabel : null,
          quantiteStock: 0, variantes: [],
          fournisseurId: fouId,
        );
        final newId = await widget.magasin.addProduit(newProd);
        if (newId.isEmpty) throw Exception('Erreur création produit');
        for (int i = 0; i < 40; i++) {
          if (widget.magasin.produits.any((p) => p.id == newId)) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }
        prod = newProd.copyWith(id: newId);
      } else {
        if (_selProd == null) throw Exception('Aucun produit sélectionné');
        prod = _selProd!;
        // Met à jour le fournisseurId et le magasin du produit si entrée
        if (!_isSortie) {
          final needUpdate = (fouId != null && prod.fournisseurId != fouId) || prod.magasin != magasinFinal;
          if (needUpdate) {
            prod = prod.copyWith(fournisseurId: fouId ?? prod.fournisseurId, magasin: magasinFinal);
            await widget.magasin.updateProduit(prod);
          }
        }
      }

      final lignes = _hasVar
          ? _selVar.map((u) => LigneMouvement(unite: u, quantite: int.tryParse(_varCtrl[u]?.text ?? '0') ?? 0)).where((l) => l.quantite > 0).toList()
          : <LigneMouvement>[];
      final quantite = _hasVar ? 0 : (int.tryParse(_qteC.text) ?? 0);
      if (!_hasVar && quantite <= 0) throw Exception('Quantité invalide');
      if (_hasVar && lignes.isEmpty) throw Exception('Sélectionnez au moins une variante');

      final mouvement = Mouvement(
        id: _isEditing ? widget.mouvement!.id : '',
        type: widget.type,
        produitId: prod.id,
        nomProduit: (_isEditing && !_newProdMode) ? (_mvtNomCtrl.text.trim().isNotEmpty ? _mvtNomCtrl.text.trim() : prod.nom) : prod.nom,
        reference: (_isEditing && !_newProdMode) ? (_mvtRefCtrl.text.trim().isNotEmpty ? _mvtRefCtrl.text.trim() : prod.reference) : prod.reference,
        categorie: catFinal,
        magasin: magasinFinal,
        aVariantes: _hasVar,
        groupeUniteLabel: _hasVar ? (prod.groupeUniteLabel ?? _newGroupeLabel) : null,
        quantite: quantite,
        lignes: lignes,
        date: _mvtDate,
        preneurNom: (_isSortie && _preneurC.text.trim().isNotEmpty) ? _preneurC.text.trim() : null,
        fournisseurId: fouId,
        fournisseurNom: fouNom,
      );

      if (_isEditing) {
        _isSortie ? await widget.magasin.updateSortie(widget.mouvement!.id, mouvement) : await widget.magasin.updateEntree(widget.mouvement!.id, mouvement);
      } else {
        _isSortie ? await widget.magasin.addSortie(mouvement) : await widget.magasin.addEntree(mouvement);
      }

      if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) Navigator.of(dialogCtx, rootNavigator: true).pop();
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(
          content: Text(_isEditing ? (_isSortie ? 'Sortie mise à jour' : 'Entrée mise à jour') : (_isSortie ? 'Sortie enregistrée' : 'Entrée enregistrée')),
          backgroundColor: _isSortie ? kOrange : kGreen, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (scaffoldCtx != null && scaffoldCtx.mounted) {
        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: kRed, behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _showPreneurDialog(BuildContext context) async {
    final employeesProv = context.read<EmployeesProvider>();
    final activeEmployes = employeesProv.employes.where((e) => e.statut == EmployeStatut.enService).toList()..sort((a, b) => a.nom.compareTo(b.nom));
    final postes = activeEmployes.map((e) => e.poste.trim()).where((p) => p.isNotEmpty).toSet().toList()..sort();

    if (!employeesProv.firebaseAvailable) {
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Employés'), content: const Text('Firebase غير متاح حالياً.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))]));
      return;
    }

    String q = '';
    String? selectedPoste;

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setStateD) {
          final qLower = q.trim().toLowerCase();
          final selectedPosteLower = selectedPoste?.trim().toLowerCase();
          final hasAnyFilter = qLower.isNotEmpty || selectedPosteLower != null;
          final filtered = hasAnyFilter
              ? activeEmployes.where((e) { final matchesName = e.nom.trim().toLowerCase().contains(qLower); final matchesPoste = selectedPosteLower == null || e.poste.trim().toLowerCase() == selectedPosteLower; return matchesName && matchesPoste; }).toList()
              : <Employe>[];
          final currentPreneur = _preneurC.text.trim();

          return AlertDialog(
            title: const Text('Choisir le prélevé par'),
            content: SizedBox(
              width: dialogMaxWidth(context),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()), onChanged: (v) => setStateD(() => q = v)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: selectedPoste, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Poste', border: OutlineInputBorder()),
                  items: [const DropdownMenuItem<String?>(value: null, child: Text('Tous')), ...postes.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))],
                  onChanged: (v) => setStateD(() => selectedPoste = v),
                ),
                const SizedBox(height: 12),
                SizedBox(height: 320, child: activeEmployes.isEmpty ? const Center(child: Text('Aucun employé en service')) : !hasAnyFilter ? const Center(child: Text('Choisissez un nom ou un poste')) : filtered.isEmpty ? const Center(child: Text('Aucun résultat'))
                    : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
                  final e = filtered[i];
                  final selected = currentPreneur == e.nom.trim();
                  return ListTile(dense: true, title: Text(e.nom, overflow: TextOverflow.ellipsis), subtitle: Text(e.poste, overflow: TextOverflow.ellipsis),
                    trailing: selected ? const Icon(Icons.check_circle_rounded, color: kBlue, size: 18) : null,
                    onTap: () { setState(() => _preneurC.text = e.nom.trim()); Navigator.of(dialogCtx).pop(); },
                  );
                })),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Fermer'))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final fournisseurs = widget.magasin.fournisseurs;

    return _FullDialog(
      color: _col,
      icon: _isSortie ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
      title: _isEditing
          ? (_isSortie ? 'Modification Sortie de Stock' : 'Modification Entrée de Stock')
          : (_isSortie ? 'Nouvelle Sortie de Stock' : 'Nouvelle Entrée de Stock'),
      onSave: _canSave ? _save : null,
      saveLabel: _saving ? 'Enregistrement…' : (_isEditing ? (_isSortie ? 'Mettre à jour la sortie' : "Mettre à jour l'entrée") : (_isSortie ? 'Valider la sortie' : "Valider l'entrée")),
      saving: _saving,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 1. Date manuelle ─────────────────────────────────────────────
        const SizedBox(height: 8),
        _SectionHdr('1. Date de l\'opération', Icons.calendar_today_rounded, _col),
        const SizedBox(height: 10),
        _StyledTF(
          ctrl: _dateCtrl,
          hint: 'jj/mm/aaaa hh:mm',
          prefix: Icon(Icons.calendar_today_rounded, size: 18, color: _col),
          readOnly: true,
          onTap: () => _pickDateTime(context),
        ),
        const SizedBox(height: 20),

        // ── 2. Fournisseur (entrée uniquement) ───────────────────────────
        if (!_isSortie) ...[
          _SectionHdr('2. Fournisseur *', Icons.business_rounded, _col),
          const SizedBox(height: 10),
          if (fournisseurs.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kOrange.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: kOrange, size: 16),
                const SizedBox(width: 8),
                const Flexible(child: Text('Aucun fournisseur enregistré. Ajoutez d\'abord un fournisseur dans l\'onglet « Fournisseurs ».', style: TextStyle(fontSize: 11, color: kOrange))),
              ]),
            )
          else
            _StyledDrop<String>(
              value: _selFournisseurId,
              hint: 'Sélectionner un fournisseur',
              items: fournisseurs.map((f) => DropdownMenuItem(
                value: f.id,
                child: Row(children: [
                  const Icon(Icons.business_outlined, size: 14, color: kTeal),
                  const SizedBox(width: 8),
                  Flexible(child: Text(f.nom, overflow: TextOverflow.ellipsis)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selFournisseurId = v),
            ),
          const SizedBox(height: 20),

          // ── 3. Magasin de stock ──────────────────────────────────────
          _SectionHdr('3. Magasin de stock *', Icons.warehouse_rounded, _col),
          const SizedBox(height: 10),
          _StyledDrop<String>(
            value: _selMag,
            hint: 'Sélectionner un magasin',
            items: kMagasins.map((m) => DropdownMenuItem(
              value: m,
              child: Row(children: [
                const Icon(Icons.warehouse_outlined, size: 14, color: kBlue),
                const SizedBox(width: 8),
                Flexible(child: Text(m, overflow: TextOverflow.ellipsis)),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => _selMag = v),
          ),
          const SizedBox(height: 20),

          // ── 4. Catégorie ─────────────────────────────────────────────
          _SectionHdr('4. Catégorie', Icons.category_outlined, _col),
        ] else ...[
          // Pour sortie : section 2
          _SectionHdr('2. Catégorie', Icons.category_outlined, _col),
        ],
        const SizedBox(height: 10),

        Builder(builder: (ctx) {
          final allowCreate = !_isSortie;
          final cats = _availableCatsForSelection;
          final field = _newCatMode
              ? _StyledTF(ctrl: _newCatCtrl, hint: 'Nom de la nouvelle catégorie…', prefix: const Icon(Icons.category_outlined, size: 18, color: kMuted), onChanged: (_) => setState(() {}))
              : _StyledDrop<String>(
            value: _selCat, hint: cats.isEmpty ? 'Aucune catégorie' : 'Sélectionner une catégorie',
            items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() { _selCat = v; _selProd = null; _selVar.clear(); _varCtrl.clear(); _prodSearchC.clear(); }),
          );

          if (!allowCreate) return field;
          if (mobile) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              field, const SizedBox(height: 8),
              _ModeBtn(label: _newCatMode ? '← Existante' : '+ Nouvelle', color: _col, onTap: () => setState(() { _newCatMode = !_newCatMode; _selCat = null; })),
            ]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: field), const SizedBox(width: 8),
            _ModeBtn(label: _newCatMode ? '← Existante' : '+ Nouvelle', color: _col, onTap: () => setState(() { _newCatMode = !_newCatMode; _selCat = null; })),
          ]);
        }),
        const SizedBox(height: 20),

        if (_selCat != null || _newCatMode) ...[
          // ── Produit ──────────────────────────────────────────────────
          Builder(builder: (ctx) {
            final secNum = _isSortie ? '3' : '5';
            return _SectionHdr('$secNum. Produit', Icons.inventory_2_outlined, _col);
          }),
          const SizedBox(height: 10),
          Builder(builder: (ctx) {
            final allowCreate = !_isSortie;
            final field = _newProdMode
                ? _NewProdBlock(
              nomCtrl: _newNomCtrl, refCtrl: _newRefCtrl, hasVar: _newHasVar, groupeLabel: _newGroupeLabel, color: _col,
              onHasVarChanged: (v) => setState(() { _newHasVar = v; _selVar.clear(); _varCtrl.clear(); }),
              onGroupeChanged: (v) => setState(() { _newGroupeLabel = v; _selVar.clear(); _varCtrl.clear(); }),
              onChanged: () => setState(() {}),
            )
                : Builder(builder: (ctx) {
              final query = _prodSearchC.text.trim().toLowerCase();
              final matches = query.isEmpty ? const <Produit>[] : _filteredProduits.where((p) => p.nom.toLowerCase().contains(query) || p.reference.toLowerCase().contains(query)).take(8).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _prodSearchC,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit…',
                      hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
                      prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 17),
                      suffixIcon: query.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 14), onPressed: () => setState(() => _prodSearchC.clear())) : null,
                      filled: true, fillColor: kSurface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 8),
                if (_selProd != null && query.isEmpty) Text('Produit sélectionné : ${_selProd!.nom}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
                if (query.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
                    constraints: BoxConstraints(maxHeight: mobile ? 240 : 220),
                    child: matches.isEmpty
                        ? const Padding(padding: EdgeInsets.all(14), child: Text('Aucun produit', style: TextStyle(fontSize: 12)))
                        : ListView.builder(padding: EdgeInsets.zero, shrinkWrap: true, itemCount: matches.length, itemBuilder: (_, i) {
                      final p = matches[i];
                      final isSel = _selProd?.id == p.id;
                      return InkWell(
                        onTap: () => setState(() {
                          _selProd = p; _prodSearchC.text = p.nom;
                          _mvtNomCtrl.text = p.nom; _mvtRefCtrl.text = p.reference;
                          _selVar.clear(); _varCtrl.clear(); _stockError = null; _varStockErrors = {};
                          if (!_isSortie && p.fournisseurId != null) _selFournisseurId = p.fournisseurId;
                          _validateStock();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis, maxLines: 1),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              _PillBadge(p.reference, kBlueLt, kBlue),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt, borderRadius: BorderRadius.circular(20)),
                                child: Text('${p.total}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: p.rupture ? kRed : p.bas ? kOrange : kGreen)),
                              ),
                              if (isSel) const Icon(Icons.check_circle_rounded, size: 14, color: kBlue),
                            ]),
                          ]),
                        ),
                      );
                    }),
                  ),
              ]);
            });

            if (!allowCreate) return field;
            if (mobile) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                field, const SizedBox(height: 8),
                _ModeBtn(label: _newProdMode ? '← Existant' : '+ Nouveau', color: _col, onTap: () => setState(() { _newProdMode = !_newProdMode; _selProd = null; _selVar.clear(); _varCtrl.clear(); _prodSearchC.clear(); _stockError = null; _varStockErrors = {}; })),
              ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: field), const SizedBox(width: 8),
              _ModeBtn(label: _newProdMode ? '← Existant' : '+ Nouveau', color: _col, onTap: () => setState(() { _newProdMode = !_newProdMode; _selProd = null; _selVar.clear(); _varCtrl.clear(); _prodSearchC.clear(); _stockError = null; _varStockErrors = {}; })),
            ]);
          }),
          const SizedBox(height: 20),

          if (_isEditing && !_newProdMode && _selProd != null) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: mobile ? double.infinity : 280, child: _StyledTF(ctrl: _mvtNomCtrl, hint: 'Nom (mouvement)', prefix: const Icon(Icons.edit_note_rounded, size: 18, color: kMuted), onChanged: (_) => setState(() {}))),
              SizedBox(width: mobile ? double.infinity : 220, child: _StyledTF(ctrl: _mvtRefCtrl, hint: 'Référence (mouvement)', prefix: const Icon(Icons.tag_rounded, size: 18, color: kMuted), onChanged: (_) => setState(() {}))),
            ]),
            const SizedBox(height: 14),
          ],

          if (_selProd != null || _newProdMode) ...[
            // ── Quantité ────────────────────────────────────────────────
            Builder(builder: (ctx) {
              final secNum = _isSortie ? '4' : '5';
              return _SectionHdr('$secNum. Quantité', _hasVar ? Icons.grid_view_rounded : Icons.tag_rounded, _col);
            }),
            const SizedBox(height: 10),

            if (_isSortie && _selProd != null && !_newProdMode && _stockError != null)
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 220),
                child: _NumStepField(ctrl: _qteC, color: _col, onChanged: () { setState(() {}); _validateStock(); }),
              )
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: sel ? _col : kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? _col : kBorder, width: sel ? 2 : 1.5)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(u, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : kMuted)),
                      if (disp != null) Text('$disp dispo', style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : kMuted)),
                    ]),
                  ),
                );
              }).toList()),
              if (_selVar.isNotEmpty) ...[
                const SizedBox(height: 14),
                _VarQteTable(selVar: _selVar, varCtrl: _varCtrl, color: _col, onRemove: _toggleVar, stockErrors: _varStockErrors, stockDisp: _isSortie && _selProd != null ? {for (var v in _selProd!.variantes) v.unite: v.quantite} : {}, onQteChanged: _validateStock),
              ],
            ],
            const SizedBox(height: 20),
          ],

          if (_isSortie && (_selProd != null || _newProdMode)) ...[
            Builder(builder: (ctx) {
              final secNum = '5';
              return _SectionHdr('$secNum. Prélevé par', Icons.person_outline_rounded, _col);
            }),
            const SizedBox(height: 10),
            _StyledTF(ctrl: _preneurC, hint: 'Cliquez pour choisir…', prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted), readOnly: true, onTap: () => _showPreneurDialog(context)),
          ],
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 13 — WIDGETS FORMULAIRE
// ─────────────────────────────────────────────────────────────────────────────

class _NewProdBlock extends StatelessWidget {
  final TextEditingController nomCtrl, refCtrl;
  final bool hasVar;
  final String? groupeLabel;
  final Color color;
  final ValueChanged<bool> onHasVarChanged;
  final ValueChanged<String?> onGroupeChanged;
  final VoidCallback onChanged;

  const _NewProdBlock({required this.nomCtrl, required this.refCtrl, required this.hasVar, this.groupeLabel, required this.color, required this.onHasVarChanged, required this.onGroupeChanged, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Column(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('NOM DU PRODUIT', style: _label), const SizedBox(height: 5), _StyledTF(ctrl: nomCtrl, hint: 'Ex: Casque de sécurité', onChanged: (_) => onChanged())]),
          const SizedBox(height: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('RÉFÉRENCE', style: _label), const SizedBox(height: 5), _StyledTF(ctrl: refCtrl, hint: 'Ex: EPI-010', onChanged: (_) => onChanged())]),
        ]),
        const SizedBox(height: 12),
        const Text('A DES VARIANTES ?', style: _label),
        const SizedBox(height: 5),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _ToggleBtn('Oui', hasVar, color, () => onHasVarChanged(true)),
          _ToggleBtn('Non', !hasVar, color, () => onHasVarChanged(false)),
        ]),
        if (hasVar) ...[
          const SizedBox(height: 12),
          const Text("GROUPE D'UNITÉS", style: _label),
          const SizedBox(height: 5),
          _StyledDrop<String>(
            value: groupeLabel, hint: 'Choisir un groupe',
            items: kGroupes.map((g) => DropdownMenuItem(value: g.label, child: Row(children: [Text(g.emoji), const SizedBox(width: 8), Flexible(child: Text(g.label, overflow: TextOverflow.ellipsis))]))).toList(),
            onChanged: onGroupeChanged,
          ),
        ],
      ]),
    );
  }
}

class _VarQteTable extends StatefulWidget {
  final Set<String> selVar;
  final Map<String, TextEditingController> varCtrl;
  final Color color;
  final void Function(String) onRemove;
  final Map<String, String> stockErrors;
  final Map<String, int> stockDisp;
  final VoidCallback onQteChanged;

  const _VarQteTable({required this.selVar, required this.varCtrl, required this.color, required this.onRemove, this.stockErrors = const {}, this.stockDisp = const {}, required this.onQteChanged});

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: col.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(kR))),
          child: Row(children: [
            Expanded(flex: 2, child: Text('UNITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 10),
            Expanded(flex: 5, child: Text('QUANTITÉ', style: _label.copyWith(color: col))),
            const SizedBox(width: 34),
          ]),
        ),
        ...widget.selVar.toList().asMap().entries.map((e) {
          final i = e.key; final u = e.value;
          final ctrl = widget.varCtrl[u]!;
          final err = widget.stockErrors[u];
          final disp = widget.stockDisp[u];
          return Column(children: [
            if (i > 0) const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(children: [
                Row(children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 60, maxWidth: 90),
                    child: Container(height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: err != null ? kRed : col, borderRadius: BorderRadius.circular(7)), child: Text(u, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Row(children: [
                    _StepBtn(Icons.remove_rounded, col, () { final v = int.tryParse(ctrl.text) ?? 0; if (v > 0) { ctrl.text = '${v - 1}'; setState(() {}); widget.onQteChanged(); } }),
                    Expanded(child: SizedBox(height: 38, child: TextField(
                      controller: ctrl, keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText),
                      decoration: InputDecoration(hintText: '0', contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : kBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : col, width: 2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: err != null ? kRed : kBorder, width: err != null ? 2 : 1)),
                      ),
                      onChanged: (_) { setState(() {}); widget.onQteChanged(); },
                    ))),
                    _StepBtn(Icons.add_rounded, col, () { final v = int.tryParse(ctrl.text) ?? 0; ctrl.text = '${v + 1}'; setState(() {}); widget.onQteChanged(); }),
                  ])),
                  const SizedBox(width: 6),
                  InkWell(borderRadius: BorderRadius.circular(6), onTap: () { widget.onRemove(u); setState(() {}); },
                    child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close_rounded, size: 14, color: kRed)),
                  ),
                ]),
                if (err != null) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const SizedBox(width: 8), const Icon(Icons.error_outline, size: 12, color: kRed), const SizedBox(width: 3), Expanded(child: Text(err, style: const TextStyle(fontSize: 10, color: kRed, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]))
                else if (disp != null) Padding(padding: const EdgeInsets.only(top: 3), child: Row(children: [const SizedBox(width: 8), Icon(Icons.info_outline, size: 11, color: kMuted.withOpacity(0.7)), const SizedBox(width: 3), Text('$disp dispo', style: TextStyle(fontSize: 10, color: kMuted.withOpacity(0.8)))])),
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
//  SECTION 14 — DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

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
      color: kBlue, icon: Icons.inventory_2_rounded, title: p.nom,
      saveLabel: 'Fermer', onSave: () => Navigator.of(context, rootNavigator: true).pop(), showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _DetCard(Icons.qr_code_rounded, '🏷️ Référence', p.reference),
          _DetCard(Icons.category_outlined, '📂 Catégorie', p.categorie),
          _DetCard(Icons.warehouse_rounded, '🏪 Magasin', 'Magasin ${p.magasin}'),
          if (g != null) _DetCard(Icons.widgets_rounded, '${g.emoji} Mesures', g.label),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: stockColor.withOpacity(0.2))),
          child: Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Icon(Icons.inventory_2_outlined, color: stockColor, size: 20),
            Text('${p.total}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: stockColor)),
            Text('unité${p.total != 1 ? "s" : ""}', style: TextStyle(fontSize: 12, color: stockColor.withOpacity(0.8))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: stockColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(stockLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: stockColor))),
          ]),
        ),
        if (p.aVariantes && p.variantes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          const SizedBox(height: 10),
          Column(children: p.variantes.map((v) {
            final r = v.quantite == 0; final lo = v.quantite > 0 && v.quantite <= 3;
            final vc = r ? kRed : lo ? kOrange : kGreen;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: vc.withOpacity(0.15))),
              child: Row(children: [
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 50, maxWidth: 80), child: Container(height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(6)), child: Text(v.unite, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 12),
                Text('${v.quantite}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: vc)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: r ? kRedLt : lo ? kOrangeLt : kGreenLt, borderRadius: BorderRadius.circular(20)), child: Text(r ? 'Rupture' : lo ? 'Bas' : 'OK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: vc))),
              ]),
            );
          }).toList()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBlue.withOpacity(0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('TOTAL', style: _label.copyWith(color: kBlue)),
              Text('${p.total}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kBlue)),
            ]),
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
    final isE = m.type == 'entree';
    final color = isE ? kGreen : kOrange;
    final bg = isE ? kGreenLt : kOrangeLt;
    final g = groupeByLabel(m.groupeUniteLabel);

    return _FullDialog(
      color: color, icon: isE ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded,
      title: isE ? "Détails de l'entrée" : 'Détails de la sortie',
      saveLabel: 'Fermer', onSave: () => Navigator.of(context, rootNavigator: true).pop(), showCancel: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _DetCard(Icons.inventory_2_outlined, '📦 Produit', m.nomProduit),
          _DetCard(Icons.qr_code_rounded, '🏷️ Référence', m.reference),
          _DetCard(Icons.category_outlined, '📂 Catégorie', m.categorie),
          _DetCard(Icons.warehouse_rounded, '🏪 Magasin', 'Magasin ${m.magasin}'),
          _DetCard(Icons.calendar_today_rounded, '📅 Date', _fmtFull(m.date)),
          if (m.preneurNom != null) _DetCard(Icons.person_outline_rounded, '👤 Prélevé par', m.preneurNom!),
          if (isE && m.fournisseurNom != null) _DetCard(Icons.business_rounded, '🏭 Fournisseur', m.fournisseurNom!),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: color.withOpacity(0.2))),
          child: Row(children: [
            Icon(isE ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(isE ? 'Entrée de stock — ${m.totalQte} unité${m.totalQte != 1 ? "s" : ""}' : 'Sortie de stock — ${m.totalQte} unité${m.totalQte != 1 ? "s" : ""}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (m.aVariantes && m.lignes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Détail par ${g?.label.toLowerCase() ?? "variante"}', style: _h2),
          const SizedBox(height: 10),
          Column(children: m.lignes.asMap().entries.map((e) {
            final ligne = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(kR), border: Border.all(color: color.withOpacity(0.15))),
              child: Row(children: [
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 50, maxWidth: 90), child: Container(height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)), child: Text(ligne.unite, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 12),
                Text('${ligne.quantite}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              ]),
            );
          }).toList()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(kR), border: Border.all(color: color.withOpacity(0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('TOTAL', style: _label.copyWith(color: color)),
              Text('${m.totalQte}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ]),
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

  static String _fmtFull(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
//  SECTION 15 — FULL DIALOG SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _FullDialog extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title, saveLabel;
  final VoidCallback? onSave;
  final Widget child;
  final bool showCancel, saving;

  const _FullDialog({required this.color, required this.icon, required this.title, required this.saveLabel, required this.onSave, required this.child, this.showCancel = true, this.saving = false});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final hMargin = mobile ? 12.0 : 40.0;
    final maxW = mobile ? sw - hMargin * 2 : 600.0;
    final maxH = sh * (mobile ? 0.93 : 0.88);

    return Align(
      alignment: mobile ? Alignment.bottomCenter : Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.only(left: hMargin, right: hMargin, top: mobile ? 40 : 30, bottom: mobile ? 0 : 30),
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: mobile ? const BorderRadius.vertical(top: Radius.circular(20)) : BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (mobile) Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kBorderMd, borderRadius: BorderRadius.circular(2)))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : kP, vertical: 14),
              decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.white, size: 17)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: TextStyle(fontSize: mobile ? 14 : 16, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis, maxLines: 1)),
                const SizedBox(width: 8),
                InkWell(onTap: () => Navigator.of(context, rootNavigator: true).pop(), borderRadius: BorderRadius.circular(7), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.close_rounded, color: Colors.white, size: 16))),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: EdgeInsets.all(mobile ? 14 : kP), child: child)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : kP, vertical: 12),
              decoration: const BoxDecoration(color: kBg, border: Border(top: BorderSide(color: kBorder)), borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
              child: mobile
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                if (showCancel) ...[
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(), style: OutlinedButton.styleFrom(foregroundColor: kMuted, side: const BorderSide(color: kBorderMd), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR))), child: const Text('Annuler'))),
                  const SizedBox(height: 8),
                ],
                SizedBox(width: double.infinity, child: AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: onSave != null ? 1.0 : 0.4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)), padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: onSave,
                    child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14), const SizedBox(width: 6), Flexible(child: Text(saveLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))]),
                  ),
                )),
              ])
                  : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (showCancel) ...[
                  TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(), child: const Text('Annuler', style: TextStyle(color: kMuted))),
                  const SizedBox(width: 8),
                ],
                AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: onSave != null ? 1.0 : 0.4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: onSave,
                    child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14), const SizedBox(width: 6), Flexible(child: Text(saveLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))]),
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
//  SECTION 16 — COMPOSANTS UI PARTAGÉS
// ─────────────────────────────────────────────────────────────────────────────

class _Col { final String label; final int flex; const _Col(this.label, {this.flex = 1}); }
class _DataTableRow { final List<Widget> cells; const _DataTableRow({required this.cells}); }

class _DataTable extends StatelessWidget {
  final List<_Col> columns;
  final List<_DataTableRow> rows;
  final bool empty;
  final Color? accentColor;

  const _DataTable({required this.columns, required this.rows, required this.empty, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? kBlue;
    return Container(
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR2), border: Border.all(color: kBorder), boxShadow: [BoxShadow(color: accent.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kR2),
        child: Column(children: [
          Container(
            color: accent.withOpacity(0.07),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: columns.map((c) => Expanded(flex: c.flex, child: Text(c.label, style: _label.copyWith(color: accent), overflow: TextOverflow.ellipsis, maxLines: 1))).toList()),
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(child: empty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 48, color: accent.withOpacity(0.2)), const SizedBox(height: 10), Text('Aucun résultat', style: _muted, textAlign: TextAlign.center)]))
              : ListView.separated(itemCount: rows.length, separatorBuilder: (_, _) => const Divider(height: 1, color: kBorder), itemBuilder: (_, i) => _RowWidget(row: rows[i], columns: columns, accentColor: accent))),
        ]),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.columns.length, (i) => Expanded(flex: widget.columns[i].flex,
          child: i < widget.row.cells.length ? Align(alignment: Alignment.centerLeft, child: widget.row.cells[i]) : const SizedBox.shrink(),
        )),
      ),
    ),
  );
}

class _MouvRow extends _DataTableRow {
  final Mouvement m;
  final Color color, bgColor;
  final bool showPreneur, showFournisseur;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  _MouvRow({required this.m, required this.color, required this.bgColor, this.showPreneur = false, this.showFournisseur = false, required this.onDelete, this.onEdit}) : super(cells: const []);

  String get _d => '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}';
  String get _t => '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';

  @override
  List<Widget> get cells => [
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
      Text(_t, style: _muted.copyWith(fontSize: 10)),
    ]),
    Text(m.nomProduit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1),
    Text(m.reference, style: _mono, overflow: TextOverflow.ellipsis, maxLines: 1),
    _PillBadge(m.categorie, kBlueLt, kBlue),
    if (showFournisseur)
      m.fournisseurNom != null ? _PillBadge(m.fournisseurNom!, kTealLt, kTeal) : Text('—', style: _muted.copyWith(fontSize: 11)),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text('${m.totalQte}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    ),
    if (showPreneur) Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.person_outline_rounded, size: 12, color: kMuted),
      const SizedBox(width: 4),
      Flexible(child: Text(m.preneurNom ?? '—', style: const TextStyle(fontSize: 11, color: kText), overflow: TextOverflow.ellipsis, maxLines: 1)),
    ]),
    Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (onEdit != null) ...[_IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, onEdit!), const SizedBox(width: 6)],
      _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
    ])),
  ];
}

// ── Petits composants ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  final Color color;
  const _EmptyState({required this.message, required this.color});

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inbox_rounded, size: 52, color: color.withOpacity(0.2)), const SizedBox(height: 12), Text(message, style: _muted, textAlign: TextAlign.center)])));
}

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
  Widget build(BuildContext context) => Tooltip(message: tip, child: InkWell(borderRadius: BorderRadius.circular(7), onTap: fn, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 14, color: col))));
}

class _DetCard extends StatelessWidget {
  final IconData icon;
  final String label, val;
  const _DetCard(this.icon, this.label, this.val);

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final sw = MediaQuery.of(context).size.width;
    final cardWidth = mobile ? sw - 80.0 : 175.0;
    return Container(
      width: cardWidth.clamp(140.0, double.infinity),
      padding: const EdgeInsets.all(11),
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
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis),
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
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: active ? color : kSurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? color : kBorder, width: 1.5)),
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
    Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 13, color: color)),
    const SizedBox(width: 8),
    Flexible(child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: .5), overflow: TextOverflow.ellipsis)),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: color.withOpacity(0.2))),
  ]);
}

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBox({required this.label, required this.date, required this.onTap});

  String get _txt => date != null
      ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
      : 'jj/mm/aaaa';

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(kR),
    onTap: onTap,
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kR),
        border: Border.all(color: date != null ? kBlue.withOpacity(0.5) : kBorder, width: date != null ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: date != null ? kBlue : kMuted),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 0.4)),
          Text(_txt, style: TextStyle(fontSize: 11, fontWeight: date != null ? FontWeight.w700 : FontWeight.w400, color: date != null ? kText : kMuted)),
        ])),
        Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: date != null ? kBlue : kMuted),
      ]),
    ),
  );
}

class _GlassDropdown extends StatelessWidget {
  final String value, hint;
  final List<String> items;
  final void Function(String) onChanged;
  final IconData icon;
  const _GlassDropdown({required this.value, required this.items, required this.onChanged, required this.icon, required this.hint});

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.3))),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: items.contains(value) ? value : items.first,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 14),
      dropdownColor: const Color(0xFF1E293B), isExpanded: true,
      style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'Roboto', fontWeight: FontWeight.w600),
      items: items.map((v) => DropdownMenuItem(value: v, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: Colors.white70), const SizedBox(width: 5), Flexible(child: Text(v, style: const TextStyle(fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis))]))).toList(),
      onChanged: (v) => onChanged(v!),
    )),
  );
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
      controller: ctrl, style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Rechercher…', hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
        prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 17),
        suffixIcon: value.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 14), onPressed: () { ctrl.clear(); onChanged(''); }) : null,
        filled: true, fillColor: kSurface, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBlue, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
      ),
      onChanged: onChanged,
    ),
  );
}

class _DropBox extends StatelessWidget {
  final dynamic value;
  final List<String> items;
  final void Function(String) onChanged;
  const _DropBox({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: items.contains(value) ? value as String : items.first,
      isExpanded: true,
      style: const TextStyle(fontSize: 12, color: kText, fontFamily: 'Roboto'),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kBlue, size: 17),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => onChanged(v!),
    )),
  );
}

class _LabeledDrop extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String) onChanged;
  const _LabeledDrop({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: _label),
      const SizedBox(height: 4),
      _DropBox(value: value, items: items, onChanged: onChanged),
    ],
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
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
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
  final bool readOnly;
  final VoidCallback? onTap;
  const _StyledTF({required this.ctrl, required this.hint, this.prefix, this.onChanged, this.readOnly = false, this.onTap});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, style: const TextStyle(fontSize: 12, color: kText),
    onTap: onTap, onChanged: onChanged, readOnly: readOnly,
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
      prefixIcon: prefix, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true, fillColor: kSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
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
    _StepBtn(Icons.remove_rounded, color, () { final v = int.tryParse(ctrl.text) ?? 0; if (v > 1) { ctrl.text = '${v - 1}'; onChanged(); } }),
    Expanded(child: SizedBox(height: 48, child: TextField(
      controller: ctrl, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center, onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText),
      decoration: InputDecoration(hintText: '0', contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide(color: color, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: kBorder)),
      ),
    ))),
    _StepBtn(Icons.add_rounded, color, () { final v = int.tryParse(ctrl.text) ?? 0; ctrl.text = '${v + 1}'; onChanged(); }),
  ]);
}

class _AscBtn extends StatelessWidget {
  final bool asc;
  final VoidCallback onTap;
  const _AscBtn({required this.asc, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(kR), onTap: onTap,
    child: Container(width: 42, height: 42, decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBlueMd.withOpacity(.5))), child: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: kBlue, size: 16)),
  );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StepBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(7), onTap: onTap,
    child: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(.2))), child: Icon(icon, color: color, size: 17)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 17 — ÉTATS VIDES / ERREUR
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 56, height: 56, decoration: BoxDecoration(color: kBlueLt, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.store_rounded, color: kBlue, size: 28)),
    const SizedBox(height: 16),
    const CircularProgressIndicator(color: kBlue, strokeWidth: 2.5),
    const SizedBox(height: 12),
    const Text('Chargement du stock…', style: TextStyle(fontSize: 14, color: kMuted)),
  ]);
}

class _FirebaseErrorState extends StatelessWidget {
  const _FirebaseErrorState();
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 64, height: 64, decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.cloud_off_rounded, color: kRed, size: 32)),
    const SizedBox(height: 16),
    const Text('Firebase non disponible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kText), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    const Text('Vérifiez votre connexion et la configuration Firebase', style: TextStyle(color: kMuted), textAlign: TextAlign.center),
  ]));
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline_rounded, size: 56, color: kRed),
    const SizedBox(height: 12),
    const Text('Une erreur est survenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kText), textAlign: TextAlign.center),
    const SizedBox(height: 8),
    Text(message, style: const TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center),
  ]));
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 18 — HELPER DIALOG
// ─────────────────────────────────────────────────────────────────────────────

void _showDialog(BuildContext context, Widget dialog) {
  showGeneralDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (_, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
    ),
    pageBuilder: (_, _, _) => dialog,
  );
}

// Helper pour la largeur max des dialogs internes (ex: dialog prélevé par)
double dialogMaxWidth(BuildContext context) {
  final sw = MediaQuery.of(context).size.width;
  return sw > 600 ? 500 : sw - 48;
}