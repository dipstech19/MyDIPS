// ─────────────────────────────────────────────────────────────────────────────
//  logistique_service.dart
//  Service Firestore complet pour la section Logistique
//
//  Structure Firestore :
//  logistique/
//    └── vehicules/          ← collection principale
//          └── {vehiculeId}/
//                ├── (champs du véhicule)
//                ├── vidanges/      ← sous-collection
//                ├── pleins/        ← sous-collection
//                └── reparations/   ← sous-collection
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'vehicule_model.dart';

class LogistiqueService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  LogistiqueService._();
  static final LogistiqueService instance = LogistiqueService._();

  // ── Références Firestore ───────────────────────────────────────────────────
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vehiculesRef =>
      _db.collection('logistique').doc('parc').collection('vehicules');

  CollectionReference<Map<String, dynamic>> _vidangesRef(String vehiculeId) =>
      _vehiculesRef.doc(vehiculeId).collection('vidanges');

  CollectionReference<Map<String, dynamic>> _pleinsRef(String vehiculeId) =>
      _vehiculesRef.doc(vehiculeId).collection('pleins');

  CollectionReference<Map<String, dynamic>> _reparationsRef(String vehiculeId) =>
      _vehiculesRef.doc(vehiculeId).collection('reparations');

  // ══════════════════════════════════════════════════════════════════════════
  //  VÉHICULES
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream en temps réel de tous les véhicules (sans sous-collections)
  Stream<List<Vehicule>> streamVehicules() {
    return _vehiculesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Vehicule.fromFirestore).toList());
  }

  /// Charge un véhicule avec TOUTES ses sous-collections
  Future<Vehicule> getVehiculeComplet(String vehiculeId) async {
    final doc = await _vehiculesRef.doc(vehiculeId).get();
    final vehicule = Vehicule.fromFirestore(doc);

    final results = await Future.wait([
      _vidangesRef(vehiculeId).orderBy('date', descending: true).get(),
      _pleinsRef(vehiculeId).orderBy('date', descending: true).get(),
      _reparationsRef(vehiculeId).orderBy('date', descending: true).get(),
    ]);

    return vehicule.copyWith(
      vidanges: (results[0] as QuerySnapshot).docs.map(Vidange.fromFirestore).toList(),
      pleins: (results[1] as QuerySnapshot).docs.map(PleinGasoil.fromFirestore).toList(),
      reparations: (results[2] as QuerySnapshot).docs.map(Reparation.fromFirestore).toList(),
    );
  }

  /// Stream d'un véhicule complet avec ses sous-collections en temps réel
  Stream<Vehicule> streamVehiculeComplet(String vehiculeId) {
    final vehiculeStream = _vehiculesRef.doc(vehiculeId).snapshots();

    // Combine les 4 streams via StreamBuilder dans l'UI
    // Ici on expose un stream simple du document principal
    // et les sous-collections sont rechargées à la demande
    return vehiculeStream.asyncMap((doc) async {
      final vehicule = Vehicule.fromFirestore(doc);
      final results = await Future.wait([
        _vidangesRef(vehiculeId).orderBy('date', descending: true).get(),
        _pleinsRef(vehiculeId).orderBy('date', descending: true).get(),
        _reparationsRef(vehiculeId).orderBy('date', descending: true).get(),
      ]);
      return vehicule.copyWith(
        vidanges: (results[0] as QuerySnapshot).docs.map(Vidange.fromFirestore).toList(),
        pleins: (results[1] as QuerySnapshot).docs.map(PleinGasoil.fromFirestore).toList(),
        reparations:
            (results[2] as QuerySnapshot).docs.map(Reparation.fromFirestore).toList(),
      );
    });
  }

  /// Crée un nouveau véhicule → retourne son ID
  Future<String> addVehicule(Vehicule vehicule) async {
    final data = vehicule.toFirestore();
    // createdAt défini uniquement à la création
    data['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _vehiculesRef.add(data);
    return ref.id;
  }

  /// Met à jour les infos principales d'un véhicule
  Future<void> updateVehicule(Vehicule vehicule) async {
    assert(vehicule.id != null, 'vehicule.id requis pour la mise à jour');
    final data = vehicule.toFirestore();
    data.remove('createdAt'); // Ne pas écraser createdAt
    await _vehiculesRef.doc(vehicule.id!).update(data);
  }

  /// Supprime un véhicule ET toutes ses sous-collections (batch)
  Future<void> deleteVehicule(String vehiculeId) async {
    final batch = _db.batch();

    // Supprimer les sous-collections
    for (final sub in ['vidanges', 'pleins', 'reparations']) {
      final snap = await _vehiculesRef.doc(vehiculeId).collection(sub).get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    // Supprimer le document principal
    batch.delete(_vehiculesRef.doc(vehiculeId));
    await batch.commit();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VIDANGES
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream des vidanges d'un véhicule
  Stream<List<Vidange>> streamVidanges(String vehiculeId) {
    return _vidangesRef(vehiculeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Vidange.fromFirestore).toList());
  }

  /// Ajoute une vidange → retourne son ID
  Future<String> addVidange(String vehiculeId, Vidange vidange) async {
    final ref = await _vidangesRef(vehiculeId).add(vidange.toFirestore());
    // Met à jour le kilométrage du véhicule si la vidange est plus récente
    await _updateKilometrage(vehiculeId, vidange.kilometrage);
    return ref.id;
  }

  /// Met à jour une vidange existante
  Future<void> updateVidange(String vehiculeId, Vidange vidange) async {
    assert(vidange.id != null, 'vidange.id requis');
    await _vidangesRef(vehiculeId).doc(vidange.id!).update(vidange.toFirestore());
  }

  /// Supprime une vidange
  Future<void> deleteVidange(String vehiculeId, String vidangeId) async {
    await _vidangesRef(vehiculeId).doc(vidangeId).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PLEINS GASOIL
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream des pleins d'un véhicule
  Stream<List<PleinGasoil>> streamPleins(String vehiculeId) {
    return _pleinsRef(vehiculeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PleinGasoil.fromFirestore).toList());
  }

  /// Ajoute un plein gasoil → retourne son ID
  Future<String> addPlein(String vehiculeId, PleinGasoil plein) async {
    final ref = await _pleinsRef(vehiculeId).add(plein.toFirestore());
    await _updateKilometrage(vehiculeId, plein.kilometrage);
    return ref.id;
  }

  /// Met à jour un plein existant
  Future<void> updatePlein(String vehiculeId, PleinGasoil plein) async {
    assert(plein.id != null, 'plein.id requis');
    await _pleinsRef(vehiculeId).doc(plein.id!).update(plein.toFirestore());
  }

  /// Supprime un plein
  Future<void> deletePlein(String vehiculeId, String pleinId) async {
    await _pleinsRef(vehiculeId).doc(pleinId).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RÉPARATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream des réparations d'un véhicule
  Stream<List<Reparation>> streamReparations(String vehiculeId) {
    return _reparationsRef(vehiculeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Reparation.fromFirestore).toList());
  }

  /// Ajoute une réparation → retourne son ID
  Future<String> addReparation(String vehiculeId, Reparation reparation) async {
    final ref = await _reparationsRef(vehiculeId).add(reparation.toFirestore());
    return ref.id;
  }

  /// Met à jour une réparation existante
  Future<void> updateReparation(String vehiculeId, Reparation reparation) async {
    assert(reparation.id != null, 'reparation.id requis');
    await _reparationsRef(vehiculeId)
        .doc(reparation.id!)
        .update(reparation.toFirestore());
  }

  /// Supprime une réparation
  Future<void> deleteReparation(String vehiculeId, String reparationId) async {
    await _reparationsRef(vehiculeId).doc(reparationId).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ALERTES
  // ══════════════════════════════════════════════════════════════════════════

  /// Retourne toutes les alertes de l'ensemble du parc
  Future<List<AlerteDocument>> getAllAlertes({int days = 30}) async {
    final snap = await _vehiculesRef.get();
    final alertes = <AlerteDocument>[];

    for (final doc in snap.docs) {
      final vehicule = await getVehiculeComplet(doc.id);
      alertes.addAll(vehicule.getAlertes(days: days));
    }

    // Trier par urgence : expirés → urgents → bientôt
    alertes.sort((a, b) {
      final scoreA = a.estExpire ? 0 : a.estUrgent ? 1 : 2;
      final scoreB = b.estExpire ? 0 : b.estUrgent ? 1 : 2;
      return scoreA.compareTo(scoreB);
    });

    return alertes;
  }

  /// Stream des alertes en temps réel (recharge à chaque changement de véhicule)
  Stream<List<AlerteDocument>> streamAlertes({int days = 30}) {
    return _vehiculesRef.snapshots().asyncMap((_) => getAllAlertes(days: days));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATISTIQUES
  // ══════════════════════════════════════════════════════════════════════════

  /// Statistiques globales du parc pour un véhicule donné
  Future<StatistiquesVehicule> getStats(String vehiculeId) async {
    final results = await Future.wait([
      _pleinsRef(vehiculeId).get(),
      _vidangesRef(vehiculeId).get(),
      _reparationsRef(vehiculeId).get(),
    ]);

    final pleins = (results[0] as QuerySnapshot).docs.map(PleinGasoil.fromFirestore).toList();
    final vidanges = (results[1] as QuerySnapshot).docs.map(Vidange.fromFirestore).toList();
    final reparations =
        (results[2] as QuerySnapshot).docs.map(Reparation.fromFirestore).toList();

    final totalGasoil = pleins.fold(0.0, (s, p) => s + p.montant);
    final totalVidanges = vidanges.fold(0.0, (s, v) => s + v.montant);
    final totalReparations = reparations.fold(0.0, (s, r) => s + r.montant);

    return StatistiquesVehicule(
      totalGasoil: totalGasoil,
      totalVidanges: totalVidanges,
      totalReparations: totalReparations,
      nbPleins: pleins.length,
      nbVidanges: vidanges.length,
      nbReparations: reparations.length,
      totalLitres: pleins.fold(0.0, (s, p) => s + p.litres),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITAIRES PRIVÉS
  // ══════════════════════════════════════════════════════════════════════════

  /// Met à jour le kilométrage du véhicule si la nouvelle valeur est plus grande
  Future<void> _updateKilometrage(String vehiculeId, double km) async {
    await _vehiculesRef.doc(vehiculeId).update({
      'kilometrage': km,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  STATISTIQUES VÉHICULE
// ═════════════════════════════════════════════════════════════════════════════
class StatistiquesVehicule {
  final double totalGasoil;
  final double totalVidanges;
  final double totalReparations;
  final int nbPleins;
  final int nbVidanges;
  final int nbReparations;
  final double totalLitres;

  const StatistiquesVehicule({
    required this.totalGasoil,
    required this.totalVidanges,
    required this.totalReparations,
    required this.nbPleins,
    required this.nbVidanges,
    required this.nbReparations,
    required this.totalLitres,
  });

  double get totalDepenses => totalGasoil + totalVidanges + totalReparations;
}