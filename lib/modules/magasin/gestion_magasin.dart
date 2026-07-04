
// =============================================================================
//  gestion_magasin.dart — VERSION AVEC FOURNISSEURS
//  + Page Fournisseurs dans la nav
//  + Sélection fournisseur dans le formulaire d'entrée
//  + Date manuelle pour entrées/sorties
//  + Filtre par fournisseur dans l'historique
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/notifications/ops_notifications_service.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/site/site_model.dart';
import '../../core/site/site_provider.dart';
import '../../core/utils/responsive.dart';
import '../employees/employees_provider.dart';
import '../employees/models/employe_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 1 — MODÈLES
// ─────────────────────────────────────────────────────────────────────────────

/// Normalise les anciens siteId ('default' ou null) vers 'jadida'.
String _normSite(String? v) => (v == null || v == 'default') ? SiteId.jadida : v;

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

// ── Modèle Modulaire (Base de vie) ───────────────────────────────────────────
class Modulaire {
  final String id;
  final String nom;
  const Modulaire({required this.id, required this.nom});

  Map<String, dynamic> toFirestore() => {'nom': nom};

  factory Modulaire.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Modulaire(id: doc.id, nom: d['nom'] as String? ?? '');
  }
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
  final String? modulaireId;   // MODULAIRE (Base de vie)
  final String? modulaireNom;  // dénormalisé

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
    this.siteId = 'jadida',
    this.fournisseurId,
    this.modulaireId,
    this.modulaireNom,
  });

  int get total =>
      aVariantes ? variantes.fold(0, (s, v) => s + v.quantite) : quantiteStock;

  // Rupture : au moins une taille (ou le produit sans taille) à 0
  bool get rupture => aVariantes
      ? variantes.any((v) => v.quantite == 0)
      : quantiteStock == 0;

  // Bas : au moins une taille (ou le produit sans taille) entre 1 et 2 inclus
  bool get bas => aVariantes
      ? variantes.any((v) => v.quantite > 0 && v.quantite <= 2)
      : (quantiteStock > 0 && quantiteStock <= 2);

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
    'modulaireId': modulaireId,
    'modulaireNom': modulaireNom,
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
      siteId: _normSite(d['siteId'] as String?),
      fournisseurId: d['fournisseurId'] as String?,
      modulaireId: d['modulaireId'] as String?,
      modulaireNom: d['modulaireNom'] as String?,
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
    String? modulaireId,
    String? modulaireNom,
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
    modulaireId: modulaireId ?? this.modulaireId,
    modulaireNom: modulaireNom ?? this.modulaireNom,
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
  final String? modulaireId;     // MODULAIRE (Base de vie)
  final String? modulaireNom;    // dénormalisé
  final double? prixUnitaire;    // P.U en MAD (optionnel, entrées uniquement)

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
    this.siteId = 'jadida',
    this.fournisseurId,
    this.fournisseurNom,
    this.modulaireId,
    this.modulaireNom,
    this.prixUnitaire,
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
    'modulaireId': modulaireId,
    'modulaireNom': modulaireNom,
    'prixUnitaire': prixUnitaire,
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
      siteId: _normSite(d['siteId'] as String?),
      fournisseurId: d['fournisseurId'] as String?,
      fournisseurNom: d['fournisseurNom'] as String?,
      modulaireId: d['modulaireId'] as String?,
      modulaireNom: d['modulaireNom'] as String?,
      prixUnitaire: (d['prixUnitaire'] as num?)?.toDouble(),
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
  CollectionReference<Map<String, dynamic>> get _modulairesRef =>
      _db.collection('magasin').doc('stock').collection('modulaires');

  List<Produit> _produits = [];
  List<Mouvement> _mouvements = [];
  List<String> _categories = [];
  List<Fournisseur> _fournisseurs = [];
  List<Modulaire> _modulaires = [];
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
  List<Modulaire> get modulaires => _modulaires;
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
      final cm2 = _modulairesRef
          .orderBy('nom')
          .snapshots()
          .listen(
            (snap) {
          _modulaires = snap.docs.map(Modulaire.fromFirestore).toList();
          notifyListeners();
        },
        onError: (e) {
          _error = e.toString();
          notifyListeners();
        },
      );
      _cancelListeners.addAll([cp.cancel, cm.cancel, cc.cancel, cf.cancel, cm2.cancel]);
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

  // ── Modulaires CRUD ───────────────────────────────────────────────────────
  Future<String> addModulaire(String nom) async {
    final existing = _modulaires.where(
      (m) => m.nom.trim().toLowerCase() == nom.trim().toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first.id;
    final data = {'nom': nom.trim(), 'createdAt': FieldValue.serverTimestamp()};
    final ref = await _modulairesRef.add(data);
    return ref.id;
  }

  Future<void> deleteModulaire(String id) async =>
      _modulairesRef.doc(id).delete();

  Modulaire? modulaireById(String? id) {
    if (id == null) return null;
    final matches = _modulaires.where((m) => m.id == id);
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
    if (m.produitId.isEmpty) return;
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
    try {
      final snap = await _mouvementsRef.doc(id).get();
      if (!snap.exists) return;
      await _appliquerMouvement(Mouvement.fromFirestore(snap), annuler: true);
      await _mouvementsRef.doc(id).delete();
    } catch (e) {
      debugPrint('deleteEntree error: $e');
    }
  }

  Future<void> updateEntree(String id, Mouvement mouvement) async =>
      _updateMouvement(id, mouvement);

  Future<Produit?> _produitById(String produitId) async {
    if (produitId.isEmpty) return null;
    final snap = await _produitsRef.doc(produitId).get();
    if (!snap.exists) return null;
    return Produit.fromFirestore(snap);
  }

  Future<void> addSortie(
    Mouvement mouvement, {
    String? actorUserId,
    String? actorUserName,
  }) async {
    final before = await _produitById(mouvement.produitId);
    final ref = _mouvementsRef.doc();
    await ref.set(mouvement.toFirestore());
    await _appliquerMouvement(mouvement.copyWithId(ref.id), annuler: false);
    final after = await _produitById(mouvement.produitId);
    if (after != null) {
      unawaited(
        OpsNotificationsService.instance.emitStockSortie(
          mouvement: mouvement.copyWithId(ref.id),
          stockRestant: after.total,
          actorUserId: actorUserId,
          actorUserName: actorUserName,
        ),
      );
      if (before != null) {
        unawaited(
          OpsNotificationsService.instance.emitStockLevelIfNeeded(before: before, after: after),
        );
      }
    }
  }

  Future<void> deleteSortie(String id) async {
    try {
      final snap = await _mouvementsRef.doc(id).get();
      if (!snap.exists) return;
      final mouvement = Mouvement.fromFirestore(snap);
      await _appliquerMouvement(mouvement, annuler: true);
      await _mouvementsRef.doc(id).delete();
    } catch (e) {
      debugPrint('deleteSortie error: $e');
    }
  }

  Future<void> updateSortie(String id, Mouvement mouvement) async =>
      _updateMouvement(id, mouvement);

  Future<void> ajusterQuantiteDirecte(Produit produit, {int? nouvelleQuantite, List<VarianteProduit>? nouvellesVariantes}) async {
    if (produit.aVariantes && nouvellesVariantes != null) {
      await _produitsRef.doc(produit.id).update({
        'variantes': nouvellesVariantes.map((v) => v.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (!produit.aVariantes && nouvelleQuantite != null) {
      await _produitsRef.doc(produit.id).update({
        'quantiteStock': nouvelleQuantite.clamp(0, 999999),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
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
    modulaireId: modulaireId,
    modulaireNom: modulaireNom,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 3 — CONSTANTES UI
// ─────────────────────────────────────────────────────────────────────────────

const Color kBlue = Color(0xFF000966);
const Color kBlueDk = Color(0xFF000966);
const Color kBlueLt = Color(0xFFE8E9F3);
const Color kBlueMd = Color(0xFFC8CBE8);
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
const Color kBrown = Color(0xFF92400E);     // Modulaire (Base de vie)
const Color kBrownLt = Color(0xFFFFF7ED);   // Modulaire bg

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

  void _showStockAlert(BuildContext ctx, List<Produit> produits, String titre, Color color, Color colorLt, {required bool isRupture}) {
    showDialog(
      context: ctx,
      builder: (_) => _StockAlertDialog(produits: produits, titre: titre, color: color, colorLt: colorLt, isRupture: isRupture),
    );
  }

  Future<void> _exportExcel(
    BuildContext ctx,
    List<Produit> produits,
    List<Mouvement> entrees,
    List<Mouvement> sorties,
  ) async {
    try {
      final wb = Excel.createExcel();
      final fmt = DateFormat('dd/MM/yyyy');

      final hStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#1D4ED8'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      void writeHeader(Sheet sheet, List<String> cols) {
        for (var c = 0; c < cols.length; c++) {
          final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
          cell.value = TextCellValue(cols[c]);
          cell.cellStyle = hStyle;
        }
      }

      // ── Feuille 1 : Stock Actuel ───────────────────────────────────────────
      final stock = wb['Stock Actuel'];
      wb.setDefaultSheet('Stock Actuel');
      wb.delete('Sheet1');
      writeHeader(stock, const ['PRODUIT', 'RÉFÉRENCE', 'CATÉGORIE', 'MAGASIN', 'MODULAIRE', 'TAILLE', 'QUANTITÉ']);

      for (final p in produits) {
        if (!p.aVariantes) {
          stock.appendRow([
            TextCellValue(p.nom), TextCellValue(p.reference), TextCellValue(p.categorie),
            TextCellValue(p.magasin), TextCellValue(p.modulaireNom ?? '-'),
            TextCellValue('-'), IntCellValue(p.quantiteStock),
          ]);
        } else {
          for (final v in p.variantes) {
            stock.appendRow([
              TextCellValue(p.nom), TextCellValue(p.reference), TextCellValue(p.categorie),
              TextCellValue(p.magasin), TextCellValue(p.modulaireNom ?? '-'),
              TextCellValue(v.unite), IntCellValue(v.quantite),
            ]);
          }
        }
      }

      // ── Feuille 2 : Entrées ────────────────────────────────────────────────
      final sheetEntrees = wb['Entrées'];
      writeHeader(sheetEntrees, const ['DATE', 'PRODUIT', 'RÉFÉRENCE', 'CATÉGORIE', 'MAGASIN', 'MODULAIRE', 'FOURNISSEUR', 'TAILLE', 'QUANTITÉ', 'PRIX UNITAIRE (MAD)']);

      for (final m in entrees) {
        final date = TextCellValue(fmt.format(m.date));
        final prix = m.prixUnitaire != null ? DoubleCellValue(m.prixUnitaire!) : TextCellValue('-');
        if (!m.aVariantes) {
          sheetEntrees.appendRow([
            date, TextCellValue(m.nomProduit), TextCellValue(m.reference), TextCellValue(m.categorie),
            TextCellValue(m.magasin), TextCellValue(m.modulaireNom ?? '-'),
            TextCellValue(m.fournisseurNom ?? '-'), TextCellValue('-'), IntCellValue(m.quantite), prix,
          ]);
        } else {
          for (final l in m.lignes) {
            sheetEntrees.appendRow([
              date, TextCellValue(m.nomProduit), TextCellValue(m.reference), TextCellValue(m.categorie),
              TextCellValue(m.magasin), TextCellValue(m.modulaireNom ?? '-'),
              TextCellValue(m.fournisseurNom ?? '-'), TextCellValue(l.unite), IntCellValue(l.quantite), prix,
            ]);
          }
        }
      }

      // ── Feuille 3 : Sorties ────────────────────────────────────────────────
      final sheetSorties = wb['Sorties'];
      writeHeader(sheetSorties, const ['DATE', 'PRODUIT', 'RÉFÉRENCE', 'CATÉGORIE', 'MAGASIN', 'MODULAIRE', 'PRÉLEVÉ PAR', 'TAILLE', 'QUANTITÉ']);

      for (final m in sorties) {
        final date = TextCellValue(fmt.format(m.date));
        if (!m.aVariantes) {
          sheetSorties.appendRow([
            date, TextCellValue(m.nomProduit), TextCellValue(m.reference), TextCellValue(m.categorie),
            TextCellValue(m.magasin), TextCellValue(m.modulaireNom ?? '-'),
            TextCellValue(m.preneurNom ?? '-'), TextCellValue('-'), IntCellValue(m.quantite),
          ]);
        } else {
          for (final l in m.lignes) {
            sheetSorties.appendRow([
              date, TextCellValue(m.nomProduit), TextCellValue(m.reference), TextCellValue(m.categorie),
              TextCellValue(m.magasin), TextCellValue(m.modulaireNom ?? '-'),
              TextCellValue(m.preneurNom ?? '-'), TextCellValue(l.unite), IntCellValue(l.quantite),
            ]);
          }
        }
      }

      // ── Sauvegarde ────────────────────────────────────────────────────────
      final bytes = wb.encode();
      if (bytes == null) throw Exception('Échec de l\'encodage du fichier Excel');

      final siteId = ctx.read<SiteProvider>().selectedSiteId ?? SiteId.all;
      final siteLabel = SiteId.labelFr(siteId);
      final now = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'stock_magasin_${siteLabel}_$now.xlsx';

      if (Platform.isWindows) {
        // Windows : sauvegarde dans Desktop\Rapports Stock
        final dir = await _getRapportsDir();
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes);
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Fichier sauvegardé :\n${file.path}'),
            backgroundColor: kGreen,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        // Android/autre : sauvegarde dans temp puis partage
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (ctx.mounted) {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], subject: 'Export Stock Magasin'),
          );
        }
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Erreur lors de l\'export : $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final magasin = context.watch<MagasinProvider>();
    final auth    = context.watch<AuthProvider>();
    final site    = context.watch<SiteProvider>();
    final mobile = isMobile(context);

    final filteredProduits = SiteId.filterBySite(
      magasin.produits,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (p) => p.siteId,
    );
    final filteredEntrees = SiteId.filterBySite(
      magasin.entrees,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (m) => m.siteId,
    );
    final filteredSorties = SiteId.filterBySite(
      magasin.sorties,
      auth.currentUser?.allowedSiteIds,
      auth.currentUser?.isSuperAdmin == true ? site.selectedSiteId : null,
      (m) => m.siteId,
    );
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

    final rupt = filteredProduits.where((p) => p.rupture && p.categorie == 'EPI').length;
    final bas = filteredProduits.where((p) => p.bas && p.categorie == 'EPI').length;
    final totalE = filteredEntrees.fold(0, (s, m) => s + m.totalQte);
    final totalS = filteredSorties.fold(0, (s, m) => s + m.totalQte);
    final totalH = filteredEntrees.length + filteredSorties.length;

    final navBar = _TopNavBar(
      tab: _tab,
      onTap: (i) => setState(() {
        _tab = i;
        _tabCtrl.animateTo(i);
      }),
      onExport: () => _exportExcel(context, filteredProduits, filteredEntrees, filteredSorties),
      statChips: [
        if (_tab == 0) ...[
          if (rupt > 0) _AlertChipButton(
            label: '$rupt rupture${rupt > 1 ? "s" : ""} EPI',
            col: kRed,
            icon: Icons.remove_shopping_cart_rounded,
            onTap: () => _showStockAlert(
              context,
              filteredProduits.where((p) => p.rupture && p.categorie == 'EPI').toList(),
              'Ruptures de Stock — EPI', kRed, kRedLt,
              isRupture: true,
            ),
          ),
          if (bas > 0) _AlertChipButton(
            label: '$bas stock bas EPI',
            col: kOrange,
            icon: Icons.warning_amber_rounded,
            onTap: () => _showStockAlert(
              context,
              filteredProduits.where((p) => p.bas && p.categorie == 'EPI').toList(),
              'Stock Bas — EPI', kOrange, kOrangeLt,
              isRupture: false,
            ),
          ),
        ],
        if (_tab == 1) ...[
          _StatChip('${filteredEntrees.length} entrée${filteredEntrees.length != 1 ? "s" : ""}', kGreenLt, kGreen),
          _StatChip('$totalE unités', kBlueLt, kBlue),
        ],
        if (_tab == 2) ...[
          _StatChip('${filteredSorties.length} sortie${filteredSorties.length != 1 ? "s" : ""}', kOrangeLt, kOrange),
          _StatChip('$totalS unités', kBlueLt, kBlue),
        ],
        if (_tab == 3) _StatChip('$totalH opérations', kPurpleLt, kPurple),
        if (_tab == 4) _StatChip('${magasin.fournisseurs.length} fournisseur${magasin.fournisseurs.length != 1 ? "s" : ""}', kTealLt, kTeal),
      ],
    );

    if (mobile) {
      Widget activePage;
      if (_tab == 0) {
        activePage = _StockPage(magasin: magasin, produits: filteredProduits, internalScroll: false);
      } else if (_tab == 1) {
        activePage = _EntreesPage(magasin: magasin, entrees: filteredEntrees, internalScroll: false);
      } else if (_tab == 2) {
        activePage = _SortiesPage(magasin: magasin, sorties: filteredSorties, internalScroll: false);
      } else if (_tab == 3) {
        activePage = _HistoriquePage(magasin: magasin, mouvements: [...filteredEntrees, ...filteredSorties], internalScroll: false);
      } else {
        activePage = _FournisseursPage(magasin: magasin, internalScroll: false);
      }

      return ColoredBox(
        color: kBg,
        child: SingleChildScrollView(
          child: Column(
            children: [
              navBar,
              activePage,
            ],
          ),
        ),
      );
    }

    final screenH = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: screenH,
      child: ColoredBox(
        color: kBg,
        child: Column(
          children: [
            navBar,
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StockPage(magasin: magasin, produits: filteredProduits),
                  _EntreesPage(magasin: magasin, entrees: filteredEntrees),
                  _SortiesPage(magasin: magasin, sorties: filteredSorties),
                  _HistoriquePage(magasin: magasin, mouvements: [...filteredEntrees, ...filteredSorties]),
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
  final Future<void> Function()? onExport;
  const _TopNavBar({required this.tab, required this.onTap, required this.statChips, this.onExport});

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
                    if (onExport != null) ...[
                      const SizedBox(width: 6),
                      _ExportButton(onTap: onExport!),
                    ],
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
                if (onExport != null) ...[
                  const SizedBox(width: 12),
                  Container(width: 1.5, height: 24, color: kBorder),
                  const SizedBox(width: 12),
                  _ExportButton(onTap: onExport!),
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

class _ExportButton extends StatefulWidget {
  final Future<void> Function() onTap;
  const _ExportButton({required this.onTap});
  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Exporter Excel (Stock, Entrées, Sorties)',
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        try {
          await widget.onTap();
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: kGreen))
            else
              const Icon(Icons.download_rounded, size: 15, color: kGreen),
            const SizedBox(width: 6),
            const Text('Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreen)),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALERT CHIP BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AlertChipButton extends StatelessWidget {
  final String label;
  final Color col;
  final IconData icon;
  final VoidCallback onTap;
  const _AlertChipButton({required this.label, required this.col, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: col),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: col)),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  STOCK ALERT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

/// Retourne le dossier Desktop\Rapports Stock, le crée si nécessaire.
Future<Directory> _getRapportsDir() async {
  final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  final dir = Directory('$userProfile${Platform.pathSeparator}Desktop${Platform.pathSeparator}Rapports Stock');
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}

Future<void> _exportAlertPdf(List<Produit> produits, String titre, {required bool isRupture}) async {
  // ── Préparer les lignes ──────────────────────────────────────────────────
  final dataRows = <List<String>>[];
  for (final p in produits) {
    if (!p.aVariantes) {
      dataRows.add([p.nom, p.reference, p.categorie, p.magasin, p.modulaireNom ?? '-', '-', '${p.quantiteStock}']);
    } else {
      final filtrees = p.variantes.where((v) => isRupture ? v.quantite == 0 : (v.quantite > 0 && v.quantite <= 2));
      for (final v in filtrees) {
        dataRows.add([p.nom, p.reference, p.categorie, p.magasin, p.modulaireNom ?? '-', v.unite, '${v.quantite}']);
      }
    }
  }

  final accentColor = isRupture ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#D97706');

  final headerBg    = PdfColor.fromHex('#1D4ED8');
  final rowAlt      = PdfColor.fromHex('#F9FAFB');
  final borderColor = PdfColor.fromHex('#E5E7EB');
  final dateStr     = DateFormat('dd/MM/yyyy').format(DateTime.now()); // affichage dans le PDF
  final dateFile    = DateFormat('yyyy-MM-dd').format(DateTime.now()); // nom de fichier (sans /)

  const headers = ['PRODUIT', 'RÉFÉRENCE', 'CATÉGORIE', 'MAGASIN', 'MODULAIRE', 'TAILLE', 'QTÉ'];
  const colWidths = <int, pw.TableColumnWidth>{
    0: pw.FlexColumnWidth(3),
    1: pw.FlexColumnWidth(2),
    2: pw.FlexColumnWidth(2),
    3: pw.FlexColumnWidth(2),
    4: pw.FlexColumnWidth(2),
    5: pw.FlexColumnWidth(1.5),
    6: pw.FlexColumnWidth(1),
  };

  // Chargement du logo depuis les assets Flutter
  final logoBytes = await rootBundle.load('assets/images/logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final doc = pw.Document();

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // ── Logo gauche ───────────────────────────────────────────────
            pw.Image(logoImage, width: 48, height: 48, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 12),
            // ── Titre centre ──────────────────────────────────────────────
            pw.Expanded(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Rapport de Stock',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: headerBg),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    titre,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentColor),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            // ── Infos droite ──────────────────────────────────────────────
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Généré le $dateStr',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 3),
                pw.Text('${dataRows.length} ligne${dataRows.length != 1 ? "s" : ""}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: borderColor, thickness: 0.8),
        pw.SizedBox(height: 8),
      ],
    ),
    build: (_) => [
      pw.Table(
        columnWidths: colWidths,
        border: pw.TableBorder.all(color: borderColor, width: 0.5),
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          pw.TableRow(
            decoration: pw.BoxDecoration(color: headerBg),
            children: headers.map((h) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            )).toList(),
          ),
          // ── Données ────────────────────────────────────────────────────
          ...dataRows.asMap().entries.map((e) {
            final idx = e.key;
            final row = e.value;
            final qty = int.tryParse(row.last) ?? 0;
            final qtyColor = qty == 0 ? PdfColor.fromHex('#DC2626') : PdfColor.fromHex('#D97706');
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: idx.isEven ? PdfColors.white : rowAlt),
              children: row.asMap().entries.map((ce) {
                final isQty = ce.key == row.length - 1;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  child: pw.Text(
                    ce.value,
                    textAlign: isQty ? pw.TextAlign.right : pw.TextAlign.left,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: isQty ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: isQty ? qtyColor : PdfColors.grey800,
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    ],
  ));

  final bytes = await doc.save();
  final safeName = titre.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  final fileName = '${safeName}_$dateFile.pdf';

  if (Platform.isWindows) {
    final dir = await _getRapportsDir();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
  } else {
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
  }
}

class _StockAlertDialog extends StatefulWidget {
  final List<Produit> produits;
  final String titre;
  final Color color, colorLt;
  final bool isRupture;
  const _StockAlertDialog({required this.produits, required this.titre, required this.color, required this.colorLt, required this.isRupture});
  @override
  State<_StockAlertDialog> createState() => _StockAlertDialogState();
}

class _StockAlertDialogState extends State<_StockAlertDialog> {
  bool _exporting = false;

  // Explose les variantes en lignes plates — seules les tailles concernées
  List<({String nom, String reference, String categorie, String magasin, String modulaire, String taille, int quantite})> get _rows {
    final result = <({String nom, String reference, String categorie, String magasin, String modulaire, String taille, int quantite})>[];
    for (final p in widget.produits) {
      if (!p.aVariantes) {
        result.add((nom: p.nom, reference: p.reference, categorie: p.categorie, magasin: p.magasin, modulaire: p.modulaireNom ?? '-', taille: '-', quantite: p.quantiteStock));
      } else {
        final variantesFiltrees = p.variantes.where((v) => widget.isRupture ? v.quantite == 0 : (v.quantite > 0 && v.quantite <= 2));
        for (final v in variantesFiltrees) {
          result.add((nom: p.nom, reference: p.reference, categorie: p.categorie, magasin: p.magasin, modulaire: p.modulaireNom ?? '-', taille: v.unite, quantite: v.quantite));
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final rows = _rows;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 48, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── En-tête ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.colorLt,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: widget.color.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(
                      widget.color == kRed ? Icons.remove_shopping_cart_rounded : Icons.warning_amber_rounded,
                      color: widget.color, size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.titre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: widget.color)),
                      Text('${widget.produits.length} produit${widget.produits.length != 1 ? "s" : ""}', style: const TextStyle(fontSize: 12, color: kMuted)),
                    ]),
                  ),
                  // Bouton export
                  StatefulBuilder(builder: (ctx, setSt) => Tooltip(
                    message: 'Télécharger rapport Excel',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _exporting ? null : () async {
                        setState(() => _exporting = true);
                        try {
                          await _exportAlertPdf(widget.produits, widget.titre, isRupture: widget.isRupture);
                          if (mounted && Platform.isWindows) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Rapport sauvegardé dans Desktop\\Rapports Stock'),
                              backgroundColor: widget.color,
                              duration: const Duration(seconds: 5),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Erreur export : $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        } finally {
                          if (mounted) setState(() => _exporting = false);
                        }
                      },
                      child: Container(
                        height: 34, padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_exporting)
                            SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                          else
                            Icon(Icons.download_rounded, size: 15, color: widget.color),
                          const SizedBox(width: 6),
                          Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                        ]),
                      ),
                    ),
                  )),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
            ),
            // ── Tableau ──────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // En-tête tableau
                    Container(
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text('PRODUIT', style: _thStyle)),
                        if (!mobile) Expanded(flex: 2, child: Text('RÉFÉR.', style: _thStyle)),
                        if (!mobile) Expanded(flex: 2, child: Text('CATÉGORIE', style: _thStyle)),
                        Expanded(flex: 2, child: Text('MAGASIN', style: _thStyle)),
                        Expanded(flex: 2, child: Text('TAILLE', style: _thStyle)),
                        Expanded(flex: 1, child: Text('QTÉ', style: _thStyle, textAlign: TextAlign.right)),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    // Lignes
                    ...rows.asMap().entries.map((e) {
                      final i = e.key;
                      final r = e.value;
                      final isZero = r.quantite == 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(r.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText), overflow: TextOverflow.ellipsis)),
                          if (!mobile) Expanded(flex: 2, child: Text(r.reference, style: _tdStyle, overflow: TextOverflow.ellipsis)),
                          if (!mobile) Expanded(flex: 2, child: Text(r.categorie, style: _tdStyle, overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 2, child: Text(r.magasin, style: _tdStyle, overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 2, child: Text(r.taille, style: _tdStyle)),
                          Expanded(flex: 1, child: Text(
                            '${r.quantite}',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isZero ? kRed : kOrange),
                          )),
                        ]),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _thStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: .5);
  static const _tdStyle = TextStyle(fontSize: 12, color: kMuted);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 6 — PAGE STOCK
// ─────────────────────────────────────────────────────────────────────────────

class _StockPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Produit> produits;
  final bool internalScroll;
  const _StockPage({required this.magasin, required this.produits, this.internalScroll = true});
  @override
  State<_StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<_StockPage> {
  String _q = '', _cat = 'Toutes', _mag = 'Tous', _modulaire = 'Tous';
  bool _asc = false;
  final _sc = TextEditingController();

  List<Produit> get _list {
    final q = _q.toLowerCase();
    var l = widget.produits.where((p) {
      final mq = q.isEmpty || p.nom.toLowerCase().contains(q) || p.reference.toLowerCase().contains(q);
      final modOk = _modulaire == 'Tous' || p.modulaireNom == _modulaire;
      return mq && (_cat == 'Toutes' || p.categorie == _cat) && (_mag == 'Tous' || p.magasin == _mag) && modOk;
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
    final showModulaire = _mag == 'Base de vie';
    final modItems = ['Tous', ...widget.magasin.modulaires.map((m) => m.nom)];

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
              _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; })),
              if (showModulaire) ...[
                const SizedBox(height: 8),
                _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v)),
              ],
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
              Expanded(flex: 2, child: _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; }))),
              if (showModulaire) ...[
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v))),
              ],
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
        if (widget.internalScroll)
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
              onTap: () => _showDialog(ctx, _DetailsDialog(produit: list[i], groupe: groupeByLabel(list[i].groupeUniteLabel), magasin: widget.magasin)),
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
                _Col('MODULAIRE', flex: 2),
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
                  p.modulaireNom != null
                      ? _PillBadge('📦 ${p.modulaireNom!}', kBrownLt, kBrown)
                      : Text('—', style: _muted.copyWith(fontSize: 11)),
                  Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${p.total}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: stockColor)),
                  )),
                  Center(child: _IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () {
                    _showDialog(context, _DetailsDialog(produit: p, groupe: g, magasin: widget.magasin));
                  })),
                ]);
              }).toList(),
            ),
            ),
          )
        else
          (list.isEmpty
              ? _EmptyState(message: 'Aucun produit trouvé', color: kBlue)
              : mobile
              ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  itemCount: list.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _ProduitCard(
                    produit: list[i],
                    fournisseur: widget.magasin.fournisseurById(list[i].fournisseurId),
                    onTap: () => _showDialog(ctx, _DetailsDialog(produit: list[i], groupe: groupeByLabel(list[i].groupeUniteLabel), magasin: widget.magasin)),
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
                      _Col('MODULAIRE', flex: 2),
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
                        p.modulaireNom != null
                            ? _PillBadge('📦 ${p.modulaireNom!}', kBrownLt, kBrown)
                            : Text('—', style: _muted.copyWith(fontSize: 11)),
                        Center(child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: stockBg, borderRadius: BorderRadius.circular(20)),
                          child: Text('${p.total}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: stockColor)),
                        )),
                        Center(child: _IconBtn(Icons.visibility_outlined, 'Détails', kBlueLt, kBlue, () {
                          _showDialog(context, _DetailsDialog(produit: p, groupe: g, magasin: widget.magasin));
                        })),
                      ]);
                    }).toList(),
                  ),
                )),
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
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _PillBadge(p.categorie, kBlueLt, kBlue),
                  if (p.magasin.isNotEmpty) _PillBadge(p.magasin, kIndigoLt, kIndigo),
                  if (p.modulaireNom != null) _PillBadge('📦 ${p.modulaireNom!}', kBrownLt, kBrown),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Voir détails',
                        style: TextStyle(
                          fontSize: 11,
                          color: kBlue.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: kBlue.withOpacity(0.8),
                      ),
                    ],
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
//  SECTION 7 — PAGE ENTRÉES
// ─────────────────────────────────────────────────────────────────────────────

