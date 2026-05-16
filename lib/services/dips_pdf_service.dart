import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─── Constantes DIPS ─────────────────────────────────────────────────────────
const _kBlue      = PdfColor.fromInt(0xFF000966);
const _kBlueLight = PdfColor.fromInt(0xFF328EEE);
const _kBlack     = PdfColor.fromInt(0xFF000000);
const _kGrey      = PdfColor.fromInt(0xFF555555);

const _kAdresse   = 'Résidence REDA, 1ier Étage, N°: 6, Av. ANNAKHIL, El Jadida';
const _kInfoFisc  = 'Identifiant Fiscal (IF):39424282 – Taxe Professionnelle (TP):42102445 – RC:16049 – ICE:002368424000093';
const _kTelephone = 'Téléphones.: 0523352515 – 0666282392     www.dips.ma';

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class DipsPdfService {

  // ── Chargement des assets ──────────────────────────────────────────────────
  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      // Le chemin d'asset tel que défini dans pubspec.yaml
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null; // logo absent → on continue sans
    }
  }

  static Future<pw.Font> _loadFont() async {
    // Utilise la police embarquée dans le package pdf (pas besoin d'asset)
    return pw.Font.helvetica();
  }

  // ── En-tête commun ─────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(pw.ImageProvider? logo) {
    return pw.Column(children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo à gauche
          if (logo != null)
            pw.Container(
              width: 70,
              height: 55,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(width: 70, height: 55),

          pw.SizedBox(width: 12),

          // Texte entreprise à droite du logo
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIGITALIZATION, INNOVATION',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _kBlue,
                  ),
                ),
                pw.Text(
                  '& PROCESS SIMULATION',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _kBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      pw.SizedBox(height: 6),

      // Ligne de séparation bleue
      pw.Divider(color: _kBlue, thickness: 1.5),

      pw.SizedBox(height: 4),

      // Infos de contact sous la ligne
      pw.Text(
        'Adresse : $_kAdresse',
        style: pw.TextStyle(fontSize: 7.5, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
      pw.Text(
        _kInfoFisc,
        style: pw.TextStyle(fontSize: 7, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
      pw.Text(
        _kTelephone,
        style: pw.TextStyle(fontSize: 7.5, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
    ]);
  }

  // ── Pied de page commun ────────────────────────────────────────────────────
  static pw.Widget _buildFooter() {
    return pw.Column(children: [
      pw.Divider(color: _kBlue, thickness: 1),
      pw.SizedBox(height: 4),
      pw.Text(
        'Adresse : $_kAdresse',
        style: pw.TextStyle(fontSize: 7.5, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
      pw.Text(
        '$_kInfoFisc',
        style: pw.TextStyle(fontSize: 7, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
      pw.Text(
        _kTelephone,
        style: pw.TextStyle(fontSize: 7.5, color: _kGrey),
        textAlign: pw.TextAlign.center,
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  1. DEMANDE DE CONGÉ
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> genererDemandeConge({
    required String nomEmploye,
    required String telephone,
    required int nbJours,
    required String dateDebut,
    required String dateFin,
    required int nbMoisTravail,
    required String periodeDebutTravail,
    required String periodeFinTravail,
    required String dateDocument, Uint8List? logoBytes,   // ex: "05/12/2025"
  }) async {
    final logo = await _loadLogo();
    final pdf  = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          _buildHeader(logo),
          pw.SizedBox(height: 30),

          // Date alignée à droite
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'El Jadida le $dateDocument',
              style: pw.TextStyle(fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 20),

          // Nom + téléphone
          pw.Text(nomEmploye,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Text(telephone, style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 20),

          // Objet centré
          pw.Center(
            child: pw.Text(
              'Objet : Demande de congé',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),

          // Formule d'appel
          pw.Text('Monsieur le directeur,',
              style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),

          // Corps de la lettre
          pw.Text(
            'Je sollicite, par la présente, votre autorisation de bien vouloir m\'accorder '
                '$nbJours jours de congé pour la période du $dateDebut au $dateFin inclus.',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Je précise que cette demande intervient à l\'issue d\'une période de travail de '
                '$nbMoisTravail mois, débutant à partir de $periodeDebutTravail au $periodeFinTravail.',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'En vous remerciant à l\'avance pour votre compréhension, je vous prie de croire, '
                'Monsieur, en l\'expression de mes salutations distinguées.',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 50),

          // Signature à droite
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Signature',
                style: pw.TextStyle(fontSize: 11)),
          ),

          pw.Spacer(),
          _buildFooter(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  2. ATTESTATION DE TRAVAIL
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> genererAttestationTravail({
    required String nomEmploye,
    required String poste,
    required String dateEmbauche,
    required String dateDocument,
    required String motif, Uint8List? logoBytes,
  }) async {
    final logo = await _loadLogo();
    final pdf  = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          _buildHeader(logo),
          pw.SizedBox(height: 30),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('El Jadida le $dateDocument',
                style: pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 30),

          // Titre centré
          pw.Center(
            child: pw.Text(
              'ATTESTATION DE TRAVAIL',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _kBlue,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 30),

          // Corps
          pw.Text(
            'Je soussigné, le Directeur Général de la société DIGITALIZATION, INNOVATION & PROCESS SIMULATION (DIPS), atteste par la présente que :',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'M. / Mme  $nomEmploye',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Occupe le poste de : $poste',
            style: pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Et ce depuis le : $dateEmbauche',
            style: pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'Cette attestation est délivrée à l\'intéressé(e) pour servir et valoir ce que de droit, notamment pour : $motif.',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 50),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Le Directeur Général',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 40),
                pw.Text('Signature & Cachet',
                    style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),

          pw.Spacer(),
          _buildFooter(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  3. BULLETIN DE PAIE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> genererBulletinPaie({
    required String nomEmploye,
    required String poste,
    required String mois,
    required double salaireBrut,
    required double cnss,       // cotisation CNSS
    required double amo,        // AMO
    required double ir,         // IR
    required String dateDocument, Uint8List? logoBytes,
  }) async {
    final logo        = await _loadLogo();
    final pdf         = pw.Document();
    final salaireNet  = salaireBrut - cnss - amo - ir;

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          _buildHeader(logo),
          pw.SizedBox(height: 20),

          // Titre
          pw.Center(
            child: pw.Text(
              'BULLETIN DE PAIE – $mois',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _kBlue,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Infos employé
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _kBlue, width: 0.8),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _bulletinRow('Nom et Prénom', nomEmploye),
                _bulletinRow('Poste',         poste),
                _bulletinRow('Période',       mois),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Tableau des éléments de salaire
          pw.Table(
            border: pw.TableBorder.all(color: _kGrey, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _kBlue),
                children: [
                  _tableCell('Désignation', header: true),
                  _tableCell('Montant (DH)', header: true),
                ],
              ),
              pw.TableRow(children: [
                _tableCell('Salaire brut'),
                _tableCell('${salaireBrut.toStringAsFixed(2)} DH'),
              ]),
              pw.TableRow(children: [
                _tableCell('Cotisation CNSS'),
                _tableCell('- ${cnss.toStringAsFixed(2)} DH'),
              ]),
              pw.TableRow(children: [
                _tableCell('AMO'),
                _tableCell('- ${amo.toStringAsFixed(2)} DH'),
              ]),
              pw.TableRow(children: [
                _tableCell('Impôt sur le Revenu (IR)'),
                _tableCell('- ${ir.toStringAsFixed(2)} DH'),
              ]),
              // Total
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell('SALAIRE NET À PAYER', bold: true),
                  _tableCell('${salaireNet.toStringAsFixed(2)} DH', bold: true),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          pw.Text(
            'Arrêté le présent bulletin de paie à la somme de : '
                '${salaireNet.toStringAsFixed(2)} Dirhams nets.',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Signature du collaborateur', style: pw.TextStyle(fontSize: 11)),
              pw.Text('Le Directeur Général',   style: pw.TextStyle(fontSize: 11)),
            ],
          ),

          pw.Spacer(),
          _buildFooter(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4. ATTESTATION DE SALAIRE
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> genererAttestationSalaire({
    required String nomEmploye,
    required String poste,
    required double salaireMensuel,
    required String motif,
    required String dateDocument, Uint8List? logoBytes,
  }) async {
    final logo = await _loadLogo();
    final pdf  = pw.Document();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(50, 40, 50, 40),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          _buildHeader(logo),
          pw.SizedBox(height: 30),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('El Jadida le $dateDocument',
                style: pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 30),

          pw.Center(
            child: pw.Text(
              'ATTESTATION DE SALAIRE',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _kBlue,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 30),

          pw.Text(
            'Je soussigné, le Directeur Général de la société DIGITALIZATION, INNOVATION & PROCESS SIMULATION (DIPS), atteste par la présente que :',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),

          pw.Text('M. / Mme  $nomEmploye',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Occupe le poste de : $poste',
              style: pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Perçoit un salaire mensuel net de : ${salaireMensuel.toStringAsFixed(2)} Dirhams (DH).',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'Cette attestation est délivrée à l\'intéressé(e) pour servir et valoir ce que de droit, notamment pour : $motif.',
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 50),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Le Directeur Général',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 40),
                pw.Text('Signature & Cachet',
                    style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),

          pw.Spacer(),
          _buildFooter(),
        ],
      ),
    ));

    return pdf.save();
  }

  // ─── Helpers tableau ──────────────────────────────────────────────────────
  static pw.Widget _tableCell(String text,
      {bool header = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: header ? PdfColors.white : _kBlack,
          fontWeight:
          (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _bulletinRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text('$label :',
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Text(value, style: pw.TextStyle(fontSize: 10)),
      ]),
    );
  }

  // ─── Impression / téléchargement ──────────────────────────────────────────

  /// Ouvre la boîte de dialogue d'impression/partage native
  static Future<void> imprimer(Uint8List pdfBytes, String nomFichier) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: nomFichier,
    );
  }

  /// Partage le PDF (mobile)
  static Future<void> partager(Uint8List pdfBytes, String nomFichier) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: '$nomFichier.pdf');
  }
}
