// ─────────────────────────────────────────────────────────────────────────────
//  vehicule_model.dart
//  Modèles de données avec sérialisation Firestore complète
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  VIDANGE
// ═════════════════════════════════════════════════════════════════════════════
class Vidange {
  final String? id; // ID du document Firestore (sous-collection)
  final DateTime date;
  final double kilometrage;
  final double prochaineVidange;
  final double montant;
  final bool filtreHuile;
  final bool filtreAir;
  final bool filtreGasoil;
  final String? documentPath; // chemin local ou URL Firebase Storage

  const Vidange({
    this.id,
    required this.date,
    required this.kilometrage,
    required this.filtreHuile,
    required this.filtreAir,
    required this.filtreGasoil,
    required this.prochaineVidange,
    required this.montant,
    this.documentPath,
  });

  // ── Firestore ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'date': Timestamp.fromDate(date),
        'kilometrage': kilometrage,
        'prochaineVidange': prochaineVidange,
        'montant': montant,
        'filtreHuile': filtreHuile,
        'filtreAir': filtreAir,
        'filtreGasoil': filtreGasoil,
        'documentPath': documentPath,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Vidange.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Vidange(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      kilometrage: (d['kilometrage'] as num).toDouble(),
      prochaineVidange: (d['prochaineVidange'] as num).toDouble(),
      montant: (d['montant'] as num).toDouble(),
      filtreHuile: d['filtreHuile'] as bool? ?? false,
      filtreAir: d['filtreAir'] as bool? ?? false,
      filtreGasoil: d['filtreGasoil'] as bool? ?? false,
      documentPath: d['documentPath'] as String?,
    );
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  Vidange copyWith({
    String? id,
    DateTime? date,
    double? kilometrage,
    double? prochaineVidange,
    double? montant,
    bool? filtreHuile,
    bool? filtreAir,
    bool? filtreGasoil,
    String? documentPath,
  }) =>
      Vidange(
        id: id ?? this.id,
        date: date ?? this.date,
        kilometrage: kilometrage ?? this.kilometrage,
        prochaineVidange: prochaineVidange ?? this.prochaineVidange,
        montant: montant ?? this.montant,
        filtreHuile: filtreHuile ?? this.filtreHuile,
        filtreAir: filtreAir ?? this.filtreAir,
        filtreGasoil: filtreGasoil ?? this.filtreGasoil,
        documentPath: documentPath ?? this.documentPath,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  PLEIN GASOIL
// ═════════════════════════════════════════════════════════════════════════════
class PleinGasoil {
  final String? id;
  final DateTime date;
  final double kilometrage;
  final double litres;
  final double prixParLitre;
  final String? documentPath;

  const PleinGasoil({
    this.id,
    required this.date,
    required this.kilometrage,
    required this.litres,
    required this.prixParLitre,
    this.documentPath,
  });

  double get montant => litres * prixParLitre;

  // ── Firestore ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'date': Timestamp.fromDate(date),
        'kilometrage': kilometrage,
        'litres': litres,
        'prixParLitre': prixParLitre,
        'montant': montant, // stocké pour les requêtes d'agrégation
        'documentPath': documentPath,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory PleinGasoil.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PleinGasoil(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      kilometrage: (d['kilometrage'] as num).toDouble(),
      litres: (d['litres'] as num).toDouble(),
      prixParLitre: (d['prixParLitre'] as num).toDouble(),
      documentPath: d['documentPath'] as String?,
    );
  }

  PleinGasoil copyWith({
    String? id,
    DateTime? date,
    double? kilometrage,
    double? litres,
    double? prixParLitre,
    String? documentPath,
  }) =>
      PleinGasoil(
        id: id ?? this.id,
        date: date ?? this.date,
        kilometrage: kilometrage ?? this.kilometrage,
        litres: litres ?? this.litres,
        prixParLitre: prixParLitre ?? this.prixParLitre,
        documentPath: documentPath ?? this.documentPath,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  RÉPARATION
// ═════════════════════════════════════════════════════════════════════════════
class Reparation {
  final String? id;
  final DateTime date;
  final String description;
  final List<String> piecesChangees;
  final double montant;
  final String? documentPath;

  const Reparation({
    this.id,
    required this.date,
    this.description = '',
    required this.piecesChangees,
    required this.montant,
    this.documentPath,
  });

  // ── Firestore ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirestore() => {
        'date': Timestamp.fromDate(date),
        'description': description,
        'piecesChangees': piecesChangees,
        'montant': montant,
        'documentPath': documentPath,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Reparation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Reparation(
      id: doc.id,
      date: (d['date'] as Timestamp).toDate(),
      description: d['description'] as String? ?? '',
      piecesChangees: List<String>.from(d['piecesChangees'] as List? ?? []),
      montant: (d['montant'] as num).toDouble(),
      documentPath: d['documentPath'] as String?,
    );
  }

  Reparation copyWith({
    String? id,
    DateTime? date,
    String? description,
    List<String>? piecesChangees,
    double? montant,
    String? documentPath,
  }) =>
      Reparation(
        id: id ?? this.id,
        date: date ?? this.date,
        description: description ?? this.description,
        piecesChangees: piecesChangees ?? this.piecesChangees,
        montant: montant ?? this.montant,
        documentPath: documentPath ?? this.documentPath,
      );
}

// ═════════════════════════════════════════════════════════════════════════════
//  VÉHICULE
// ═════════════════════════════════════════════════════════════════════════════
class Vehicule {
  final String? id; // ID document Firestore
  final String matricule;
  final String marque;
  final String modele;
  final double kilometrage;

  // Dates juridiques
  final DateTime? expirationCarteGrise;
  final DateTime? expirationAssurance;
  final DateTime? expirationVisite;
  final DateTime? expirationAutorisationTransport;
  final DateTime? dateTaxe;
  final DateTime? expirationBadge;

  // Sous-listes (chargées séparément depuis les sous-collections)
  final List<Vidange> vidanges;
  final List<PleinGasoil> pleins;
  final List<Reparation> reparations;

  const Vehicule({
    this.id,
    required this.matricule,
    required this.marque,
    required this.modele,
    required this.kilometrage,
    this.expirationCarteGrise,
    this.expirationAssurance,
    this.expirationVisite,
    this.expirationAutorisationTransport,
    this.dateTaxe,
    this.expirationBadge,
    List<Vidange>? vidanges,
    List<PleinGasoil>? pleins,
    List<Reparation>? reparations,
  })  : vidanges = vidanges ?? const [],
        pleins = pleins ?? const [],
        reparations = reparations ?? const [];

  // ── Firestore ──────────────────────────────────────────────────────────────
  /// Sérialise uniquement les champs du document principal (pas les sous-collections)
  Map<String, dynamic> toFirestore() => {
        'matricule': matricule,
        'marque': marque,
        'modele': modele,
        'kilometrage': kilometrage,
        'expirationCarteGrise':
            expirationCarteGrise != null ? Timestamp.fromDate(expirationCarteGrise!) : null,
        'expirationAssurance':
            expirationAssurance != null ? Timestamp.fromDate(expirationAssurance!) : null,
        'expirationVisite':
            expirationVisite != null ? Timestamp.fromDate(expirationVisite!) : null,
        'expirationAutorisationTransport': expirationAutorisationTransport != null
            ? Timestamp.fromDate(expirationAutorisationTransport!)
            : null,
        'dateTaxe': dateTaxe != null ? Timestamp.fromDate(dateTaxe!) : null,
        'expirationBadge':
            expirationBadge != null ? Timestamp.fromDate(expirationBadge!) : null,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Désérialise depuis un DocumentSnapshot (sans sous-collections)
  factory Vehicule.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Vehicule(
      id: doc.id,
      matricule: d['matricule'] as String? ?? '',
      marque: d['marque'] as String? ?? '',
      modele: d['modele'] as String? ?? '',
      kilometrage: (d['kilometrage'] as num?)?.toDouble() ?? 0,
      expirationCarteGrise: (d['expirationCarteGrise'] as Timestamp?)?.toDate(),
      expirationAssurance: (d['expirationAssurance'] as Timestamp?)?.toDate(),
      expirationVisite: (d['expirationVisite'] as Timestamp?)?.toDate(),
      expirationAutorisationTransport:
          (d['expirationAutorisationTransport'] as Timestamp?)?.toDate(),
      dateTaxe: (d['dateTaxe'] as Timestamp?)?.toDate(),
      expirationBadge: (d['expirationBadge'] as Timestamp?)?.toDate(),
    );
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  Vehicule copyWith({
    String? id,
    String? matricule,
    String? marque,
    String? modele,
    double? kilometrage,
    DateTime? expirationCarteGrise,
    DateTime? expirationAssurance,
    DateTime? expirationVisite,
    DateTime? expirationAutorisationTransport,
    DateTime? dateTaxe,
    DateTime? expirationBadge,
    List<Vidange>? vidanges,
    List<PleinGasoil>? pleins,
    List<Reparation>? reparations,
  }) =>
      Vehicule(
        id: id ?? this.id,
        matricule: matricule ?? this.matricule,
        marque: marque ?? this.marque,
        modele: modele ?? this.modele,
        kilometrage: kilometrage ?? this.kilometrage,
        expirationCarteGrise: expirationCarteGrise ?? this.expirationCarteGrise,
        expirationAssurance: expirationAssurance ?? this.expirationAssurance,
        expirationVisite: expirationVisite ?? this.expirationVisite,
        expirationAutorisationTransport:
            expirationAutorisationTransport ?? this.expirationAutorisationTransport,
        dateTaxe: dateTaxe ?? this.dateTaxe,
        expirationBadge: expirationBadge ?? this.expirationBadge,
        vidanges: vidanges ?? this.vidanges,
        pleins: pleins ?? this.pleins,
        reparations: reparations ?? this.reparations,
      );

  // ── Helpers alertes ────────────────────────────────────────────────────────
  /// Retourne les documents expirant dans moins de [days] jours (ou déjà expirés)
  List<AlerteDocument> getAlertes({int days = 30}) {
    final alertes = <AlerteDocument>[];
    final now = DateTime.now();

    void check(String label, DateTime? date) {
      if (date == null) return;
      final diff = date.difference(now).inDays;
      if (diff <= days) {
        alertes.add(AlerteDocument(
          vehiculeMatricule: matricule,
          label: label,
          date: date,
          joursRestants: diff,
        ));
      }
    }

    check('Assurance', expirationAssurance);
    check('Visite technique', expirationVisite);
    check('Carte grise', expirationCarteGrise);
    check('Autorisation transport', expirationAutorisationTransport);
    check('Badge', expirationBadge);

    // Alerte vidange kilométrique
    if (vidanges.isNotEmpty) {
      final derniere = vidanges.first;
      final kmRestants = derniere.prochaineVidange - kilometrage;
      if (kmRestants <= 1000) {
        alertes.add(AlerteDocument(
          vehiculeMatricule: matricule,
          label: 'Vidange',
          date: null,
          joursRestants: null,
          kmRestants: kmRestants,
        ));
      }
    }

    return alertes;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  ALERTE DOCUMENT
// ═════════════════════════════════════════════════════════════════════════════
class AlerteDocument {
  final String vehiculeMatricule;
  final String label;
  final DateTime? date;
  final int? joursRestants;
  final double? kmRestants;

  const AlerteDocument({
    required this.vehiculeMatricule,
    required this.label,
    this.date,
    this.joursRestants,
    this.kmRestants,
  });

  bool get estExpire => joursRestants != null && joursRestants! < 0;
  bool get estUrgent => joursRestants != null && joursRestants! < 7;
  bool get estBientot =>
      (joursRestants != null && joursRestants! < 30) ||
      (kmRestants != null && kmRestants! <= 500);
}