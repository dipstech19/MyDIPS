import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/employe_model.dart';
import '../models/document_model.dart';

class PdfService {
  static Future<Uint8List> generateEmployeePdf(Employe employe, {String? chefNom, Uint8List? photoBytes}) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    // Use a font that supports Unicode
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    
    // Try to load photo from URL or local file if not provided
    Uint8List? employeePhoto = photoBytes;
    if (employeePhoto == null && employe.photoUrl.isNotEmpty) {
      employeePhoto = await _loadPhotoFromPath(employe.photoUrl);
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => _buildHeader(employe, dateFormat.format(now), employeePhoto),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildSection('Informations Personnelles', [
            _buildInfoRow('Nom complet', employe.nom),
            _buildInfoRow('CIN', employe.cin),
            if (employe.dateNaissance.isNotEmpty)
              _buildInfoRow('Date de naissance', employe.dateNaissance),
            if (employe.adresse.isNotEmpty)
              _buildInfoRow('Adresse', employe.adresse),
            _buildInfoRow('Téléphone 1', employe.telephone),
            if (employe.telephone2.isNotEmpty)
              _buildInfoRow('Téléphone 2', employe.telephone2),
            if (employe.email.isNotEmpty)
              _buildInfoRow('Email', employe.email),
          ]),
          pw.SizedBox(height: 20),
          
          _buildSection('Informations Professionnelles', [
            _buildInfoRow('Poste', employe.poste),
            _buildInfoRow('Site', employe.siteId),
            if (employe.departement.isNotEmpty)
              _buildInfoRow('Département', employe.departement),
            if (chefNom != null && chefNom.isNotEmpty && chefNom != '—')
              _buildInfoRow('Chef direct', chefNom),
            _buildInfoRow('Type de contrat', employe.typeContrat),
            if (employe.dateDebut.isNotEmpty)
              _buildInfoRow('Date de début', employe.dateDebut),
            if (employe.finContrat.isNotEmpty)
              _buildInfoRow('Fin de contrat', employe.finContrat),
            _buildInfoRow('Salaire de base', '${employe.salaireBase.toStringAsFixed(2)} DH'),
            _buildInfoRow('Statut', employe.statut.label),
            _buildInfoRow('Badge accès', employe.badgeActif ? 'Actif' : 'Inactif'),
            if (employe.badgeExpiration.isNotEmpty)
              _buildInfoRow('Expiration badge', employe.badgeExpiration),
          ]),
          pw.SizedBox(height: 20),
          
          // Only show CNSS section if at least one field is not empty
          if (employe.cnss.isNotEmpty || employe.dateCnss.isNotEmpty)
            _buildSection('Sécurité Sociale (CNSS)', [
              if (employe.cnss.isNotEmpty)
                _buildInfoRow('Numéro CNSS', employe.cnss),
              if (employe.dateCnss.isNotEmpty)
                _buildInfoRow('Date d\'inscription', employe.dateCnss),
            ]),
          if (employe.cnss.isNotEmpty || employe.dateCnss.isNotEmpty)
            pw.SizedBox(height: 20),
          
          if (employe.documents.isNotEmpty)
            _buildSection('Documents associés', [
              ...employe.documents.map((doc) => _buildInfoRow(
                doc.categorie.label,
                '${doc.nom} (${doc.extension.toUpperCase()}) - Ajouté le ${doc.dateAjout}',
              )),
            ]),
        ],
      ),
    );
    
    return pdf.save();
  }
  
  static pw.Widget _buildHeader(Employe employe, String downloadDate, Uint8List? photoBytes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIPS',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  'Système de Gestion',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Fiche Collaborateur',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Téléchargé le: $downloadDate',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.blue800, thickness: 2),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              // Photo or initial
              photoBytes != null
                  ? pw.ClipOval(
                      child: pw.Image(
                        pw.MemoryImage(photoBytes),
                        width: 60,
                        height: 60,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  : pw.Container(
                      width: 60,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue800,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          employe.nom.isNotEmpty ? employe.nom[0].toUpperCase() : '?',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ),
              pw.SizedBox(width: 12),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    employe.nom,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${employe.poste} - ${employe.siteId}',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }
  
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Document généré automatiquement par DIPS',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
  
  static Future<void> printEmployeePdf(Employe employe, {String? chefNom, Uint8List? photoBytes}) async {
    final pdfData = await generateEmployeePdf(employe, chefNom: chefNom, photoBytes: photoBytes);
    await Printing.layoutPdf(onLayout: (_) => pdfData);
  }
  
  static Future<void> shareEmployeePdf(Employe employe, {String? chefNom, Uint8List? photoBytes}) async {
    final pdfData = await generateEmployeePdf(employe, chefNom: chefNom, photoBytes: photoBytes);
    await Printing.sharePdf(
      bytes: pdfData,
      filename: 'employe_${employe.cin}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
  
  /// Helper to load photo from either URL or local file path
  static Future<Uint8List?> _loadPhotoFromPath(String path) async {
    if (path.isEmpty) return null;
    
    try {
      // Check if it's a network URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(path))
            .timeout(const Duration(seconds: 25), onTimeout: () => throw TimeoutException('photo_url'));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } 
      // Check if it's a local file path (Windows or Unix)
      else if (path.contains(':\\') || path.contains(':/') || path.startsWith('/')) {
        if (!kIsWeb) {
          final file = File(path);
          if (await file.exists()) {
            return await file.readAsBytes();
          }
        }
      }
    } catch (e) {
      debugPrint('PdfService: Error loading photo from $path: $e');
    }
    
    return null;
  }
}
