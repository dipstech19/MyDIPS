import 'package:flutter_test/flutter_test.dart';
import 'package:dips_managment/modules/employees/models/equipe_model.dart';
import 'package:dips_managment/modules/pointage/pointage_hours_config.dart';
import 'package:dips_managment/modules/shifts/models/shift_models.dart';

/// Le pointage du chef d'équipe suit le planning : une équipe inscrite à la
/// rotation prend les horaires de son poste du jour (et ses jours de repos),
/// une équipe hors planning garde ses horaires propres.
void main() {
  final equipeAvecHorairesFixes = Equipe(
    id: 'eq1',
    nom: 'EQUIPE 1',
    magasin: 'Atelier',
    chefId: 'c1',
    pointageStartHour: 8,
    pointageStartMinute: 0,
    pointageEndHour: 17,
    pointageEndMinute: 0,
  );
  final equipeSansHoraires =
      Equipe(id: 'eq2', nom: 'EQUIPE 2', magasin: 'Atelier', chefId: 'c2');
  final date = DateTime(2026, 9, 1);

  test('équipe au planning : le poste du jour prime sur les horaires fixes', () {
    final cfg = getConfigForEquipeAndDate(
        equipeAvecHorairesFixes, date, ShiftType.night);
    expect(cfg.startHour, 22);
    expect(cfg.endHour, 6);
    expect(cfg.isRestDay, isFalse);
  });

  test('équipe au planning en repos : pointage fermé même avec horaires fixes', () {
    final cfg =
        getConfigForEquipeAndDate(equipeAvecHorairesFixes, date, ShiftType.rest);
    expect(cfg.isRestDay, isTrue);
    expect(getPointageHoursStatus(DateTime(2026, 9, 1, 9), cfg),
        PointageHoursStatus.closed);
  });

  test('équipe hors planning : ses horaires propres sont conservés', () {
    final cfg = getConfigForEquipeAndDate(equipeAvecHorairesFixes, date, null);
    expect(cfg.startHour, 8);
    expect(cfg.endHour, 17);
    expect(cfg.isRestDay, isFalse);
  });

  test('équipe hors planning sans horaires : configuration par défaut, jamais repos', () {
    final cfg = getConfigForEquipeAndDate(equipeSansHoraires, date, null);
    expect(cfg.isRestDay, isFalse);
  });
}
