import 'package:flutter/material.dart';

/// Affiche un dialogue bloquant avec indicateur de chargement pendant [future]
/// (utile quand le réseau est lent — l’utilisateur voit que l’action est prise en compte).
Future<T?> withLoadingDialog<T>(
  BuildContext context,
  Future<T> future, {
  String message = 'Envoi en cours...',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    final result = await future;
    if (context.mounted) navigator.pop();
    return result;
  } catch (e) {
    if (context.mounted) navigator.pop();
    rethrow;
  }
}