class _EntreesPage extends StatefulWidget {
  final MagasinProvider magasin;
  final List<Mouvement> entrees;
  final bool internalScroll;
  const _EntreesPage({required this.magasin, required this.entrees, this.internalScroll = true});
  @override
  State<_EntreesPage> createState() => _EntreesPageState();
}

class _EntreesPageState extends State<_EntreesPage> {
  String _cat = 'Toutes', _mag = 'Tous', _modulaire = 'Tous';
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Mouvement> get _list => widget.entrees.where((m) {
    final catOk = _cat == 'Toutes' || m.categorie == _cat;
    final magOk = _mag == 'Tous' || m.magasin == _mag;
    final modOk = _modulaire == 'Tous' || m.modulaireNom == _modulaire;
    final searchOk = _search.isEmpty || m.nomProduit.toLowerCase().contains(_search.toLowerCase());
    return catOk && magOk && modOk && searchOk;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final total = list.fold(0, (s, m) => s + m.totalQte);
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    final mags = ['Tous', ...kMagasins];
    final showModulaire = _mag == 'Base de vie';
    final modItems = ['Tous', ...widget.magasin.modulaires.map((m) => m.nom)];
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
        // ── Filtres Magasin + Modulaire ────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
          child: mobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; })),
            if (showModulaire) ...[
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v)),
            ],
          ])
              : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 2, child: _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; }))),
            if (showModulaire) ...[
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v))),
            ],
            if (!showModulaire) const Spacer(),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un article…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kGreen, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.internalScroll)
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
              modulaireNom: list[i].modulaireNom,
              onDetails: () => showDialog(context: ctx, builder: (_) => _MouvDetailDialog(m: list[i], color: kGreen, bgColor: kGreenLt)),
              onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
              onEdit: () => _showDialog(ctx, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kGreen,
              columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('FOURNISSEUR', flex: 2), _Col('MODULAIRE', flex: 2), _Col('QTÉ', flex: 1), _Col('', flex: 2)],
              rows: list.map((m) => _MouvRow(m: m, color: kGreen, bgColor: kGreenLt, showPreneur: false, showFournisseur: true, showModulaire: true,
                onDetails: () => showDialog(context: context, builder: (_) => _MouvDetailDialog(m: m, color: kGreen, bgColor: kGreenLt)),
                onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                onEdit: () => _showDialog(context, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
              )).toList(),
            ),
            ),
          )
        else
          (list.isEmpty
              ? _EmptyState(message: 'Aucune entrée — cliquez sur « Nouvelle entrée »', color: kGreen)
              : mobile
              ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  itemCount: list.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _MouvCard(
                    m: list[i], color: kGreen, bgColor: kGreenLt,
                    fournisseurNom: list[i].fournisseurNom,
                    modulaireNom: list[i].modulaireNom,
                    onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
                    onEdit: () => _showDialog(ctx, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  child: _DataTable(
                    empty: false, accentColor: kGreen,
                    columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('FOURNISSEUR', flex: 2), _Col('MODULAIRE', flex: 2), _Col('QTÉ', flex: 1), _Col('', flex: 1)],
                    rows: list.map((m) => _MouvRow(m: m, color: kGreen, bgColor: kGreenLt, showPreneur: false, showFournisseur: true, showModulaire: true,
                      onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: 'Supprimer cette entrée ? Le stock sera décrémenté.', onConfirm: () { widget.magasin.deleteEntree(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                      onEdit: () => _showDialog(context, _MouvForm(type: 'entree', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
                    )).toList(),
                  ),
                )),
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
  final bool internalScroll;
  const _SortiesPage({required this.magasin, required this.sorties, this.internalScroll = true});
  @override
  State<_SortiesPage> createState() => _SortiesPageState();
}

class _SortiesPageState extends State<_SortiesPage> {
  String _cat = 'Toutes', _mag = 'Tous', _modulaire = 'Tous';
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  String _msgRestitution(Mouvement m) {
    if (!m.aVariantes || m.lignes.isEmpty) {
      return 'La suppression restituera ${m.quantite} unité(s) au stock de ce produit.';
    }
    final detail = m.lignes.where((l) => l.quantite > 0).map((l) => '${l.quantite} × ${l.unite}').join(', ');
    return 'La suppression restituera ${m.totalQte} article(s) au stock ($detail).';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Mouvement> get _list => widget.sorties.where((m) {
    final catOk = _cat == 'Toutes' || m.categorie == _cat;
    final magOk = _mag == 'Tous' || m.magasin == _mag;
    final modOk = _modulaire == 'Tous' || m.modulaireNom == _modulaire;
    final searchOk = _search.isEmpty || m.nomProduit.toLowerCase().contains(_search.toLowerCase());
    return catOk && magOk && modOk && searchOk;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final total = list.fold(0, (s, m) => s + m.totalQte);
    final cats = ['Toutes', ...widget.magasin.categoryNames];
    final mags = ['Tous', ...kMagasins];
    final showModulaire = _mag == 'Base de vie';
    final modItems = ['Tous', ...widget.magasin.modulaires.map((m) => m.nom)];
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
        // ── Filtres Magasin + Modulaire ────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
          child: mobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; })),
            if (showModulaire) ...[
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v)),
            ],
          ])
              : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(flex: 2, child: _LabeledDrop(label: 'Magasin', value: _mag, items: mags, onChanged: (v) => setState(() { _mag = v; if (v != 'Base de vie') _modulaire = 'Tous'; }))),
            if (showModulaire) ...[
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaire) ? _modulaire : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaire = v))),
            ],
            if (!showModulaire) const Spacer(),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un article…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange, width: 1.5)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(padding, 6, padding, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.person_search_rounded, size: 16),
              label: const Text('Récap par personne', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kOrange, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              onPressed: () => showDialog(context: context, builder: (_) => _RecapPreneurDialog(sorties: widget.sorties)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.internalScroll)
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
              modulaireNom: list[i].modulaireNom,
              onDetails: () => showDialog(context: ctx, builder: (_) => _MouvDetailDialog(m: list[i], color: kOrange, bgColor: kOrangeLt)),
              onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: _msgRestitution(list[i]), onConfirm: () { widget.magasin.deleteSortie(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
              onEdit: () => _showDialog(ctx, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
            ),
          )
              : Padding(
            padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
            child: _DataTable(
              empty: false, accentColor: kOrange,
              columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('MODULAIRE', flex: 2), _Col('QTÉ', flex: 1), _Col('PRÉLEVÉ PAR', flex: 2), _Col('', flex: 2)],
              rows: list.map((m) => _MouvRow(m: m, color: kOrange, bgColor: kOrangeLt, showPreneur: true, showFournisseur: false, showModulaire: true,
                onDetails: () => showDialog(context: context, builder: (_) => _MouvDetailDialog(m: m, color: kOrange, bgColor: kOrangeLt)),
                onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: _msgRestitution(m), onConfirm: () { widget.magasin.deleteSortie(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                onEdit: () => _showDialog(context, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
              )).toList(),
            ),
            ),
          )
        else
          (list.isEmpty
              ? _EmptyState(message: 'Aucune sortie — cliquez sur « Nouvelle sortie »', color: kOrange)
              : mobile
              ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  itemCount: list.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _MouvCard(
                    m: list[i], color: kOrange, bgColor: kOrangeLt, showPreneur: true,
                    modulaireNom: list[i].modulaireNom,
                    onDelete: () => _showDialog(ctx, _ConfirmDel(nom: list[i].nomProduit, msg: _msgRestitution(list[i]), onConfirm: () { widget.magasin.deleteSortie(list[i].id); Navigator.of(ctx, rootNavigator: true).pop(); })),
                    onEdit: () => _showDialog(ctx, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: list[i])),
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  child: _DataTable(
                    empty: false, accentColor: kOrange,
                    columns: const [_Col('DATE', flex: 2), _Col('PRODUIT', flex: 3), _Col('RÉFÉR.', flex: 2), _Col('CATÉGORIE', flex: 2), _Col('MODULAIRE', flex: 2), _Col('QTÉ', flex: 1), _Col('PRÉLEVÉ PAR', flex: 2), _Col('', flex: 1)],
                    rows: list.map((m) => _MouvRow(m: m, color: kOrange, bgColor: kOrangeLt, showPreneur: true, showFournisseur: false, showModulaire: true,
                      onDelete: () => _showDialog(context, _ConfirmDel(nom: m.nomProduit, msg: _msgRestitution(m), onConfirm: () { widget.magasin.deleteSortie(m.id); Navigator.of(context, rootNavigator: true).pop(); })),
                      onEdit: () => _showDialog(context, _MouvForm(type: 'sortie', magasin: widget.magasin, scaffoldContext: context, mouvement: m)),
                    )).toList(),
                  ),
                )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RÉCAP PAR PERSONNE
// ─────────────────────────────────────────────────────────────────────────────

class _RecapPreneurDialog extends StatefulWidget {
  final List<Mouvement> sorties;
  const _RecapPreneurDialog({required this.sorties});
  @override
  State<_RecapPreneurDialog> createState() => _RecapPreneurDialogState();
}

class _RecapPreneurDialogState extends State<_RecapPreneurDialog> {
  String _search = '';
  String? _selected;
  final TextEditingController _ctrl = TextEditingController();

  List<String> get _allNoms {
    final noms = widget.sorties
        .where((m) => m.preneurNom != null && m.preneurNom!.isNotEmpty)
        .map((m) => m.preneurNom!)
        .toSet()
        .toList()
      ..sort();
    return noms;
  }

  List<String> get _filteredNoms {
    if (_search.isEmpty) return _allNoms;
    return _allNoms.where((n) => n.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  List<Mouvement> get _selectedSorties => widget.sorties
      .where((m) => m.preneurNom == _selected)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final selectedSorties = _selectedSorties;
    final totalQte = selectedSorties.fold(0, (s, m) => s + m.totalQte);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF92400E), Color(0xFFD97706)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Récap par personne', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => Navigator.of(context).pop(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _ctrl,
                      onChanged: (v) => setState(() { _search = v; _selected = null; }),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un préleveur…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _ctrl.clear(); setState(() { _search = ''; _selected = null; }); })
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_selected == null) ...[
                      if (_filteredNoms.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('Aucun préleveur trouvé', style: TextStyle(color: kMuted)))
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _filteredNoms.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final nom = _filteredNoms[i];
                              final count = widget.sorties.where((m) => m.preneurNom == nom).length;
                              return ListTile(
                                dense: true,
                                leading: const CircleAvatar(backgroundColor: kOrangeLt, child: Icon(Icons.person_outline_rounded, color: kOrange, size: 18)),
                                title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                trailing: Chip(
                                  label: Text('$count sortie${count != 1 ? "s" : ""}', style: const TextStyle(fontSize: 11)),
                                  backgroundColor: kOrangeLt,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                onTap: () => setState(() => _selected = nom),
                              );
                            },
                          ),
                        ),
                    ] else ...[
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            onPressed: () => setState(() => _selected = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_selected!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              '$totalQte unité${totalQte != 1 ? "s" : ""} · ${selectedSorties.length} sortie${selectedSorties.length != 1 ? "s" : ""}',
                              style: const TextStyle(color: kOrange, fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: selectedSorties.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final m = selectedSorties[i];
                            return ListTile(
                              dense: true,
                              leading: Text(fmt.format(m.date), style: const TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w500)),
                              title: Text(m.nomProduit, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text(m.categorie, style: const TextStyle(fontSize: 11, color: kMuted)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: kOrangeLt, borderRadius: BorderRadius.circular(12)),
                                child: Text('${m.totalQte} unité${m.totalQte != 1 ? "s" : ""}', style: const TextStyle(color: kOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  final String? modulaireNom;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDetails;
  const _MouvCard({required this.m, required this.color, required this.bgColor, this.showPreneur = false, this.fournisseurNom, this.modulaireNom, required this.onDelete, this.onEdit, this.onDetails});

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
          if (modulaireNom != null) _PillBadge('📦 $modulaireNom', kBrownLt, kBrown),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 11, color: kMuted),
          const SizedBox(width: 4),
          Flexible(child: Text('$_d à $_t', style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis)),
          if (showPreneur && m.preneurNom != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.person_outline_rounded, size: 12, color: kMuted),
            const SizedBox(width: 3),
            Expanded(child: Text(m.preneurNom!, style: _muted.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1)),
          ] else const Spacer(),
          const SizedBox(width: 6),
          if (onDetails != null) ...[_IconBtn(Icons.visibility_rounded, 'Voir détails', kBlueLt, kBlue, onDetails!), const SizedBox(width: 6)],
          if (onEdit != null) ...[_IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, onEdit!), const SizedBox(width: 6)],
          _IconBtn(Icons.delete_outline_rounded, 'Supprimer', kRedLt, kRed, onDelete),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DETAIL DIALOG MOUVEMENT
// ─────────────────────────────────────────────────────────────────────────────

class _MouvDetailDialog extends StatelessWidget {
  final Mouvement m;
  final Color color, bgColor;
  const _MouvDetailDialog({required this.m, required this.color, required this.bgColor});

  String get _date => '${m.date.day.toString().padLeft(2, '0')}/${m.date.month.toString().padLeft(2, '0')}/${m.date.year}  ${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isEntree = m.type == 'entree';
    final totalQte = m.aVariantes ? m.lignes.fold(0, (s, l) => s + l.quantite) : m.quantite;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── En-tête ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.visibility_rounded, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  m.nomProduit,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  overflow: TextOverflow.ellipsis,
                )),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  style: IconButton.styleFrom(foregroundColor: kMuted),
                ),
              ]),
            ),
            // ── Corps ─────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Métadonnées
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _InfoChip(Icons.calendar_today_rounded, _date),
                      _InfoChip(Icons.qr_code_rounded, m.reference),
                      _PillBadge(m.categorie, kBlueLt, kBlue),
                      _PillBadge(m.magasin, kBlueMd, kBlueDk),
                      if (m.modulaireNom != null) _PillBadge(m.modulaireNom!, kBrownLt, kBrown),
                      if (isEntree && m.fournisseurNom != null) _PillBadge(m.fournisseurNom!, kTealLt, kTeal),
                      if (!isEntree && m.preneurNom != null) _InfoChip(Icons.person_outline_rounded, m.preneurNom!),
                    ]),
                    if (isEntree && m.prixUnitaire != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.attach_money_rounded, size: 13, color: kMuted),
                        const SizedBox(width: 4),
                        Text('Prix unitaire : ${m.prixUnitaire!.toStringAsFixed(2)} MAD',
                            style: const TextStyle(fontSize: 12, color: kMuted)),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    // ── Tailles ──────────────────────────────────────────
                    if (m.aVariantes && m.lignes.isNotEmpty) ...[
                      Text(
                        (m.groupeUniteLabel?.isNotEmpty == true ? m.groupeUniteLabel! : 'Détail par taille').toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: .5),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorder),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            // header
                            Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.07),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(children: [
                                Expanded(child: Text('TAILLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
                                Text('QTÉ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                              ]),
                            ),
                            const Divider(height: 1, color: kBorder),
                            // lignes
                            ...m.lignes.asMap().entries.map((e) {
                              final i = e.key;
                              final l = e.value;
                              return Column(mainAxisSize: MainAxisSize.min, children: [
                                if (i > 0) const Divider(height: 1, color: kBorder),
                                Container(
                                  color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  child: Row(children: [
                                    Expanded(child: Text(l.unite, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                                      child: Text('${l.quantite}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                                    ),
                                  ]),
                                ),
                              ]);
                            }),
                            // total
                            const Divider(height: 1, color: kBorder),
                            Container(
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.05),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              child: Row(children: [
                                Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                                  child: Text('$totalQte', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Produit sans variantes
                      Row(children: [
                        Text('Quantité :', style: const TextStyle(fontSize: 12, color: kMuted)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                          child: Text('$totalQte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 11, color: kMuted),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11, color: kMuted)),
  ]);
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
  final List<Mouvement> mouvements;
  final bool internalScroll;
  const _HistoriquePage({required this.magasin, required this.mouvements, this.internalScroll = true});
  @override
  State<_HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<_HistoriquePage> {
  String _typeFiltre = 'Tout';
  String _magasinFiltre = 'Tous';

  String _msgSuppression(Mouvement m) {
    if (m.type == 'entree') return 'Supprimer cette entrée du journal ?';
    if (!m.aVariantes || m.lignes.isEmpty) {
      return 'La suppression restituera ${m.quantite} unité(s) au stock de ce produit.';
    }
    final detail = m.lignes.where((l) => l.quantite > 0).map((l) => '${l.quantite} × ${l.unite}').join(', ');
    return 'La suppression restituera ${m.totalQte} article(s) au stock ($detail).';
  }
  String _fournisseurFiltre = 'Tous';
  String _modulaireFiltre = 'Tous';
  DateTime? _dateDebut, _dateFin;

  List<Mouvement> get _list {
    final all = List<Mouvement>.from(widget.mouvements);
    all.sort((a, b) => b.date.compareTo(a.date));
    return all.where((m) {
      final typeOk = _typeFiltre == 'Tout' || (_typeFiltre == 'Entrées' && m.type == 'entree') || (_typeFiltre == 'Sorties' && m.type == 'sortie');
      final debutOk = _dateDebut == null || !m.date.isBefore(DateTime(_dateDebut!.year, _dateDebut!.month, _dateDebut!.day));
      final finOk = _dateFin == null || !m.date.isAfter(DateTime(_dateFin!.year, _dateFin!.month, _dateFin!.day, 23, 59, 59));
      final magOk = _magasinFiltre == 'Tous' || m.magasin == _magasinFiltre;
      final fouOk = _fournisseurFiltre == 'Tous' || m.fournisseurNom == _fournisseurFiltre;
      final modOk = _modulaireFiltre == 'Tous' || m.modulaireNom == _modulaireFiltre;
      return typeOk && debutOk && finOk && magOk && fouOk && modOk;
    }).toList();
  }

  bool get _hasActiveFilter => _typeFiltre != 'Tout' || _magasinFiltre != 'Tous' || _fournisseurFiltre != 'Tous' || _modulaireFiltre != 'Tous' || _dateDebut != null || _dateFin != null;

  void _resetFilters() => setState(() {
    _typeFiltre = 'Tout'; _magasinFiltre = 'Tous'; _fournisseurFiltre = 'Tous';
    _modulaireFiltre = 'Tous'; _dateDebut = null; _dateFin = null;
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
    final showModulaire = _magasinFiltre == 'Base de vie';
    final modItems = ['Tous', ...widget.magasin.modulaires.map((m) => m.nom)];

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
            _LabeledDrop(label: 'Magasin', value: _magasinFiltre, items: mags, onChanged: (v) => setState(() { _magasinFiltre = v; if (v != 'Base de vie') _modulaireFiltre = 'Tous'; })),
            if (showModulaire) ...[
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaireFiltre) ? _modulaireFiltre : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaireFiltre = v)),
            ],
            if (fournisseurs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LabeledDrop(label: 'Fournisseur', value: _fournisseurFiltre, items: fouNoms, onChanged: (v) => setState(() => _fournisseurFiltre = v)),
            ],
            const SizedBox(height: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Période', style: _label),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 170,
                  child: _DateBox(label: 'De', date: _dateDebut, onTap: () => _pickDate(context, true)),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: kMuted),
                SizedBox(
                  width: 170,
                  child: _DateBox(label: 'À', date: _dateFin, onTap: () => _pickDate(context, false)),
                ),
                if (_dateDebut != null || _dateFin != null) ...[
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
            const SizedBox(width: 8),
            Expanded(child: _LabeledDrop(label: 'Magasin', value: _magasinFiltre, items: mags, onChanged: (v) => setState(() { _magasinFiltre = v; if (v != 'Base de vie') _modulaireFiltre = 'Tous'; }))),
            if (showModulaire) ...[
              const SizedBox(width: 8),
              Expanded(child: _LabeledDrop(label: 'Modulaire', value: modItems.contains(_modulaireFiltre) ? _modulaireFiltre : 'Tous', items: modItems, onChanged: (v) => setState(() => _modulaireFiltre = v))),
            ],
            if (fournisseurs.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(child: _LabeledDrop(label: 'Fournisseur', value: _fournisseurFiltre, items: fouNoms, onChanged: (v) => setState(() => _fournisseurFiltre = v))),
            ],
            const SizedBox(width: 8),
            Expanded(child: _DateBox(label: 'De', date: _dateDebut, onTap: () => _pickDate(context, true))),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: kMuted),
            const SizedBox(width: 4),
            Expanded(child: _DateBox(label: 'À', date: _dateFin, onTap: () => _pickDate(context, false))),
            if (_dateDebut != null || _dateFin != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => setState(() { _dateDebut = null; _dateFin = null; }),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(7), border: Border.all(color: kRed.withOpacity(0.2))),
                  child: const Icon(Icons.close_rounded, color: kRed, size: 13),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 10),

        // ── Liste / Table ─────────────────────────────────────────────────
        if (widget.internalScroll)
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
                modulaireNom: m.modulaireNom,
                onDelete: () => _showDialog(ctx, _ConfirmDel(nom: m.nomProduit, msg: _msgSuppression(m), onConfirm: () { isE ? widget.magasin.deleteEntree(m.id) : widget.magasin.deleteSortie(m.id); Navigator.of(ctx, rootNavigator: true).pop(); })),
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
                _Col('QTÉ', flex: 1), _Col('FOURNISSEUR', flex: 2), _Col('MODULAIRE', flex: 2), _Col('', flex: 1),
              ],
              rows: list.map((m) {
                final isE = m.type == 'entree';
                final color = isE ? kGreen : kOrange;
                final bg = isE ? kGreenLt : kOrangeLt;
                return _DataTableRow(cells: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.3))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isE ? Icons.south_rounded : Icons.north_rounded, size: 10, color: color),
                        const SizedBox(width: 3),
                        Text(isE ? 'Entrée' : 'Sortie', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                      ]),
                    ),
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
                  m.modulaireNom != null
                      ? _PillBadge('📦 ${m.modulaireNom!}', kBrownLt, kBrown)
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
          )
        else
          (list.isEmpty
              ? _EmptyState(message: 'Aucune opération pour ces filtres', color: kPurple)
              : mobile
              ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  itemCount: list.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    final isE = m.type == 'entree';
                    return _MouvCard(
                      m: m, color: isE ? kGreen : kOrange, bgColor: isE ? kGreenLt : kOrangeLt,
                      showPreneur: false,
                      fournisseurNom: isE ? m.fournisseurNom : null,
                      modulaireNom: m.modulaireNom,
                      onDelete: () => _showDialog(ctx, _ConfirmDel(nom: m.nomProduit, msg: _msgSuppression(m), onConfirm: () { isE ? widget.magasin.deleteEntree(m.id) : widget.magasin.deleteSortie(m.id); Navigator.of(ctx, rootNavigator: true).pop(); })),
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
                      _Col('QTÉ', flex: 1), _Col('FOURNISSEUR', flex: 2), _Col('MODULAIRE', flex: 2), _Col('', flex: 1),
                    ],
                    rows: list.map((m) {
                      final isE = m.type == 'entree';
                      final color = isE ? kGreen : kOrange;
                      final bg = isE ? kGreenLt : kOrangeLt;
                      return _DataTableRow(cells: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.3))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(isE ? Icons.south_rounded : Icons.north_rounded, size: 10, color: color),
                              const SizedBox(width: 3),
                              Text(isE ? 'Entrée' : 'Sortie', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                            ]),
                          ),
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
                        m.modulaireNom != null
                            ? _PillBadge('📦 ${m.modulaireNom!}', kBrownLt, kBrown)
                            : Text('—', style: _muted.copyWith(fontSize: 11)),
                        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _IconBtn(Icons.edit_rounded, 'Modifier', kBlueLt, kBlue, () => _showDialog(context, _MouvForm(type: m.type, magasin: widget.magasin, scaffoldContext: context, mouvement: m))),
                          const SizedBox(width: 6),
                          _IconBtn(Icons.visibility_outlined, 'Détails', kPurpleLt, kPurple, () => _showDialog(context, _DetailsOperationDialog(m: m))),
                        ])),
                      ]);
                    }).toList(),
                  ),
                )),
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
  final bool internalScroll;
  const _FournisseursPage({required this.magasin, this.internalScroll = true});
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
        if (widget.internalScroll)
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
          )
        else
          (list.isEmpty
              ? _EmptyState(message: 'Aucun fournisseur — cliquez sur « Nouveau fournisseur »', color: kTeal)
              : mobile
              ? ListView.separated(
                  padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
                  itemCount: list.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                )),
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

