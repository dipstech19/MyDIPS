import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../auth/app_permissions.dart';
import '../auth/auth_model.dart';
import '../../modules/logistique/logistique_service.dart';
import '../../modules/logistique/vehicule_model.dart';
import '../../modules/magasin/gestion_magasin.dart';

/// Événements stock / logistique → collection `ops_events` → Cloud Functions → FCM.
class OpsNotificationsService {
  OpsNotificationsService._();
  static final OpsNotificationsService instance = OpsNotificationsService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'ops_events';

  Future<void> emitStockSortie({
    required Mouvement mouvement,
    required int stockRestant,
    String? actorUserId,
    String? actorUserName,
  }) async {
    final preneur = (mouvement.preneurNom ?? '').trim();
    final actor = (actorUserName ?? '').trim();
    final by = preneur.isNotEmpty
        ? preneur
        : (actor.isNotEmpty ? actor : 'Utilisateur magasin');
    await _write(
      type: 'stock_sortie',
      title: 'Sortie de stock',
      body:
          '$by a retiré ${mouvement.totalQte} unité(s) de « ${mouvement.nomProduit} ». Reste : $stockRestant.',
      data: {
        'produitId': mouvement.produitId,
        'nomProduit': mouvement.nomProduit,
        'quantite': mouvement.totalQte,
        'stockRestant': stockRestant,
        'magasin': mouvement.magasin,
        'actorUserId': actorUserId,
        'actorUserName': actorUserName,
        'preneurNom': mouvement.preneurNom,
      },
    );
  }

  Future<void> emitStockLevelIfNeeded({
    required Produit before,
    required Produit after,
  }) async {
    final wasRupture = before.rupture;
    final wasBas = before.bas && !before.rupture;
    final nowRupture = after.rupture;
    final nowBas = after.bas && !after.rupture;

    if (!wasRupture && nowRupture) {
      await _write(
        type: 'stock_rupture',
        title: 'Rupture de stock',
        body: '« ${after.nom} » est en rupture (0 unité disponible).',
        data: {'produitId': after.id, 'nomProduit': after.nom, 'stockRestant': after.total},
      );
    } else if (!wasBas && !wasRupture && nowBas) {
      await _write(
        type: 'stock_low',
        title: 'Stock bas',
        body: '« ${after.nom} » : stock critique (${after.total} unité(s) restante(s)).',
        data: {'produitId': after.id, 'nomProduit': after.nom, 'stockRestant': after.total},
      );
    }
  }

  /// Scan parc logistique — un résumé (évite le spam à la connexion).
  Future<void> syncLogistiqueExpiryAlerts({int days = 30}) async {
    try {
      final alertes = await LogistiqueService.instance.getAllAlertes(days: days);
      if (alertes.isEmpty) return;

      final expires = alertes.where((a) => a.estExpire).length;
      final urgents = alertes.where((a) => a.estUrgent && !a.estExpire).length;
      final soon = alertes.length - expires - urgents;
      final sample = alertes.take(3).map((a) {
        final d = a.kmRestants != null
            ? '${a.kmRestants!.toStringAsFixed(0)} km'
            : a.estExpire
                ? 'expiré'
                : '${a.joursRestants} j';
        return '${a.vehiculeMatricule} ${a.label} ($d)';
      }).join(' · ');

      await _write(
        type: 'logistique_digest',
        title: 'Logistique — ${alertes.length} alerte(s)',
        body: '$expires expiré(s), $urgents urgent(s), $soon à surveiller. $sample',
        data: {
          'count': alertes.length,
          'expires': expires,
          'urgents': urgents,
          'soon': soon,
        },
      );
    } catch (e) {
      debugPrint('syncLogistiqueExpiryAlerts: $e');
    }
  }

  Future<void> bindUser(AppUser? user) async {
    if (user == null || user.role != UserRole.directeur) return;
    final role = (user.adminRole ?? '').toLowerCase();
    final canLogistique = user.permissions.contains(AppPermissions.logistiqueView) ||
        user.permissions.contains(AppPermissions.all) ||
        role.contains('général') ||
        role.contains('general') ||
        role.contains('zone');
    if (!canLogistique) return;
    await syncLogistiqueExpiryAlerts();
  }

  Future<void> _write({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'type': type,
        'title': title,
        'body': body,
        if (data != null) ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ops_events write ($type): $e');
    }
  }
}
