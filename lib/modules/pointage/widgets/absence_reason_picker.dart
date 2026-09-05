import 'package:flutter/material.dart';

import '../models/absence_reason_config.dart';
import '../models/pointage_model.dart';

/// Sélecteur de raison d'absence affiché au chef / responsable dès qu'il marque
/// quelqu'un « Absent ».
///
/// Retourne l'id de la raison configurée (Paramètres) ou, à défaut de
/// configuration, le `name` de l'enum [AbsenceReason]. `null` = annulé, l'appelant
/// ne doit alors rien enregistrer.
Future<String?> showAbsenceReasonPicker(
  BuildContext context, {
  required List<AbsenceReasonConfig> reasons,
  String? currentReason,
}) {
  final entries = reasons.isNotEmpty
      ? [for (final c in reasons) (id: c.id, label: c.label)]
      : [for (final r in AbsenceReason.values) (id: r.name, label: r.label)];

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Raison de l\'absence'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in entries)
                ListTile(
                  leading: Icon(
                    e.id == currentReason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: e.id == currentReason
                        ? Theme.of(ctx).colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(e.label),
                  onTap: () => Navigator.pop(ctx, e.id),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
      ],
    ),
  );
}