class _EpiItem {
  final Produit produit;
  bool checked = false;
  final Set<String> selVar = {};
  final Map<String, TextEditingController> varCtrl = {};
  final TextEditingController qteCtrl = TextEditingController(text: '1');
  String? stockError;
  Map<String, String> varStockErrors = {};

  _EpiItem(this.produit);

  void dispose() {
    qteCtrl.dispose();
    for (final c in varCtrl.values) c.dispose();
  }

  void validateStock() {
    if (!checked) { stockError = null; varStockErrors = {}; return; }
    if (!produit.aVariantes) {
      final d = int.tryParse(qteCtrl.text) ?? 0;
      stockError = d > produit.total ? 'Max ${produit.total}' : null;
      varStockErrors = {};
    } else {
      stockError = null;
      final errors = <String, String>{};
      for (final u in selVar) {
        final d = int.tryParse(varCtrl[u]?.text ?? '0') ?? 0;
        final vm = produit.variantes.where((v) => v.unite == u);
        final dispo = vm.isEmpty ? 0 : vm.first.quantite;
        if (d > dispo) errors[u] = 'Max $dispo';
      }
      varStockErrors = errors;
    }
  }

  bool get hasStockError => stockError != null || varStockErrors.isNotEmpty;

  bool get isValid {
    if (!checked) return true;
    if (produit.aVariantes) return selVar.isNotEmpty && varStockErrors.isEmpty;
    return (int.tryParse(qteCtrl.text) ?? 0) > 0 && stockError == null;
  }
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
  String _siteId = SiteId.jadida;
  String? _selFournisseurId;      // NOUVEAU
  String? _selModulaireId;        // MODULAIRE (Base de vie)
  bool _newModulaireMode = false;
  final _newModulaireCtrl = TextEditingController();

