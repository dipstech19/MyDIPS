# Notifications pointage (Firebase Cloud Functions)

Ces fonctions envoient des **push FCM** même quand l'application est fermée.

## Déploiement

```bash
cd functions
npm install
firebase deploy --only functions
```

Prérequis : projet Firebase lié (`firebase use <project-id>`).

## Déclencheurs

| Collection        | Événement                    | Destinataires |
|-------------------|------------------------------|---------------|
| `pointage_events` | `chef_report_submitted`      | Directeur / Chef de zone / Chef atelier |
| `pointage_events` | `chef_report_missed`         | Superviseurs + chef d'équipe concerné |
| `ops_events`      | `stock_sortie`               | Admin général, Chef de zone, Admin magasin |
| `ops_events`      | `stock_low` / `stock_rupture`| Idem |
| `ops_events`      | `logistique_digest`          | Admin général, Chef de zone, droit logistique |
| Planifié 07:00    | `dailyOpsDigest`             | Résumé stock + logistique (app fermée) |

L'application Flutter écrit dans `pointage_events` et `ops_events`.
