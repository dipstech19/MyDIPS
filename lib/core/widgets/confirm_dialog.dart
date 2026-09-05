import 'package:flutter/material.dart';
import '../locale/app_locale.dart';

/// Boîtes de confirmation communes à toute l'application.
///
/// Règle : **aucune action sensible (suppression ou modification de données)
/// ne doit s'exécuter sans une confirmation explicite de l'utilisateur.**
/// Utiliser [confirmDelete] avant une suppression, [confirmUpdate] avant un
/// enregistrement / une modification, et [confirmAction] pour les autres
/// actions sensibles (validation, envoi, réinitialisation…).

/// Affiche une confirmation générique. Retourne `true` uniquement si
/// l'utilisateur a explicitement confirmé.
Future<bool> confirmAction(
  BuildContext context, {
  required String message,
  String? title,
  String? confirmLabel,
  String? details,
  IconData icon = Icons.help_outline_rounded,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final color = danger ? Colors.red.shade700 : Theme.of(ctx).colorScheme.primary;
      return AlertDialog(
        icon: Icon(icon, color: color, size: 28),
        title: Text(
          title ?? trOf(ctx, 'confirm_title'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (details != null && details.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                details,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? trOf(ctx, 'confirm_yes')),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Confirmation avant une **suppression**. [itemLabel] = nom de l'élément
/// concerné (affiché dans le message) ; [details] = précision optionnelle.
Future<bool> confirmDelete(
  BuildContext context, {
  String? itemLabel,
  String? message,
  String? title,
  String? details,
}) {
  final label = itemLabel?.trim() ?? '';
  final defaultMessage = label.isEmpty
      ? trOf(context, 'confirm_delete_message')
      : trOf(context, 'confirm_delete_message_named').replaceAll('%s', label);
  return confirmAction(
    context,
    title: title ?? trOf(context, 'confirm_delete_title'),
    message: message ?? defaultMessage,
    details: details ?? trOf(context, 'confirm_irreversible'),
    confirmLabel: trOf(context, 'confirm_yes_delete'),
    icon: Icons.delete_outline_rounded,
    danger: true,
  );
}

/// Confirmation avant une **modification / un enregistrement**.
Future<bool> confirmUpdate(
  BuildContext context, {
  String? itemLabel,
  String? message,
  String? title,
  String? details,
}) {
  final label = itemLabel?.trim() ?? '';
  final defaultMessage = label.isEmpty
      ? trOf(context, 'confirm_update_message')
      : trOf(context, 'confirm_update_message_named').replaceAll('%s', label);
  return confirmAction(
    context,
    title: title ?? trOf(context, 'confirm_update_title'),
    message: message ?? defaultMessage,
    details: details,
    confirmLabel: trOf(context, 'confirm_yes_save'),
    icon: Icons.edit_outlined,
  );
}