  // EPI multi-select
  final List<_EpiItem> _epiItems = [];
  final _epiSearchCtrl = TextEditingController();

  late DateTime _mvtDate;
  final _dateCtrl = TextEditingController(); // NOUVEAU : date manuelle
  final _puCtrl = TextEditingController();   // P.U en MAD (optionnel)

  bool get _isEditing => widget.mouvement != null;
  bool get _isSortie => widget.type == 'sortie';
  Color get _col => _isSortie ? kOrange : kGreen;

  final _mvtNomCtrl = TextEditingController();
  final _mvtRefCtrl = TextEditingController();

  GroupeUnites? get _groupe => _newProdMode ? groupeByLabel(_newGroupeLabel) : groupeByLabel(_selProd?.groupeUniteLabel);
  bool get _hasVar => _newProdMode ? _newHasVar : (_selProd?.aVariantes ?? false);

  bool get _isEpiMode => _isSortie && !_isEditing && _selCat == 'EPI';

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
      _siteId = m.siteId == 'default' ? SiteId.jadida : m.siteId;
      _selCat = m.categorie;
      _mvtNomCtrl.text = m.nomProduit;
      _mvtRefCtrl.text = m.reference;
      _selFournisseurId = m.fournisseurId;
      _selMag = m.magasin.isNotEmpty ? m.magasin : 'Base de vie';
      _selModulaireId = m.modulaireId;
      if (m.prixUnitaire != null) _puCtrl.text = m.prixUnitaire!.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

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
    _prodSearchC.dispose(); _preneurC.dispose(); _dateCtrl.dispose(); _puCtrl.dispose();
    _newModulaireCtrl.dispose(); _epiSearchCtrl.dispose();
    for (final c in _varCtrl.values) c.dispose();
    for (final item in _epiItems) item.dispose();
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
    if (_isEpiMode) {
      final checked = _epiItems.where((e) => e.checked).toList();
      return checked.isNotEmpty && checked.every((e) => e.isValid);
    }
    final catOk = _newCatMode ? _newCatCtrl.text.trim().isNotEmpty : _selCat != null;
    final prodOk = _newProdMode ? (_newNomCtrl.text.trim().isNotEmpty && _newRefCtrl.text.trim().isNotEmpty) : _selProd != null;
    final qteOk = _hasVar ? _selVar.isNotEmpty : (int.tryParse(_qteC.text) ?? 0) > 0;
    // Pour une entrée, le fournisseur est obligatoire
    final fouOk = _isSortie || _selFournisseurId != null;
    return catOk && prodOk && qteOk && fouOk && !_hasStockError;
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

