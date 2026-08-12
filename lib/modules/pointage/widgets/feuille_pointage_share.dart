import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/locale/app_locale.dart';
import '../services/pointage_export_service.dart';

/// Libellés de la colonne « Statut » (celle qui remplace « Signature » du modèle papier).
const String feuilleStatutPresent = 'Présent';
const String feuilleStatutAbsent = 'Absent';

/// Construit une ligne de feuille à partir du nom complet (découpé NOM / PRENOM).
FeuillePointageLine feuillePointageLine({
  required String nomComplet,
  required String statut,
  String commentaire = '',
}) {
  final split = PointageExportService.splitNomPrenomForExcel(nomComplet);
  return (
    nom: split.nom,
    prenom: split.prenom,
    statut: statut,
    commentaire: commentaire,
  );
}

/// Génère la feuille de pointage puis ouvre le partage système (WhatsApp, …).
/// Utilisé par les pointages Équipe, Groupe et Distribution.
Future<void> exportFeuillePointage(
  BuildContext context, {
  required DateTime date,
  required String equipeLabel,
  required String posteLabel,
  required List<FeuillePointageLine> lines,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await PointageExportService.buildFeuillePointagePdf(
      date: date,
      equipeLabel: equipeLabel,
      posteLabel: posteLabel,
      lines: lines,
    );
    final fileName = PointageExportService.feuillePointageFileName(
      date: date,
      equipeLabel: equipeLabel,
      posteLabel: posteLabel,
    );
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Échec de la génération du PDF : $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }
}

/// Dialogue affiché juste après la confirmation du pointage : partage WhatsApp
/// ou téléchargement de la feuille en PDF.
Future<void> showPointageConfirmedDialog(
  BuildContext context, {
  required DateTime date,
  required String equipeLabel,
  required String posteLabel,
  required List<FeuillePointageLine> lines,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 52),
          ),
          const SizedBox(height: 16),
          Text(
            tr(ctx, 'pointage_confirmed'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            tr(ctx, 'pointage_share_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => exportFeuillePointage(
                ctx,
                date: date,
                equipeLabel: equipeLabel,
                posteLabel: posteLabel,
                lines: lines,
              ),
              icon: const Icon(Icons.share, size: 18),
              label: Text(tr(ctx, 'pointage_share_whatsapp')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// Panneau « Partager la feuille de pointage » affiché sur la page une fois le
/// pointage confirmé. [linesBuilder] est appelé au moment du clic pour refléter
/// l'état courant.
class FeuillePointageShareSection extends StatelessWidget {
  final DateTime date;
  final String equipeLabel;
  final String posteLabel;
  final List<FeuillePointageLine> Function() linesBuilder;

  const FeuillePointageShareSection({
    super.key,
    required this.date,
    required this.equipeLabel,
    required this.posteLabel,
    required this.linesBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, 'pointage_share_title'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: () => exportFeuillePointage(
                context,
                date: date,
                equipeLabel: equipeLabel,
                posteLabel: posteLabel,
                lines: linesBuilder(),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: Text(
                tr(context, 'pointage_share_whatsapp'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
