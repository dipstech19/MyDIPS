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

| Collection        | Événement                    | Destinataires                          |
|-------------------|------------------------------|----------------------------------------|
| `pointage_events` | `chef_report_submitted`      | Directeur / Chef de zone / Chef atelier |
| `pointage_events` | `chef_report_missed`         | Superviseurs + chef d'équipe concerné  |

L'application Flutter écrit dans `pointage_events` à chaque confirmation ou retard détecté.
