import 'package:flutter_test/flutter_test.dart';
import 'package:dips_managment/modules/pointage/services/pointage_export_service.dart';
import 'package:dips_managment/modules/shifts/models/shift_models.dart';

/// Vérifie que la feuille de pointage partagée par le chef d'équipe se génère
/// sans erreur de mise en page (logo, en-tête, tableau NOM/PRENOM/STATUT/COMMENTAIRE).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la feuille de pointage se génère', () async {
    const lines = <FeuillePointageLine>[
      (nom: 'EL-M\'GARI', prenom: 'MOHAMED', statut: 'Présent', commentaire: ''),
      (nom: 'NADI', prenom: 'RACHID', statut: 'Absent', commentaire: 'Maladie'),
      (nom: 'EL HANTATI', prenom: 'AHMED', statut: 'Présent', commentaire: 'Formation'),
    ];

    final bytes = await PointageExportService.buildFeuillePointagePdf(
      date: DateTime(2026, 8, 7),
      equipeLabel: 'Équipe 2',
      posteLabel: 'P2',
      journeeLabel: '2',
      chefName: 'EL-M\'GARI MOHAMED',
      lines: lines,
    );

    expect(bytes.length, greaterThan(1000));
  });

  test('la journée du poste est libellée « Journée 1 » / « Journée 2 »', () {
    expect(PointageExportService.feuilleJourneeTitle('1'), 'Journée 1');
    expect(PointageExportService.feuilleJourneeTitle('2'), 'Journée 2');
    expect(PointageExportService.feuilleJourneeTitle(''), '');
  });

  test('journée 1 le premier jour du poste, journée 2 le lendemain', () {
    expect(
      ShiftRotationLogic.journeeDansPoste(
        today: ShiftType.evening,
        previousDay: ShiftType.morning,
      ),
      1,
    );
    expect(
      ShiftRotationLogic.journeeDansPoste(
        today: ShiftType.evening,
        previousDay: ShiftType.evening,
      ),
      2,
    );
    expect(
      ShiftRotationLogic.journeeDansPoste(
        today: ShiftType.rest,
        previousDay: ShiftType.night,
      ),
      0,
    );
  });

  test('le titre porte la journée du poste', () {
    final name = PointageExportService.feuillePointageFileName(
      date: DateTime(2026, 8, 7),
      equipeLabel: 'Équipe 2',
      posteLabel: 'P2',
      journeeLabel: '1',
    );
    expect(name, '07-08-2026 Equipe 2 Poste 2 Journee 1.pdf');
  });

  test('le rapport partagé est titré « date equipe poste »', () {
    final name = PointageExportService.feuillePointageFileName(
      date: DateTime(2026, 8, 7),
      equipeLabel: 'Équipe 2',
      posteLabel: 'P2',
    );
    expect(name, '07-08-2026 Equipe 2 Poste 2.pdf');
  });

  test('le poste est omis du titre quand il est inconnu (repos)', () {
    final name = PointageExportService.feuillePointageFileName(
      date: DateTime(2026, 8, 7),
      equipeLabel: 'Groupe Nettoyage',
    );
    expect(name, '07-08-2026 Groupe Nettoyage.pdf');
  });

  test('les caractères interdits dans un nom de fichier sont retirés', () {
    final name = PointageExportService.feuillePointageFileName(
      date: DateTime(2026, 8, 7),
      equipeLabel: 'Équipe 2/3 : nuit',
      posteLabel: 'P3',
    );
    expect(name, '07-08-2026 Equipe 2 3 nuit Poste 3.pdf');
  });
}