      // ── Mode EPI : plusieurs articles en une fois ──────────────────
      if (_isEpiMode) {
        final auth = scaffoldCtx != null ? Provider.of<AuthProvider>(scaffoldCtx, listen: false) : null;
        final checkedItems = _epiItems.where((e) => e.checked && e.isValid).toList();
        if (checkedItems.isEmpty) throw Exception('Aucun article EPI sélectionné');
        for (final item in checkedItems) {
          final prod = item.produit;
          final lignes = prod.aVariantes
              ? item.selVar.map((u) => LigneMouvement(unite: u, quantite: int.tryParse(item.varCtrl[u]?.text ?? '0') ?? 0)).where((l) => l.quantite > 0).toList()
              : <LigneMouvement>[];
          final qte = prod.aVariantes ? 0 : (int.tryParse(item.qteCtrl.text) ?? 0);
          final mvt = Mouvement(
            id: '', type: 'sortie', produitId: prod.id, nomProduit: prod.nom,
            reference: prod.reference, categorie: catFinal, magasin: magasinFinal,
            aVariantes: prod.aVariantes, groupeUniteLabel: prod.aVariantes ? prod.groupeUniteLabel : null,
            quantite: qte, lignes: lignes, date: _mvtDate,
            preneurNom: _preneurC.text.trim().isNotEmpty ? _preneurC.text.trim() : null,
            siteId: _siteId, fournisseurId: null, fournisseurNom: null,
            modulaireId: null, modulaireNom: null, prixUnitaire: null,
          );
          await widget.magasin.addSortie(mvt, actorUserId: auth?.currentUser?.id, actorUserName: auth?.currentUser?.nom);
        }
        if (Navigator.of(dialogCtx, rootNavigator: true).canPop()) Navigator.of(dialogCtx, rootNavigator: true).pop();
        if (scaffoldCtx != null && scaffoldCtx.mounted) {
          ScaffoldMessenger.of(scaffoldCtx).showSnackBar(SnackBar(
            content: Text('${checkedItems.length} sortie(s) EPI enregistrée(s)'),
            backgroundColor: kOrange, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2),
          ));
        }
        return;
      }

      // Résolution fournisseur (N.A = pas de fournisseur)
      final fouId = (_isSortie || _selFournisseurId == '__NA__') ? null : _selFournisseurId;
      final fouNom = fouId != null ? widget.magasin.fournisseurById(fouId)?.nom : null;

      // Résolution modulaire (Base de vie uniquement)
      String? modulaireId;
      String? modulaireNom;
      if (!_isSortie && magasinFinal == 'Base de vie') {
        if (_newModulaireMode && _newModulaireCtrl.text.trim().isNotEmpty) {
          modulaireId = await widget.magasin.addModulaire(_newModulaireCtrl.text.trim());
          modulaireNom = _newModulaireCtrl.text.trim();
        } else if (_selModulaireId != null) {
          modulaireId = _selModulaireId;
          modulaireNom = widget.magasin.modulaireById(_selModulaireId)?.nom;
        }
      }

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
          siteId: _siteId,
          fournisseurId: fouId,
          modulaireId: modulaireId,
          modulaireNom: modulaireNom,
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
        // Met à jour le fournisseurId, magasin et modulaire du produit si entrée
        if (!_isSortie) {
          final needUpdate = (fouId != null && prod.fournisseurId != fouId)
              || prod.magasin != magasinFinal
              || prod.modulaireId != modulaireId;
          if (needUpdate) {
            prod = prod.copyWith(
              fournisseurId: fouId ?? prod.fournisseurId,
              magasin: magasinFinal,
              modulaireId: modulaireId,
              modulaireNom: modulaireNom,
            );
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
        siteId: _siteId,
        fournisseurId: fouId,
        fournisseurNom: fouNom,
        modulaireId: modulaireId,
        modulaireNom: modulaireNom,
        prixUnitaire: !_isSortie && _puCtrl.text.trim().isNotEmpty ? double.tryParse(_puCtrl.text.trim().replaceAll(',', '.')) : null,
      );

      if (_isEditing) {
        _isSortie ? await widget.magasin.updateSortie(widget.mouvement!.id, mouvement) : await widget.magasin.updateEntree(widget.mouvement!.id, mouvement);
      } else if (_isSortie) {
        final auth = scaffoldCtx != null ? Provider.of<AuthProvider>(scaffoldCtx, listen: false) : null;
        await widget.magasin.addSortie(
          mouvement,
          actorUserId: auth?.currentUser?.id,
          actorUserName: auth?.currentUser?.nom,
        );
      } else {
        await widget.magasin.addEntree(mouvement);
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
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Collaborateurs'), content: const Text('Firebase غير متاح حالياً.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))]));
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
                SizedBox(height: 320, child: activeEmployes.isEmpty ? const Center(child: Text('Aucun collaborateur en service')) : !hasAnyFilter ? const Center(child: Text('Choisissez un nom ou un poste')) : filtered.isEmpty ? const Center(child: Text('Aucun résultat'))
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
          _StyledDrop<String>(
            value: _selFournisseurId,
            hint: 'Sélectionner un fournisseur',
            items: [
              const DropdownMenuItem(
                value: '__NA__',
                child: Row(children: [
                  Icon(Icons.remove_circle_outline_rounded, size: 14, color: kMuted),
                  SizedBox(width: 8),
                  Text('N.A', style: TextStyle(color: kMuted, fontStyle: FontStyle.italic)),
                ]),
              ),
              ...fournisseurs.map((f) => DropdownMenuItem(
                value: f.id,
                child: Row(children: [
                  const Icon(Icons.business_outlined, size: 14, color: kTeal),
                  const SizedBox(width: 8),
                  Flexible(child: Text(f.nom, overflow: TextOverflow.ellipsis)),
                ]),
              )),
            ],
            onChanged: (v) => setState(() => _selFournisseurId = v),
          ),
          const SizedBox(height: 20),

          // ── 3. Site ──────────────────────────────────────────────────
          _SectionHdr('3. Site *', Icons.location_on_rounded, kBlue),
          const SizedBox(height: 10),
          _StyledDrop<String>(
            value: _siteId,
            items: [
              DropdownMenuItem(
                value: SiteId.jadida,
                child: Row(children: [
                  const Icon(Icons.location_city_outlined, size: 14, color: kBlue),
                  const SizedBox(width: 8),
                  Text(SiteId.labelFr(SiteId.jadida)),
                ]),
              ),
              DropdownMenuItem(
                value: SiteId.safi,
                child: Row(children: [
                  const Icon(Icons.location_city_outlined, size: 14, color: kBlue),
                  const SizedBox(width: 8),
                  Text(SiteId.labelFr(SiteId.safi)),
                ]),
              ),
            ],
            onChanged: (v) => setState(() => _siteId = v ?? SiteId.jadida),
          ),
          const SizedBox(height: 20),

          // ── 4. Magasin de stock ──────────────────────────────────────
          _SectionHdr('4. Magasin de stock *', Icons.warehouse_rounded, _col),
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
            onChanged: (v) => setState(() {
              _selMag = v;
              // Reset modulaire si on change de magasin
              if (v != 'Base de vie') { _selModulaireId = null; _newModulaireMode = false; _newModulaireCtrl.clear(); }
            }),
          ),
          const SizedBox(height: 20),

          // ── 5. Modulaire (Base de vie uniquement, optionnel) ─────────
          if (_selMag == 'Base de vie') ...[
            _SectionHdr('5. Modulaire', Icons.home_work_rounded, kBrown),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kBrownLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBrown.withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 12, color: kBrown.withOpacity(0.7)),
                const SizedBox(width: 6),
                Flexible(child: Text('Optionnel — associer à un modulaire de la base de vie.', style: TextStyle(fontSize: 10, color: kBrown.withOpacity(0.8)))),
              ]),
            ),
            const SizedBox(height: 8),
            if (_newModulaireMode)
              _StyledTF(
                ctrl: _newModulaireCtrl,
                hint: 'Nom du nouveau modulaire…',
                prefix: const Icon(Icons.home_work_outlined, size: 18, color: kMuted),
                onChanged: (_) => setState(() {}),
              )
            else
              _StyledDrop<String>(
                value: _selModulaireId,
                hint: widget.magasin.modulaires.isEmpty ? 'Aucun modulaire (créez-en un)' : 'Sélectionner un modulaire',
                items: widget.magasin.modulaires.map((m) => DropdownMenuItem(
                  value: m.id,
                  child: Row(children: [
                    const Icon(Icons.home_work_outlined, size: 14, color: kBrown),
                    const SizedBox(width: 8),
                    Flexible(child: Text(m.nom, overflow: TextOverflow.ellipsis)),
                  ]),
                )).toList(),
                onChanged: (v) => setState(() => _selModulaireId = v),
              ),
            const SizedBox(height: 8),
            if (mobile)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_selModulaireId != null && !_newModulaireMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selModulaireId = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withOpacity(0.2))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close_rounded, size: 13, color: kRed), SizedBox(width: 4), Text('Retirer le modulaire', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kRed))]),
                      ),
                    ),
                  ),
                _ModeBtn(label: _newModulaireMode ? '← Existant' : '+ Nouveau modulaire', color: kBrown, onTap: () => setState(() { _newModulaireMode = !_newModulaireMode; _selModulaireId = null; _newModulaireCtrl.clear(); })),
              ])
            else
              Row(children: [
                if (_selModulaireId != null && !_newModulaireMode) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _selModulaireId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(color: kRedLt, borderRadius: BorderRadius.circular(8), border: Border.all(color: kRed.withOpacity(0.2))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close_rounded, size: 13, color: kRed), SizedBox(width: 4), Text('Retirer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kRed))]),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _ModeBtn(label: _newModulaireMode ? '← Existant' : '+ Nouveau', color: kBrown, onTap: () => setState(() { _newModulaireMode = !_newModulaireMode; _selModulaireId = null; _newModulaireCtrl.clear(); })),
              ]),
            const SizedBox(height: 20),
          ],

          // ── 6/5. Catégorie ───────────────────────────────────────────
          _SectionHdr('${_selMag == 'Base de vie' ? '6' : '5'}. Catégorie', Icons.category_outlined, _col),
        ] else ...[
          // Pour sortie : site puis catégorie
          _SectionHdr('2. Site *', Icons.location_on_rounded, kBlue),
          const SizedBox(height: 10),
          _StyledDrop<String>(
            value: _siteId,
            items: [
              DropdownMenuItem(
                value: SiteId.jadida,
                child: Row(children: [
                  const Icon(Icons.location_city_outlined, size: 14, color: kBlue),
                  const SizedBox(width: 8),
                  Text(SiteId.labelFr(SiteId.jadida)),
                ]),
              ),
              DropdownMenuItem(
                value: SiteId.safi,
                child: Row(children: [
                  const Icon(Icons.location_city_outlined, size: 14, color: kBlue),
                  const SizedBox(width: 8),
                  Text(SiteId.labelFr(SiteId.safi)),
                ]),
              ),
            ],
            onChanged: (v) => setState(() => _siteId = v ?? SiteId.jadida),
          ),
          const SizedBox(height: 20),
          _SectionHdr('3. Catégorie', Icons.category_outlined, _col),
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
            onChanged: (v) => setState(() {
              _selCat = v; _selProd = null; _selVar.clear(); _varCtrl.clear(); _prodSearchC.clear();
              for (final item in _epiItems) item.dispose();
              _epiItems.clear(); _epiSearchCtrl.clear();
              if (v == 'EPI' && _isSortie && !_isEditing) {
                final epiProds = widget.magasin.produits.where((p) => p.categorie == 'EPI').toList()..sort((a, b) => a.nom.compareTo(b.nom));
                _epiItems.addAll(epiProds.map((p) => _EpiItem(p)));
              }
            }),
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
          if (_isEpiMode) ...[
            // ── Mode EPI : liste multi-sélection ─────────────────────
            _SectionHdr('4. Articles EPI', Icons.verified_user_rounded, _col),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: TextField(
                controller: _epiSearchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Rechercher un article EPI…',
                  hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
                  prefixIcon: const Icon(Icons.search_rounded, color: kBlue, size: 17),
                  suffixIcon: _epiSearchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded, size: 14), onPressed: () => setState(() => _epiSearchCtrl.clear())) : null,
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
            Builder(builder: (ctx) {
              final q = _epiSearchCtrl.text.trim().toLowerCase();
              final visibleItems = q.isEmpty ? _epiItems : _epiItems.where((e) => e.produit.nom.toLowerCase().contains(q) || e.produit.reference.toLowerCase().contains(q)).toList();
              if (visibleItems.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
                  child: const Center(child: Text('Aucun article EPI', style: TextStyle(fontSize: 12, color: kMuted))),
                );
              }
              return Container(
                constraints: BoxConstraints(maxHeight: mobile ? 400 : 360),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kBorder)),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: visibleItems.length,
                  itemBuilder: (_, idx) {
                    final item = visibleItems[idx];
                    final p = item.produit;
                    final groupe = groupeByLabel(p.groupeUniteLabel);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            item.checked = !item.checked;
                            if (!item.checked) {
                              for (final c in item.varCtrl.values) c.dispose();
                              item.selVar.clear(); item.varCtrl.clear();
                              item.stockError = null; item.varStockErrors = {};
                            } else { item.validateStock(); }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: item.checked,
                                  onChanged: (v) => setState(() {
                                    item.checked = v ?? false;
                                    if (!item.checked) {
                                      for (final c in item.varCtrl.values) c.dispose();
                                      item.selVar.clear(); item.varCtrl.clear();
                                      item.stockError = null; item.varStockErrors = {};
                                    } else { item.validateStock(); }
                                  }),
                                  activeColor: _col,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _PillBadge(p.reference, kBlueLt, kBlue),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: p.rupture ? kRedLt : p.bas ? kOrangeLt : kGreenLt, borderRadius: BorderRadius.circular(20)),
                                    child: Text('Stock: ${p.total}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.rupture ? kRed : p.bas ? kOrange : kGreen)),
                                  ),
                                ]),
                              ])),
                            ]),
                          ),
                        ),
                        if (item.checked) ...[
                          if (p.aVariantes && groupe != null) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(46, 0, 12, 6),
                              child: Wrap(spacing: 6, runSpacing: 6, children: groupe.unites.map((u) {
                                final sel = item.selVar.contains(u);
                                final vm = p.variantes.where((v) => v.unite == u);
                                final dispo = vm.isEmpty ? 0 : vm.first.quantite;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() {
                                    if (sel) { item.selVar.remove(u); item.varCtrl.remove(u)?.dispose(); }
                                    else { item.selVar.add(u); item.varCtrl[u] = TextEditingController(text: '1'); }
                                    item.validateStock();
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel ? _col : kSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: sel ? _col : kBorder, width: sel ? 2 : 1.5),
                                    ),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Text(u, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? Colors.white : (dispo == 0 ? kRed : kMuted))),
                                      Text('$dispo', style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : (dispo == 0 ? kRed : kMuted))),
                                    ]),
                                  ),
                                );
                              }).toList()),
                            ),
                            if (item.selVar.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(46, 0, 12, 8),
                                child: _VarQteTable(
                                  selVar: item.selVar, varCtrl: item.varCtrl, color: _col,
                                  onRemove: (u) => setState(() { item.selVar.remove(u); item.varCtrl.remove(u)?.dispose(); item.validateStock(); }),
                                  stockErrors: item.varStockErrors,
                                  stockDisp: {for (var v in p.variantes) v.unite: v.quantite},
                                  onQteChanged: () => setState(() => item.validateStock()),
                                ),
                              ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(46, 0, 12, 10),
                              child: Row(children: [
                                const Text('Quantité :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kMuted)),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 130,
                                  child: _NumStepField(ctrl: item.qteCtrl, color: _col, onChanged: () => setState(() => item.validateStock())),
                                ),
                                if (item.stockError != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(item.stockError!, style: const TextStyle(fontSize: 10, color: kRed, fontWeight: FontWeight.w600))),
                                ],
                              ]),
                            ),
                          ],
                        ],
                        if (idx < visibleItems.length - 1) const Divider(height: 1, indent: 46, color: kBorder),
                      ],
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 20),
            _SectionHdr('5. Prélevé par', Icons.person_outline_rounded, _col),
            const SizedBox(height: 10),
            _StyledTF(ctrl: _preneurC, hint: '', prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted), readOnly: true, onTap: () => _showPreneurDialog(context)),
          ] else ...[
            // ── Mode standard : sélection d'un seul produit ───────────
            Builder(builder: (ctx) {
              final secNum = _isSortie ? '4' : (_selMag == 'Base de vie' ? '7' : '6');
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
              Builder(builder: (ctx) {
                final secNum = _isSortie ? '4' : (_selMag == 'Base de vie' ? '7' : '6');
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

            if (!_isSortie && (_selProd != null || _newProdMode)) ...[
              Builder(builder: (ctx) {
                final secNum = _selMag == 'Base de vie' ? '8' : '7';
                return _SectionHdr('$secNum. Prix Unitaire (P.U)', Icons.price_change_outlined, kGreen);
              }),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kGreenLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kGreen.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 12, color: kGreen.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  const Flexible(child: Text('Optionnel — saisir le prix unitaire en MAD.', style: TextStyle(fontSize: 10, color: kGreen))),
                ]),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: TextField(
                  controller: _puCtrl,
                  style: const TextStyle(fontSize: 12, color: kText),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Ex: 150.00',
                    hintStyle: const TextStyle(fontSize: 12, color: kBorderMd),
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18, color: kMuted),
                    suffixText: 'MAD',
                    suffixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted),
                    filled: true, fillColor: kSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kGreen, width: 2)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_isSortie && (_selProd != null || _newProdMode)) ...[
              _SectionHdr('5. Prélevé par', Icons.person_outline_rounded, _col),
              const SizedBox(height: 10),
              _StyledTF(ctrl: _preneurC, hint: '', prefix: const Icon(Icons.person_outline_rounded, size: 18, color: kMuted), readOnly: true, onTap: () => _showPreneurDialog(context)),
            ],
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

class _AjustementStockDialog extends StatefulWidget {
  final Produit produit;
  final GroupeUnites? groupe;
  final MagasinProvider magasin;
  const _AjustementStockDialog({required this.produit, this.groupe, required this.magasin});

  @override
  State<_AjustementStockDialog> createState() => _AjustementStockDialogState();
}

class _AjustementStockDialogState extends State<_AjustementStockDialog> {
  late final TextEditingController _qteCtrl;
  late final Map<String, TextEditingController> _varianteCtrls;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.produit;
    if (!p.aVariantes) {
      _qteCtrl = TextEditingController(text: '${p.quantiteStock}');
      _varianteCtrls = {};
    } else {
      _qteCtrl = TextEditingController();
      _varianteCtrls = {
        for (final v in p.variantes) v.unite: TextEditingController(text: '${v.quantite}'),
      };
    }
  }

  @override
  void dispose() {
    _qteCtrl.dispose();
    for (final c in _varianteCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = widget.produit;
      if (!p.aVariantes) {
        final val = int.tryParse(_qteCtrl.text.trim()) ?? 0;
        await widget.magasin.ajusterQuantiteDirecte(p, nouvelleQuantite: val);
      } else {
        final nouvellesVariantes = p.variantes.map((v) {
          final val = int.tryParse(_varianteCtrls[v.unite]?.text.trim() ?? '') ?? v.quantite;
          return VarianteProduit(unite: v.unite, quantite: val.clamp(0, 999999));
        }).toList();
        await widget.magasin.ajusterQuantiteDirecte(p, nouvellesVariantes: nouvellesVariantes);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final g = widget.groupe;

    return _FullDialog(
      color: kIndigo,
      icon: Icons.tune_rounded,
      title: 'Ajuster le stock — ${p.nom}',
      saveLabel: 'Enregistrer',
      onSave: _save,
      saving: _saving,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kIndigoLt, borderRadius: BorderRadius.circular(kR), border: Border.all(color: kIndigo.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: kIndigo, size: 16),
            const SizedBox(width: 8),
            const Flexible(child: Text('Modification directe du stock sans déclaration de mouvement.', style: TextStyle(fontSize: 12, color: kIndigo, fontWeight: FontWeight.w500))),
          ]),
        ),
        const SizedBox(height: 16),
        if (!p.aVariantes) ...[
          const Text('Nouvelle quantité en stock', style: _label),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _qteCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText),
              decoration: InputDecoration(
                hintText: 'Quantité',
                hintStyle: const TextStyle(fontSize: 12, color: kMuted),
                filled: true, fillColor: kBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kIndigo, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ] else ...[
          Text('Quantités par ${g?.label.toLowerCase() ?? "variante"}', style: _label),
          const SizedBox(height: 10),
          ...p.variantes.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 60, maxWidth: 90),
                child: Container(
                  height: 34, alignment: Alignment.center,
                  decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(7)),
                  child: Text(v.unite, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _varianteCtrls[v.unite],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText),
                  decoration: InputDecoration(
                    hintText: 'Quantité',
                    hintStyle: const TextStyle(fontSize: 12, color: kMuted),
                    filled: true, fillColor: kBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kR), borderSide: const BorderSide(color: kIndigo, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              )),
            ]),
          )),
        ],
      ]),
    );
  }
}

class _DetailsDialog extends StatelessWidget {
  final Produit produit;
  final GroupeUnites? groupe;
  final MagasinProvider? magasin;
  const _DetailsDialog({required this.produit, this.groupe, this.magasin});

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
          if (p.modulaireNom != null) _DetCard(Icons.home_work_rounded, '📦 Modulaire', p.modulaireNom!),
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
        if (magasin != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kIndigo, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kR)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Ajuster le stock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                _showDialog(context, _AjustementStockDialog(produit: p, groupe: g, magasin: magasin!));
              },
            ),
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
          if (m.modulaireNom != null) _DetCard(Icons.home_work_rounded, '📦 Modulaire', m.modulaireNom!),
          if (isE && m.prixUnitaire != null) _DetCard(Icons.payments_outlined, '💰 P.U', '${m.prixUnitaire!.toStringAsFixed(2)} MAD'),
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
  void _setHov(bool v) {
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hov = v); });
  }
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _setHov(true),
    onExit: (_) => _setHov(false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _hov ? widget.accentColor.withOpacity(0.04) : kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRect(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.columns.length, (i) => Expanded(flex: widget.columns[i].flex,
            child: i < widget.row.cells.length ? Align(alignment: Alignment.centerLeft, child: widget.row.cells[i]) : const SizedBox.shrink(),
          )),
        ),
      ),
    ),
  );
}

class _MouvRow extends _DataTableRow {
  final Mouvement m;
  final Color color, bgColor;
  final bool showPreneur, showFournisseur, showModulaire;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDetails;

  _MouvRow({required this.m, required this.color, required this.bgColor, this.showPreneur = false, this.showFournisseur = false, this.showModulaire = true, required this.onDelete, this.onEdit, this.onDetails}) : super(cells: const []);

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
    if (showModulaire)
      m.modulaireNom != null ? _PillBadge('📦 ${m.modulaireNom!}', kBrownLt, kBrown) : Text('—', style: _muted.copyWith(fontSize: 11)),
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
      if (onDetails != null) ...[_IconBtn(Icons.visibility_rounded, 'Voir détails', kBlueLt, kBlue, onDetails!), const SizedBox(width: 6)],
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
